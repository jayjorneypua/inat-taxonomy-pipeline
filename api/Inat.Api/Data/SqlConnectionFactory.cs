using Microsoft.Data.SqlClient;

namespace Inat.Api.Data;

// one place that knows the connection string. sqlclient pools connections automatically,
// so opening one per call is cheap: it is borrowed from the pool and returned on dispose
public sealed class SqlConnectionFactory
{
    private readonly string connectionString;

    public SqlConnectionFactory(IConfiguration configuration)
    {
        connectionString = configuration.GetConnectionString("Inat") ?? throw new InvalidOperationException("Connection string 'Inat' is missing. Set it with dotnet user-secrets.");
    }

    public async Task<SqlConnection> OpenAsync(CancellationToken cancellationToken)
    {
        SqlConnection connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }
}