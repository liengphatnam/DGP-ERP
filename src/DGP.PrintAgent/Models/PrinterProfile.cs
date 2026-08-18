namespace DGP.PrintAgent.Models;

public sealed class PrinterProfile
{
    public string PrinterCode { get; set; } = string.Empty;
    public string PrinterName { get; set; } = string.Empty;
    public string ConnectionType { get; set; } = "IP";
    public string? PrinterIp { get; set; }
    public int PrinterPort { get; set; } = 9100;
    public string? WindowsPrinterName { get; set; }
    public string? LocationName { get; set; }
    public bool IsActive { get; set; } = true;
}
