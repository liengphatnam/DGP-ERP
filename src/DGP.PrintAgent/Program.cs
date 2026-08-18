using DGP.Application;
using DGP.Infrastructure;
using DGP.PrintAgent;
using DGP.PrintAgent.Models;
using DGP.PrintAgent.PrinterServices;

var builder = Host.CreateApplicationBuilder(args);

builder.Configuration
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables();

builder.Services.Configure<PrintAgentOptions>(builder.Configuration.GetSection("PrintAgent"));
builder.Services.AddApplicationServices();
builder.Services.AddInfrastructureServices(builder.Configuration);
builder.Services.AddSingleton<IpZebraPrinterService>();
builder.Services.AddSingleton<WindowsRawPrinterService>();
builder.Services.AddHostedService<Worker>();

var host = builder.Build();
host.Run();
