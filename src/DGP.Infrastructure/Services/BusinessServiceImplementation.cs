using System.Data;
using Dapper;
using DGP.Application.Services;
using Microsoft.Data.SqlClient;

namespace DGP.Infrastructure.Services;

public sealed class CatalogLookupService : ICatalogLookupService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public CatalogLookupService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<ItemCatalogLookupResult?> GetCatalogAsync(string itemCode, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@ItemCode", itemCode, DbType.String);

        var result = await connection.QuerySingleOrDefaultAsync<ItemCatalogLookupResult>(
            "EXEC dbo.usp_GetItemCatalogForOrder @ItemCode",
            parameters);

        return result;
    }
}

public sealed class BoxSpecSnapshotService : IBoxSpecSnapshotService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public BoxSpecSnapshotService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<long> CreateFromCatalogAsync(long salesOrderId, string itemCode, decimal quantity, string createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@SalesOrderID", salesOrderId, DbType.Int64);
        parameters.Add("@ItemCode", itemCode, DbType.String);
        parameters.Add("@Quantity", quantity, DbType.Decimal);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        var lineId = await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_CreateSalesOrderLineBoxFromCatalog @SalesOrderID, @ItemCode, @Quantity, @CreatedBy",
            parameters);

        return lineId;
    }
}

public sealed class SheetSpecSnapshotService : ISheetSpecSnapshotService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public SheetSpecSnapshotService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<long> CreateSnapshotAsync(long salesOrderId, string itemCode, decimal quantity, string createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@SalesOrderID", salesOrderId, DbType.Int64);
        parameters.Add("@ItemCode", itemCode, DbType.String);
        parameters.Add("@Quantity", quantity, DbType.Decimal);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_CreateSalesOrderLineBoxFromCatalog @SalesOrderID, @ItemCode, @Quantity, @CreatedBy",
            parameters);
    }
}

public sealed class SalesOrderService : ISalesOrderService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public SalesOrderService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<long> CreateLineFromCatalogAsync(long salesOrderId, string itemCode, decimal quantity, string createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@SalesOrderID", salesOrderId, DbType.Int64);
        parameters.Add("@ItemCode", itemCode, DbType.String);
        parameters.Add("@Quantity", quantity, DbType.Decimal);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_CreateSalesOrderLineBoxFromCatalog @SalesOrderID, @ItemCode, @Quantity, @CreatedBy",
            parameters);
    }

    public async Task<bool> ConfirmAsync(long salesOrderId, string confirmedBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@SalesOrderID", salesOrderId, DbType.Int64);
        parameters.Add("@ConfirmedBy", confirmedBy, DbType.String);

        var result = await connection.ExecuteScalarAsync<int>(
            "EXEC dbo.usp_ConfirmSalesOrder @SalesOrderID, @ConfirmedBy",
            parameters);

        return result > 0;
    }

    public async Task<long> CreateRevisionAsync(long salesOrderId, string reason, string createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@SalesOrderID", salesOrderId, DbType.Int64);
        parameters.Add("@Reason", reason, DbType.String);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_CreateSalesOrderRevision @SalesOrderID, @Reason, @CreatedBy",
            parameters);
    }

    public async Task<bool> CancelLineAsync(long lineId, string reason, string cancelledBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@LineID", lineId, DbType.Int64);
        parameters.Add("@Reason", reason, DbType.String);
        parameters.Add("@CancelledBy", cancelledBy, DbType.String);

        var result = await connection.ExecuteScalarAsync<int>(
            "EXEC dbo.usp_CancelSalesOrderLine @LineID, @Reason, @CancelledBy",
            parameters);

        return result > 0;
    }
}

public sealed class ProductionOrderService : IProductionOrderService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public ProductionOrderService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<long> CreateFromSalesOrderLineAsync(long lineId, string createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@LineID", lineId, DbType.Int64);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_CreateProductionOrderFromSalesOrderLine @LineID, @CreatedBy",
            parameters);
    }

    public async Task<long> GenerateWaveRequirementAsync(long productionOrderId, string createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@ProductionOrderID", productionOrderId, DbType.Int64);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_CreateWaveRequirementFromCatalog @ProductionOrderID, @CreatedBy",
            parameters);
    }
}

public sealed class WaveRequirementService : IWaveRequirementService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public WaveRequirementService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<long> GenerateFromCatalogAsync(long productionOrderId, string createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@ProductionOrderID", productionOrderId, DbType.Int64);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_CreateWaveRequirementFromCatalog @ProductionOrderID, @CreatedBy",
            parameters);
    }
}

