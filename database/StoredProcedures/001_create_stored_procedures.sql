SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.usp_GetItemCatalogForOrder', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GetItemCatalogForOrder;
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetItemCatalogForOrder
    @ItemCode NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        im.ItemID,
        im.ItemCode,
        im.ItemName,
        im.ItemType,
        icb.LengthMM AS LengthMM,
        icb.WidthMM AS WidthMM,
        icb.HeightMM AS HeightMM,
        icb.FluteCode,
        icb.DieCutCode,
        icb.PrintColor,
        icb.PrintNote,
        icb.GlueType,
        irs.SingleSheetLengthMM,
        irs.SingleSheetWidthMM,
        irs.SheetPerBox,
        irs.LossRate
    FROM dbo.ItemMaster im
    INNER JOIN dbo.ItemCatalogBox icb
        ON icb.ItemID = im.ItemID
    LEFT JOIN dbo.ItemRecipeSheet irs
        ON irs.ItemID = im.ItemID
       AND irs.IsDefault = 1
       AND irs.IsActive = 1
    WHERE im.ItemCode = @ItemCode
      AND im.IsActive = 1;
END;
GO

IF OBJECT_ID(N'dbo.usp_CreateSalesOrderLineBoxFromCatalog', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CreateSalesOrderLineBoxFromCatalog;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CreateSalesOrderLineBoxFromCatalog
    @SalesOrderID BIGINT,
    @ItemCode NVARCHAR(100),
    @Quantity DECIMAL(18,2),
    @UnitPrice DECIMAL(18,2) = NULL,
    @Note NVARCHAR(MAX) = NULL,
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalesOrderStatus NVARCHAR(30);
    DECLARE @ItemID BIGINT;
    DECLARE @LineID BIGINT;
    DECLARE @LengthMM DECIMAL(18,2);
    DECLARE @WidthMM DECIMAL(18,2);
    DECLARE @HeightMM DECIMAL(18,2);
    DECLARE @FluteCode NVARCHAR(20);
    DECLARE @DieCutCode NVARCHAR(100);
    DECLARE @PrintColor INT;
    DECLARE @PrintNote NVARCHAR(500);
    DECLARE @GlueType NVARCHAR(50);

    SELECT @SalesOrderStatus = Status
    FROM dbo.SalesOrder
    WHERE SalesOrderID = @SalesOrderID;

    IF @SalesOrderStatus IS NULL
        THROW 50001, 'Sales order not found.', 1;

    IF @SalesOrderStatus NOT IN ('Draft', 'Open')
        THROW 50002, 'Only draft or open sales orders can add box lines.', 1;

    SELECT
        @ItemID = im.ItemID,
        @LengthMM = icb.LengthMM,
        @WidthMM = icb.WidthMM,
        @HeightMM = icb.HeightMM,
        @FluteCode = icb.FluteCode,
        @DieCutCode = icb.DieCutCode,
        @PrintColor = icb.PrintColor,
        @PrintNote = icb.PrintNote,
        @GlueType = icb.GlueType
    FROM dbo.ItemMaster im
    INNER JOIN dbo.ItemCatalogBox icb ON icb.ItemID = im.ItemID
    WHERE im.ItemCode = @ItemCode
      AND im.IsActive = 1;

    IF @ItemID IS NULL
        THROW 50003, 'Catalog item not found.', 1;

    INSERT INTO dbo.SalesOrderLine
    (
        SalesOrderID,
        ItemID,
        ProductType,
        Quantity,
        Unit,
        UnitPrice,
        LineStatus,
        Note
    )
    VALUES
    (
        @SalesOrderID,
        @ItemID,
        'BOX',
        @Quantity,
        'PCS',
        @UnitPrice,
        'Open',
        @Note
    );

    SET @LineID = SCOPE_IDENTITY();

    INSERT INTO dbo.BoxSpec
    (
        LineID,
        LengthMM,
        WidthMM,
        HeightMM,
        FluteCode,
        DieCutCode,
        PrintColor,
        PrintNote,
        GlueType
    )
    VALUES
    (
        @LineID,
        @LengthMM,
        @WidthMM,
        @HeightMM,
        @FluteCode,
        @DieCutCode,
        @PrintColor,
        @PrintNote,
        @GlueType
    );

    INSERT INTO dbo.SalesOrderAudit
    (
        SalesOrderID,
        LineID,
        ActionType,
        OldValue,
        NewValue,
        Reason,
        CreatedBy,
        CreatedAt
    )
    VALUES
    (
        @SalesOrderID,
        @LineID,
        'CREATE',
        NULL,
        CONCAT('ItemCode=', @ItemCode, '; Quantity=', CONVERT(NVARCHAR(50), @Quantity)),
        'Catalog box line created',
        @CreatedBy,
        SYSDATETIME()
    );

    SELECT @LineID AS LineID;
END;
GO

IF OBJECT_ID(N'dbo.usp_CreateProductionOrderFromSalesOrderLine', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CreateProductionOrderFromSalesOrderLine;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CreateProductionOrderFromSalesOrderLine
    @LineID BIGINT,
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SalesOrderID BIGINT;
    DECLARE @ItemID BIGINT;
    DECLARE @ProductType NVARCHAR(20);
    DECLARE @PlannedQty DECIMAL(18,2);
    DECLARE @ProductionOrderID BIGINT;
    DECLARE @WaveReqID BIGINT;

    SELECT
        @SalesOrderID = sol.SalesOrderID,
        @ItemID = sol.ItemID,
        @ProductType = sol.ProductType,
        @PlannedQty = sol.Quantity
    FROM dbo.SalesOrderLine sol
    WHERE sol.LineID = @LineID;

    IF @SalesOrderID IS NULL
        THROW 50010, 'Sales order line not found.', 1;

    IF EXISTS (
        SELECT 1
        FROM dbo.ProductionOrder po
        WHERE po.LineID = @LineID
    )
        THROW 50011, 'A production order already exists for this line.', 1;

    INSERT INTO dbo.ProductionOrder
    (
        ProductionOrderNo,
        LineID,
        ItemID,
        ProductType,
        PlannedQty,
        ProducedQty,
        Status,
        CreatedBy,
        CreatedAt
    )
    VALUES
    (
        CONCAT('PO-', FORMAT(SYSDATETIME(), 'yyyyMMddHHmmss'), '-', @LineID),
        @LineID,
        @ItemID,
        @ProductType,
        @PlannedQty,
        0,
        'Created',
        @CreatedBy,
        SYSDATETIME()
    );

    SET @ProductionOrderID = SCOPE_IDENTITY();

    EXEC dbo.usp_CreateWaveRequirementFromCatalog
        @ProductionOrderID = @ProductionOrderID,
        @CreatedBy = @CreatedBy;

    SET @WaveReqID = (
        SELECT TOP 1 WaveReqID
        FROM dbo.WaveRequirement
        WHERE ProductionOrderID = @ProductionOrderID
        ORDER BY WaveReqID DESC
    );

    UPDATE dbo.SalesOrderLine
    SET LineStatus = 'Planned'
    WHERE LineID = @LineID;

    SELECT
        @ProductionOrderID AS ProductionOrderID,
        @WaveReqID AS WaveReqID;
END;
GO

IF OBJECT_ID(N'dbo.usp_SuggestCorrugatorLayout_Grid', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SuggestCorrugatorLayout_Grid;
GO
CREATE OR ALTER PROCEDURE dbo.usp_SuggestCorrugatorLayout_Grid
    @MachineCode NVARCHAR(50),
    @SingleSheetWidthMM DECIMAL(18,2),
    @SingleSheetLengthMM DECIMAL(18,2),
    @RequiredSheetQty DECIMAL(18,2),
    @RecipeSheetID BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MachineID BIGINT;
    DECLARE @EdgeTrimMM DECIMAL(18,2);
    DECLARE @MinRunWidthMM DECIMAL(18,2);
    DECLARE @MaxRunWidthMM DECIMAL(18,2);
    DECLARE @WidthStepMM DECIMAL(18,2);
    DECLARE @LaneCount INT = 1;
    DECLARE @MaxLaneCount INT = 20;
    DECLARE @RunWidthMM DECIMAL(18,2);
    DECLARE @WidthUsedMM DECIMAL(18,2);
    DECLARE @RawNeedWidthMM DECIMAL(18,2);
    DECLARE @CutCount DECIMAL(18,2);
    DECLARE @ProducedSheetQty DECIMAL(18,2);
    DECLARE @OverQty DECIMAL(18,2);
    DECLARE @RunningLengthM DECIMAL(18,2);
    DECLARE @Utilization DECIMAL(18,6);
    DECLARE @Score DECIMAL(18,6);

    SELECT
        @MachineID = cm.MachineID,
        @EdgeTrimMM = cm.EdgeTrimMM,
        @MinRunWidthMM = cm.MinRunWidthMM,
        @MaxRunWidthMM = cm.MaxRunWidthMM,
        @WidthStepMM = cm.WidthStepMM
    FROM dbo.CorrugatorMachine cm
    WHERE cm.MachineCode = @MachineCode
      AND cm.IsActive = 1;

    IF @MachineID IS NULL
        THROW 50020, 'Machine not found or inactive.', 1;

    CREATE TABLE #CandidateResults
    (
        LaneCount INT,
        RunWidthMM DECIMAL(18,2),
        WidthUsedMM DECIMAL(18,2),
        EdgeTrimMM DECIMAL(18,2),
        RawNeedWidthMM DECIMAL(18,2),
        CutCount DECIMAL(18,2),
        ProducedSheetQty DECIMAL(18,2),
        OverQty DECIMAL(18,2),
        RunningLengthM DECIMAL(18,2),
        WidthUtilization DECIMAL(18,6),
        Score DECIMAL(18,6)
    );

    WHILE @LaneCount <= @MaxLaneCount
    BEGIN
        SET @WidthUsedMM = @SingleSheetWidthMM * @LaneCount;
        SET @RawNeedWidthMM = @WidthUsedMM + @EdgeTrimMM;

        SET @RunWidthMM = (
            SELECT TOP 1 aw.RunWidthMM
            FROM dbo.CorrugatorAllowedWidth aw
            WHERE aw.MachineID = @MachineID
              AND aw.RunWidthMM >= @RawNeedWidthMM
              AND aw.IsActive = 1
            ORDER BY aw.RunWidthMM ASC
        );

        IF @RunWidthMM IS NOT NULL
        BEGIN
            SET @CutCount = CEILING(@RequiredSheetQty / CAST(@LaneCount AS DECIMAL(18,2)));
            SET @ProducedSheetQty = @CutCount * @LaneCount;
            SET @OverQty = @ProducedSheetQty - @RequiredSheetQty;
            SET @RunningLengthM = (@CutCount * @SingleSheetLengthMM) / 1000.0;
            SET @Utilization = @WidthUsedMM / @RunWidthMM;
            SET @Score = (@Utilization * 100) - (@OverQty * 0.05) - ((@RunWidthMM - @RawNeedWidthMM) * 0.01) + (@LaneCount * 0.25);

            INSERT INTO #CandidateResults
            (
                LaneCount,
                RunWidthMM,
                WidthUsedMM,
                EdgeTrimMM,
                RawNeedWidthMM,
                CutCount,
                ProducedSheetQty,
                OverQty,
                RunningLengthM,
                WidthUtilization,
                Score
            )
            VALUES
            (
                @LaneCount,
                @RunWidthMM,
                @WidthUsedMM,
                @EdgeTrimMM,
                @RawNeedWidthMM,
                @CutCount,
                @ProducedSheetQty,
                @OverQty,
                @RunningLengthM,
                @Utilization,
                @Score
            );
        END;

        SET @LaneCount = @LaneCount + 1;
    END;

    SELECT
        LaneCount,
        RunWidthMM,
        WidthUsedMM,
        EdgeTrimMM,
        RawNeedWidthMM,
        CutCount,
        ProducedSheetQty,
        OverQty,
        RunningLengthM,
        WidthUtilization,
        Score
    FROM #CandidateResults
    ORDER BY Score DESC, RunWidthMM ASC, LaneCount ASC;
END;
GO

IF OBJECT_ID(N'dbo.usp_CreateWaveRequirementFromCatalog', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CreateWaveRequirementFromCatalog;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CreateWaveRequirementFromCatalog
    @ProductionOrderID BIGINT,
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ItemID BIGINT;
    DECLARE @ItemCode NVARCHAR(100);
    DECLARE @RecipeSheetID BIGINT;
    DECLARE @PlannedQty DECIMAL(18,2);
    DECLARE @SheetPerBox DECIMAL(18,4);
    DECLARE @LossRate DECIMAL(18,4);
    DECLARE @MachineCode NVARCHAR(50);
    DECLARE @SingleSheetLengthMM DECIMAL(18,2);
    DECLARE @SingleSheetWidthMM DECIMAL(18,2);
    DECLARE @RequiredQty DECIMAL(18,2);
    DECLARE @WaveReqID BIGINT;

    SELECT
        @ItemID = po.ItemID,
        @PlannedQty = po.PlannedQty,
        @ItemCode = im.ItemCode
    FROM dbo.ProductionOrder po
    INNER JOIN dbo.ItemMaster im ON im.ItemID = po.ItemID
    WHERE po.ProductionOrderID = @ProductionOrderID;

    IF @ItemID IS NULL
        THROW 50030, 'Production order not found.', 1;

    SELECT TOP 1
        @RecipeSheetID = irs.RecipeSheetID,
        @SingleSheetLengthMM = irs.SingleSheetLengthMM,
        @SingleSheetWidthMM = irs.SingleSheetWidthMM,
        @SheetPerBox = irs.SheetPerBox,
        @LossRate = irs.LossRate,
        @MachineCode = COALESCE(irs.PreferredMachineCode, 'SONG_2500')
    FROM dbo.ItemRecipeSheet irs
    WHERE irs.ItemID = @ItemID
      AND irs.IsActive = 1
      AND irs.IsDefault = 1
    ORDER BY irs.UpdatedAt DESC;

    IF @RecipeSheetID IS NULL
        THROW 50031, 'No active default recipe sheet found for item.', 1;

    SET @RequiredQty = CAST(CEILING(@PlannedQty * @SheetPerBox * (1 + @LossRate)) AS DECIMAL(18,2));

    CREATE TABLE #LayoutCandidates
    (
        LaneCount INT,
        RunWidthMM DECIMAL(18,2),
        WidthUsedMM DECIMAL(18,2),
        EdgeTrimMM DECIMAL(18,2),
        RawNeedWidthMM DECIMAL(18,2),
        CutCount DECIMAL(18,2),
        ProducedSheetQty DECIMAL(18,2),
        OverQty DECIMAL(18,2),
        RunningLengthM DECIMAL(18,2),
        WidthUtilization DECIMAL(18,6),
        Score DECIMAL(18,6)
    );

    INSERT INTO #LayoutCandidates
    EXEC dbo.usp_SuggestCorrugatorLayout_Grid
        @MachineCode = @MachineCode,
        @SingleSheetWidthMM = @SingleSheetWidthMM,
        @SingleSheetLengthMM = @SingleSheetLengthMM,
        @RequiredSheetQty = @RequiredQty,
        @RecipeSheetID = @RecipeSheetID;

    DECLARE @BestLaneCount INT;
    DECLARE @BestRunWidthMM DECIMAL(18,2);
    DECLARE @BestWidthUsedMM DECIMAL(18,2);
    DECLARE @BestEdgeTrimMM DECIMAL(18,2);
    DECLARE @BestRequiredCutCount DECIMAL(18,2);
    DECLARE @BestProducedSheetQty DECIMAL(18,2);
    DECLARE @BestOverQty DECIMAL(18,2);
    DECLARE @BestRunningLengthM DECIMAL(18,2);
    DECLARE @BestUtilization DECIMAL(18,6);
    DECLARE @BestScore DECIMAL(18,6);

    SELECT TOP 1
        @BestLaneCount = LaneCount,
        @BestRunWidthMM = RunWidthMM,
        @BestWidthUsedMM = WidthUsedMM,
        @BestEdgeTrimMM = EdgeTrimMM,
        @BestRequiredCutCount = CutCount,
        @BestProducedSheetQty = ProducedSheetQty,
        @BestOverQty = OverQty,
        @BestRunningLengthM = RunningLengthM,
        @BestUtilization = WidthUtilization,
        @BestScore = Score
    FROM #LayoutCandidates
    ORDER BY Score DESC, RunWidthMM ASC, LaneCount ASC;

    INSERT INTO dbo.CorrugatorLayoutCandidate
    (
        RecipeSheetID,
        MachineID,
        SingleSheetLengthMM,
        SingleSheetWidthMM,
        LaneCount,
        WidthUsedMM,
        EdgeTrimMM,
        RawNeedWidthMM,
        RunWidthMM,
        TotalWasteWidthMM,
        ExtraWasteWidthMM,
        WidthUtilization,
        RequiredSheetQty,
        RequiredCutCount,
        ProducedSheetQty,
        OverQty,
        RunningLengthM,
        Score,
        IsBest,
        CreatedAt
    )
    VALUES
    (
        @RecipeSheetID,
        (SELECT MachineID FROM dbo.CorrugatorMachine WHERE MachineCode = @MachineCode),
        @SingleSheetLengthMM,
        @SingleSheetWidthMM,
        @BestLaneCount,
        @BestWidthUsedMM,
        @BestEdgeTrimMM,
        @BestWidthUsedMM + @BestEdgeTrimMM,
        @BestRunWidthMM,
        @BestRunWidthMM - @BestWidthUsedMM,
        @BestRunWidthMM - (@BestWidthUsedMM + @BestEdgeTrimMM),
        @BestUtilization,
        @RequiredQty,
        @BestRequiredCutCount,
        @BestProducedSheetQty,
        @BestOverQty,
        @BestRunningLengthM,
        @BestScore,
        1,
        SYSDATETIME()
    );

    SET @WaveReqID = SCOPE_IDENTITY();

    INSERT INTO dbo.WaveRequirement
    (
        ProductionOrderID,
        SourceLineID,
        ProductType,
        ItemID,
        RecipeSheetID,
        FluteCode,
        SingleSheetLengthMM,
        SingleSheetWidthMM,
        LaneCount,
        RunWidthMM,
        WidthUsedMM,
        EdgeTrimMM,
        WidthUtilization,
        LayoutCandidateID,
        RequiredQty,
        CutCount,
        PlannedSheetQty,
        ProducedQty,
        IssuedQty,
        OverQty,
        RunningLengthM,
        Status,
        CreatedAt
    )
    SELECT
        @ProductionOrderID,
        po.LineID,
        po.ProductType,
        po.ItemID,
        @RecipeSheetID,
        irs.FluteCode,
        @SingleSheetLengthMM,
        @SingleSheetWidthMM,
        @BestLaneCount,
        @BestRunWidthMM,
        @BestWidthUsedMM,
        @BestEdgeTrimMM,
        @BestUtilization,
        SCOPE_IDENTITY(),
        @RequiredQty,
        @BestRequiredCutCount,
        @BestProducedSheetQty,
        0,
        0,
        @BestOverQty,
        @BestRunningLengthM,
        'Open',
        SYSDATETIME()
    FROM dbo.ProductionOrder po
    INNER JOIN dbo.ItemRecipeSheet irs ON irs.RecipeSheetID = @RecipeSheetID
    WHERE po.ProductionOrderID = @ProductionOrderID;

    UPDATE dbo.ProductionOrder
    SET Status = 'WaveRequired'
    WHERE ProductionOrderID = @ProductionOrderID;

    SELECT SCOPE_IDENTITY() AS WaveReqID;
END;
GO

IF OBJECT_ID(N'dbo.usp_CreateWavePlanFromRequirements', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CreateWavePlanFromRequirements;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CreateWavePlanFromRequirements
    @WavePlanNo NVARCHAR(50),
    @PlanDate DATE,
    @MachineCode NVARCHAR(50),
    @FluteCode NVARCHAR(20),
    @RunWidthMM DECIMAL(18,2),
    @WaveReqIDs NVARCHAR(MAX),
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WavePlanID BIGINT;
    DECLARE @x XML;

    IF NULLIF(LTRIM(RTRIM(@WaveReqIDs)), '') IS NULL
        THROW 50040, 'Wave requirement IDs are required.', 1;

    INSERT INTO dbo.WavePlan
    (
        WavePlanNo,
        PlanDate,
        MachineCode,
        FluteCode,
        RunWidthMM,
        TotalPlannedSheetQty,
        TotalCutCount,
        TotalRunningLengthM,
        Status,
        CreatedBy,
        CreatedAt
    )
    VALUES
    (
        @WavePlanNo,
        @PlanDate,
        @MachineCode,
        @FluteCode,
        @RunWidthMM,
        0,
        0,
        0,
        'Planned',
        @CreatedBy,
        SYSDATETIME()
    );

    SET @WavePlanID = SCOPE_IDENTITY();
    SET @x = CAST('<root><s>' + REPLACE(@WaveReqIDs, ',', '</s><s>') + '</s></root>' AS XML);

    INSERT INTO dbo.WavePlanDetail
    (
        WavePlanID,
        WaveReqID,
        SingleSheetLengthMM,
        SingleSheetWidthMM,
        LaneCount,
        RunWidthMM,
        RequiredSheetQty,
        CutCount,
        PlannedSheetQty,
        ProducedSheetQty,
        OverQty,
        RunningLengthM,
        WidthUtilization
    )
    SELECT
        @WavePlanID,
        CAST(d.value('.', 'BIGINT') AS BIGINT),
        wr.SingleSheetLengthMM,
        wr.SingleSheetWidthMM,
        wr.LaneCount,
        wr.RunWidthMM,
        wr.RequiredQty,
        wr.CutCount,
        wr.PlannedSheetQty,
        0,
        COALESCE(wr.OverQty, 0),
        wr.RunningLengthM,
        wr.WidthUtilization
    FROM @x.nodes('/root/s') AS T(d)
    INNER JOIN dbo.WaveRequirement wr ON wr.WaveReqID = CAST(d.value('.', 'BIGINT') AS BIGINT);

    UPDATE wp
    SET
        TotalPlannedSheetQty = (SELECT SUM(PlannedSheetQty) FROM dbo.WavePlanDetail WHERE WavePlanID = @WavePlanID),
        TotalCutCount = (SELECT SUM(CutCount) FROM dbo.WavePlanDetail WHERE WavePlanID = @WavePlanID),
        TotalRunningLengthM = (SELECT SUM(ISNULL(RunningLengthM, 0)) FROM dbo.WavePlanDetail WHERE WavePlanID = @WavePlanID)
    FROM dbo.WavePlan wp
    WHERE wp.WavePlanID = @WavePlanID;

    UPDATE wr
    SET Status = 'Planned'
    FROM dbo.WaveRequirement wr
    INNER JOIN @x.nodes('/root/s') AS T(d)
        ON wr.WaveReqID = CAST(d.value('.', 'BIGINT') AS BIGINT);

    SELECT @WavePlanID AS WavePlanID;
END;
GO

IF OBJECT_ID(N'dbo.usp_WaveReceipt', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_WaveReceipt;
GO
CREATE OR ALTER PROCEDURE dbo.usp_WaveReceipt
    @WavePlanID BIGINT,
    @WaveReqID BIGINT,
    @WarehouseID BIGINT,
    @Qty DECIMAL(18,2),
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ItemID BIGINT;
    DECLARE @WavePlanNo NVARCHAR(50);
    DECLARE @RefNo NVARCHAR(100);

    SELECT
        @ItemID = wr.ItemID,
        @WavePlanNo = wp.WavePlanNo
    FROM dbo.WaveRequirement wr
    INNER JOIN dbo.WavePlan wp ON wp.WavePlanID = @WavePlanID
    WHERE wr.WaveReqID = @WaveReqID;

    IF @ItemID IS NULL
        THROW 50050, 'Wave requirement not found.', 1;

    SET @RefNo = CONCAT('WAVE-', @WavePlanNo, '-', @WaveReqID);

    INSERT INTO dbo.InventoryTransaction
    (
        ItemID,
        WarehouseID,
        TransactionType,
        Qty,
        Unit,
        RefType,
        RefID,
        RefNo,
        Note,
        CreatedBy,
        CreatedAt
    )
    VALUES
    (
        @ItemID,
        @WarehouseID,
        'WAVE_RECEIPT',
        @Qty,
        'PCS',
        'WAVEPLAN',
        @WaveReqID,
        @RefNo,
        'Wave receipt',
        @CreatedBy,
        SYSDATETIME()
    );

    MERGE dbo.InventoryBalance AS target
    USING (
        SELECT @ItemID AS ItemID, @WarehouseID AS WarehouseID, NULL AS LotNo, NULL AS PalletNo, @Qty AS Qty
    ) AS src
    ON target.ItemID = src.ItemID
   AND target.WarehouseID = src.WarehouseID
   AND target.LotNo IS NULL
   AND target.PalletNo IS NULL
    WHEN MATCHED THEN
        UPDATE SET QtyOnHand = QtyOnHand + src.Qty, UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ItemID, WarehouseID, LotNo, PalletNo, QtyOnHand, ReservedQty, UpdatedAt)
        VALUES (src.ItemID, src.WarehouseID, src.LotNo, src.PalletNo, src.Qty, 0, SYSDATETIME());

    UPDATE dbo.WaveRequirement
    SET ProducedQty = ProducedQty + @Qty,
        Status = 'Completed'
    WHERE WaveReqID = @WaveReqID;

    SELECT @RefNo AS RefNo;
END;
GO

IF OBJECT_ID(N'dbo.usp_IssueSheetToPrint', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_IssueSheetToPrint;
GO
CREATE OR ALTER PROCEDURE dbo.usp_IssueSheetToPrint
    @ProductionOrderID BIGINT,
    @ItemID BIGINT,
    @WarehouseID BIGINT,
    @Qty DECIMAL(18,2),
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StageID BIGINT;
    DECLARE @WIPTransID BIGINT;

    SELECT @StageID = StageID
    FROM dbo.WIPStage
    WHERE StageCode = 'PRINT';

    IF @StageID IS NULL
        THROW 50060, 'PRINT stage not found.', 1;

    INSERT INTO dbo.InventoryTransaction
    (
        ItemID,
        WarehouseID,
        TransactionType,
        Qty,
        Unit,
        RefType,
        RefID,
        RefNo,
        Note,
        CreatedBy,
        CreatedAt
    )
    VALUES
    (
        @ItemID,
        @WarehouseID,
        'ISSUE_TO_PRINT',
        -@Qty,
        'PCS',
        'PRODUCTION',
        @ProductionOrderID,
        CONCAT('PO-', @ProductionOrderID),
        'Issue to print',
        @CreatedBy,
        SYSDATETIME()
    );

    MERGE dbo.InventoryBalance AS target
    USING (
        SELECT @ItemID AS ItemID, @WarehouseID AS WarehouseID, NULL AS LotNo, NULL AS PalletNo, -@Qty AS Qty
    ) AS src
    ON target.ItemID = src.ItemID
   AND target.WarehouseID = src.WarehouseID
   AND target.LotNo IS NULL
   AND target.PalletNo IS NULL
    WHEN MATCHED THEN
        UPDATE SET QtyOnHand = QtyOnHand + src.Qty, UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ItemID, WarehouseID, LotNo, PalletNo, QtyOnHand, ReservedQty, UpdatedAt)
        VALUES (src.ItemID, src.WarehouseID, src.LotNo, src.PalletNo, src.Qty, 0, SYSDATETIME());

    INSERT INTO dbo.WIPTransaction
    (
        ProductionOrderID,
        StageID,
        ItemID,
        WIPTransType,
        Qty,
        Unit,
        RefType,
        RefID,
        Note,
        CreatedBy,
        CreatedAt
    )
    VALUES
    (
        @ProductionOrderID,
        @StageID,
        @ItemID,
        'START_STAGE',
        @Qty,
        'PCS',
        'PRODUCTION',
        @ProductionOrderID,
        'Issue to print stage',
        @CreatedBy,
        SYSDATETIME()
    );

    SET @WIPTransID = SCOPE_IDENTITY();

    MERGE dbo.WIPBalance AS target
    USING (
        SELECT @ProductionOrderID AS ProductionOrderID, @StageID AS StageID, @ItemID AS ItemID, @Qty AS Qty
    ) AS src
    ON target.ProductionOrderID = src.ProductionOrderID
   AND target.StageID = src.StageID
   AND target.ItemID = src.ItemID
    WHEN MATCHED THEN
        UPDATE SET QtyInStage = QtyInStage + src.Qty, UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ProductionOrderID, StageID, ItemID, QtyInStage, UpdatedAt)
        VALUES (src.ProductionOrderID, src.StageID, src.ItemID, src.Qty, SYSDATETIME());

    UPDATE dbo.ProductionOrder
    SET Status = 'InProduction'
    WHERE ProductionOrderID = @ProductionOrderID;

    SELECT @WIPTransID AS WIPTransID;
END;
GO

IF OBJECT_ID(N'dbo.usp_FinishStage', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_FinishStage;
GO
CREATE OR ALTER PROCEDURE dbo.usp_FinishStage
    @ProductionOrderID BIGINT,
    @StageCode NVARCHAR(50),
    @Qty DECIMAL(18,2),
    @ScrapQty DECIMAL(18,2) = 0,
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StageID BIGINT;
    DECLARE @ItemID BIGINT;

    SELECT @StageID = StageID
    FROM dbo.WIPStage
    WHERE StageCode = @StageCode;

    SELECT @ItemID = ItemID
    FROM dbo.ProductionOrder
    WHERE ProductionOrderID = @ProductionOrderID;

    IF @StageID IS NULL
        THROW 50070, 'Stage not found.', 1;

    INSERT INTO dbo.WIPTransaction
    (
        ProductionOrderID,
        StageID,
        ItemID,
        WIPTransType,
        Qty,
        Unit,
        RefType,
        RefID,
        Note,
        CreatedBy,
        CreatedAt
    )
    VALUES
    (
        @ProductionOrderID,
        @StageID,
        @ItemID,
        'FINISH_STAGE',
        @Qty,
        'PCS',
        'PRODUCTION',
        @ProductionOrderID,
        'Finish stage',
        @CreatedBy,
        SYSDATETIME()
    );

    IF @ScrapQty > 0
    BEGIN
        INSERT INTO dbo.WIPTransaction
        (
            ProductionOrderID,
            StageID,
            ItemID,
            WIPTransType,
            Qty,
            Unit,
            RefType,
            RefID,
            Note,
            CreatedBy,
            CreatedAt
        )
        VALUES
        (
            @ProductionOrderID,
            @StageID,
            @ItemID,
            'SCRAP',
            @ScrapQty,
            'PCS',
            'PRODUCTION',
            @ProductionOrderID,
            'Scrap at stage',
            @CreatedBy,
            SYSDATETIME()
        );
    END;

    UPDATE wb
    SET QtyInStage = CASE WHEN QtyInStage >= @Qty THEN QtyInStage - @Qty ELSE 0 END,
        UpdatedAt = SYSDATETIME()
    FROM dbo.WIPBalance wb
    WHERE wb.ProductionOrderID = @ProductionOrderID
      AND wb.StageID = @StageID;

    SELECT @StageID AS StageID;
END;
GO

IF OBJECT_ID(N'dbo.usp_FGReceipt', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_FGReceipt;
GO
CREATE OR ALTER PROCEDURE dbo.usp_FGReceipt
    @ProductionOrderID BIGINT,
    @ItemID BIGINT,
    @WarehouseID BIGINT,
    @Qty DECIMAL(18,2),
    @PalletNo NVARCHAR(100) = NULL,
    @PrintLabel BIT = 0,
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.InventoryTransaction
    (
        ItemID,
        WarehouseID,
        TransactionType,
        Qty,
        Unit,
        RefType,
        RefID,
        RefNo,
        LotNo,
        PalletNo,
        Note,
        CreatedBy,
        CreatedAt
    )
    VALUES
    (
        @ItemID,
        @WarehouseID,
        'FG_RECEIPT',
        @Qty,
        'PCS',
        'PRODUCTION',
        @ProductionOrderID,
        CONCAT('FG-', @ProductionOrderID),
        NULL,
        @PalletNo,
        'Finished goods receipt',
        @CreatedBy,
        SYSDATETIME()
    );

    MERGE dbo.InventoryBalance AS target
    USING (
        SELECT @ItemID AS ItemID, @WarehouseID AS WarehouseID, NULL AS LotNo, @PalletNo AS PalletNo, @Qty AS Qty
    ) AS src
    ON target.ItemID = src.ItemID
   AND target.WarehouseID = src.WarehouseID
   AND target.LotNo = src.LotNo
   AND target.PalletNo = src.PalletNo
    WHEN MATCHED THEN
        UPDATE SET QtyOnHand = QtyOnHand + src.Qty, UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ItemID, WarehouseID, LotNo, PalletNo, QtyOnHand, ReservedQty, UpdatedAt)
        VALUES (src.ItemID, src.WarehouseID, src.LotNo, src.PalletNo, src.Qty, 0, SYSDATETIME());

    UPDATE po
    SET ProducedQty = ProducedQty + @Qty,
        Status = CASE WHEN (ProducedQty + @Qty) >= PlannedQty THEN 'Completed' ELSE 'InProduction' END
    FROM dbo.ProductionOrder po
    WHERE po.ProductionOrderID = @ProductionOrderID;

    IF @PrintLabel = 1
    BEGIN
        INSERT INTO dbo.PrintQueue
        (
            PrinterCode,
            LabelType,
            RefType,
            RefID,
            ZPL,
            Status,
            RetryCount,
            MaxRetry,
            ErrorMessage,
            CreatedBy,
            CreatedAt,
            ProcessingAt,
            PrintedAt
        )
        VALUES
        (
            'KHO_TP',
            'FG',
            'PRODUCTION',
            @ProductionOrderID,
            '^XA^FO40,30^FDFG LABEL^FS^XZ',
            'Pending',
            0,
            3,
            NULL,
            @CreatedBy,
            SYSDATETIME(),
            NULL,
            NULL
        );
    END;

    SELECT @ProductionOrderID AS ProductionOrderID;
END;
GO

IF OBJECT_ID(N'dbo.usp_SaleIssue', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_SaleIssue;
GO
CREATE OR ALTER PROCEDURE dbo.usp_SaleIssue
    @ItemID BIGINT,
    @WarehouseID BIGINT,
    @Qty DECIMAL(18,2),
    @RefType NVARCHAR(50),
    @RefNo NVARCHAR(100),
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.InventoryTransaction
    (
        ItemID,
        WarehouseID,
        TransactionType,
        Qty,
        Unit,
        RefType,
        RefID,
        RefNo,
        Note,
        CreatedBy,
        CreatedAt
    )
    VALUES
    (
        @ItemID,
        @WarehouseID,
        'SALE_ISSUE',
        -@Qty,
        'PCS',
        @RefType,
        NULL,
        @RefNo,
        'Sale issue',
        @CreatedBy,
        SYSDATETIME()
    );

    MERGE dbo.InventoryBalance AS target
    USING (
        SELECT @ItemID AS ItemID, @WarehouseID AS WarehouseID, NULL AS LotNo, NULL AS PalletNo, -@Qty AS Qty
    ) AS src
    ON target.ItemID = src.ItemID
   AND target.WarehouseID = src.WarehouseID
   AND target.LotNo IS NULL
   AND target.PalletNo IS NULL
    WHEN MATCHED THEN
        UPDATE SET QtyOnHand = QtyOnHand + src.Qty, UpdatedAt = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (ItemID, WarehouseID, LotNo, PalletNo, QtyOnHand, ReservedQty, UpdatedAt)
        VALUES (src.ItemID, src.WarehouseID, src.LotNo, src.PalletNo, src.Qty, 0, SYSDATETIME());

    SELECT @RefNo AS RefNo;
END;
GO

IF OBJECT_ID(N'dbo.usp_CreatePrintQueue', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CreatePrintQueue;
GO
CREATE OR ALTER PROCEDURE dbo.usp_CreatePrintQueue
    @PrinterCode NVARCHAR(50),
    @LabelType NVARCHAR(50),
    @RefType NVARCHAR(50),
    @RefID BIGINT,
    @ZPL NVARCHAR(MAX),
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.PrinterList WHERE PrinterCode = @PrinterCode AND IsActive = 1)
        THROW 50080, 'Printer is not active.', 1;

    INSERT INTO dbo.PrintQueue
    (
        PrinterCode,
        LabelType,
        RefType,
        RefID,
        ZPL,
        Status,
        RetryCount,
        MaxRetry,
        ErrorMessage,
        CreatedBy,
        CreatedAt,
        ProcessingAt,
        PrintedAt
    )
    VALUES
    (
        @PrinterCode,
        @LabelType,
        @RefType,
        @RefID,
        @ZPL,
        'Pending',
        0,
        3,
        NULL,
        @CreatedBy,
        SYSDATETIME(),
        NULL,
        NULL
    );

    SELECT SCOPE_IDENTITY() AS PrintID;
END;
GO

IF OBJECT_ID(N'dbo.usp_ReprintLabel', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ReprintLabel;
GO
CREATE OR ALTER PROCEDURE dbo.usp_ReprintLabel
    @PrintID BIGINT,
    @CreatedBy NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ZPL NVARCHAR(MAX);
    DECLARE @PrinterCode NVARCHAR(50);
    DECLARE @LabelType NVARCHAR(50);
    DECLARE @RefType NVARCHAR(50);
    DECLARE @RefID BIGINT;

    SELECT
        @ZPL = ZPL,
        @PrinterCode = PrinterCode,
        @LabelType = LabelType,
        @RefType = RefType,
        @RefID = RefID
    FROM dbo.PrintQueue
    WHERE PrintID = @PrintID;

    IF @ZPL IS NULL
        THROW 50090, 'Print record not found.', 1;

    INSERT INTO dbo.PrintQueue
    (
        PrinterCode,
        LabelType,
        RefType,
        RefID,
        ZPL,
        Status,
        RetryCount,
        MaxRetry,
        ErrorMessage,
        CreatedBy,
        CreatedAt,
        ProcessingAt,
        PrintedAt
    )
    VALUES
    (
        @PrinterCode,
        @LabelType,
        @RefType,
        @RefID,
        @ZPL,
        'Pending',
        0,
        3,
        NULL,
        @CreatedBy,
        SYSDATETIME(),
        NULL,
        NULL
    );

    SELECT SCOPE_IDENTITY() AS ReprintPrintID;
END;
GO
