namespace DGP.Application.Services;

public interface IDatabaseConnectionFactory
{
    string ConnectionString { get; }
}

public interface ICatalogLookupService
{
    Task<ItemCatalogLookupResult?> GetCatalogAsync(string itemCode, CancellationToken cancellationToken = default);
}

public interface IBoxSpecSnapshotService
{
    Task<long> CreateFromCatalogAsync(long salesOrderId, string itemCode, decimal quantity, string createdBy, CancellationToken cancellationToken = default);
}

public interface ISheetSpecSnapshotService
{
    Task<long> CreateSnapshotAsync(long salesOrderId, string itemCode, decimal quantity, string createdBy, CancellationToken cancellationToken = default);
}

public interface ISalesOrderService
{
    Task<long> CreateLineFromCatalogAsync(long salesOrderId, string itemCode, decimal quantity, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> ConfirmAsync(long salesOrderId, string confirmedBy, CancellationToken cancellationToken = default);
    Task<long> CreateRevisionAsync(long salesOrderId, string reason, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> CancelLineAsync(long lineId, string reason, string cancelledBy, CancellationToken cancellationToken = default);
}

public interface IProductionOrderService
{
    Task<long> CreateFromSalesOrderLineAsync(long lineId, string createdBy, CancellationToken cancellationToken = default);
    Task<long> GenerateWaveRequirementAsync(long productionOrderId, string createdBy, CancellationToken cancellationToken = default);
}

public interface IWaveRequirementService
{
    Task<long> GenerateFromCatalogAsync(long productionOrderId, string createdBy, CancellationToken cancellationToken = default);
}

public interface ICorrugatorLayoutOptimizerService
{
    Task<CorrugatorLayoutSuggestion> SuggestLayoutAsync(string machineCode, decimal singleSheetWidthMm, decimal singleSheetLengthMm, decimal requiredSheetQty, long? recipeSheetId = null, CancellationToken cancellationToken = default);
}

public interface IWavePlanService
{
    Task<long> CreateWavePlanAsync(string machineCode, string fluteCode, decimal runWidthMm, IEnumerable<long> waveRequirementIds, string createdBy, CancellationToken cancellationToken = default);
}

public interface IInventoryTransactionService
{
    Task<long> RecordTransactionAsync(
        long itemId,
        long warehouseId,
        string transactionType,
        decimal quantity,
        string unit,
        string? refType,
        long? refId,
        string? refNo,
        string? note,
        string? createdBy,
        CancellationToken cancellationToken = default);
}

public interface IInventoryBalanceService
{
    Task UpdateBalanceAsync(long itemId, long warehouseId, decimal quantityDelta, string? lotNo = null, string? palletNo = null, CancellationToken cancellationToken = default);
    Task<IEnumerable<InventoryBalanceItem>> GetBalancesAsync(string? itemCode = null, string? warehouseCode = null, CancellationToken cancellationToken = default);
}

public interface IWipService
{
    Task<long> StartStageAsync(long productionOrderId, long stageId, long itemId, decimal quantity, string? note, string? createdBy, CancellationToken cancellationToken = default);
    Task<long> FinishStageAsync(long productionOrderId, long stageId, long itemId, decimal quantity, decimal scrapQty, string? note, string? createdBy, CancellationToken cancellationToken = default);
    Task<long> MoveStageAsync(long productionOrderId, long fromStageId, long toStageId, long itemId, decimal quantity, string? note, string? createdBy, CancellationToken cancellationToken = default);
}

public interface IPrintQueueService
{
    Task<long> CreatePrintQueueAsync(string printerCode, string labelType, string refType, long? refId, string zpl, string createdBy, CancellationToken cancellationToken = default);
    Task<long> ReprintAsync(long printId, string createdBy, CancellationToken cancellationToken = default);
}

public interface IAuditTrailService
{
    Task WriteAsync(long salesOrderId, long? lineId, string actionType, string? oldValue, string? newValue, string? reason, string? createdBy, CancellationToken cancellationToken = default);
    Task<IEnumerable<AuditTrailEntry>> GetAsync(long salesOrderId, CancellationToken cancellationToken = default);
}

public interface IRevisionHistoryService
{
    Task<IEnumerable<RevisionHistoryEntry>> GetHistoryAsync(long salesOrderId, CancellationToken cancellationToken = default);
}

public sealed class ItemCatalogLookupResult
{
    public long ItemId { get; set; }
    public string ItemCode { get; set; } = string.Empty;
    public string ItemName { get; set; } = string.Empty;
    public string ItemType { get; set; } = string.Empty;
    public decimal LengthMM { get; set; }
    public decimal WidthMM { get; set; }
    public decimal HeightMM { get; set; }
    public string FluteCode { get; set; } = string.Empty;
    public string? DieCutCode { get; set; }
    public int? PrintColor { get; set; }
    public string? PrintNote { get; set; }
    public string? GlueType { get; set; }
    public decimal SingleSheetLengthMM { get; set; }
    public decimal SingleSheetWidthMM { get; set; }
    public decimal SheetPerBox { get; set; }
    public decimal LossRate { get; set; }
}

public sealed class CorrugatorLayoutSuggestion
{
    public int LaneCount { get; set; }
    public decimal RunWidthMM { get; set; }
    public decimal WidthUsedMM { get; set; }
    public decimal CutCount { get; set; }
    public decimal ProducedSheetQty { get; set; }
    public decimal OverQty { get; set; }
    public decimal RunningLengthM { get; set; }
    public decimal WidthUtilization { get; set; }
    public decimal Score { get; set; }
}

public sealed class InventoryBalanceItem
{
    public long BalanceId { get; set; }
    public long ItemId { get; set; }
    public string ItemCode { get; set; } = string.Empty;
    public string ItemName { get; set; } = string.Empty;
    public long WarehouseId { get; set; }
    public string WarehouseCode { get; set; } = string.Empty;
    public string? LotNo { get; set; }
    public string? PalletNo { get; set; }
    public decimal QtyOnHand { get; set; }
    public decimal ReservedQty { get; set; }
    public decimal AvailableQty { get; set; }
    public string Unit { get; set; } = "PCS";
}

public sealed class AuditTrailEntry
{
    public long AuditId { get; set; }
    public long SalesOrderId { get; set; }
    public long? LineId { get; set; }
    public string ActionType { get; set; } = string.Empty;
    public string? OldValue { get; set; }
    public string? NewValue { get; set; }
    public string? Reason { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}

public sealed class RevisionHistoryEntry
{
    public long SalesOrderId { get; set; }
    public int VersionNo { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public string? Note { get; set; }
}
