namespace Inat.Api.Models;

// one row of dbo.spDashboard_TaxonChildrenCounts
public sealed record TaxonChildCount(
    int Id,
    string ScientificName,
    string? CommonName,
    string Rank,
    bool HasChildren,
    int ObservationCount
);