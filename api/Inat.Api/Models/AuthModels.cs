namespace Inat.Api.Models;

// what the client sends
public sealed record LoginRequest(string Username, string Password);

public sealed record RefreshRequest(string RefreshToken);

// what the client gets back after login or refresh
public sealed record TokenResponse(
    string AccessToken,
    DateTime AccessTokenExpiresAt,
    string RefreshToken,
    DateTime RefreshTokenExpiresAt);

// internal: a signed access token and when it expires
public sealed record AccessToken(string Token, DateTime ExpiresAt);

// internal: the refresh token the client keeps, and the hash the database keeps
public sealed record RefreshToken(string Token, byte[] TokenHash, DateTime ExpiresAt);

// internal: what security.spSession_Refresh answered (ok, invalid or reused)
public sealed record SessionRefreshResult(string Result, long? SessionId);