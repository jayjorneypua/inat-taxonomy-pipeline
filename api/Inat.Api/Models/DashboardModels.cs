namespace Inat.Api.Models;

// null means start at the root of the tree (Life)
public sealed record TaxonChildrenRequest(int? ParentTaxonId);