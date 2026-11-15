using System.Data;
using Inat.Api.Models;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Data;

// calls the administration stored procedures
public sealed class AdminRepository(SqlConnectionFactory connectionFactory)
{
    public async Task<UserGridResponse> GetUsersGridAsync(
        long sessionId,
        int page,
        int pageSize,
        string? search,
        string? filtersJson,
        string sortColumn,
        string sortDirection,
        string? clientIpAddress,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("security.spUser_Grid", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_Session", SqlDbType.BigInt).Value = sessionId;
        command.Parameters.Add("@Page", SqlDbType.Int).Value = page;
        command.Parameters.Add("@PageSize", SqlDbType.Int).Value = pageSize;
        command.Parameters.Add("@Search", SqlDbType.NVarChar, 100).Value = (object?)search ?? DBNull.Value;
        command.Parameters.Add("@Filters", SqlDbType.NVarChar, -1).Value = (object?)filtersJson ?? DBNull.Value;
        command.Parameters.Add("@SortColumn", SqlDbType.NVarChar, 50).Value = sortColumn;
        command.Parameters.Add("@SortDirection", SqlDbType.NVarChar, 4).Value = sortDirection;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        List<UserGridRow> rows = new List<UserGridRow>();
        int totalCount = 0;

        await using SqlDataReader reader = await command.ExecuteReaderAsync(cancellationToken);

        int idOrdinal = reader.GetOrdinal("ID");
        int usernameOrdinal = reader.GetOrdinal("Username");
        int firstNameOrdinal = reader.GetOrdinal("FirstName");
        int lastNameOrdinal = reader.GetOrdinal("LastName");
        int emailOrdinal = reader.GetOrdinal("Email");
        int activeOrdinal = reader.GetOrdinal("Active");
        int isLockedOrdinal = reader.GetOrdinal("IsLocked");
        int loginCountOrdinal = reader.GetOrdinal("LoginCount");
        int lastLoginDateOrdinal = reader.GetOrdinal("LastLoginDate");
        int groupNamesOrdinal = reader.GetOrdinal("GroupNames");
        int roleNamesOrdinal = reader.GetOrdinal("RoleNames");
        int totalCountOrdinal = reader.GetOrdinal("TotalCount");

        while (await reader.ReadAsync(cancellationToken))
        {
            DateTime? lastLoginDate = null;
            if (reader.IsDBNull(lastLoginDateOrdinal) == false)
            {
                lastLoginDate = reader.GetDateTime(lastLoginDateOrdinal);
            }

            rows.Add(new UserGridRow(
                reader.GetInt32(idOrdinal),
                reader.GetString(usernameOrdinal),
                reader.GetString(firstNameOrdinal),
                reader.GetString(lastNameOrdinal),
                reader.GetString(emailOrdinal),
                reader.GetBoolean(activeOrdinal),
                reader.GetBoolean(isLockedOrdinal),
                reader.GetInt32(loginCountOrdinal),
                lastLoginDate,
                ReadNullableString(reader, groupNamesOrdinal),
                ReadNullableString(reader, roleNamesOrdinal)));

            // every row carries the same total, the number of users matching before paging
            totalCount = reader.GetInt32(totalCountOrdinal);
        }

        return new UserGridResponse(rows, totalCount, page, pageSize);
    }

    private static string? ReadNullableString(SqlDataReader reader, int ordinal)
    {
        if (reader.IsDBNull(ordinal))
        {
            return null;
        }

        return reader.GetString(ordinal);
    }
}