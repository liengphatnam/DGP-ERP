using DGP.Application.Services;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace DGP.Infrastructure.Services;

public sealed class SqlConnectionFactory : IDatabaseConnectionFactory
{
    private readonly IConfiguration _configuration;

    public SqlConnectionFactory(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public string ConnectionString =>
        _configuration.GetConnectionString("DefaultConnection")
        ?? throw new InvalidOperationException("Connection string 'DefaultConnection' was not configured.");

    public SqlConnection CreateConnection() => new(ConnectionString);
}
