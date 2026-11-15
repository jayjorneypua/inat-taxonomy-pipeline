namespace Inat.Api.Models;

// one filter in the grid request. Column and Operator must be a pair the stored procedure allows
public sealed record GridFilter(string Column, string Operator, string Value);

public sealed record UserGridRequest(
    int? Page,
    int? PageSize,
    string? Search,
    IReadOnlyList<GridFilter>? Filters,
    string? SortColumn,
    string? SortDirection);

// one row of security.spUser_Grid
public sealed record UserGridRow(
    int Id,
    string Username,
    string FirstName,
    string LastName,
    string Email,
    bool Active,
    bool IsLocked,
    int LoginCount,
    DateTime? LastLoginDate,
    string? GroupNames,
    string? RoleNames);

public sealed record UserGridResponse(
    IReadOnlyList<UserGridRow> Items,
    int TotalCount,
    int Page,
    int PageSize);