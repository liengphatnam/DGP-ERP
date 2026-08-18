using DGP.Application.Services;
using DGP.Infrastructure.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace DGP.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddScoped<IDatabaseConnectionFactory, SqlConnectionFactory>();
        services.AddScoped<ICatalogLookupService, CatalogLookupService>();
        services.AddScoped<IBoxSpecSnapshotService, BoxSpecSnapshotService>();
        services.AddScoped<ISheetSpecSnapshotService, SheetSpecSnapshotService>();
        services.AddScoped<ISalesOrderService, SalesOrderService>();
        services.AddScoped<IProductionOrderService, ProductionOrderService>();
        services.AddScoped<IWaveRequirementService, WaveRequirementService>();
        services.AddScoped<ICorrugatorLayoutOptimizerService, CorrugatorLayoutOptimizerService>();
        services.AddScoped<IWavePlanService, WavePlanService>();
        services.AddScoped<IInventoryTransactionService, InventoryTransactionService>();
        services.AddScoped<IInventoryBalanceService, InventoryBalanceService>();
        services.AddScoped<IWipService, WipService>();
        services.AddScoped<IPrintQueueService, PrintQueueService>();
        services.AddScoped<IAuditTrailService, AuditTrailService>();
        services.AddScoped<IRevisionHistoryService, RevisionHistoryService>();
        return services;
    }
}
