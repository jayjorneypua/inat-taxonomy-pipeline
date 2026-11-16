using System.Data;
using Inat.Api.Infrastructure;
using Inat.Api.Models;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Data;

// calls the export stored procedures
public sealed class ExportRepository(SqlConnectionFactory connectionFactory)
{
    private const int RowsCommandTimeoutSeconds = 300;

    public async Task<int> CreateAsync(
        long sessionId,
        int taxonId,
        string? clientIpAddress,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("dbo.spExport_Create", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_Session", SqlDbType.BigInt).Value = sessionId;
        command.Parameters.Add("@ID_Taxon", SqlDbType.Int).Value = taxonId;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        object? result = await command.ExecuteScalarAsync(cancellationToken);
        return Convert.ToInt32(result);
    }

    public async Task<ExportJob?> GetAsync(
        long sessionId,
        int exportJobId,
        string? clientIpAddress,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("dbo.spExport_Get", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_Session", SqlDbType.BigInt).Value = sessionId;
        command.Parameters.Add("@ID_Export_Job", SqlDbType.Int).Value = exportJobId;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        await using SqlDataReader reader = await command.ExecuteReaderAsync(cancellationToken);
        if (await reader.ReadAsync(cancellationToken) == false)
        {
            return null;
        }

        int? rowCount = null;
        if (reader.IsDBNull(reader.GetOrdinal("ExportRowCount")) == false)
        {
            rowCount = reader.GetInt32(reader.GetOrdinal("ExportRowCount"));
        }

        DateTime? finishedDate = null;
        if (reader.IsDBNull(reader.GetOrdinal("FinishedDate")) == false)
        {
            finishedDate = DateTime.SpecifyKind(reader.GetDateTime(reader.GetOrdinal("FinishedDate")), DateTimeKind.Utc);
        }

        return new ExportJob(
            reader.GetInt32(reader.GetOrdinal("ID")),
            reader.GetInt32(reader.GetOrdinal("ID_Taxon")),
            reader.GetString(reader.GetOrdinal("Status")),
            rowCount,
            ReadNullableString(reader, reader.GetOrdinal("FileName")),
            ReadNullableString(reader, reader.GetOrdinal("ErrorMessage")),
            DateTime.SpecifyKind(reader.GetDateTime(reader.GetOrdinal("CreatedDate")), DateTimeKind.Utc),
            finishedDate);
    }

    public async Task<ClaimedExport?> ClaimAsync(string claimedBy, CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("dbo.spExport_Claim", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ClaimedBy", SqlDbType.NVarChar, 100).Value = claimedBy;

        await using SqlDataReader reader = await command.ExecuteReaderAsync(cancellationToken);
        if (await reader.ReadAsync(cancellationToken) == false)
        {
            return null;
        }

        return new ClaimedExport(
            reader.GetInt32(reader.GetOrdinal("ID")),
            reader.GetInt64(reader.GetOrdinal("ID_Session")),
            reader.GetInt32(reader.GetOrdinal("ID_Taxon")));
    }

    // streams the rows straight into the writer, so a big export never sits in memory.
    // the header comes from the procedure's column names. returns the number of data rows.
    public async Task<int> WriteRowsAsync(
        int exportJobId,
        int maxRows,
        TextWriter writer,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("dbo.spExport_Rows", connection);
        command.CommandType = CommandType.StoredProcedure;
        command.CommandTimeout = RowsCommandTimeoutSeconds;

        command.Parameters.Add("@ID_Export_Job", SqlDbType.Int).Value = exportJobId;
        command.Parameters.Add("@MaxRows", SqlDbType.Int).Value = maxRows;

        await using SqlDataReader reader = await command.ExecuteReaderAsync(cancellationToken);

        List<object?> header = new List<object?>(reader.FieldCount);
        for (int ordinal = 0; ordinal < reader.FieldCount; ordinal++)
        {
            header.Add(reader.GetName(ordinal));
        }
        await writer.WriteLineAsync(CsvFormat.Line(header));

        object?[] values = new object?[reader.FieldCount];
        int rowCount = 0;

        while (await reader.ReadAsync(cancellationToken))
        {
            for (int ordinal = 0; ordinal < reader.FieldCount; ordinal++)
            {
                values[ordinal] = reader.GetValue(ordinal);
            }

            await writer.WriteLineAsync(CsvFormat.Line(values));
            rowCount++;
        }

        return rowCount;
    }

    public async Task FinishAsync(
        int exportJobId,
        string status,
        int? exportRowCount,
        string? fileName,
        string? errorMessage,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("dbo.spExport_Finish", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_Export_Job", SqlDbType.Int).Value = exportJobId;
        command.Parameters.Add("@Status", SqlDbType.VarChar, 20).Value = status;
        command.Parameters.Add("@ExportRowCount", SqlDbType.Int).Value = (object?)exportRowCount ?? DBNull.Value;
        command.Parameters.Add("@FileName", SqlDbType.NVarChar, 260).Value = (object?)fileName ?? DBNull.Value;
        command.Parameters.Add("@ErrorMessage", SqlDbType.NVarChar, 4000).Value = (object?)errorMessage ?? DBNull.Value;

        await command.ExecuteNonQueryAsync(cancellationToken);
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