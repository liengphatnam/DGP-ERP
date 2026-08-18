using DGP.PrintAgent.Models;

namespace DGP.PrintAgent.PrinterServices;

public interface IPrinterService
{
    Task<bool> PrintAsync(PrinterProfile printer, string zpl, CancellationToken cancellationToken);
}
