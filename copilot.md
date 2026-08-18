# copilot.md
# DGP ERP Carton - Prompt cho VS Code + GitHub Copilot Agent / Copilot CLI

## 0. Mục tiêu
Bạn là GitHub Copilot Agent chạy trong VS Code hoặc Copilot CLI. Hãy xây dựng một hệ thống ERP carton hoàn chỉnh cho DONA GREEN PACK.

Hệ thống phải gồm:

- Azure SQL Database
- ASP.NET Core 8 WebApp + Web API
- Bootstrap UI hoặc Blazor Server/Razor Pages
- Dapper để gọi Stored Procedure
- Swagger/OpenAPI cho Power Apps Custom Connector
- Local Windows Print Agent Service để in tem Zebra qua IP LAN hoặc USB/Windows Printer
- Dashboard, báo cáo, toàn bộ giao diện nghiệp vụ
- Logic sản xuất carton gồm: đơn thùng, đơn giấy tấm, catalog kỹ thuật, BOM single sheet, kế hoạch chạy sóng, inventory, WIP, print queue, revise/cancel order

Tên project:

```text
DGP.ERP
```

Tên doanh nghiệp mẫu:

```text
DONA GREEN PACK
```

---

## 1. Kiến trúc tổng thể

```text
WebApp ERP Admin
        ↓
ASP.NET Core API
        ↓
Azure SQL Database
        ↓
PrintQueue
        ↓
Local Windows Print Agent
        ↓
Zebra Printer IP LAN hoặc USB/Windows Printer
```

Power Apps dùng cho mobile tại xưởng/kho:

```text
Power Apps Mobile
        ↓
Custom Connector
        ↓
ASP.NET Core API
```

Quy tắc bắt buộc:

- Power Apps không được kết nối SQL trực tiếp.
- WebApp và Power Apps đều phải gọi API.
- Inventory, WIP, Wave Planning, Print Queue phải xử lý bằng stored procedure.
- Không hard-code printer IP, warehouse, machine width trong code. Tất cả lấy từ database.

---

## 2. Công nghệ yêu cầu

- .NET 8 hoặc mới hơn
- ASP.NET Core WebApp + Web API
- Razor Pages hoặc Blazor Server cho UI quản trị
- Bootstrap 5 cho giao diện
- Azure SQL compatible T-SQL
- Dapper cho data access
- Swagger/OpenAPI
- Windows Worker Service cho Local Print Agent
- Serilog hoặc built-in logging
- appsettings.json sử dụng connection string placeholder

---

## 3. Cấu trúc solution cần tạo

```text
DGP.ERP/
  copilot.md
  DGP.ERP.sln

  src/
    DGP.Api/
      Controllers/
      Pages/ hoặc Components/
      Services/
      Repositories/
      DTOs/
      Models/
      ViewModels/
      Program.cs
      appsettings.json

    DGP.PrintAgent/
      Worker.cs
      PrinterServices/
        IPrinterService.cs
        IpZebraPrinterService.cs
        WindowsRawPrinterService.cs
        RawPrinterHelper.cs
      Models/
      Program.cs
      appsettings.json

  database/
    001_create_tables.sql
    002_create_indexes.sql
    003_create_stored_procedures.sql
    004_seed_data.sql
    005_test_cases.sql

  docs/
    erd.md
    api.md
    powerapps-guide.md
    print-agent-guide.md
    deployment-azure.md
    user-flow.md
```

---

## 4. Nguyên tắc nghiệp vụ quan trọng

### 4.1 Catalog là nguồn kỹ thuật chuẩn

Khi người dùng chọn hoặc nhập mã hàng, ví dụ:

```text
HN001
```

Hệ thống phải lookup catalog để lấy:

- Dài x Rộng x Cao
- Sóng
- Mã khuôn bế
- Số màu in
- Ghi chú in
- Loại keo
- SingleSheetLengthMM
- SingleSheetWidthMM
- SheetPerBox
- LossRate

Không tính Single Sheet từ công thức Dài x Rộng x Cao trong nghiệp vụ chính. Single Sheet là dữ liệu kỹ thuật chuẩn trong `ItemRecipeSheet`.

### 4.2 BoxSpec và SheetSpec là snapshot

Khi tạo dòng đơn hàng, dữ liệu kỹ thuật phải copy từ catalog vào snapshot:

- `BoxSpec` cho đơn thùng
- `SheetSpec` cho đơn giấy tấm

Nếu catalog đổi sau này, đơn hàng cũ không bị thay đổi.

### 4.3 Không tách kho giấy tấm và kho thùng thành 2 hệ thống riêng

Dùng chung:

- `ItemMaster`
- `InventoryTransaction`
- `InventoryBalance`

Phân biệt bằng:

- `ItemType`
- `WarehouseType`
- `TransactionType`
- `RefType`
- `RefID`

### 4.4 Không cập nhật tồn kho trực tiếp

Mọi biến động kho phải đi qua:

```text
InventoryTransaction
        ↓
InventoryBalance
```

Controller không được update `InventoryBalance` trực tiếp.

### 4.5 WIP tách khỏi Inventory

Inventory là tồn vật lý trong kho:

- Giấy cuộn
- Giấy tấm bán thành phẩm
- Thùng thành phẩm

WIP là hàng đang nằm tại công đoạn:

- PRINT
- DIECUT
- GLUE
- PACKING

Dùng riêng:

- `WIPTransaction`
- `WIPBalance`

### 4.6 WaveRequirement sinh tự động

Không nhập tay `WaveRequirement`.

WaveRequirement sinh từ:

```text
ProductionOrder
+ ItemRecipeSheet
+ CorrugatorLayoutCandidate best
```

### 4.7 WavePlan là kế hoạch máy sóng

WavePlan không thuộc một đơn hàng riêng. WavePlan có thể gom nhiều `WaveRequirement` cùng:

- MachineCode
- FluteCode
- RunWidthMM

### 4.8 Sửa/xóa đơn hàng phải theo trạng thái

Không cho delete bừa bãi khi đã phát sinh LSX/Wave/Inventory/WIP.

Quy tắc:

```text
Draft
  - Cho sửa header
  - Cho sửa line
  - Cho xóa line
  - Cho xóa đơn thật nếu chưa có phát sinh

Confirmed
  - Không cho xóa thật
  - Không cho sửa ItemCode trực tiếp
  - Cho Create Revision

Has ProductionOrder
  - Không xóa
  - Cho Cancel Line nếu chưa có WavePlan/Inventory

Has WaveRequirement
  - Nếu sửa qty thì phải cancel WaveRequirement cũ và regenerate

Has WavePlan
  - Lock line
  - Muốn sửa phải remove khỏi WavePlan trước

Produced hoặc có InventoryTransaction/WIPTransaction
  - Lock
  - Chỉ cho Adjustment/Return/Credit/Cancel bằng chứng từ đảo
```

