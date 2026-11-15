using System.Security.Cryptography;
using Inat.Api.Controllers;
using Inat.Api.Data;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;

namespace Inat.Api.Tests.Integration;

// integration tests: the real AuthController with the real repository in inat_test_empty, logged in as inat_api.
// checks that the refresh token only travels in an HttpOnly cookie, rotates on refresh, and dies on reuse
[TestClass]
public sealed class AuthCookieIntegrationTests
{
    private static SecurityRepository securityRepository = null!;
    private static TokenService tokenService = null!;

    [ClassInitialize]
    public static async Task ClassInitialize(TestContext testContext)
    {
        await TestDatabase.SeedAsync();

        IConfiguration apiConfiguration = TestDatabase.CreateApiConfiguration();
        securityRepository = new SecurityRepository(new SqlConnectionFactory(apiConfiguration));

        Dictionary<string, string?> tokenSettings = new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64))
        };
        IConfiguration tokenConfiguration = new ConfigurationBuilder().AddInMemoryCollection(tokenSettings).Build();
        tokenService = new TokenService(tokenConfiguration);
    }

    // a controller with its own fake request, optionally carrying the refresh cookie
    private static AuthController CreateController(string? refreshCookieValue)
    {
        DefaultHttpContext httpContext = new DefaultHttpContext();
        if (refreshCookieValue != null)
        {
            httpContext.Request.Headers.Cookie = $"{AuthController.RefreshCookieName}={refreshCookieValue}";
        }

        AuthController controller = new AuthController(securityRepository, tokenService);
        controller.ControllerContext = new ControllerContext { HttpContext = httpContext };
        return controller;
    }

    private static string GetSetCookieHeader(AuthController controller)
    {
        return controller.HttpContext.Response.Headers.SetCookie.ToString();
    }

    // the cookie value from a Set-Cookie header like "inat_refresh=abc; expires=...; path=/api/auth; ..."
    private static string ReadCookieValue(string setCookieHeader)
    {
        string prefix = AuthController.RefreshCookieName + "=";
        int start = setCookieHeader.IndexOf(prefix, StringComparison.Ordinal);
        if (start < 0)
        {
            return "";
        }

        start = start + prefix.Length;
        int end = setCookieHeader.IndexOf(';', start);
        if (end < 0)
        {
            end = setCookieHeader.Length;
        }

        return setCookieHeader.Substring(start, end - start);
    }

    private static async Task<string> LogInAndGetCookieAsync()
    {
        AuthController controller = CreateController(null);
        ActionResult<TokenResponse> result = await controller.Login(
            new LoginRequest(TestDatabase.AdminUsername, TestDatabase.AdminPassword), CancellationToken.None);

        Assert.IsInstanceOfType(result.Result, typeof(OkObjectResult));
        return ReadCookieValue(GetSetCookieHeader(controller));
    }

    [TestMethod]
    public async Task Login_PutsTheRefreshTokenInAnHttpOnlyCookieOnly()
    {
        AuthController controller = CreateController(null);

        ActionResult<TokenResponse> result = await controller.Login(
            new LoginRequest(TestDatabase.AdminUsername, TestDatabase.AdminPassword), CancellationToken.None);

        OkObjectResult? okResult = result.Result as OkObjectResult;
        Assert.IsNotNull(okResult);
        TokenResponse? body = okResult.Value as TokenResponse;
        Assert.IsNotNull(body);
        Assert.IsFalse(string.IsNullOrEmpty(body.AccessToken));

        string setCookieHeader = GetSetCookieHeader(controller);
        Assert.IsFalse(string.IsNullOrEmpty(ReadCookieValue(setCookieHeader)));
        Assert.IsTrue(setCookieHeader.Contains("httponly", StringComparison.OrdinalIgnoreCase));
        Assert.IsTrue(setCookieHeader.Contains("secure", StringComparison.OrdinalIgnoreCase));
        Assert.IsTrue(setCookieHeader.Contains("samesite=strict", StringComparison.OrdinalIgnoreCase));
        Assert.IsTrue(setCookieHeader.Contains("path=/api/auth", StringComparison.OrdinalIgnoreCase));
    }

    [TestMethod]
    public async Task Refresh_WithTheCookie_ReturnsAnAccessTokenAndRotatesTheCookie()
    {
        string firstCookieValue = await LogInAndGetCookieAsync();

        AuthController controller = CreateController(firstCookieValue);
        ActionResult<TokenResponse> result = await controller.Refresh(CancellationToken.None);

        OkObjectResult? okResult = result.Result as OkObjectResult;
        Assert.IsNotNull(okResult);
        TokenResponse? body = okResult.Value as TokenResponse;
        Assert.IsNotNull(body);
        Assert.IsFalse(string.IsNullOrEmpty(body.AccessToken));

        string secondCookieValue = ReadCookieValue(GetSetCookieHeader(controller));
        Assert.IsFalse(string.IsNullOrEmpty(secondCookieValue));
        Assert.AreNotEqual(firstCookieValue, secondCookieValue);
    }

    [TestMethod]
    public async Task Refresh_WithAnAlreadyUsedCookie_IsRejectedAndClearsTheCookie()
    {
        string firstCookieValue = await LogInAndGetCookieAsync();

        AuthController firstRefreshController = CreateController(firstCookieValue);
        ActionResult<TokenResponse> firstRefresh = await firstRefreshController.Refresh(CancellationToken.None);
        Assert.IsInstanceOfType(firstRefresh.Result, typeof(OkObjectResult));

        // the same cookie again, like an attacker replaying a stolen copy
        AuthController reuseController = CreateController(firstCookieValue);
        ActionResult<TokenResponse> reuse = await reuseController.Refresh(CancellationToken.None);

        Assert.IsInstanceOfType(reuse.Result, typeof(UnauthorizedObjectResult));
        Assert.IsTrue(GetSetCookieHeader(reuseController).Contains("1970", StringComparison.Ordinal));
    }

    [TestMethod]
    public async Task Refresh_WithoutACookie_IsRejected()
    {
        AuthController controller = CreateController(null);

        ActionResult<TokenResponse> result = await controller.Refresh(CancellationToken.None);

        Assert.IsInstanceOfType(result.Result, typeof(UnauthorizedObjectResult));
    }
}