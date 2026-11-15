using System.Data;
using Inat.Api.Models;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Data;

// calls the login and session stored procedures in the security schema
public sealed class SecurityRepository(SqlConnectionFactory connectionFactory)
{
    public async Task<LoginInfo?> GetLoginInfoAsync(string username, CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("security.spUser_GetLoginInfo", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = username;

        await using SqlDataReader reader = await command.ExecuteReaderAsync(cancellationToken);

        bool hasRow = await reader.ReadAsync(cancellationToken);
        if (hasRow == false)
        {
            return null;
        }

        int lockedUntilOrdinal = reader.GetOrdinal("LockedUntil");
        DateTime? lockedUntil = null;
        if (reader.IsDBNull(lockedUntilOrdinal) == false)
        {
            lockedUntil = reader.GetDateTime(lockedUntilOrdinal);
        }

        return new LoginInfo(
            reader.GetInt32(reader.GetOrdinal("ID_User")),
            reader.GetString(reader.GetOrdinal("PasswordHash")),
            reader.GetBoolean(reader.GetOrdinal("IsLocked")),
            lockedUntil,
            reader.GetBoolean(reader.GetOrdinal("HasChangedPassword")));
    }

    public async Task RecordFailedLoginAsync(string username, string? clientIpAddress, CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("security.spUser_LoginFailed", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@Username", SqlDbType.NVarChar, 100).Value = username;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<long> CreateSessionAsync(
        int userId,
        byte[] tokenHash,
        DateTime expiresAt,
        string? clientIpAddress,
        string? userAgent,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("security.spSession_Create", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_User", SqlDbType.Int).Value = userId;
        command.Parameters.Add("@TokenHash", SqlDbType.VarBinary, 32).Value = tokenHash;
        command.Parameters.Add("@ExpiresDate", SqlDbType.DateTime2).Value = expiresAt;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;
        command.Parameters.Add("@UserAgent", SqlDbType.NVarChar, 500).Value = (object?)userAgent ?? DBNull.Value;

        SqlParameter sessionIdParameter = command.Parameters.Add("@ID_Session", SqlDbType.BigInt);
        sessionIdParameter.Direction = ParameterDirection.Output;

        await command.ExecuteNonQueryAsync(cancellationToken);

        return (long)sessionIdParameter.Value;
    }

    public async Task<SessionRefreshResult> RefreshSessionAsync(
        byte[] oldTokenHash,
        byte[] newTokenHash,
        DateTime newExpiresAt,
        string? clientIpAddress,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("security.spSession_Refresh", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@OldTokenHash", SqlDbType.VarBinary, 32).Value = oldTokenHash;
        command.Parameters.Add("@NewTokenHash", SqlDbType.VarBinary, 32).Value = newTokenHash;
        command.Parameters.Add("@NewExpiresDate", SqlDbType.DateTime2).Value = newExpiresAt;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        SqlParameter resultParameter = command.Parameters.Add("@Result", SqlDbType.NVarChar, 20);
        resultParameter.Direction = ParameterDirection.Output;

        SqlParameter sessionIdParameter = command.Parameters.Add("@ID_Session", SqlDbType.BigInt);
        sessionIdParameter.Direction = ParameterDirection.Output;

        await command.ExecuteNonQueryAsync(cancellationToken);

        string result = (string)resultParameter.Value;

        long? sessionId = null;
        if (sessionIdParameter.Value != DBNull.Value)
        {
            sessionId = (long)sessionIdParameter.Value;
        }

        return new SessionRefreshResult(result, sessionId);
    }

    public async Task RevokeSessionAsync(
        long sessionId,
        string reason,
        string? clientIpAddress,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("security.spSession_Revoke", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_Session", SqlDbType.BigInt).Value = sessionId;
        command.Parameters.Add("@Reason", SqlDbType.NVarChar, 200).Value = reason;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}