---

## 5. Database schema bắt buộc

Tạo toàn bộ bảng dưới đây bằng Azure SQL compatible T-SQL.

### 5.1 Customer

```sql
CREATE TABLE dbo.Customer
(
    CustomerID BIGINT IDENTITY(1,1) PRIMARY KEY,
    CustomerCode NVARCHAR(50) NOT NULL UNIQUE,
    CustomerName NVARCHAR(255) NOT NULL,
    TaxCode NVARCHAR(50) NULL,
    Address NVARCHAR(500) NULL,
    Phone NVARCHAR(50) NULL,
    Email NVARCHAR(255) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
```

### 5.2 ItemMaster

```sql
CREATE TABLE dbo.ItemMaster
(
    ItemID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ItemCode NVARCHAR(100) NOT NULL UNIQUE,
    ItemName NVARCHAR(255) NOT NULL,
    ItemType NVARCHAR(30) NOT NULL,
    Unit NVARCHAR(20) NOT NULL DEFAULT 'PCS',
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
```

ItemType:

```text
ROLL
SHEET
BOX
PALLET
MATERIAL
```

### 5.3 ItemCatalogBox

```sql
CREATE TABLE dbo.ItemCatalogBox
(
    ItemID BIGINT PRIMARY KEY,
    ItemCode NVARCHAR(100) NOT NULL,
    ItemName NVARCHAR(255) NOT NULL,
    LengthMM DECIMAL(18,2) NOT NULL,
    WidthMM DECIMAL(18,2) NOT NULL,
    HeightMM DECIMAL(18,2) NOT NULL,
    FluteCode NVARCHAR(20) NOT NULL,
    DieCutCode NVARCHAR(100) NULL,
    PrintColor INT NULL,
    PrintNote NVARCHAR(500) NULL,
    GlueType NVARCHAR(50) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_ItemCatalogBox_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID)
);
```

Relationship:

```text
ItemMaster 1:1 ItemCatalogBox
```

### 5.4 ItemRecipeSheet

```sql
CREATE TABLE dbo.ItemRecipeSheet
(
    RecipeSheetID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ItemID BIGINT NOT NULL,
    RecipeVersion NVARCHAR(30) NOT NULL DEFAULT 'V1',
    IsDefault BIT NOT NULL DEFAULT 1,
    SheetItemCode NVARCHAR(100) NULL,
    FluteCode NVARCHAR(20) NOT NULL,
    SingleSheetLengthMM DECIMAL(18,2) NOT NULL,
    SingleSheetWidthMM DECIMAL(18,2) NOT NULL,
    SheetPerBox DECIMAL(18,4) NOT NULL DEFAULT 1,
    LossRate DECIMAL(18,4) NOT NULL DEFAULT 0,
    PreferredMachineCode NVARCHAR(50) NULL,
    PreferredLaneCount INT NULL,
    PreferredRunWidthMM DECIMAL(18,2) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_ItemRecipeSheet_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID)
);
```

Relationship:

```text
ItemMaster 1:N ItemRecipeSheet
```

### 5.5 SalesOrder

```sql
CREATE TABLE dbo.SalesOrder
(
    SalesOrderID BIGINT IDENTITY(1,1) PRIMARY KEY,
    SalesOrderNo NVARCHAR(50) NOT NULL,
    CustomerID BIGINT NOT NULL,
    OrderDate DATE NOT NULL,
    RequiredDate DATE NULL,
    Status NVARCHAR(30) NOT NULL DEFAULT 'Draft',
    VersionNo INT NOT NULL DEFAULT 1,
    ParentSalesOrderID BIGINT NULL,
    IsCurrentVersion BIT NOT NULL DEFAULT 1,
    Note NVARCHAR(MAX) NULL,
    CreatedBy NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_SalesOrder_Customer FOREIGN KEY (CustomerID) REFERENCES dbo.Customer(CustomerID),
    CONSTRAINT FK_SalesOrder_Parent FOREIGN KEY (ParentSalesOrderID) REFERENCES dbo.SalesOrder(SalesOrderID)
);
```

Add unique index:

```text
SalesOrderNo + VersionNo
```

Status:

```text
Draft
Confirmed
InProduction
Completed
Cancelled
```

### 5.6 SalesOrderLine

```sql
CREATE TABLE dbo.SalesOrderLine
(
    LineID BIGINT IDENTITY(1,1) PRIMARY KEY,
    SalesOrderID BIGINT NOT NULL,
    ItemID BIGINT NOT NULL,
    ProductType NVARCHAR(20) NOT NULL,
    Quantity DECIMAL(18,2) NOT NULL,
    Unit NVARCHAR(20) NOT NULL DEFAULT 'PCS',
    UnitPrice DECIMAL(18,2) NULL,
    LineStatus NVARCHAR(30) NOT NULL DEFAULT 'Open',
    CancelReason NVARCHAR(500) NULL,
    Note NVARCHAR(MAX) NULL,
    CONSTRAINT FK_SOLine_SO FOREIGN KEY (SalesOrderID) REFERENCES dbo.SalesOrder(SalesOrderID),
    CONSTRAINT FK_SOLine_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID)
);
```

ProductType:

```text
BOX
SHEET
```

LineStatus:

```text
Open
Planned
InProduction
Completed
Cancelled
Locked
```

### 5.7 BoxSpec Snapshot

```sql
CREATE TABLE dbo.BoxSpec
(
    LineID BIGINT PRIMARY KEY,
    LengthMM DECIMAL(18,2) NOT NULL,
    WidthMM DECIMAL(18,2) NOT NULL,
    HeightMM DECIMAL(18,2) NOT NULL,
    FluteCode NVARCHAR(20) NOT NULL,
    DieCutCode NVARCHAR(100) NULL,
    PrintColor INT NULL,
    PrintNote NVARCHAR(500) NULL,
    GlueType NVARCHAR(50) NULL,
    CONSTRAINT FK_BoxSpec_SOLine FOREIGN KEY (LineID) REFERENCES dbo.SalesOrderLine(LineID)
);
```

### 5.8 SheetSpec Snapshot

