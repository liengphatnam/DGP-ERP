SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.CorrugatorMachine WHERE MachineCode = 'SONG_2500')
    BEGIN
        INSERT INTO dbo.CorrugatorMachine (MachineCode, MachineName, MinRunWidthMM, MaxRunWidthMM, WidthStepMM, EdgeTrimMM, IsActive)
        VALUES ('SONG_2500', 'Song 2500', 1250, 2500, 50, 20, 1);
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.WIPStage WHERE StageCode = 'WAVE')
        INSERT INTO dbo.WIPStage (StageCode, StageName, SortOrder, IsActive) VALUES ('WAVE', 'Wave', 1, 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.WIPStage WHERE StageCode = 'PRINT')
        INSERT INTO dbo.WIPStage (StageCode, StageName, SortOrder, IsActive) VALUES ('PRINT', 'Print', 2, 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.WIPStage WHERE StageCode = 'DIECUT')
        INSERT INTO dbo.WIPStage (StageCode, StageName, SortOrder, IsActive) VALUES ('DIECUT', 'Die Cut', 3, 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.WIPStage WHERE StageCode = 'GLUE')
        INSERT INTO dbo.WIPStage (StageCode, StageName, SortOrder, IsActive) VALUES ('GLUE', 'Glue', 4, 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.WIPStage WHERE StageCode = 'PACKING')
        INSERT INTO dbo.WIPStage (StageCode, StageName, SortOrder, IsActive) VALUES ('PACKING', 'Packing', 5, 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.Warehouse WHERE WarehouseCode = 'WH_ROLL')
        INSERT INTO dbo.Warehouse (WarehouseCode, WarehouseName, WarehouseType, IsActive) VALUES ('WH_ROLL', 'Roll Warehouse', 'ROLL', 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.Warehouse WHERE WarehouseCode = 'WH_SHEET')
        INSERT INTO dbo.Warehouse (WarehouseCode, WarehouseName, WarehouseType, IsActive) VALUES ('WH_SHEET', 'Sheet Warehouse', 'SHEET', 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.Warehouse WHERE WarehouseCode = 'WH_FG')
        INSERT INTO dbo.Warehouse (WarehouseCode, WarehouseName, WarehouseType, IsActive) VALUES ('WH_FG', 'Finished Goods Warehouse', 'FG', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.PrinterList WHERE PrinterCode = 'KHO_TP')
        INSERT INTO dbo.PrinterList (PrinterCode, PrinterName, PrinterType, ConnectionType, PrinterIP, PrinterPort, WindowsPrinterName, LocationName, IsActive)
        VALUES ('KHO_TP', 'Kho TP Zebra', 'ZEBRA', 'IP', '192.168.1.200', 9100, NULL, 'Kho TP', 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.PrinterList WHERE PrinterCode = 'KHO_GIAY')
        INSERT INTO dbo.PrinterList (PrinterCode, PrinterName, PrinterType, ConnectionType, PrinterIP, PrinterPort, WindowsPrinterName, LocationName, IsActive)
        VALUES ('KHO_GIAY', 'Kho Giay Zebra', 'ZEBRA', 'WINDOWS_PRINTER', NULL, NULL, 'Zebra_Giay', 'Kho Giay', 1);

    DECLARE @MachineID BIGINT = (SELECT MachineID FROM dbo.CorrugatorMachine WHERE MachineCode = 'SONG_2500');
    DECLARE @RunWidth DECIMAL(18,2) = 1250;
    WHILE @RunWidth <= 2500
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.CorrugatorAllowedWidth WHERE MachineID = @MachineID AND RunWidthMM = @RunWidth)
            INSERT INTO dbo.CorrugatorAllowedWidth (MachineID, RunWidthMM, IsActive) VALUES (@MachineID, @RunWidth, 1);

        SET @RunWidth = @RunWidth + 50;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.ItemMaster WHERE ItemCode = 'HN001')
        INSERT INTO dbo.ItemMaster (ItemCode, ItemName, ItemType, Unit, IsActive) VALUES ('HN001', 'Carton HN001', 'BOX', 'PCS', 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.ItemMaster WHERE ItemCode = 'HN002')
        INSERT INTO dbo.ItemMaster (ItemCode, ItemName, ItemType, Unit, IsActive) VALUES ('HN002', 'Carton HN002', 'BOX', 'PCS', 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.ItemMaster WHERE ItemCode = 'AS001')
        INSERT INTO dbo.ItemMaster (ItemCode, ItemName, ItemType, Unit, IsActive) VALUES ('AS001', 'Carton AS001', 'BOX', 'PCS', 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.ItemMaster WHERE ItemCode = 'BC1250')
        INSERT INTO dbo.ItemMaster (ItemCode, ItemName, ItemType, Unit, IsActive) VALUES ('BC1250', 'Sheet BC1250', 'SHEET', 'PCS', 1);

    DECLARE @HN001 BIGINT = (SELECT ItemID FROM dbo.ItemMaster WHERE ItemCode = 'HN001');
    DECLARE @HN002 BIGINT = (SELECT ItemID FROM dbo.ItemMaster WHERE ItemCode = 'HN002');
    DECLARE @AS001 BIGINT = (SELECT ItemID FROM dbo.ItemMaster WHERE ItemCode = 'AS001');
    DECLARE @BC1250 BIGINT = (SELECT ItemID FROM dbo.ItemMaster WHERE ItemCode = 'BC1250');

    IF NOT EXISTS (SELECT 1 FROM dbo.ItemCatalogBox WHERE ItemID = @HN001)
        INSERT INTO dbo.ItemCatalogBox (ItemID, ItemCode, ItemName, LengthMM, WidthMM, HeightMM, FluteCode, DieCutCode, PrintColor, PrintNote, GlueType, IsActive)
        VALUES (@HN001, 'HN001', 'Carton HN001', 350, 250, 200, 'BC', 'K001', 2, '2 colors', 'Standard', 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.ItemCatalogBox WHERE ItemID = @HN002)
        INSERT INTO dbo.ItemCatalogBox (ItemID, ItemCode, ItemName, LengthMM, WidthMM, HeightMM, FluteCode, DieCutCode, PrintColor, PrintNote, GlueType, IsActive)
        VALUES (@HN002, 'HN002', 'Carton HN002', 400, 300, 250, 'BC', 'K002', 3, '3 colors', 'Standard', 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.ItemCatalogBox WHERE ItemID = @AS001)
        INSERT INTO dbo.ItemCatalogBox (ItemID, ItemCode, ItemName, LengthMM, WidthMM, HeightMM, FluteCode, DieCutCode, PrintColor, PrintNote, GlueType, IsActive)
        VALUES (@AS001, 'AS001', 'Carton AS001', 420, 310, 280, 'E', 'K011', 4, '4 colors', 'Adhesive', 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.ItemRecipeSheet WHERE ItemID = @HN001 AND RecipeVersion = 'V1')
        INSERT INTO dbo.ItemRecipeSheet (ItemID, RecipeVersion, IsDefault, SheetItemCode, FluteCode, SingleSheetLengthMM, SingleSheetWidthMM, SheetPerBox, LossRate, PreferredMachineCode, PreferredLaneCount, PreferredRunWidthMM, IsActive)
        VALUES (@HN001, 'V1', 1, 'BC1250', 'BC', 1250, 500, 1, 0.03, 'SONG_2500', 4, 2050, 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.ItemRecipeSheet WHERE ItemID = @HN002 AND RecipeVersion = 'V1')
        INSERT INTO dbo.ItemRecipeSheet (ItemID, RecipeVersion, IsDefault, SheetItemCode, FluteCode, SingleSheetLengthMM, SingleSheetWidthMM, SheetPerBox, LossRate, PreferredMachineCode, PreferredLaneCount, PreferredRunWidthMM, IsActive)
        VALUES (@HN002, 'V1', 1, 'BC1250', 'BC', 1400, 600, 1, 0.03, 'SONG_2500', 4, 2050, 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.ItemRecipeSheet WHERE ItemID = @AS001 AND RecipeVersion = 'V1')
        INSERT INTO dbo.ItemRecipeSheet (ItemID, RecipeVersion, IsDefault, SheetItemCode, FluteCode, SingleSheetLengthMM, SingleSheetWidthMM, SheetPerBox, LossRate, PreferredMachineCode, PreferredLaneCount, PreferredRunWidthMM, IsActive)
        VALUES (@AS001, 'V1', 1, 'BC1250', 'E', 1500, 700, 1, 0.04, 'SONG_2500', 4, 2050, 1);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
