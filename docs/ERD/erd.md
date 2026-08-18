# DGP ERP Carton ERD

This document describes the relational model for the DGP ERP Carton database and the key relationships between core business entities.

## 1. Core entities

The design centers on these business domains:

- Customer management
- Item catalog and recipe management
- Sales orders and order revisions
- Production planning and wave requirements
- Inventory and WIP tracking
- Printer and print queue operations

## 2. ER diagram

```mermaid
erDiagram
    CUSTOMER ||--o{ SALES_ORDER : places
    CUSTOMER ||--o{ SALES_ORDER_AUDIT : logs

    ITEM_MASTER ||--o| ITEM_CATALOG_BOX : has
    ITEM_MASTER ||--o{ ITEM_RECIPE_SHEET : has
    ITEM_MASTER ||--o{ SALES_ORDER_LINE : used_in
    ITEM_MASTER ||--o{ PRODUCTION_ORDER : planned_for
    ITEM_MASTER ||--o{ INVENTORY_TRANSACTION : tracked_by
    ITEM_MASTER ||--o{ INVENTORY_BALANCE : balances
    ITEM_MASTER ||--o{ WIP_TRANSACTION : stage_activity
    ITEM_MASTER ||--o{ WIP_BALANCE : stage_balance

    SALES_ORDER ||--o{ SALES_ORDER_LINE : contains
    SALES_ORDER ||--o{ SALES_ORDER_AUDIT : audited
    SALES_ORDER_LINE ||--o| BOX_SPEC : snapshot
    SALES_ORDER_LINE ||--o| SHEET_SPEC : snapshot
    SALES_ORDER_LINE ||--o{ PRODUCTION_ORDER : generates
    SALES_ORDER_LINE ||--o{ WAVE_REQUIREMENT : sources

    CORRUGATOR_MACHINE ||--o{ CORRUGATOR_ALLOWED_WIDTH : supports
    CORRUGATOR_MACHINE ||--o{ CORRUGATOR_LAYOUT_CANDIDATE : evaluates
    ITEM_RECIPE_SHEET ||--o{ CORRUGATOR_LAYOUT_CANDIDATE : optimized

    PRODUCTION_ORDER ||--o{ WAVE_REQUIREMENT : creates
    PRODUCTION_ORDER ||--o{ WIP_TRANSACTION : enters
    PRODUCTION_ORDER ||--o{ WIP_BALANCE : tracked_on

    WAVE_REQUIREMENT ||--o{ WAVE_PLAN_DETAIL : included_in
    WAVE_PLAN ||--o{ WAVE_PLAN_DETAIL : contains

    WAREHOUSE ||--o{ INVENTORY_TRANSACTION : records
    WAREHOUSE ||--o{ INVENTORY_BALANCE : maintains

    WIP_STAGE ||--o{ WIP_TRANSACTION : stage_transition
    WIP_STAGE ||--o{ WIP_BALANCE : stage_balance

    PRINTER_LIST ||--o{ PRINT_QUEUE : prints

    CUSTOMER {
        bigint CustomerID PK
        nvarchar CustomerCode
        nvarchar CustomerName
    }

    ITEM_MASTER {
        bigint ItemID PK
        nvarchar ItemCode
        nvarchar ItemName
        nvarchar ItemType
    }

    ITEM_CATALOG_BOX {
        bigint ItemID PK, FK
        nvarchar ItemCode
        decimal LengthMM
        decimal WidthMM
        decimal HeightMM
        nvarchar FluteCode
    }

    ITEM_RECIPE_SHEET {
        bigint RecipeSheetID PK
        bigint ItemID FK
        nvarchar RecipeVersion
        nvarchar FluteCode
        decimal SingleSheetLengthMM
        decimal SingleSheetWidthMM
    }

    SALES_ORDER {
        bigint SalesOrderID PK
        nvarchar SalesOrderNo
        bigint CustomerID FK
        date OrderDate
        nvarchar Status
        int VersionNo
    }

    SALES_ORDER_LINE {
        bigint LineID PK
        bigint SalesOrderID FK
        bigint ItemID FK
        nvarchar ProductType
        decimal Quantity
        nvarchar LineStatus
    }

    BOX_SPEC {
        bigint LineID PK, FK
        decimal LengthMM
        decimal WidthMM
        decimal HeightMM
        nvarchar FluteCode
    }

    SHEET_SPEC {
        bigint LineID PK, FK
        nvarchar FluteCode
        decimal SingleSheetLengthMM
        decimal SingleSheetWidthMM
    }

    PRODUCTION_ORDER {
        bigint ProductionOrderID PK
        bigint LineID FK
        bigint ItemID FK
        nvarchar ProductionOrderNo
        decimal PlannedQty
        nvarchar Status
    }

    WAVE_REQUIREMENT {
        bigint WaveReqID PK
        bigint ProductionOrderID FK
        bigint SourceLineID FK
        bigint ItemID FK
        decimal RequiredQty
        nvarchar Status
    }

    WAVE_PLAN {
        bigint WavePlanID PK
        nvarchar WavePlanNo
        date PlanDate
        nvarchar MachineCode
        nvarchar FluteCode
        decimal RunWidthMM
    }

    WAVE_PLAN_DETAIL {
        bigint WavePlanDetailID PK
        bigint WavePlanID FK
        bigint WaveReqID FK
        decimal RequiredSheetQty
        decimal PlannedSheetQty
    }

    WAREHOUSE {
        bigint WarehouseID PK
        nvarchar WarehouseCode
        nvarchar WarehouseName
    }

    INVENTORY_TRANSACTION {
        bigint TransID PK
        bigint ItemID FK
        bigint WarehouseID FK
        nvarchar TransactionType
        decimal Qty
    }

    INVENTORY_BALANCE {
        bigint BalanceID PK
        bigint ItemID FK
        bigint WarehouseID FK
        decimal QtyOnHand
        decimal ReservedQty
    }

    WIP_STAGE {
        bigint StageID PK
        nvarchar StageCode
        nvarchar StageName
    }

    WIP_TRANSACTION {
        bigint WIPTransID PK
        bigint ProductionOrderID FK
        bigint StageID FK
        nvarchar WIPTransType
        decimal Qty
    }

    WIP_BALANCE {
        bigint WIPBalanceID PK
        bigint ProductionOrderID FK
        bigint StageID FK
        decimal QtyInStage
    }

    PRINTER_LIST {
        nvarchar PrinterCode PK
        nvarchar PrinterName
        nvarchar ConnectionType
        nvarchar PrinterIP
    }

    PRINT_QUEUE {
        bigint PrintID PK
        nvarchar PrinterCode FK
        nvarchar LabelType
        nvarchar Status
        bigint RefID
    }
```

## 3. Relationship notes

- A Customer can have many SalesOrder records.
- Each SalesOrder can have many SalesOrderLine records.
- Each SalesOrderLine stores a snapshot of box or sheet technical details in BoxSpec or SheetSpec.
- A ProductionOrder is generated from a sales order line and can create one or more WaveRequirement records.
- A WavePlan groups compatible WaveRequirement records for a machine and flute width.
- Inventory transactions are the source of inventory balance updates, and WIP transactions track stage level movement.
- PrintQueue records represent asynchronous print jobs sent to a configured printer.

## 4. Key constraints summary

The database uses the following types of integrity rules:

- Primary keys for each entity
- Foreign keys for all dependent relationships
- Unique constraints for business identifiers
- Status check constraints for workflow states
- Value and quantity validation constraints for item and order data

## 5. Database conventions

- Use Azure SQL compatible T-SQL.
- Use IDs as BIGINT identity keys for transaction scale.
- Keep audit records on every sales order lifecycle change.
- Do not allow direct inventory updates without transaction-based flow.
- Separate operational inventory from WIP stage movement.
- Use print queue processing for all printer jobs.

## 6. Next step

This ERD is the schema foundation for the database layer. The next phase is to add stored procedures and application logic on top of this structure.