public sealed class CorrugatorLayoutOptimizerService : ICorrugatorLayoutOptimizerService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public CorrugatorLayoutOptimizerService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<CorrugatorLayoutSuggestion> SuggestLayoutAsync(string machineCode, decimal singleSheetWidthMm, decimal singleSheetLengthMm, decimal requiredSheetQty, long? recipeSheetId = null, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@MachineCode", machineCode, DbType.String);
        parameters.Add("@SingleSheetWidthMM", singleSheetWidthMm, DbType.Decimal);
        parameters.Add("@SingleSheetLengthMM", singleSheetLengthMm, DbType.Decimal);
        parameters.Add("@RequiredSheetQty", requiredSheetQty, DbType.Decimal);
        parameters.Add("@RecipeSheetID", recipeSheetId, DbType.Int64);

        var result = await connection.QuerySingleOrDefaultAsync<CorrugatorLayoutSuggestion>(
            "EXEC dbo.usp_SuggestCorrugatorLayout_Grid @MachineCode, @SingleSheetWidthMM, @SingleSheetLengthMM, @RequiredSheetQty, @RecipeSheetID",
            parameters);

        return result ?? new CorrugatorLayoutSuggestion();
    }
}

public sealed class WavePlanService : IWavePlanService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public WavePlanService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<long> CreateWavePlanAsync(string machineCode, string fluteCode, decimal runWidthMm, IEnumerable<long> waveRequirementIds, string createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);

        var ids = waveRequirementIds as long[] ?? waveRequirementIds.ToArray();
        var requirementList = string.Join(",", ids);

        var parameters = new DynamicParameters();
        parameters.Add("@MachineCode", machineCode, DbType.String);
        parameters.Add("@FluteCode", fluteCode, DbType.String);
        parameters.Add("@RunWidthMM", runWidthMm, DbType.Decimal);
        parameters.Add("@WaveRequirementIDs", requirementList, DbType.String);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_CreateWavePlanFromRequirements @MachineCode, @FluteCode, @RunWidthMM, @WaveRequirementIDs, @CreatedBy",
            parameters);
    }
}

public sealed class InventoryTransactionService : IInventoryTransactionService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public InventoryTransactionService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<long> RecordTransactionAsync(long itemId, long warehouseId, string transactionType, decimal quantity, string unit, string? refType, long? refId, string? refNo, string? note, string? createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@ItemID", itemId, DbType.Int64);
        parameters.Add("@WarehouseID", warehouseId, DbType.Int64);
        parameters.Add("@TransactionType", transactionType, DbType.String);
        parameters.Add("@Qty", quantity, DbType.Decimal);
        parameters.Add("@Unit", unit, DbType.String);
        parameters.Add("@RefType", refType, DbType.String);
        parameters.Add("@RefID", refId, DbType.Int64);
        parameters.Add("@RefNo", refNo, DbType.String);
        parameters.Add("@Note", note, DbType.String);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_InventoryApplyTransaction @ItemID, @WarehouseID, @TransactionType, @Qty, @Unit, @RefType, @RefID, @RefNo, @Note, @CreatedBy",
            parameters);
    }
}

public sealed class InventoryBalanceService : IInventoryBalanceService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public InventoryBalanceService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task UpdateBalanceAsync(long itemId, long warehouseId, decimal quantityDelta, string? lotNo = null, string? palletNo = null, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@ItemID", itemId, DbType.Int64);
        parameters.Add("@WarehouseID", warehouseId, DbType.Int64);
        parameters.Add("@QtyDelta", quantityDelta, DbType.Decimal);
        parameters.Add("@LotNo", lotNo, DbType.String);
        parameters.Add("@PalletNo", palletNo, DbType.String);

        await connection.ExecuteAsync(
            "EXEC dbo.usp_UpdateInventoryBalance @ItemID, @WarehouseID, @QtyDelta, @LotNo, @PalletNo",
            parameters);
    }

    public async Task<IEnumerable<InventoryBalanceItem>> GetBalancesAsync(string? itemCode = null, string? warehouseCode = null, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@ItemCode", itemCode, DbType.String);
        parameters.Add("@WarehouseCode", warehouseCode, DbType.String);

        return await connection.QueryAsync<InventoryBalanceItem>(
            "EXEC dbo.usp_GetInventoryBalance @ItemCode, @WarehouseCode",
            parameters);
    }
}