```sql
CREATE TABLE dbo.SheetSpec
(
    LineID BIGINT PRIMARY KEY,
    FluteCode NVARCHAR(20) NOT NULL,
    SingleSheetLengthMM DECIMAL(18,2) NOT NULL,
    SingleSheetWidthMM DECIMAL(18,2) NOT NULL,
    LossRate DECIMAL(18,4) NOT NULL DEFAULT 0,
    CONSTRAINT FK_SheetSpec_SOLine FOREIGN KEY (LineID) REFERENCES dbo.SalesOrderLine(LineID)
);
```

### 5.9 SalesOrderAudit

```sql
CREATE TABLE dbo.SalesOrderAudit
(
    AuditID BIGINT IDENTITY(1,1) PRIMARY KEY,
    SalesOrderID BIGINT NOT NULL,
    LineID BIGINT NULL,
    ActionType NVARCHAR(50) NOT NULL,
    OldValue NVARCHAR(MAX) NULL,
    NewValue NVARCHAR(MAX) NULL,
    Reason NVARCHAR(500) NULL,
    CreatedBy NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_SalesOrderAudit_SO FOREIGN KEY (SalesOrderID) REFERENCES dbo.SalesOrder(SalesOrderID)
);
```

ActionType:

```text
CREATE
UPDATE
DELETE_DRAFT
CONFIRM
CREATE_REVISION
CANCEL_LINE
CANCEL_ORDER
LOCK
UNLOCK
```

### 5.10 CorrugatorMachine

```sql
CREATE TABLE dbo.CorrugatorMachine
(
    MachineID BIGINT IDENTITY(1,1) PRIMARY KEY,
    MachineCode NVARCHAR(50) NOT NULL UNIQUE,
    MachineName NVARCHAR(100) NOT NULL,
    MinRunWidthMM DECIMAL(18,2) NOT NULL,
    MaxRunWidthMM DECIMAL(18,2) NOT NULL,
    WidthStepMM DECIMAL(18,2) NOT NULL DEFAULT 50,
    EdgeTrimMM DECIMAL(18,2) NOT NULL DEFAULT 20,
    IsActive BIT NOT NULL DEFAULT 1
);
```

### 5.11 CorrugatorAllowedWidth

```sql
CREATE TABLE dbo.CorrugatorAllowedWidth
(
    AllowedWidthID BIGINT IDENTITY(1,1) PRIMARY KEY,
    MachineID BIGINT NOT NULL,
    RunWidthMM DECIMAL(18,2) NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT FK_CorrWidth_Machine FOREIGN KEY (MachineID) REFERENCES dbo.CorrugatorMachine(MachineID),
    CONSTRAINT UQ_CorrWidth UNIQUE (MachineID, RunWidthMM)
);
```

Seed khổ `1250` đến `2500`, bước `50`, cho máy `SONG_2500`.

### 5.12 ProductionOrder

```sql
CREATE TABLE dbo.ProductionOrder
(
    ProductionOrderID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ProductionOrderNo NVARCHAR(50) NOT NULL UNIQUE,
    LineID BIGINT NOT NULL,
    ItemID BIGINT NOT NULL,
    ProductType NVARCHAR(20) NOT NULL,
    PlannedQty DECIMAL(18,2) NOT NULL,
    ProducedQty DECIMAL(18,2) NOT NULL DEFAULT 0,
    Status NVARCHAR(30) NOT NULL DEFAULT 'Created',
    CreatedBy NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_PO_SOLine FOREIGN KEY (LineID) REFERENCES dbo.SalesOrderLine(LineID),
    CONSTRAINT FK_PO_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID)
);
```

Status:

```text
Created
WaveRequired
Planned
InProduction
Completed
Cancelled
```

### 5.13 CorrugatorLayoutCandidate

```sql
CREATE TABLE dbo.CorrugatorLayoutCandidate
(
    CandidateID BIGINT IDENTITY(1,1) PRIMARY KEY,
    RecipeSheetID BIGINT NULL,
    MachineID BIGINT NOT NULL,
    SingleSheetLengthMM DECIMAL(18,2) NOT NULL,
    SingleSheetWidthMM DECIMAL(18,2) NOT NULL,
    LaneCount INT NOT NULL,
    WidthUsedMM DECIMAL(18,2) NOT NULL,
    EdgeTrimMM DECIMAL(18,2) NOT NULL,
    RawNeedWidthMM DECIMAL(18,2) NOT NULL,
    RunWidthMM DECIMAL(18,2) NOT NULL,
    TotalWasteWidthMM DECIMAL(18,2) NOT NULL,
    ExtraWasteWidthMM DECIMAL(18,2) NOT NULL,
    WidthUtilization DECIMAL(18,6) NOT NULL,
    RequiredSheetQty DECIMAL(18,2) NULL,
    RequiredCutCount DECIMAL(18,2) NULL,
    ProducedSheetQty DECIMAL(18,2) NULL,
    OverQty DECIMAL(18,2) NULL,
    RunningLengthM DECIMAL(18,2) NULL,
    Score DECIMAL(18,6) NOT NULL,
    IsBest BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Candidate_Machine FOREIGN KEY (MachineID) REFERENCES dbo.CorrugatorMachine(MachineID),
    CONSTRAINT FK_Candidate_RecipeSheet FOREIGN KEY (RecipeSheetID) REFERENCES dbo.ItemRecipeSheet(RecipeSheetID)
);
```

### 5.14 WaveRequirement

