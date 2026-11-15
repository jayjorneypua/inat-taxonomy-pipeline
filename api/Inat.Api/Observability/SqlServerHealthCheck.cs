using Inat.Api.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Inat.Api.Observability;

public sealed class SqlServerHealthCheck : IHealthCheck
{
    private readonly SqlConnectionFactory _connectionFactory;

    public SqlServerHealthCheck(SqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            await using SqlConnection connection = await _connectionFactory.OpenAsync(cancellationToken);

            await using SqlCommand command = new SqlCommand("SELECT 1;", connection);
            await command.ExecuteScalarAsync(cancellationToken);

            return HealthCheckResult.Healthy("SQL Server reachable");
        }
        catch (Exception ex)
        {
            return new HealthCheckResult(context.Registration.FailureStatus, "SQL Server unreachable", ex);
        }
    }
}