public sealed class WipService : IWipService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public WipService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<long> StartStageAsync(long productionOrderId, long stageId, long itemId, decimal quantity, string? note, string? createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@ProductionOrderID", productionOrderId, DbType.Int64);
        parameters.Add("@StageID", stageId, DbType.Int64);
        parameters.Add("@ItemID", itemId, DbType.Int64);
        parameters.Add("@Qty", quantity, DbType.Decimal);
        parameters.Add("@Note", note, DbType.String);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_StartWIPStage @ProductionOrderID, @StageID, @ItemID, @Qty, @Note, @CreatedBy",
            parameters);
    }

    public async Task<long> FinishStageAsync(long productionOrderId, long stageId, long itemId, decimal quantity, decimal scrapQty, string? note, string? createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@ProductionOrderID", productionOrderId, DbType.Int64);
        parameters.Add("@StageID", stageId, DbType.Int64);
        parameters.Add("@ItemID", itemId, DbType.Int64);
        parameters.Add("@Qty", quantity, DbType.Decimal);
        parameters.Add("@ScrapQty", scrapQty, DbType.Decimal);
        parameters.Add("@Note", note, DbType.String);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_FinishStage @ProductionOrderID, @StageID, @ItemID, @Qty, @ScrapQty, @Note, @CreatedBy",
            parameters);
    }

    public async Task<long> MoveStageAsync(long productionOrderId, long fromStageId, long toStageId, long itemId, decimal quantity, string? note, string? createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@ProductionOrderID", productionOrderId, DbType.Int64);
        parameters.Add("@FromStageID", fromStageId, DbType.Int64);
        parameters.Add("@ToStageID", toStageId, DbType.Int64);
        parameters.Add("@ItemID", itemId, DbType.Int64);
        parameters.Add("@Qty", quantity, DbType.Decimal);
        parameters.Add("@Note", note, DbType.String);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_MoveWIPStage @ProductionOrderID, @FromStageID, @ToStageID, @ItemID, @Qty, @Note, @CreatedBy",
            parameters);
    }
}

public sealed class PrintQueueService : IPrintQueueService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public PrintQueueService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<long> CreatePrintQueueAsync(string printerCode, string labelType, string refType, long? refId, string zpl, string createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@PrinterCode", printerCode, DbType.String);
        parameters.Add("@LabelType", labelType, DbType.String);
        parameters.Add("@RefType", refType, DbType.String);
        parameters.Add("@RefID", refId, DbType.Int64);
        parameters.Add("@ZPL", zpl, DbType.String);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_CreatePrintQueue @PrinterCode, @LabelType, @RefType, @RefID, @ZPL, @CreatedBy",
            parameters);
    }

    public async Task<long> ReprintAsync(long printId, string createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@PrintID", printId, DbType.Int64);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        return await connection.QuerySingleAsync<long>(
            "EXEC dbo.usp_ReprintLabel @PrintID, @CreatedBy",
            parameters);
    }
}

public sealed class AuditTrailService : IAuditTrailService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public AuditTrailService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task WriteAsync(long salesOrderId, long? lineId, string actionType, string? oldValue, string? newValue, string? reason, string? createdBy, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@SalesOrderID", salesOrderId, DbType.Int64);
        parameters.Add("@LineID", lineId, DbType.Int64);
        parameters.Add("@ActionType", actionType, DbType.String);
        parameters.Add("@OldValue", oldValue, DbType.String);
        parameters.Add("@NewValue", newValue, DbType.String);
        parameters.Add("@Reason", reason, DbType.String);
        parameters.Add("@CreatedBy", createdBy, DbType.String);

        await connection.ExecuteAsync(
            "INSERT INTO dbo.SalesOrderAudit (SalesOrderID, LineID, ActionType, OldValue, NewValue, Reason, CreatedBy, CreatedAt) VALUES (@SalesOrderID, @LineID, @ActionType, @OldValue, @NewValue, @Reason, @CreatedBy, SYSDATETIME())",
            parameters);
    }

    public async Task<IEnumerable<AuditTrailEntry>> GetAsync(long salesOrderId, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@SalesOrderID", salesOrderId, DbType.Int64);

        return await connection.QueryAsync<AuditTrailEntry>(
            "SELECT AuditID, SalesOrderID, LineID, ActionType, OldValue, NewValue, Reason, CreatedBy, CreatedAt FROM dbo.SalesOrderAudit WHERE SalesOrderID = @SalesOrderID ORDER BY CreatedAt DESC",
            parameters);
    }
}

public sealed class RevisionHistoryService : IRevisionHistoryService
{
    private readonly IDatabaseConnectionFactory _connectionFactory;

    public RevisionHistoryService(IDatabaseConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IEnumerable<RevisionHistoryEntry>> GetHistoryAsync(long salesOrderId, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionFactory.ConnectionString);
        var parameters = new DynamicParameters();
        parameters.Add("@SalesOrderID", salesOrderId, DbType.Int64);

        return await connection.QueryAsync<RevisionHistoryEntry>(
            "SELECT SalesOrderID, VersionNo, Status, CreatedAt, CreatedBy, Note FROM dbo.SalesOrder WHERE ParentSalesOrderID = @SalesOrderID OR SalesOrderID = @SalesOrderID ORDER BY CreatedAt DESC",
            parameters);
    }
}
