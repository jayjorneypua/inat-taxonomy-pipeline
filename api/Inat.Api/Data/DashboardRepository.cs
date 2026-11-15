using System.Data;
using Inat.Api.Models;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Data;

// calls the dashboard stored procedures. no sql text lives here, only procedure names and parameters
public sealed class DashboardRepository(SqlConnectionFactory connectionFactory)
{
    public async Task<IReadOnlyList<TaxonChildCount>> GetTaxonChildrenCountsAsync(
        long sessionId,
        int? parentTaxonId,
        string? clientIpAddress,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("dbo.spDashboard_TaxonChildrenCounts", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_Session", SqlDbType.BigInt).Value = sessionId;
        command.Parameters.Add("@ID_ParentTaxon", SqlDbType.Int).Value = (object?)parentTaxonId ?? DBNull.Value;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        List<TaxonChildCount> taxonChildCounts = new List<TaxonChildCount>();

        await using SqlDataReader reader = await command.ExecuteReaderAsync(cancellationToken);

        int idOrdinal = reader.GetOrdinal("ID");
        int scientificNameOrdinal = reader.GetOrdinal("ScientificName");
        int commonNameOrdinal = reader.GetOrdinal("CommonName");
        int rankOrdinal = reader.GetOrdinal("Rank");
        int hasChildrenOrdinal = reader.GetOrdinal("HasChildren");
        int observationCountOrdinal = reader.GetOrdinal("ObservationCount");

        while (await reader.ReadAsync(cancellationToken))
        {
            string? commonName = null;
            if (reader.IsDBNull(commonNameOrdinal) == false)
            {
                commonName = reader.GetString(commonNameOrdinal);
            }

            taxonChildCounts.Add(new TaxonChildCount(
                reader.GetInt32(idOrdinal),
                reader.GetString(scientificNameOrdinal),
                commonName,
                reader.GetString(rankOrdinal),
                reader.GetBoolean(hasChildrenOrdinal),
                reader.GetInt32(observationCountOrdinal)));
        }

        return taxonChildCounts;
    }

    public async Task<IReadOnlyList<ObservationMonthCount>> GetObservationsByMonthAsync(
        long sessionId,
        int? taxonId,
        string? clientIpAddress,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("dbo.spDashboard_ObservationsByMonth", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_Session", SqlDbType.BigInt).Value = sessionId;
        command.Parameters.Add("@ID_Taxon", SqlDbType.Int).Value = (object?)taxonId ?? DBNull.Value;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        List<ObservationMonthCount> monthCounts = new List<ObservationMonthCount>();

        await using SqlDataReader reader = await command.ExecuteReaderAsync(cancellationToken);

        int monthStartOrdinal = reader.GetOrdinal("MonthStart");
        int observationCountOrdinal = reader.GetOrdinal("ObservationCount");

        while (await reader.ReadAsync(cancellationToken))
        {
            monthCounts.Add(new ObservationMonthCount(
                DateOnly.FromDateTime(reader.GetDateTime(monthStartOrdinal)),
                reader.GetInt32(observationCountOrdinal)));
        }

        return monthCounts;
    }
}