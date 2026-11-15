namespace Inat.Api.Models;

// one row of dbo.spDashboard_ObservationsByMonth
public sealed record ObservationMonthCount(DateOnly MonthStart, int ObservationCount);

// one card in the photo grid, one row of dbo.spTaxonomy_ObservationsPage
public sealed record ObservationCard(
    int ObservationId,
    Guid ObservationUuid,
    DateOnly ObservedDate,
    int TaxonId,
    string ScientificName,
    string? CommonName,
    string ObserverDisplayName,
    int PhotoCount,
    string? SquareUrl,
    string? MediumUrl,
    string? Attribution,
    string? License
);

// where the next page starts: the last card's date and id
public sealed record ObservationCursor(DateOnly AfterObservedDate, int AfterObservationId);

// one page of cards. NextCursor is null on the last page
public sealed record ObservationsPageResponse(IReadOnlyList<ObservationCard> Items, ObservationCursor? NextCursor);

// what the client sends for a page. leave the cursor fields out for the first page
public sealed record ObservationsPageRequest(
    int TaxonId,
    int? PageSize,
    DateOnly? AfterObservedDate,
    int? AfterObservationId
);
