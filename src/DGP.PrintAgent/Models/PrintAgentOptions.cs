namespace DGP.PrintAgent.Models;

public sealed class PrintAgentOptions
{
    public int PollIntervalSeconds { get; set; } = 10;
    public int MaxJobsPerBatch { get; set; } = 5;
    public int MaxRetryCount { get; set; } = 3;
    public int RetryDelaySeconds { get; set; } = 30;
    public string? DefaultConnection { get; set; }
}
