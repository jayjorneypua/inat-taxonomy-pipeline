using Inat.Api.Data;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Controllers;

// login, refresh and logout.
// the access token (15 minutes) goes back in the json body and the client sends it as a bearer header.
// the refresh token (7 days) only ever lives in a cookie:
//   HttpOnly         javascript cannot read it, so an xss bug cannot steal it
//   Secure           only sent over https (browsers treat localhost as secure too)
//   SameSite=Strict  other websites cannot make the browser send it
//   Path=/api/auth   only sent to login, refresh and logout, never with data requests
[ApiController]
[Route("api/auth")]
public sealed class AuthController(SecurityRepository securityRepository, TokenService tokenService) : ControllerBase
{
    public const string RefreshCookieName = "inat_refresh";
    public const string RefreshCookiePath = "/api/auth";

    private const string InvalidLoginMessage = "Invalid username or password.";
    private const string PleaseLogInMessage = "Please log in again.";
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

        SetRefreshCookie(refreshToken);

        AccessToken accessToken = tokenService.CreateAccessToken(sessionId);
        return Ok(new TokenResponse(accessToken.Token, accessToken.ExpiresAt));
    }

    // no body: the refresh token comes from the cookie the browser attaches by itself
    [HttpPost("refresh")]
    [AllowAnonymous]
    public async Task<ActionResult<TokenResponse>> Refresh(CancellationToken cancellationToken)
    {
        string? refreshTokenValue = Request.Cookies[RefreshCookieName];
        if (string.IsNullOrEmpty(refreshTokenValue))
        {
            return Unauthorized(new { message = PleaseLogInMessage });
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        byte[] oldTokenHash = TokenService.HashRefreshToken(refreshTokenValue);
        RefreshToken newRefreshToken = tokenService.CreateRefreshToken();

        SessionRefreshResult refreshResult = await securityRepository.RefreshSessionAsync(
            oldTokenHash,
            newRefreshToken.TokenHash,
            newRefreshToken.ExpiresAt,
            clientIpAddress,
            cancellationToken);

        // invalid or reused: the cookie is useless now, remove it and make the client log in again
        if (refreshResult.Result != "ok" || refreshResult.SessionId is null)
        {
            DeleteRefreshCookie();
            return Unauthorized(new { message = PleaseLogInMessage });
        }

        SetRefreshCookie(newRefreshToken);

        AccessToken accessToken = tokenService.CreateAccessToken(refreshResult.SessionId.Value);
        return Ok(new TokenResponse(accessToken.Token, accessToken.ExpiresAt));
    }

    // allowed without a valid access token, so the cookie is always removed, even when the access token
    // already expired. the session is revoked in the database whenever the access token is still valid
    [HttpPost("logout")]
    [AllowAnonymous]
    public async Task<IActionResult> Logout(CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId != null)
        {
            string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
            await securityRepository.RevokeSessionAsync(sessionId.Value, "logout", clientIpAddress, cancellationToken);
        }

        DeleteRefreshCookie();
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

    private void SetRefreshCookie(RefreshToken refreshToken)
    {
        CookieOptions cookieOptions = new CookieOptions
        {
            HttpOnly = true,
            Secure = true,
            SameSite = SameSiteMode.Strict,
            Path = RefreshCookiePath,
            Expires = new DateTimeOffset(refreshToken.ExpiresAt),
            IsEssential = true
        };

        Response.Cookies.Append(RefreshCookieName, refreshToken.Token, cookieOptions);
    }

    // the browser only removes the cookie when name, path and flags match the ones it was set with
    private void DeleteRefreshCookie()
    {
        CookieOptions cookieOptions = new CookieOptions
        {
            HttpOnly = true,
            Secure = true,
            SameSite = SameSiteMode.Strict,
            Path = RefreshCookiePath
        };

        Response.Cookies.Delete(RefreshCookieName, cookieOptions);
    }
}