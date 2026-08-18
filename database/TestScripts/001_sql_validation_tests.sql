SET NOCOUNT ON;
GO

PRINT '=== DGP ERP SQL validation tests ===';
GO

-- Test 1: Validate required tables exist.
IF OBJECT_ID(N'dbo.Customer', N'U') IS NULL
BEGIN
    THROW 60001, 'Missing dbo.Customer table.', 1;
END;
IF OBJECT_ID(N'dbo.ItemMaster', N'U') IS NULL
BEGIN
    THROW 60002, 'Missing dbo.ItemMaster table.', 1;
END;
IF OBJECT_ID(N'dbo.SalesOrder', N'U') IS NULL
BEGIN
    THROW 60003, 'Missing dbo.SalesOrder table.', 1;
END;
IF OBJECT_ID(N'dbo.ProductionOrder', N'U') IS NULL
BEGIN
    THROW 60004, 'Missing dbo.ProductionOrder table.', 1;
END;
IF OBJECT_ID(N'dbo.WaveRequirement', N'U') IS NULL
BEGIN
    THROW 60005, 'Missing dbo.WaveRequirement table.', 1;
END;
IF OBJECT_ID(N'dbo.WavePlan', N'U') IS NULL
BEGIN
    THROW 60006, 'Missing dbo.WavePlan table.', 1;
END;
IF OBJECT_ID(N'dbo.InventoryBalance', N'U') IS NULL
BEGIN
    THROW 60007, 'Missing dbo.InventoryBalance table.', 1;
END;
IF OBJECT_ID(N'dbo.WIPBalance', N'U') IS NULL
BEGIN
    THROW 60008, 'Missing dbo.WIPBalance table.', 1;
END;
IF OBJECT_ID(N'dbo.PrintQueue', N'U') IS NULL
BEGIN
    THROW 60009, 'Missing dbo.PrintQueue table.', 1;
END;
PRINT 'Test 1 passed: core ERP tables exist.';
GO

-- Test 2: Validate required stored procedures exist.
IF OBJECT_ID(N'dbo.usp_GetItemCatalogForOrder', N'P') IS NULL
BEGIN
    THROW 60010, 'Missing dbo.usp_GetItemCatalogForOrder.', 1;
END;
IF OBJECT_ID(N'dbo.usp_CreateSalesOrderLineBoxFromCatalog', N'P') IS NULL
BEGIN
    THROW 60011, 'Missing dbo.usp_CreateSalesOrderLineBoxFromCatalog.', 1;
END;
IF OBJECT_ID(N'dbo.usp_CreateProductionOrderFromSalesOrderLine', N'P') IS NULL
BEGIN
    THROW 60012, 'Missing dbo.usp_CreateProductionOrderFromSalesOrderLine.', 1;
END;
IF OBJECT_ID(N'dbo.usp_SuggestCorrugatorLayout_Grid', N'P') IS NULL
BEGIN
    THROW 60013, 'Missing dbo.usp_SuggestCorrugatorLayout_Grid.', 1;
END;
IF OBJECT_ID(N'dbo.usp_CreateWaveRequirementFromCatalog', N'P') IS NULL
BEGIN
    THROW 60014, 'Missing dbo.usp_CreateWaveRequirementFromCatalog.', 1;
END;
IF OBJECT_ID(N'dbo.usp_CreateWavePlanFromRequirements', N'P') IS NULL
BEGIN
    THROW 60015, 'Missing dbo.usp_CreateWavePlanFromRequirements.', 1;
END;
IF OBJECT_ID(N'dbo.usp_WaveReceipt', N'P') IS NULL
BEGIN
    THROW 60016, 'Missing dbo.usp_WaveReceipt.', 1;
END;
IF OBJECT_ID(N'dbo.usp_IssueSheetToPrint', N'P') IS NULL
BEGIN
    THROW 60017, 'Missing dbo.usp_IssueSheetToPrint.', 1;
END;
IF OBJECT_ID(N'dbo.usp_FinishStage', N'P') IS NULL
BEGIN
    THROW 60018, 'Missing dbo.usp_FinishStage.', 1;
END;
IF OBJECT_ID(N'dbo.usp_FGReceipt', N'P') IS NULL
BEGIN
    THROW 60019, 'Missing dbo.usp_FGReceipt.', 1;
END;
IF OBJECT_ID(N'dbo.usp_SaleIssue', N'P') IS NULL
BEGIN
    THROW 60020, 'Missing dbo.usp_SaleIssue.', 1;
END;
IF OBJECT_ID(N'dbo.usp_CreatePrintQueue', N'P') IS NULL
BEGIN
    THROW 60021, 'Missing dbo.usp_CreatePrintQueue.', 1;
END;
IF OBJECT_ID(N'dbo.usp_ReprintLabel', N'P') IS NULL
BEGIN
    THROW 60022, 'Missing dbo.usp_ReprintLabel.', 1;
END;
PRINT 'Test 2 passed: required stored procedures exist.';
GO

-- Test 3: Validation for sample catalog item shape.
IF EXISTS (
    SELECT 1
    FROM dbo.ItemMaster im
    LEFT JOIN dbo.ItemCatalogBox icb ON icb.ItemID = im.ItemID
    LEFT JOIN dbo.ItemRecipeSheet irs ON irs.ItemID = im.ItemID
    WHERE im.ItemCode = 'HN001'
      AND icb.LengthMM > 0
      AND icb.WidthMM > 0
      AND icb.HeightMM > 0
      AND irs.SingleSheetLengthMM > 0
      AND irs.SingleSheetWidthMM > 0
)
BEGIN
    PRINT 'Test 3 passed: catalog data shape is valid.';
END
ELSE
BEGIN
    PRINT 'Test 3 warning: no sample catalog data present yet.';
END;
GO

-- Test 4: Validate index existence for key operational tables.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrder_CustomerID_Status' AND object_id = OBJECT_ID('dbo.SalesOrder'))
BEGIN
    THROW 60023, 'Missing index IX_SalesOrder_CustomerID_Status.', 1;
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ProductionOrder_Status' AND object_id = OBJECT_ID('dbo.ProductionOrder'))
BEGIN
    THROW 60024, 'Missing index IX_ProductionOrder_Status.', 1;
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_WaveRequirement_Status' AND object_id = OBJECT_ID('dbo.WaveRequirement'))
BEGIN
    THROW 60025, 'Missing index IX_WaveRequirement_Status.', 1;
END;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_PrintQueue_Status_CreatedAt' AND object_id = OBJECT_ID('dbo.PrintQueue'))
BEGIN
    THROW 60026, 'Missing index IX_PrintQueue_Status_CreatedAt.', 1;
END;
PRINT 'Test 4 passed: required operational indexes exist.';
GO

PRINT 'All SQL validation tests completed successfully.';
GO
