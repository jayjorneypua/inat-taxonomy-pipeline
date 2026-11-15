using System.Data;
using Inat.Api.Models;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Data;

// the cheap access check that runs before every cached answer
public sealed class AccessRepository(SqlConnectionFactory connectionFactory)
{
    public async Task<AccessContext> GetAccessContextAsync(
        long sessionId,
        string permissionCode,
        string? clientIpAddress,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("security.spSession_GetAccessContext", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_Session", SqlDbType.BigInt).Value = sessionId;
        command.Parameters.Add("@PermissionCode", SqlDbType.NVarChar, 200).Value = permissionCode;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        await using SqlDataReader reader = await command.ExecuteReaderAsync(cancellationToken);

        bool hasRow = await reader.ReadAsync(cancellationToken);
        if (hasRow == false)
        {
            throw new InvalidOperationException("spSession_GetAccessContext returned no row.");
        }

        return new AccessContext(
            reader.GetString(reader.GetOrdinal("ScopeSignature")),
            reader.GetInt64(reader.GetOrdinal("DataVersion")));
    }
}