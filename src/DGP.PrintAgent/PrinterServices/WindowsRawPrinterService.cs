using System.Drawing.Printing;
using DGP.PrintAgent.Models;
using Microsoft.Extensions.Logging;

namespace DGP.PrintAgent.PrinterServices;

public sealed class WindowsRawPrinterService : IPrinterService
{
    private readonly ILogger<WindowsRawPrinterService> _logger;

    public WindowsRawPrinterService(ILogger<WindowsRawPrinterService> logger)
    {
        _logger = logger;
    }

    public Task<bool> PrintAsync(PrinterProfile printer, string zpl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(printer.WindowsPrinterName))
        {
            throw new InvalidOperationException($"Printer {printer.PrinterCode} is configured as a Windows printer but has no WindowsPrinterName value.");
        }

        using var printDoc = new PrintDocument();
        printDoc.PrinterSettings.PrinterName = printer.WindowsPrinterName;

        if (!printDoc.PrinterSettings.IsValid)
        {
            throw new InvalidOperationException($"Printer '{printer.WindowsPrinterName}' is not available on this machine.");
        }

        var rawHelper = new RawPrinterHelper();
        rawHelper.SendStringToPrinter(printer.WindowsPrinterName, zpl);

        _logger.LogInformation(
            "Sent ZPL to Windows printer '{PrinterName}' for {PrinterCode}",
            printer.WindowsPrinterName,
            printer.PrinterCode);

        return Task.FromResult(true);
    }
}
