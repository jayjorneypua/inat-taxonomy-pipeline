namespace Inat.Api.Models;

// who is logged in and the permission codes of their session, from security.spSession_GetCurrentUser
public sealed record CurrentUser(
    int Id,
    string Username,
    string FirstName,
    string LastName,
    IReadOnlyList<string> Permissions
);