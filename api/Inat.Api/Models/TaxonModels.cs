namespace Inat.Api.Models;

// one ancestor in the breadcrumb, one row of dbo.spTaxonomy_TaxonPath
public sealed record TaxonPathItem(
    int Id,
    string ScientificName,
    string? CommonName,
    string Rank,
    int level
);

public sealed record TaxonPathRequest(int TaxonId);