```sql
CREATE TABLE dbo.WaveRequirement
(
    WaveReqID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ProductionOrderID BIGINT NOT NULL,
    SourceLineID BIGINT NOT NULL,
    ProductType NVARCHAR(20) NOT NULL,
    ItemID BIGINT NOT NULL,
    RecipeSheetID BIGINT NULL,
    FluteCode NVARCHAR(20) NOT NULL,
    SingleSheetLengthMM DECIMAL(18,2) NOT NULL,
    SingleSheetWidthMM DECIMAL(18,2) NOT NULL,
    LaneCount INT NULL,
    RunWidthMM DECIMAL(18,2) NULL,
    WidthUsedMM DECIMAL(18,2) NULL,
    EdgeTrimMM DECIMAL(18,2) NULL,
    WidthUtilization DECIMAL(18,6) NULL,
    LayoutCandidateID BIGINT NULL,
    RequiredQty DECIMAL(18,2) NOT NULL,
    CutCount DECIMAL(18,2) NULL,
    PlannedSheetQty DECIMAL(18,2) NOT NULL DEFAULT 0,
    ProducedQty DECIMAL(18,2) NOT NULL DEFAULT 0,
    IssuedQty DECIMAL(18,2) NOT NULL DEFAULT 0,
    OverQty DECIMAL(18,2) NULL,
    RunningLengthM DECIMAL(18,2) NULL,
    Status NVARCHAR(30) NOT NULL DEFAULT 'Open',
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_WaveReq_PO FOREIGN KEY (ProductionOrderID) REFERENCES dbo.ProductionOrder(ProductionOrderID),
    CONSTRAINT FK_WaveReq_Line FOREIGN KEY (SourceLineID) REFERENCES dbo.SalesOrderLine(LineID),
    CONSTRAINT FK_WaveReq_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID),
    CONSTRAINT FK_WaveReq_RecipeSheet FOREIGN KEY (RecipeSheetID) REFERENCES dbo.ItemRecipeSheet(RecipeSheetID),
    CONSTRAINT FK_WaveReq_Candidate FOREIGN KEY (LayoutCandidateID) REFERENCES dbo.CorrugatorLayoutCandidate(CandidateID)
);
```

Status:

```text
Open
Planned
Running
Completed
Cancelled
Locked
```

### 5.15 WavePlan

```sql
CREATE TABLE dbo.WavePlan
(
    WavePlanID BIGINT IDENTITY(1,1) PRIMARY KEY,
    WavePlanNo NVARCHAR(50) NOT NULL UNIQUE,
    PlanDate DATE NOT NULL,
    MachineCode NVARCHAR(50) NOT NULL,
    FluteCode NVARCHAR(20) NOT NULL,
    RunWidthMM DECIMAL(18,2) NOT NULL,
    TotalPlannedSheetQty DECIMAL(18,2) NOT NULL DEFAULT 0,
    TotalCutCount DECIMAL(18,2) NOT NULL DEFAULT 0,
    TotalRunningLengthM DECIMAL(18,2) NOT NULL DEFAULT 0,
    Status NVARCHAR(30) NOT NULL DEFAULT 'Planned',
    CreatedBy NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
```

### 5.16 WavePlanDetail

```sql
CREATE TABLE dbo.WavePlanDetail
(
    WavePlanDetailID BIGINT IDENTITY(1,1) PRIMARY KEY,
    WavePlanID BIGINT NOT NULL,
    WaveReqID BIGINT NOT NULL,
    SingleSheetLengthMM DECIMAL(18,2) NOT NULL,
    SingleSheetWidthMM DECIMAL(18,2) NOT NULL,
    LaneCount INT NOT NULL,
    RunWidthMM DECIMAL(18,2) NOT NULL,
    RequiredSheetQty DECIMAL(18,2) NOT NULL,
    CutCount DECIMAL(18,2) NOT NULL,
    PlannedSheetQty DECIMAL(18,2) NOT NULL,
    ProducedSheetQty DECIMAL(18,2) NOT NULL DEFAULT 0,
    OverQty DECIMAL(18,2) NOT NULL DEFAULT 0,
    RunningLengthM DECIMAL(18,2) NULL,
    WidthUtilization DECIMAL(18,6) NULL,
    CONSTRAINT FK_WavePlanDetail_Plan FOREIGN KEY (WavePlanID) REFERENCES dbo.WavePlan(WavePlanID),
    CONSTRAINT FK_WavePlanDetail_Req FOREIGN KEY (WaveReqID) REFERENCES dbo.WaveRequirement(WaveReqID)
);
```

### 5.17 Warehouse, InventoryTransaction, InventoryBalance

```sql
CREATE TABLE dbo.Warehouse
(
    WarehouseID BIGINT IDENTITY(1,1) PRIMARY KEY,
    WarehouseCode NVARCHAR(50) NOT NULL UNIQUE,
    WarehouseName NVARCHAR(100) NOT NULL,
    WarehouseType NVARCHAR(30) NULL,
    IsActive BIT NOT NULL DEFAULT 1
);

CREATE TABLE dbo.InventoryTransaction
(
    TransID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ItemID BIGINT NOT NULL,
    WarehouseID BIGINT NOT NULL,
    TransactionType NVARCHAR(50) NOT NULL,
    Qty DECIMAL(18,2) NOT NULL,
    Unit NVARCHAR(20) NOT NULL DEFAULT 'PCS',
    RefType NVARCHAR(50) NULL,
    RefID BIGINT NULL,
    RefNo NVARCHAR(100) NULL,
    LotNo NVARCHAR(100) NULL,
    PalletNo NVARCHAR(100) NULL,
    Note NVARCHAR(MAX) NULL,
    CreatedBy NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_InvTrans_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID),
    CONSTRAINT FK_InvTrans_Wh FOREIGN KEY (WarehouseID) REFERENCES dbo.Warehouse(WarehouseID)
);

CREATE TABLE dbo.InventoryBalance
(
    BalanceID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ItemID BIGINT NOT NULL,
    WarehouseID BIGINT NOT NULL,
    LotNo NVARCHAR(100) NULL,
    PalletNo NVARCHAR(100) NULL,
    QtyOnHand DECIMAL(18,2) NOT NULL DEFAULT 0,
    ReservedQty DECIMAL(18,2) NOT NULL DEFAULT 0,
    AvailableQty AS (QtyOnHand - ReservedQty),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_InvBal_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID),
    CONSTRAINT FK_InvBal_Wh FOREIGN KEY (WarehouseID) REFERENCES dbo.Warehouse(WarehouseID),
    CONSTRAINT UQ_InvBal UNIQUE (ItemID, WarehouseID, LotNo, PalletNo)
);
```

TransactionType:

```text
WAVE_RECEIPT
ISSUE_TO_PRINT
FG_RECEIPT
SALE_ISSUE
TRANSFER_IN
TRANSFER_OUT
ADJUSTMENT_IN
ADJUSTMENT_OUT
SCRAP_OUT
RETURN_IN
```

### 5.18 WIP tables

