using System.Net.Sockets;
using System.Text;
using DGP.PrintAgent.Models;
using Microsoft.Extensions.Logging;

namespace DGP.PrintAgent.PrinterServices;

public sealed class IpZebraPrinterService : IPrinterService
{
    private readonly ILogger<IpZebraPrinterService> _logger;

    public IpZebraPrinterService(ILogger<IpZebraPrinterService> logger)
    {
        _logger = logger;
    }

    public async Task<bool> PrintAsync(PrinterProfile printer, string zpl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(printer.PrinterIp))
        {
            throw new InvalidOperationException($"Printer {printer.PrinterCode} is configured for IP printing but has no PrinterIP value.");
        }

        using var client = new TcpClient();
        await client.ConnectAsync(printer.PrinterIp, printer.PrinterPort, cancellationToken);

        await using var stream = client.GetStream();
        var payload = Encoding.UTF8.GetBytes(zpl);
        await stream.WriteAsync(payload, cancellationToken);

        _logger.LogInformation(
            "Sent {ByteCount} bytes via TCP to {PrinterCode} at {PrinterIp}:{PrinterPort}",
            payload.Length,
            printer.PrinterCode,
            printer.PrinterIp,
            printer.PrinterPort);

        return true;
    }
}
