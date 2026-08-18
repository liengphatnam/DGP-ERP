SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.PrintQueue', N'U') IS NOT NULL
        DROP TABLE dbo.PrintQueue;
    IF OBJECT_ID(N'dbo.PrinterList', N'U') IS NOT NULL
        DROP TABLE dbo.PrinterList;
    IF OBJECT_ID(N'dbo.WIPBalance', N'U') IS NOT NULL
        DROP TABLE dbo.WIPBalance;
    IF OBJECT_ID(N'dbo.WIPTransaction', N'U') IS NOT NULL
        DROP TABLE dbo.WIPTransaction;
    IF OBJECT_ID(N'dbo.WIPStage', N'U') IS NOT NULL
        DROP TABLE dbo.WIPStage;
    IF OBJECT_ID(N'dbo.InventoryBalance', N'U') IS NOT NULL
        DROP TABLE dbo.InventoryBalance;
    IF OBJECT_ID(N'dbo.InventoryTransaction', N'U') IS NOT NULL
        DROP TABLE dbo.InventoryTransaction;
    IF OBJECT_ID(N'dbo.Warehouse', N'U') IS NOT NULL
        DROP TABLE dbo.Warehouse;
    IF OBJECT_ID(N'dbo.WavePlanDetail', N'U') IS NOT NULL
        DROP TABLE dbo.WavePlanDetail;
    IF OBJECT_ID(N'dbo.WavePlan', N'U') IS NOT NULL
        DROP TABLE dbo.WavePlan;
    IF OBJECT_ID(N'dbo.WaveRequirement', N'U') IS NOT NULL
        DROP TABLE dbo.WaveRequirement;
    IF OBJECT_ID(N'dbo.CorrugatorLayoutCandidate', N'U') IS NOT NULL
        DROP TABLE dbo.CorrugatorLayoutCandidate;
    IF OBJECT_ID(N'dbo.ProductionOrder', N'U') IS NOT NULL
        DROP TABLE dbo.ProductionOrder;
    IF OBJECT_ID(N'dbo.CorrugatorAllowedWidth', N'U') IS NOT NULL
        DROP TABLE dbo.CorrugatorAllowedWidth;
    IF OBJECT_ID(N'dbo.CorrugatorMachine', N'U') IS NOT NULL
        DROP TABLE dbo.CorrugatorMachine;
    IF OBJECT_ID(N'dbo.SalesOrderAudit', N'U') IS NOT NULL
        DROP TABLE dbo.SalesOrderAudit;
    IF OBJECT_ID(N'dbo.SheetSpec', N'U') IS NOT NULL
        DROP TABLE dbo.SheetSpec;
    IF OBJECT_ID(N'dbo.BoxSpec', N'U') IS NOT NULL
        DROP TABLE dbo.BoxSpec;
    IF OBJECT_ID(N'dbo.SalesOrderLine', N'U') IS NOT NULL
        DROP TABLE dbo.SalesOrderLine;
    IF OBJECT_ID(N'dbo.SalesOrder', N'U') IS NOT NULL
        DROP TABLE dbo.SalesOrder;
    IF OBJECT_ID(N'dbo.ItemRecipeSheet', N'U') IS NOT NULL
        DROP TABLE dbo.ItemRecipeSheet;
    IF OBJECT_ID(N'dbo.ItemCatalogBox', N'U') IS NOT NULL
        DROP TABLE dbo.ItemCatalogBox;
    IF OBJECT_ID(N'dbo.ItemMaster', N'U') IS NOT NULL
        DROP TABLE dbo.ItemMaster;
    IF OBJECT_ID(N'dbo.Customer', N'U') IS NOT NULL
        DROP TABLE dbo.Customer;

    CREATE TABLE dbo.Customer
    (
        CustomerID BIGINT IDENTITY(1,1) PRIMARY KEY,
        CustomerCode NVARCHAR(50) NOT NULL,
        CustomerName NVARCHAR(255) NOT NULL,
        TaxCode NVARCHAR(50) NULL,
        Address NVARCHAR(500) NULL,
        Phone NVARCHAR(50) NULL,
        Email NVARCHAR(255) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT UQ_Customer_CustomerCode UNIQUE (CustomerCode)
    );

    CREATE TABLE dbo.ItemMaster
    (
        ItemID BIGINT IDENTITY(1,1) PRIMARY KEY,
        ItemCode NVARCHAR(100) NOT NULL,
        ItemName NVARCHAR(255) NOT NULL,
        ItemType NVARCHAR(30) NOT NULL,
        Unit NVARCHAR(20) NOT NULL DEFAULT 'PCS',
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT UQ_ItemMaster_ItemCode UNIQUE (ItemCode),
        CONSTRAINT CHK_ItemMaster_ItemType CHECK (ItemType IN ('ROLL', 'SHEET', 'BOX', 'PALLET', 'MATERIAL'))
    );

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
        CONSTRAINT FK_ItemRecipeSheet_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID),
        CONSTRAINT CHK_ItemRecipeSheet_SheetPerBox CHECK (SheetPerBox > 0),
        CONSTRAINT CHK_ItemRecipeSheet_LossRate CHECK (LossRate >= 0)
    );

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
        CONSTRAINT FK_SalesOrder_Parent FOREIGN KEY (ParentSalesOrderID) REFERENCES dbo.SalesOrder(SalesOrderID),
        CONSTRAINT UQ_SalesOrder_SalesOrderNo_Version UNIQUE (SalesOrderNo, VersionNo),
        CONSTRAINT CHK_SalesOrder_Status CHECK (Status IN ('Draft', 'Confirmed', 'InProduction', 'Completed', 'Cancelled'))
    );

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
        CONSTRAINT FK_SOLine_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID),
        CONSTRAINT CHK_SalesOrderLine_ProductType CHECK (ProductType IN ('BOX', 'SHEET')),
        CONSTRAINT CHK_SalesOrderLine_LineStatus CHECK (LineStatus IN ('Open', 'Planned', 'InProduction', 'Completed', 'Cancelled', 'Locked')),
        CONSTRAINT CHK_SalesOrderLine_Quantity CHECK (Quantity > 0)
    );

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

    CREATE TABLE dbo.SheetSpec
    (
        LineID BIGINT PRIMARY KEY,
        FluteCode NVARCHAR(20) NOT NULL,
        SingleSheetLengthMM DECIMAL(18,2) NOT NULL,
        SingleSheetWidthMM DECIMAL(18,2) NOT NULL,
        LossRate DECIMAL(18,4) NOT NULL DEFAULT 0,
        CONSTRAINT FK_SheetSpec_SOLine FOREIGN KEY (LineID) REFERENCES dbo.SalesOrderLine(LineID),
        CONSTRAINT CHK_SheetSpec_LossRate CHECK (LossRate >= 0)
    );

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
        CONSTRAINT FK_SalesOrderAudit_SO FOREIGN KEY (SalesOrderID) REFERENCES dbo.SalesOrder(SalesOrderID),
        CONSTRAINT CHK_SalesOrderAudit_ActionType CHECK (ActionType IN ('CREATE', 'UPDATE', 'DELETE_DRAFT', 'CONFIRM', 'CREATE_REVISION', 'CANCEL_LINE', 'CANCEL_ORDER', 'LOCK', 'UNLOCK'))
    );

    CREATE TABLE dbo.CorrugatorMachine
    (
        MachineID BIGINT IDENTITY(1,1) PRIMARY KEY,
        MachineCode NVARCHAR(50) NOT NULL,
        MachineName NVARCHAR(100) NOT NULL,
        MinRunWidthMM DECIMAL(18,2) NOT NULL,
        MaxRunWidthMM DECIMAL(18,2) NOT NULL,
        WidthStepMM DECIMAL(18,2) NOT NULL DEFAULT 50,
        EdgeTrimMM DECIMAL(18,2) NOT NULL DEFAULT 20,
        IsActive BIT NOT NULL DEFAULT 1,
        CONSTRAINT UQ_CorrugatorMachine_MachineCode UNIQUE (MachineCode),
        CONSTRAINT CHK_CorrugatorMachine_RunWidths CHECK (MinRunWidthMM > 0 AND MaxRunWidthMM >= MinRunWidthMM AND WidthStepMM > 0)
    );

    CREATE TABLE dbo.CorrugatorAllowedWidth
    (
        AllowedWidthID BIGINT IDENTITY(1,1) PRIMARY KEY,
        MachineID BIGINT NOT NULL,
        RunWidthMM DECIMAL(18,2) NOT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CONSTRAINT FK_CorrWidth_Machine FOREIGN KEY (MachineID) REFERENCES dbo.CorrugatorMachine(MachineID),
        CONSTRAINT UQ_CorrWidth UNIQUE (MachineID, RunWidthMM),
        CONSTRAINT CHK_CorrugatorAllowedWidth_RunWidth CHECK (RunWidthMM > 0)
    );

    CREATE TABLE dbo.ProductionOrder
    (
        ProductionOrderID BIGINT IDENTITY(1,1) PRIMARY KEY,
        ProductionOrderNo NVARCHAR(50) NOT NULL,
        LineID BIGINT NOT NULL,
        ItemID BIGINT NOT NULL,
        ProductType NVARCHAR(20) NOT NULL,
        PlannedQty DECIMAL(18,2) NOT NULL,
        ProducedQty DECIMAL(18,2) NOT NULL DEFAULT 0,
        Status NVARCHAR(30) NOT NULL DEFAULT 'Created',
        CreatedBy NVARCHAR(100) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT FK_PO_SOLine FOREIGN KEY (LineID) REFERENCES dbo.SalesOrderLine(LineID),
        CONSTRAINT FK_PO_Item FOREIGN KEY (ItemID) REFERENCES dbo.ItemMaster(ItemID),
        CONSTRAINT UQ_ProductionOrder_ProductionOrderNo UNIQUE (ProductionOrderNo),
        CONSTRAINT CHK_ProductionOrder_ProductType CHECK (ProductType IN ('BOX', 'SHEET')),
        CONSTRAINT CHK_ProductionOrder_Status CHECK (Status IN ('Created', 'WaveRequired', 'Planned', 'InProduction', 'Completed', 'Cancelled')),
        CONSTRAINT CHK_ProductionOrder_PlannedQty CHECK (PlannedQty > 0)
    );

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
        CONSTRAINT FK_Candidate_RecipeSheet FOREIGN KEY (RecipeSheetID) REFERENCES dbo.ItemRecipeSheet(RecipeSheetID),
        CONSTRAINT CHK_CorrugatorLayoutCandidate_LaneCount CHECK (LaneCount > 0),
        CONSTRAINT CHK_CorrugatorLayoutCandidate_RunWidth CHECK (RunWidthMM > 0),
        CONSTRAINT CHK_CorrugatorLayoutCandidate_WidthUsed CHECK (WidthUsedMM > 0)
    );

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
        CONSTRAINT FK_WaveReq_Candidate FOREIGN KEY (LayoutCandidateID) REFERENCES dbo.CorrugatorLayoutCandidate(CandidateID),
        CONSTRAINT CHK_WaveRequirement_ProductType CHECK (ProductType IN ('BOX', 'SHEET')),
        CONSTRAINT CHK_WaveRequirement_Status CHECK (Status IN ('Open', 'Planned', 'Running', 'Completed', 'Cancelled', 'Locked')),
        CONSTRAINT CHK_WaveRequirement_RequiredQty CHECK (RequiredQty > 0)
    );

    CREATE TABLE dbo.WavePlan
    (
        WavePlanID BIGINT IDENTITY(1,1) PRIMARY KEY,
        WavePlanNo NVARCHAR(50) NOT NULL,
        PlanDate DATE NOT NULL,
        MachineCode NVARCHAR(50) NOT NULL,
        FluteCode NVARCHAR(20) NOT NULL,
        RunWidthMM DECIMAL(18,2) NOT NULL,
        TotalPlannedSheetQty DECIMAL(18,2) NOT NULL DEFAULT 0,
        TotalCutCount DECIMAL(18,2) NOT NULL DEFAULT 0,
        TotalRunningLengthM DECIMAL(18,2) NOT NULL DEFAULT 0,
        Status NVARCHAR(30) NOT NULL DEFAULT 'Planned',
        CreatedBy NVARCHAR(100) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT UQ_WavePlan_WavePlanNo UNIQUE (WavePlanNo),
        CONSTRAINT CHK_WavePlan_Status CHECK (Status IN ('Planned', 'Running', 'Completed', 'Cancelled')),
        CONSTRAINT CHK_WavePlan_RunWidth CHECK (RunWidthMM > 0)
    );

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
        CONSTRAINT FK_WavePlanDetail_Req FOREIGN KEY (WaveReqID) REFERENCES dbo.WaveRequirement(WaveReqID),
        CONSTRAINT CHK_WavePlanDetail_LaneCount CHECK (LaneCount > 0),
        CONSTRAINT CHK_WavePlanDetail_RequiredSheetQty CHECK (RequiredSheetQty > 0)
    );

    CREATE TABLE dbo.Warehouse
    (
        WarehouseID BIGINT IDENTITY(1,1) PRIMARY KEY,
        WarehouseCode NVARCHAR(50) NOT NULL,
        WarehouseName NVARCHAR(100) NOT NULL,
        WarehouseType NVARCHAR(30) NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CONSTRAINT UQ_Warehouse_WarehouseCode UNIQUE (WarehouseCode)
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
        CONSTRAINT FK_InvTrans_Wh FOREIGN KEY (WarehouseID) REFERENCES dbo.Warehouse(WarehouseID),
        CONSTRAINT CHK_InventoryTransaction_TransactionType CHECK (TransactionType IN ('WAVE_RECEIPT', 'ISSUE_TO_PRINT', 'FG_RECEIPT', 'SALE_ISSUE', 'TRANSFER_IN', 'TRANSFER_OUT', 'ADJUSTMENT_IN', 'ADJUSTMENT_OUT', 'SCRAP_OUT', 'RETURN_IN'))
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
        CONSTRAINT UQ_InvBal UNIQUE (ItemID, WarehouseID, LotNo, PalletNo),
        CONSTRAINT CHK_InventoryBalance_QtyOnHand CHECK (QtyOnHand >= 0),
        CONSTRAINT CHK_InventoryBalance_ReservedQty CHECK (ReservedQty >= 0)
    );

    CREATE TABLE dbo.WIPStage
    (
        StageID BIGINT IDENTITY(1,1) PRIMARY KEY,
        StageCode NVARCHAR(50) NOT NULL,
        StageName NVARCHAR(100) NOT NULL,
        SortOrder INT NOT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CONSTRAINT UQ_WIPStage_StageCode UNIQUE (StageCode)
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
        CONSTRAINT FK_WIPTrans_ToStage FOREIGN KEY (ToStageID) REFERENCES dbo.WIPStage(StageID),
        CONSTRAINT CHK_WIPTransaction_Type CHECK (WIPTransType IN ('START_STAGE', 'FINISH_STAGE', 'MOVE_STAGE', 'SCRAP', 'REWORK'))
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
        CONSTRAINT UQ_WIPBal UNIQUE (ProductionOrderID, StageID, ItemID),
        CONSTRAINT CHK_WIPBalance_QtyInStage CHECK (QtyInStage >= 0)
    );

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
        IsActive BIT NOT NULL DEFAULT 1,
        CONSTRAINT CHK_PrinterList_ConnectionType CHECK (ConnectionType IN ('IP', 'USB', 'WINDOWS_PRINTER'))
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
        CONSTRAINT FK_PrintQueue_Printer FOREIGN KEY (PrinterCode) REFERENCES dbo.PrinterList(PrinterCode),
        CONSTRAINT CHK_PrintQueue_Status CHECK (Status IN ('Pending', 'Processing', 'Printed', 'Failed', 'Cancelled')),
        CONSTRAINT CHK_PrintQueue_RetryCount CHECK (RetryCount >= 0),
        CONSTRAINT CHK_PrintQueue_MaxRetry CHECK (MaxRetry >= 0)
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