```sql
CREATE TABLE dbo.WIPStage
(
    StageID BIGINT IDENTITY(1,1) PRIMARY KEY,
    StageCode NVARCHAR(50) NOT NULL UNIQUE,
    StageName NVARCHAR(100) NOT NULL,
    SortOrder INT NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1
);

CREATE TABLE dbo.WIPTransaction
(
    WIPTransID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ProductionOrderID BIGINT NOT NULL,
    StageID BIGINT NOT NULL,
    ItemID BIGINT NULL,
    WIPTransType NVARCHAR(50) NOT NULL,
    Qty DECIMAL(18,2) NOT NULL,
    Unit NVARCHAR(20) NOT NULL DEFAULT 'PCS',
    FromStageID BIGINT NULL,
    ToStageID BIGINT NULL,
    RefType NVARCHAR(50) NULL,
    RefID BIGINT NULL,
    Note NVARCHAR(MAX) NULL,
    CreatedBy NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_WIPTrans_PO FOREIGN KEY (ProductionOrderID) REFERENCES dbo.ProductionOrder(ProductionOrderID),
    CONSTRAINT FK_WIPTrans_Stage FOREIGN KEY (StageID) REFERENCES dbo.WIPStage(StageID),
    CONSTRAINT FK_WIPTrans_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID),
    CONSTRAINT FK_WIPTrans_FromStage FOREIGN KEY (FromStageID) REFERENCES dbo.WIPStage(StageID),
    CONSTRAINT FK_WIPTrans_ToStage FOREIGN KEY (ToStageID) REFERENCES dbo.WIPStage(StageID)
);

CREATE TABLE dbo.WIPBalance
(
    WIPBalanceID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ProductionOrderID BIGINT NOT NULL,
    StageID BIGINT NOT NULL,
    ItemID BIGINT NULL,
    QtyInStage DECIMAL(18,2) NOT NULL DEFAULT 0,
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_WIPBal_PO FOREIGN KEY (ProductionOrderID) REFERENCES dbo.ProductionOrder(ProductionOrderID),
    CONSTRAINT FK_WIPBal_Stage FOREIGN KEY (StageID) REFERENCES dbo.WIPStage(StageID),
    CONSTRAINT FK_WIPBal_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID),
    CONSTRAINT UQ_WIPBal UNIQUE (ProductionOrderID, StageID, ItemID)
);
```

WIPTransType:

```text
START_STAGE
FINISH_STAGE
MOVE_STAGE
SCRAP
REWORK
```

### 5.19 PrinterList, PrintQueue

```sql
CREATE TABLE dbo.PrinterList
(
    PrinterCode NVARCHAR(50) PRIMARY KEY,
    PrinterName NVARCHAR(100) NOT NULL,
    PrinterType NVARCHAR(30) NOT NULL DEFAULT 'ZEBRA',
    ConnectionType NVARCHAR(20) NOT NULL,
    PrinterIP NVARCHAR(50) NULL,
    PrinterPort INT NULL,
    WindowsPrinterName NVARCHAR(255) NULL,
    LocationName NVARCHAR(100) NULL,
    IsActive BIT NOT NULL DEFAULT 1
);

CREATE TABLE dbo.PrintQueue
(
    PrintID BIGINT IDENTITY(1,1) PRIMARY KEY,
    PrinterCode NVARCHAR(50) NOT NULL,
    LabelType NVARCHAR(50) NOT NULL,
    RefType NVARCHAR(50) NULL,
    RefID BIGINT NULL,
    ZPL NVARCHAR(MAX) NOT NULL,
    Status NVARCHAR(30) NOT NULL DEFAULT 'Pending',
    RetryCount INT NOT NULL DEFAULT 0,
    MaxRetry INT NOT NULL DEFAULT 3,
    ErrorMessage NVARCHAR(MAX) NULL,
    CreatedBy NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ProcessingAt DATETIME2 NULL,
    PrintedAt DATETIME2 NULL,
    CONSTRAINT FK_PrintQueue_Printer FOREIGN KEY (PrinterCode) REFERENCES dbo.PrinterList(PrinterCode)
);
```

ConnectionType:

```text
IP
USB
WINDOWS_PRINTER
```

Print Status:

```text
Pending
Processing
Printed
Failed
Cancelled
```

---

## 6. Stored procedures bắt buộc

Tạo đầy đủ stored procedures sau.

### 6.1 usp_GetItemCatalogForOrder

Input:

```text
@ItemCode
```

Output:

- ItemID
- ItemCode
- ItemName
- ItemType
- LengthMM
- WidthMM
- HeightMM
- FluteCode
- DieCutCode
- PrintColor
- PrintNote
- GlueType
- SingleSheetLengthMM
- SingleSheetWidthMM
- SheetPerBox
- LossRate

### 6.2 usp_CreateSalesOrderLineBoxFromCatalog

Logic:

1. Validate SalesOrder status = Draft hoặc Open.
2. Lookup `ItemMaster`, `ItemCatalogBox`, default `ItemRecipeSheet`.
3. Insert `SalesOrderLine` ProductType = BOX.
4. Insert `BoxSpec` snapshot.
5. Insert audit.
6. Return LineID.

### 6.3 usp_UpdateSalesOrderDraft

Cho sửa đơn khi Status = Draft.

### 6.4 usp_DeleteSalesOrderDraft

Chỉ xóa thật khi:

- SalesOrder.Status = Draft
- Chưa có ProductionOrder
- Chưa có InventoryTransaction
- Chưa có WIPTransaction

### 6.5 usp_ConfirmSalesOrder

Chuyển Draft/Open sang Confirmed.

### 6.6 usp_CreateSalesOrderRevision

Khi đơn đã Confirmed hoặc InProduction, không sửa trực tiếp. Tạo version mới:

- Copy SalesOrder
- Copy Lines
- Copy BoxSpec/SheetSpec
- ParentSalesOrderID = bản cũ
- VersionNo = bản cũ + 1
- IsCurrentVersion = 1 cho bản mới
- IsCurrentVersion = 0 cho bản cũ
- Insert Audit

### 6.7 usp_CancelSalesOrderLine

Cho cancel line nếu chưa có WavePlan hoặc Inventory/WIP phát sinh.

### 6.8 usp_CreateProductionOrderFromSalesOrderLine

Logic:

1. Validate line chưa cancelled.
2. Create ProductionOrder.
3. Call `usp_CreateWaveRequirementFromCatalog`.
4. Update SalesOrderLine.LineStatus.
5. Return ProductionOrderID, WaveReqID.

### 6.9 usp_SuggestCorrugatorLayout_Grid

Input:

- MachineCode
- SingleSheetWidthMM
- SingleSheetLengthMM
- RequiredSheetQty
- RecipeSheetID nullable

Logic:

