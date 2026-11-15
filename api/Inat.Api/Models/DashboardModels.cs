namespace Inat.Api.Models;

// null means start at the root of the tree (Life)
public sealed record TaxonChildrenRequest(int? ParentTaxonId);

// null means the whole tree
public sealed record ObservationsByMonthRequest(int? TaxonId);