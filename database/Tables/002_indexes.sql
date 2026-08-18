SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Customer_CustomerName' AND object_id = OBJECT_ID('dbo.Customer'))
        DROP INDEX IX_Customer_CustomerName ON dbo.Customer;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ItemMaster_ItemType_IsActive' AND object_id = OBJECT_ID('dbo.ItemMaster'))
        DROP INDEX IX_ItemMaster_ItemType_IsActive ON dbo.ItemMaster;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ItemCatalogBox_ItemCode' AND object_id = OBJECT_ID('dbo.ItemCatalogBox'))
        DROP INDEX IX_ItemCatalogBox_ItemCode ON dbo.ItemCatalogBox;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ItemRecipeSheet_ItemID_IsDefault' AND object_id = OBJECT_ID('dbo.ItemRecipeSheet'))
        DROP INDEX IX_ItemRecipeSheet_ItemID_IsDefault ON dbo.ItemRecipeSheet;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrder_CustomerID_Status' AND object_id = OBJECT_ID('dbo.SalesOrder'))
        DROP INDEX IX_SalesOrder_CustomerID_Status ON dbo.SalesOrder;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrder_OrderDate' AND object_id = OBJECT_ID('dbo.SalesOrder'))
        DROP INDEX IX_SalesOrder_OrderDate ON dbo.SalesOrder;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrderLine_SalesOrderID' AND object_id = OBJECT_ID('dbo.SalesOrderLine'))
        DROP INDEX IX_SalesOrderLine_SalesOrderID ON dbo.SalesOrderLine;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrderLine_ItemID' AND object_id = OBJECT_ID('dbo.SalesOrderLine'))
        DROP INDEX IX_SalesOrderLine_ItemID ON dbo.SalesOrderLine;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ProductionOrder_LineID' AND object_id = OBJECT_ID('dbo.ProductionOrder'))
        DROP INDEX IX_ProductionOrder_LineID ON dbo.ProductionOrder;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ProductionOrder_Status' AND object_id = OBJECT_ID('dbo.ProductionOrder'))
        DROP INDEX IX_ProductionOrder_Status ON dbo.ProductionOrder;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CorrugatorLayoutCandidate_MachineID' AND object_id = OBJECT_ID('dbo.CorrugatorLayoutCandidate'))
        DROP INDEX IX_CorrugatorLayoutCandidate_MachineID ON dbo.CorrugatorLayoutCandidate;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WaveRequirement_ProductionOrderID' AND object_id = OBJECT_ID('dbo.WaveRequirement'))
        DROP INDEX IX_WaveRequirement_ProductionOrderID ON dbo.WaveRequirement;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WaveRequirement_Status' AND object_id = OBJECT_ID('dbo.WaveRequirement'))
        DROP INDEX IX_WaveRequirement_Status ON dbo.WaveRequirement;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WavePlan_PlanDate' AND object_id = OBJECT_ID('dbo.WavePlan'))
        DROP INDEX IX_WavePlan_PlanDate ON dbo.WavePlan;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WavePlanDetail_WavePlanID' AND object_id = OBJECT_ID('dbo.WavePlanDetail'))
        DROP INDEX IX_WavePlanDetail_WavePlanID ON dbo.WavePlanDetail;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InventoryTransaction_ItemID' AND object_id = OBJECT_ID('dbo.InventoryTransaction'))
        DROP INDEX IX_InventoryTransaction_ItemID ON dbo.InventoryTransaction;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InventoryTransaction_WarehouseID' AND object_id = OBJECT_ID('dbo.InventoryTransaction'))
        DROP INDEX IX_InventoryTransaction_WarehouseID ON dbo.InventoryTransaction;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InventoryBalance_ItemID_WarehouseID' AND object_id = OBJECT_ID('dbo.InventoryBalance'))
        DROP INDEX IX_InventoryBalance_ItemID_WarehouseID ON dbo.InventoryBalance;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WIPTransaction_ProductionOrderID' AND object_id = OBJECT_ID('dbo.WIPTransaction'))
        DROP INDEX IX_WIPTransaction_ProductionOrderID ON dbo.WIPTransaction;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WIPBalance_ProductionOrderID' AND object_id = OBJECT_ID('dbo.WIPBalance'))
        DROP INDEX IX_WIPBalance_ProductionOrderID ON dbo.WIPBalance;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PrintQueue_Status_CreatedAt' AND object_id = OBJECT_ID('dbo.PrintQueue'))
        DROP INDEX IX_PrintQueue_Status_CreatedAt ON dbo.PrintQueue;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PrintQueue_PrinterCode' AND object_id = OBJECT_ID('dbo.PrintQueue'))
        DROP INDEX IX_PrintQueue_PrinterCode ON dbo.PrintQueue;

    CREATE INDEX IX_Customer_CustomerName
        ON dbo.Customer(CustomerName);

    CREATE INDEX IX_ItemMaster_ItemType_IsActive
        ON dbo.ItemMaster(ItemType, IsActive);

    CREATE INDEX IX_ItemCatalogBox_ItemCode
        ON dbo.ItemCatalogBox(ItemCode);

    CREATE INDEX IX_ItemRecipeSheet_ItemID_IsDefault
        ON dbo.ItemRecipeSheet(ItemID, IsDefault);

    CREATE INDEX IX_SalesOrder_CustomerID_Status
        ON dbo.SalesOrder(CustomerID, Status);

    CREATE INDEX IX_SalesOrder_OrderDate
        ON dbo.SalesOrder(OrderDate);

    CREATE INDEX IX_SalesOrderLine_SalesOrderID
        ON dbo.SalesOrderLine(SalesOrderID);

    CREATE INDEX IX_SalesOrderLine_ItemID
        ON dbo.SalesOrderLine(ItemID);

    CREATE INDEX IX_ProductionOrder_LineID
        ON dbo.ProductionOrder(LineID);

    CREATE INDEX IX_ProductionOrder_Status
        ON dbo.ProductionOrder(Status);

    CREATE INDEX IX_CorrugatorLayoutCandidate_MachineID
        ON dbo.CorrugatorLayoutCandidate(MachineID, Score DESC);

    CREATE INDEX IX_WaveRequirement_ProductionOrderID
        ON dbo.WaveRequirement(ProductionOrderID);

    CREATE INDEX IX_WaveRequirement_Status
        ON dbo.WaveRequirement(Status);

    CREATE INDEX IX_WavePlan_PlanDate
        ON dbo.WavePlan(PlanDate, Status);

    CREATE INDEX IX_WavePlanDetail_WavePlanID
        ON dbo.WavePlanDetail(WavePlanID);

    CREATE INDEX IX_InventoryTransaction_ItemID
        ON dbo.InventoryTransaction(ItemID, CreatedAt);

    CREATE INDEX IX_InventoryTransaction_WarehouseID
        ON dbo.InventoryTransaction(WarehouseID, CreatedAt);

    CREATE INDEX IX_InventoryBalance_ItemID_WarehouseID
        ON dbo.InventoryBalance(ItemID, WarehouseID, QtyOnHand);

    CREATE INDEX IX_WIPTransaction_ProductionOrderID
        ON dbo.WIPTransaction(ProductionOrderID, StageID, CreatedAt);

    CREATE INDEX IX_WIPBalance_ProductionOrderID
        ON dbo.WIPBalance(ProductionOrderID, StageID, QtyInStage);

    CREATE INDEX IX_PrintQueue_Status_CreatedAt
        ON dbo.PrintQueue(Status, CreatedAt);

    CREATE INDEX IX_PrintQueue_PrinterCode
        ON dbo.PrintQueue(PrinterCode, Status);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