```text
For LaneCount from 1 to max:
  WidthUsed = SingleSheetWidthMM * LaneCount
  RawNeed = WidthUsed + EdgeTrim
  RunWidth = smallest allowed width >= RawNeed
  If no RunWidth, skip
  CutCount = CEILING(RequiredSheetQty / LaneCount)
  ProducedSheetQty = CutCount * LaneCount
  OverQty = ProducedSheetQty - RequiredSheetQty
  RunningLengthM = CutCount * SingleSheetLengthMM / 1000
  Utilization = WidthUsed / RunWidth
  Score = Utilization * 100 - over penalty - extra waste penalty + lane bonus
```

Example:

```text
SingleSheetWidth = 500
SingleSheetLength = 1250
RequiredQty = 10500
EdgeTrim = 20
Allowed Width = 1250..2500 step 50
Best = Lane 4, RunWidth 2050, CutCount 2625, RunningLengthM 3281.25
```

### 6.10 usp_CreateWaveRequirementFromCatalog

Logic:

1. Read ProductionOrder.
2. Read default ItemRecipeSheet.
3. RequiredQty = CEILING(PlannedQty * SheetPerBox * (1 + LossRate)).
4. Call optimizer.
5. Insert WaveRequirement with Best Candidate.

### 6.11 usp_CreateWavePlanFromRequirements

Logic:

1. Validate all WaveReq open.
2. Validate same MachineCode/FluteCode/RunWidthMM or compatible grouping.
3. Create WavePlan.
4. Insert WavePlanDetail.
5. Sum totals.
6. Set WaveRequirement.Status = Planned.

### 6.12 usp_WaveReceipt

Logic:

1. Insert InventoryTransaction WAVE_RECEIPT.
2. Update InventoryBalance.
3. Update WavePlan/WavePlanDetail/WaveRequirement produced qty.
4. Create PrintQueue sheet label if requested.

### 6.13 usp_IssueSheetToPrint

Logic:

1. Insert InventoryTransaction ISSUE_TO_PRINT qty negative.
2. Decrease InventoryBalance.
3. Insert WIPTransaction START_STAGE PRINT.
4. Increase WIPBalance PRINT.

### 6.14 usp_FinishStage

Logic:

1. Insert WIPTransaction FINISH_STAGE.
2. Insert SCRAP if ScrapQty > 0.
3. Update WIPBalance current stage.
4. Move to next stage if requested.

### 6.15 usp_FGReceipt

Logic:

1. Insert InventoryTransaction FG_RECEIPT qty positive.
2. Update InventoryBalance.
3. Update ProductionOrder.ProducedQty.
4. Decrease WIPBalance final stage.
5. Create PrintQueue FG label if requested.

### 6.16 usp_SaleIssue

Dùng cho cả bán giấy tấm và bán thùng.

Logic:

1. Insert InventoryTransaction SALE_ISSUE qty negative.
2. Update InventoryBalance.
3. No separate sheet/box issue table.

### 6.17 usp_CreatePrintQueue

Logic:

1. Validate Printer active.
2. Insert PrintQueue Pending.
3. Return PrintID.

### 6.18 usp_ReprintLabel

Logic:

1. Copy old ZPL to new PrintQueue row.
2. Status Pending.
3. Keep old row unchanged.

---

## 7. API Controllers cần tạo

### 7.1 ItemController

```http
GET /api/items/catalog/{itemCode}
GET /api/items?keyword=&page=&pageSize=
POST /api/items
PUT /api/items/{id}
```

### 7.2 CatalogController

```http
GET /api/item-catalog-box/{itemCode}
POST /api/item-catalog-box
PUT /api/item-catalog-box/{itemId}

GET /api/item-recipe-sheet/{itemCode}
POST /api/item-recipe-sheet
PUT /api/item-recipe-sheet/{id}
POST /api/item-recipe-sheet/{id}/suggest-layout
```

### 7.3 SalesOrderController

```http
GET /api/sales-orders?page=&pageSize=&keyword=
GET /api/sales-orders/{id}
POST /api/sales-orders
PUT /api/sales-orders/{id}/draft
DELETE /api/sales-orders/{id}/draft
POST /api/sales-orders/{id}/confirm
POST /api/sales-orders/{id}/revision
POST /api/sales-orders/{id}/lines/box-from-catalog
POST /api/sales-orders/{id}/lines/sheet
POST /api/sales-order-lines/{lineId}/cancel
```

### 7.4 ProductionController

```http
GET /api/production-orders
GET /api/production-orders/{id}
POST /api/production/create-from-line/{lineId}
POST /api/production-orders/{id}/generate-wave-requirement
POST /api/production-orders/{id}/issue-to-print
POST /api/production-orders/{id}/finish-stage
POST /api/production-orders/{id}/fg-receipt
```

### 7.5 WaveController

```http
GET /api/wave/requirements/open
GET /api/wave/requirements/{id}
GET /api/wave/requirements/{id}/layout-candidates
POST /api/wave/layout/suggest
POST /api/wave/plans
GET /api/wave/plans
GET /api/wave/plans/{id}
POST /api/wave/plans/{id}/receipt
```

### 7.6 InventoryController

```http
GET /api/inventory/balance
GET /api/inventory/transactions
POST /api/inventory/issue-to-print
POST /api/inventory/fg-receipt
POST /api/inventory/sale-issue
```

### 7.7 WIPController

```http
GET /api/wip/balance
GET /api/wip/production/{productionOrderId}
POST /api/wip/start-stage
POST /api/wip/finish-stage
POST /api/wip/move-stage
POST /api/wip/scrap
```

### 7.8 PrintController

```http
GET /api/print/queue
GET /api/print/queue/{id}
POST /api/print/label-sheet
POST /api/print/label-fg
POST /api/print/{id}/reprint
POST /api/print/{id}/cancel
```

---

## 8. UI WebApp cần tạo

Tạo UI bằng Razor Pages hoặc Blazor Server với Bootstrap 5.

### 8.1 Layout chung

Giao diện gồm:

- Sidebar trái
- Topbar
- Breadcrumb
- Content area

Menu:

```text
Dashboard

Master Data
  - Customers
  - Items
  - Item Catalog Box
  - Item Recipe Sheet
  - Warehouses
  - Corrugator Machines
  - Printers

Sales
  - Sales Orders
  - Create Sales Order

Production
  - Production Orders
  - Wave Requirements
  - Wave Plans
  - WIP Tracking

Inventory
  - Inventory Balance
  - Inventory Transactions
  - Issue to Print
  - FG Receipt
  - Sale Issue

Printing
  - Print Queue
  - Printers

Reports
  - Open Orders
  - Wave Plan Report
  - WIP Report
  - Inventory Report
  - Print Error Report
```

### 8.2 Dashboard

