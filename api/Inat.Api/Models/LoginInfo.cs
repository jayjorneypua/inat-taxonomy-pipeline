namespace Inat.Api.Models;

// one row of security.spUser_GetLoginInfo
public sealed record LoginInfo(
    int UserId,
    string PasswordHash,
    bool IsLocked,
    DateTime? LockedUntil,
    bool HasChangedPassword
);