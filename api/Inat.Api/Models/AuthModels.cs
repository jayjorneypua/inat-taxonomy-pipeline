namespace Inat.Api.Models;

// what the client sends
public sealed record LoginRequest(string Username, string Password);

// what the client gets back after login or refresh. the refresh token is not in here:
// it travels in an HttpOnly cookie that javascript cannot read
public sealed record TokenResponse(
    string AccessToken,
    DateTime AccessTokenExpiresAt);

// internal: a signed access token and when it expires
public sealed record AccessToken(string Token, DateTime ExpiresAt);

// internal: the refresh token the browser keeps in its cookie, and the hash the database keeps
public sealed record RefreshToken(string Token, byte[] TokenHash, DateTime ExpiresAt);

// internal: what security.spSession_Refresh answered (ok, invalid or reused)
public sealed record SessionRefreshResult(string Result, long? SessionId);