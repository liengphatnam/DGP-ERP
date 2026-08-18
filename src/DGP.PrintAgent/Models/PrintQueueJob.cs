namespace DGP.PrintAgent.Models;

public sealed class PrintQueueJob
{
    public long PrintId { get; set; }
    public string PrinterCode { get; set; } = string.Empty;
    public string LabelType { get; set; } = string.Empty;
    public string? RefType { get; set; }
    public long? RefId { get; set; }
    public string Zpl { get; set; } = string.Empty;
    public string Status { get; set; } = "Pending";
    public int RetryCount { get; set; }
    public int MaxRetry { get; set; }
    public string? ErrorMessage { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? ProcessingAt { get; set; }
    public DateTime? PrintedAt { get; set; }
}
