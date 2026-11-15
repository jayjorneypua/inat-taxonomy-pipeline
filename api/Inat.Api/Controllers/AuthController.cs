using Inat.Api.Data;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(SecurityRepository securityRepository, TokenService tokenService) : ControllerBase
{
    private const string InvalidLoginMessage = "Invalid username or password.";
    private const int UserCannotLogInErrorNumber = 50011;
    private static readonly PasswordHasher<object> passwordHasher = new PasswordHasher<object>();

    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<TokenResponse>> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        LoginInfo? loginInfo = await securityRepository.GetLoginInfoAsync(request.Username, cancellationToken);

        // unknown username: record the attempt, give the same answer as a wrong password
        if (loginInfo is null)
        {
            await securityRepository.RecordFailedLoginAsync(request.Username, clientIpAddress, cancellationToken);
            return Unauthorized(new { message = InvalidLoginMessage });
        }

        // locked: same answer, so nobody can probe which accounts exist
        if (loginInfo.IsLocked)
        {
            return Unauthorized(new { message = InvalidLoginMessage });
        }

        PasswordVerificationResult verification =
            passwordHasher.VerifyHashedPassword(new object(), loginInfo.PasswordHash, request.Password);

        if (verification == PasswordVerificationResult.Failed)
        {
            await securityRepository.RecordFailedLoginAsync(request.Username, clientIpAddress, cancellationToken);
            return Unauthorized(new { message = InvalidLoginMessage });
        }

        RefreshToken refreshToken = tokenService.CreateRefreshToken();
        string userAgent = Request.Headers.UserAgent.ToString();
        if (userAgent.Length > 500)
        {
            userAgent = userAgent.Substring(0, 500);
        }

        long sessionId;
        try
        {
            sessionId = await securityRepository.CreateSessionAsync(
                loginInfo.UserId,
                refreshToken.TokenHash,
                refreshToken.ExpiresAt,
                clientIpAddress,
                userAgent,
                cancellationToken);
        }
        catch (SqlException exception) when (exception.Number == UserCannotLogInErrorNumber)
        {
            // the database refused on its own, for example the account was locked a moment ago
            return Unauthorized(new { message = InvalidLoginMessage });
        }

        AccessToken accessToken = tokenService.CreateAccessToken(sessionId);
        return Ok(new TokenResponse(accessToken.Token, accessToken.ExpiresAt, refreshToken.Token, refreshToken.ExpiresAt));
    }

    [HttpPost("refresh")]
    [AllowAnonymous]
    public async Task<ActionResult<TokenResponse>> Refresh(RefreshRequest request, CancellationToken cancellationToken)
    {
        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        byte[] oldTokenHash = TokenService.HashRefreshToken(request.RefreshToken);
        RefreshToken newRefreshToken = tokenService.CreateRefreshToken();

        SessionRefreshResult refreshResult = await securityRepository.RefreshSessionAsync(
            oldTokenHash,
            newRefreshToken.TokenHash,
            newRefreshToken.ExpiresAt,
            clientIpAddress,
            cancellationToken);

        // invalid or reused: the client has to log in again
        if (refreshResult.Result != "ok" || refreshResult.SessionId is null)
        {
            return Unauthorized(new { message = "Please log in again." });
        }

        AccessToken accessToken = tokenService.CreateAccessToken(refreshResult.SessionId.Value);
        return Ok(new TokenResponse(accessToken.Token, accessToken.ExpiresAt, newRefreshToken.Token, newRefreshToken.ExpiresAt));
    }

    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout(CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        await securityRepository.RevokeSessionAsync(sessionId.Value, "logout", clientIpAddress, cancellationToken);
        return NoContent();
    }

    // who is logged in and what they may do, so the ui can show or hide pages and buttons
    [HttpPost("me")]
    [Authorize]
    public async Task<ActionResult<CurrentUser>> Me(CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        CurrentUser currentUser = await securityRepository.GetCurrentUserAsync(sessionId.Value, clientIpAddress, cancellationToken);
        return Ok(currentUser);
    }
}