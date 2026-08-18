using System.Data;
using Dapper;
using DGP.PrintAgent.Models;
using DGP.PrintAgent.PrinterServices;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace DGP.PrintAgent;

public sealed class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private readonly PrintAgentOptions _options;
    private readonly IConfiguration _configuration;
    private readonly IpZebraPrinterService _ipPrinterService;
    private readonly WindowsRawPrinterService _windowsPrinterService;

    public Worker(
        ILogger<Worker> logger,
        IOptions<PrintAgentOptions> options,
        IConfiguration configuration,
        IpZebraPrinterService ipPrinterService,
        WindowsRawPrinterService windowsPrinterService)
    {
        _logger = logger;
        _options = options.Value;
        _configuration = configuration;
        _ipPrinterService = ipPrinterService;
        _windowsPrinterService = windowsPrinterService;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("DGP print agent started.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessPendingJobsAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected print-worker error.");
            }

            await Task.Delay(TimeSpan.FromSeconds(Math.Max(1, _options.PollIntervalSeconds)), stoppingToken);
        }
    }

    private async Task ProcessPendingJobsAsync(CancellationToken cancellationToken)
    {
        var connectionString = _configuration.GetConnectionString("DefaultConnection") ?? _options.DefaultConnection;
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            _logger.LogWarning("No database connection string configured for DGP print agent. Skipping queue poll.");
            return;
        }

        await using var connection = new SqlConnection(connectionString);

        var jobs = await connection.QueryAsync<PrintQueueJob>(
            @"
            SELECT TOP (@Take)
                PrintID AS PrintId,
                PrinterCode,
                LabelType,
                RefType,
                RefID AS RefId,
                ZPL AS Zpl,
                Status,
                RetryCount,
                MaxRetry,
                ErrorMessage,
                CreatedBy,
                CreatedAt,
                ProcessingAt,
                PrintedAt
            FROM dbo.PrintQueue
            WHERE Status IN ('Pending','Failed')
              AND (Status = 'Pending' OR RetryCount < MaxRetry)
            ORDER BY CreatedAt ASC;",
            new { Take = _options.MaxJobsPerBatch });

        foreach (var job in jobs)
        {
            cancellationToken.ThrowIfCancellationRequested();

            try
            {
                var printer = await GetPrinterProfileAsync(connection, job.PrinterCode, cancellationToken);
                if (printer is null)
                {
                    await MarkFailedAsync(connection, job.PrintId, $"Printer '{job.PrinterCode}' is not configured or is inactive.", job.RetryCount, job.MaxRetry);
                    continue;
                }

                await UpdateProcessingStatusAsync(connection, job.PrintId);

                var service = ResolvePrinterService(printer.ConnectionType);
                var sent = await service.PrintAsync(printer, job.Zpl, cancellationToken);

                if (!sent)
                {
                    await HandleFailureAsync(connection, job, "Printer service returned false.");
                    continue;
                }

                await MarkPrintedAsync(connection, job.PrintId);
                _logger.LogInformation("Print job {PrintId} sent successfully to printer {PrinterCode}.", job.PrintId, job.PrinterCode);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Print job {PrintId} failed while sending ZPL.", job.PrintId);
                await HandleFailureAsync(connection, job, ex.Message);
            }
        }
    }

    private async Task<PrinterProfile?> GetPrinterProfileAsync(SqlConnection connection, string printerCode, CancellationToken cancellationToken)
    {
        var parameters = new DynamicParameters();
        parameters.Add("@PrinterCode", printerCode, DbType.String);

        return await connection.QuerySingleOrDefaultAsync<PrinterProfile>(
            @"
            SELECT
                PrinterCode,
                PrinterName,
                ConnectionType,
                PrinterIP AS PrinterIp,
                PrinterPort,
                WindowsPrinterName,
                LocationName,
                IsActive
            FROM dbo.PrinterList
            WHERE PrinterCode = @PrinterCode
              AND IsActive = 1;",
            parameters);
    }

    private IPrinterService ResolvePrinterService(string connectionType)
    {
        return connectionType?.Trim().ToUpperInvariant() switch
        {
            "IP" => _ipPrinterService,
            "WINDOWS_PRINTER" => _windowsPrinterService,
            "USB" => _windowsPrinterService,
            _ => throw new InvalidOperationException($"Unsupported printer connection type '{connectionType}'.")
        };
    }

    private static async Task UpdateProcessingStatusAsync(SqlConnection connection, long printId)
    {
        await connection.ExecuteAsync(
            @"UPDATE dbo.PrintQueue
              SET Status = 'Processing',
                  ProcessingAt = SYSDATETIME(),
                  ErrorMessage = NULL
              WHERE PrintID = @PrintId
                AND Status IN ('Pending', 'Failed');",
            new { PrintId = printId });
    }

    private static async Task MarkPrintedAsync(SqlConnection connection, long printId)
    {
        await connection.ExecuteAsync(
            @"UPDATE dbo.PrintQueue
              SET Status = 'Printed',
                  PrintedAt = SYSDATETIME(),
                  ErrorMessage = NULL,
                  ProcessingAt = SYSDATETIME()
              WHERE PrintID = @PrintId;",
            new { PrintId = printId });
    }

    private async Task HandleFailureAsync(SqlConnection connection, PrintQueueJob job, string errorMessage)
    {
        var nextRetry = job.RetryCount + 1;
        var shouldFailPermanently = nextRetry >= job.MaxRetry || job.MaxRetry <= 0;

        if (shouldFailPermanently)
        {
            await MarkFailedAsync(connection, job.PrintId, errorMessage, nextRetry, job.MaxRetry);
            _logger.LogWarning(
                "Print job {PrintId} reached max retry count. Marked as Failed. Error: {Error}",
                job.PrintId,
                errorMessage);
            return;
        }

        await connection.ExecuteAsync(
            @"UPDATE dbo.PrintQueue
              SET Status = 'Failed',
                  RetryCount = @RetryCount,
                  ErrorMessage = @ErrorMessage,
                  ProcessingAt = NULL
              WHERE PrintID = @PrintId;",
            new { PrintId = job.PrintId, RetryCount = nextRetry, ErrorMessage = errorMessage });

        _logger.LogWarning(
            "Print job {PrintId} failed. Retry {RetryCount}/{MaxRetry}. Error: {Error}",
            job.PrintId,
            nextRetry,
            job.MaxRetry,
            errorMessage);
    }

    private static async Task MarkFailedAsync(SqlConnection connection, long printId, string errorMessage, int retryCount, int maxRetry)
    {
        await connection.ExecuteAsync(
            @"UPDATE dbo.PrintQueue
              SET Status = 'Failed',
                  RetryCount = @RetryCount,
                  MaxRetry = @MaxRetry,
                  ErrorMessage = @ErrorMessage,
                  ProcessingAt = NULL
              WHERE PrintID = @PrintId;",
            new { PrintId = printId, RetryCount = retryCount, MaxRetry = maxRetry, ErrorMessage = errorMessage });
    }
}
