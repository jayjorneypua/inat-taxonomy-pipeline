using Microsoft.Data.SqlClient;

namespace Inat.Api.Data;

// one place that knows the connection string. sqlclient pools connections automatically,
// so opening one per call is cheap: it is borrowed from the pool and returned on dispose.
// the optional Database:Name setting points the same login at another database, for example
// the ui tests run the api with Database__Name=inat_test_copy
public sealed class SqlConnectionFactory
{
    private readonly string connectionString;

    public SqlConnectionFactory(IConfiguration configuration)
    {
        string? configuredConnectionString = configuration.GetConnectionString("Inat");
        if (configuredConnectionString == null)
        {
            throw new InvalidOperationException(
                "Connection string 'Inat' is missing. Set it with dotnet user-secrets.");
        }

        string? databaseName = configuration["Database:Name"];

        if (string.IsNullOrWhiteSpace(databaseName) == false)
        {
            SqlConnectionStringBuilder connectionStringBuilder = new SqlConnectionStringBuilder(configuredConnectionString);
            connectionStringBuilder.InitialCatalog = databaseName;
            connectionString = connectionStringBuilder.ConnectionString;
        }
        else
        {
            connectionString = configuredConnectionString;
        }
    }

    public async Task<SqlConnection> OpenAsync(CancellationToken cancellationToken)
    {
        SqlConnection connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }
}