URL:

```text
/
```

Cards:

- Open Sales Orders
- Draft Orders
- Open Production Orders
- Open Wave Requirements
- Today Wave Plans
- Inventory Sheet Qty
- FG Inventory Qty
- Failed Print Jobs

Tables/Charts:

- Open Wave Requirements
- WIP by Stage
- Inventory by Warehouse
- Print Queue latest

### 8.3 Customer Pages

```text
/customers
/customers/create
/customers/edit/{id}
```

### 8.4 Item Master Pages

```text
/items
/items/create
/items/edit/{id}
```

### 8.5 Item Catalog Box Pages

```text
/item-catalog-box
/item-catalog-box/create
/item-catalog-box/edit/{itemId}
```

Fields:

- ItemCode
- ItemName
- LengthMM
- WidthMM
- HeightMM
- FluteCode
- DieCutCode
- PrintColor
- PrintNote
- GlueType

### 8.6 Item Recipe Sheet Pages

```text
/item-recipe-sheet
/item-recipe-sheet/create
/item-recipe-sheet/edit/{id}
```

Fields:

- ItemCode
- RecipeVersion
- IsDefault
- SheetItemCode
- FluteCode
- SingleSheetLengthMM
- SingleSheetWidthMM
- SheetPerBox
- LossRate
- PreferredMachineCode
- PreferredLaneCount
- PreferredRunWidthMM

Button:

```text
Suggest Layout
```

Show candidates:

- LaneCount
- RunWidthMM
- WidthUtilization
- CutCount
- OverQty
- Score
- IsBest

### 8.7 Sales Order Pages

```text
/sales-orders
/sales-orders/create
/sales-orders/detail/{id}
```

Header fields:

- SalesOrderNo
- Customer
- OrderDate
- RequiredDate
- Status
- VersionNo
- Note

Line form:

- ProductType BOX/SHEET
- ItemCode
- Quantity
- Unit
- UnitPrice

Behavior for BOX:

1. User enters ItemCode such as `HN001`.
2. UI calls `GET /api/items/catalog/HN001`.
3. UI shows:
   - Box 350 x 250 x 200
   - Flute BC
   - Die K001
   - Print 2 colors
   - Single Sheet 1250 x 500
   - Loss 3%
4. Save line creates SalesOrderLine and BoxSpec snapshot.

UI sections:

- SalesOrder Header
- Add Line Panel
- Catalog Loaded Panel
- BoxSpec Snapshot Panel
- SalesOrderLine Grid
- Related Production Orders
- Audit Trail
- Revision History

Actions by state:

```text
Draft:
  Save Draft
  Delete Draft
  Add Line
  Delete Line
  Confirm Order

Confirmed:
  Create Revision
  Create LSX
  Cancel Line

Has Production:
  View LSX
  Cancel Line with validation

Has WavePlan:
  Locked

Produced:
  Adjustment only
```

### 8.8 Production Order Pages

```text
/production-orders
/production-orders/detail/{id}
```

Sections:

- PO header
- Sales line info
- BoxSpec/SheetSpec snapshot
- WaveRequirements
- WIPBalance
- InventoryTransactions

Actions:

- Generate WaveRequirement
- Issue To Print
- Finish Stage
- FG Receipt
- Print FG Label

### 8.9 Wave Requirement Pages

```text
/wave-requirements
/wave-requirements/{id}
```

Columns:

- WaveReqID
- ProductionOrderNo
- ItemCode
- FluteCode
- SingleSheetLengthMM
- SingleSheetWidthMM
- LaneCount
- RunWidthMM
- RequiredQty
- CutCount
- PlannedSheetQty
- OverQty
- RunningLengthM
- WidthUtilization
- Status

Actions:

- View Candidate
- Recalculate Layout
- Add to WavePlan
- Cancel if not planned

### 8.10 Wave Plan Pages

```text
/wave-plans
/wave-plans/create
/wave-plans/detail/{id}
```

Create workflow:

1. Select MachineCode.
2. Select PlanDate.
3. Select FluteCode.
4. Select RunWidthMM.
5. Show open WaveRequirement compatible.
6. User selects multiple WaveRequirement.
7. Create WavePlan.

Detail:

- WavePlan Header
- WavePlanDetail Grid
- TotalPlannedSheetQty
- TotalCutCount
- TotalRunningLengthM

Actions:

- Start Plan
- Wave Receipt
- Print Sheet Label
- Close Plan

### 8.11 Inventory Balance Page

```text
/inventory/balance
```

Filters:

- ItemCode
- ItemType
- Warehouse
- LotNo
- PalletNo

Columns:

- ItemCode
- ItemName
- ItemType
- WarehouseCode
- LotNo
- PalletNo
- QtyOnHand
- ReservedQty
- AvailableQty
- Unit

Actions:

- Movement History
- Issue
- Transfer
- Print Label

### 8.12 Inventory Transaction Page

```text
/inventory/transactions
```

Filters:

- Date range
- ItemCode
- Warehouse
- TransactionType
- RefType
- RefID

### 8.13 Issue To Print Page

```text
/inventory/issue-to-print
```

Fields:

- ProductionOrder
- SheetItem
- Warehouse
- Qty

Submit calls `usp_IssueSheetToPrint`.

### 8.14 FG Receipt Page

```text
/inventory/fg-receipt
```

Fields:

- ProductionOrder
- ItemCode
- Warehouse
- Qty
- PalletNo
- Print label checkbox

### 8.15 Sale Issue Page

```text
/inventory/sale-issue
```

Used for both:

- Bán giấy tấm
- Bán thùng carton

### 8.16 WIP Tracking Page

```text
/wip
/wip/production/{productionOrderId}
```

Actions:

- Start Stage
- Finish Stage
- Move Stage
- Scrap
- Rework

### 8.17 Print Queue Page

```text
/print-queue
```

Columns:

- PrintID
- PrinterCode
- LabelType
- RefType
- RefID
- Status
- RetryCount
- ErrorMessage
- CreatedAt
- PrintedAt

Actions:

- Reprint
- Cancel
- Mark Pending Again
- View ZPL

### 8.18 Reports

Create report pages:

```text
/reports/open-orders
/reports/wave-plan
/reports/wip
/reports/inventory
/reports/print-errors
```

Reports must support filters and export to Excel/CSV.

---

## 9. Local Print Agent

Create Worker Service:

```text
src/DGP.PrintAgent
```

Behavior:

