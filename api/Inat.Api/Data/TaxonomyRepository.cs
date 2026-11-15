using System.Data;
using Inat.Api.Models;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Data;

// calls the taxonomy stored procedures
public sealed class TaxonomyRepository(SqlConnectionFactory connectionFactory)
{
    public async Task<IReadOnlyList<ObservationCard>> GetObservationsPageAsync(
        long sessionId,
        int taxonId,
        int pageSize,
        DateOnly? afterObservedDate,
        int? afterObservationId,
        string? clientIpAddress,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("dbo.spTaxonomy_ObservationsPage", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_Session", SqlDbType.BigInt).Value = sessionId;
        command.Parameters.Add("@ID_Taxon", SqlDbType.Int).Value = taxonId;
        command.Parameters.Add("@PageSize", SqlDbType.Int).Value = pageSize;

        SqlParameter afterObservedDateParameter = command.Parameters.Add("@AfterObservedDate", SqlDbType.Date);
        afterObservedDateParameter.Value = DBNull.Value;
        if (afterObservedDate.HasValue)
        {
            afterObservedDateParameter.Value = afterObservedDate.Value.ToDateTime(TimeOnly.MinValue);
        }

        command.Parameters.Add("@AfterObservationID", SqlDbType.Int).Value = (object?)afterObservationId ?? DBNull.Value;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        List<ObservationCard> observationCards = new List<ObservationCard>();

        await using SqlDataReader reader = await command.ExecuteReaderAsync(cancellationToken);

        int observationIdOrdinal = reader.GetOrdinal("ObservationID");
        int observationUuidOrdinal = reader.GetOrdinal("ObservationUuid");
        int observedDateOrdinal = reader.GetOrdinal("ObservedDate");
        int taxonIdOrdinal = reader.GetOrdinal("ID_Taxon");
        int scientificNameOrdinal = reader.GetOrdinal("ScientificName");
        int commonNameOrdinal = reader.GetOrdinal("CommonName");
        int observerDisplayNameOrdinal = reader.GetOrdinal("ObserverDisplayName");
        int photoCountOrdinal = reader.GetOrdinal("PhotoCount");
        int squareUrlOrdinal = reader.GetOrdinal("SquareUrl");
        int mediumUrlOrdinal = reader.GetOrdinal("MediumUrl");
        int attributionOrdinal = reader.GetOrdinal("Attribution");
        int licenseOrdinal = reader.GetOrdinal("License");

        while (await reader.ReadAsync(cancellationToken))
        {
            observationCards.Add(new ObservationCard(
                reader.GetInt32(observationIdOrdinal),
                reader.GetGuid(observationUuidOrdinal),
                DateOnly.FromDateTime(reader.GetDateTime(observedDateOrdinal)),
                reader.GetInt32(taxonIdOrdinal),
                reader.GetString(scientificNameOrdinal),
                ReadNullableString(reader, commonNameOrdinal),
                reader.GetString(observerDisplayNameOrdinal),
                reader.GetInt32(photoCountOrdinal),
                ReadNullableString(reader, squareUrlOrdinal),
                ReadNullableString(reader, mediumUrlOrdinal),
                ReadNullableString(reader, attributionOrdinal),
                ReadNullableString(reader, licenseOrdinal)));
        }

        return observationCards;
    }

    public async Task<IReadOnlyList<TaxonPathItem>> GetTaxonPathAsync(
        long sessionId,
        int taxonId,
        string? clientIpAddress,
        CancellationToken cancellationToken)
    {
        await using SqlConnection connection = await connectionFactory.OpenAsync(cancellationToken);
        await using SqlCommand command = new SqlCommand("dbo.spTaxonomy_TaxonPath", connection);
        command.CommandType = CommandType.StoredProcedure;

        command.Parameters.Add("@ID_Session", SqlDbType.BigInt).Value = sessionId;
        command.Parameters.Add("@ID_Taxon", SqlDbType.Int).Value = taxonId;
        command.Parameters.Add("@ClientIpAddress", SqlDbType.VarChar, 45).Value = (object?)clientIpAddress ?? DBNull.Value;

        List<TaxonPathItem> pathItems = new List<TaxonPathItem>();

        await using SqlDataReader reader = await command.ExecuteReaderAsync(cancellationToken);

        int idOrdinal = reader.GetOrdinal("ID");
        int scientificNameOrdinal = reader.GetOrdinal("ScientificName");
        int commonNameOrdinal = reader.GetOrdinal("CommonName");
        int rankOrdinal = reader.GetOrdinal("Rank");
        int levelOrdinal = reader.GetOrdinal("Level");

        while (await reader.ReadAsync(cancellationToken))
        {
            pathItems.Add(new TaxonPathItem(
                reader.GetInt32(idOrdinal),
                reader.GetString(scientificNameOrdinal),
                ReadNullableString(reader, commonNameOrdinal),
                reader.GetString(rankOrdinal),
                reader.GetInt32(levelOrdinal)));
        }

        return pathItems;
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