```text
Every 3 seconds:
  Read TOP 5 PrintQueue where Status = Pending
  Mark Processing
  Load PrinterList
  If ConnectionType = IP:
    Send ZPL to PrinterIP:PrinterPort, default 9100
  If ConnectionType = USB or WINDOWS_PRINTER:
    Send raw ZPL to WindowsPrinterName
  If success:
    Status = Printed
  If fail:
    RetryCount += 1
    If RetryCount >= MaxRetry:
      Status = Failed
    Else:
      Status = Pending
    Save ErrorMessage
```

Must include:

- `IpZebraPrinterService`
- `WindowsRawPrinterService`
- `RawPrinterHelper`
- Logging
- appsettings connection string

---

## 10. ZPL templates

### 10.1 Sheet Label

```zpl
^XA
^PW800
^LL1200
^CI28
^FO40,30^A0N,42,42^FDDONA GREEN PACK^FS
^FO40,90^GB720,3,3^FS
^FO40,130^A0N,34,34^FDLoai: GIAY TAM^FS
^FO40,185^A0N,34,34^FDSong: {{FluteCode}}^FS
^FO40,240^A0N,34,34^FDTam don: {{SingleSheetLength}} x {{SingleSheetWidth}}^FS
^FO40,295^A0N,34,34^FDChay: {{LaneCount}}x - Kho song {{RunWidth}}^FS
^FO40,350^A0N,42,42^FDSL: {{Qty}} TAM^FS
^FO40,410^A0N,34,34^FDNhip cat: {{CutCount}}^FS
^FO250,500^BQN,2,8
^FDLA,{{WavePlanNo}}|{{FluteCode}}|{{RunWidth}}|{{Qty}}^FS
^FO40,900^A0N,28,28^FDNgay: {{PrintDate}}^FS
^FO40,945^A0N,28,28^FDNguoi in: {{CreatedBy}}^FS
^XZ
```

### 10.2 FG Label

```zpl
^XA
^PW800
^LL1200
^CI28
^FO40,30^A0N,42,42^FDDONA GREEN PACK^FS
^FO40,90^GB720,3,3^FS
^FO40,130^A0N,34,34^FDKH: {{CustomerName}}^FS
^FO40,185^A0N,34,34^FDDH: {{SalesOrderNo}}^FS
^FO40,240^A0N,34,34^FDMA: {{ItemCode}}^FS
^FO40,295^A0N,30,30^FD{{ItemName}}^FS
^FO40,370^A0N,50,50^FDSL: {{Qty}} PCS^FS
^FO250,470^BQN,2,8
^FDLA,{{SalesOrderNo}}|{{ItemCode}}|{{Qty}}|{{ProductionOrderNo}}^FS
^FO40,900^A0N,28,28^FDNgay: {{PrintDate}}^FS
^FO40,945^A0N,28,28^FDNguoi in: {{CreatedBy}}^FS
^XZ
```

---

## 11. Seed data bắt buộc

Create seed data:

```text
CorrugatorMachine:
  SONG_2500
  Min=1250
  Max=2500
  Step=50
  EdgeTrim=20

CorrugatorAllowedWidth:
  1250, 1300, 1350, ..., 2500

WIPStage:
  WAVE
  PRINT
  DIECUT
  GLUE
  PACKING

Warehouse:
  WH_ROLL
  WH_SHEET
  WH_FG

PrinterList:
  KHO_TP IP 192.168.1.200:9100
  KHO_GIAY WINDOWS_PRINTER Zebra_Giay

ItemMaster:
  HN001 BOX
  HN002 BOX
  AS001 BOX
  BC1250 SHEET

ItemCatalogBox:
  HN001 350x250x200 BC K001 2 colors
  HN002 400x300x250 BC K002 3 colors
  AS001 420x310x280 E K011 4 colors

ItemRecipeSheet:
  HN001 1250x500 BC SheetPerBox=1 LossRate=0.03
  HN002 1400x600 BC SheetPerBox=1 LossRate=0.03
  AS001 1500x700 E SheetPerBox=1 LossRate=0.04
```

---

## 12. Test cases bắt buộc

### 12.1 Catalog lookup

Input:

```text
HN001
```

Expected:

```text
Box 350x250x200
Flute BC
Die K001
PrintColor 2
SingleSheet 1250x500
LossRate 0.03
```

### 12.2 Layout optimizer 10500

Input:

```text
RequiredQty = 10500
SingleSheetWidth = 500
SingleSheetLength = 1250
Machine = SONG_2500
EdgeTrim = 20
Allowed width 1250..2500 step 50
```

Expected:

```text
Lane = 4
RunWidth = 2050
CutCount = 2625
ProducedSheetQty = 10500
OverQty = 0
RunningLengthM = 3281.25
```

### 12.3 Layout optimizer 10502

Expected:

```text
Lane = 4
CutCount = 2626
ProducedSheetQty = 10504
OverQty = 2
```

### 12.4 Delete Draft Order

Expected:

```text
Draft order without downstream records can be deleted.
```

### 12.5 Delete Confirmed Order

Expected:

```text
Delete blocked. User must create revision or cancel.
```

### 12.6 Cancel line with WavePlan

Expected:

```text
Cancel blocked if WaveRequirement is already in WavePlan.
```

### 12.7 PrintQueue

Expected:

```text
API creates Pending job.
PrintAgent picks job.
If printer succeeds: Printed.
If printer fails: Retry or Failed.
```

---

## 13. API response chuẩn

All API endpoints return:

```json
{
  "success": true,
  "message": "OK",
  "data": {}
}
```

For errors:

```json
{
  "success": false,
  "message": "Validation error message",
  "data": null
}
```

---

## 14. Build and validation rules

- Create solution and projects.
- Create database scripts first.
- Create stored procedures second.
- Create API third.
- Create UI pages fourth.
- Create Print Agent fifth.
- Run build.
- Fix compile errors.
- Generate docs.

Do not skip:

- WIPTransaction
- WIPBalance
- InventoryTransaction
- InventoryBalance
- WaveRequirement
- WavePlan
- PrintQueue
- SalesOrder revision/cancel logic

---

## 15. Final instruction to Copilot Agent

Read this full `copilot.md`.

Create the complete ERP Carton project for DONA GREEN PACK.

Start by generating:

1. Solution structure
2. Azure SQL scripts
3. Stored procedures
4. ASP.NET Core WebApp/API
5. Bootstrap UI pages
6. Local Print Agent service
7. Reports and dashboard
8. Documentation

After each milestone, run build and fix errors before continuing.

Use this document as the source of truth.
