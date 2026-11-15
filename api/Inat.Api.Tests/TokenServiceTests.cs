using System.Security.Claims;
using System.Security.Cryptography;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Inat.Api.Tests;

// unit tests: TokenService on its own, no database, no web server
[TestClass]
public sealed class TokenServiceTests
{
    private static TokenService CreateTokenService()
    {
        byte[] signingKeyBytes = RandomNumberGenerator.GetBytes(64);

        Dictionary<string, string?> settings = new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = Convert.ToBase64String(signingKeyBytes),
            ["Jwt:Issuer"] = "inat-api-tests",
            ["Jwt:Audience"] = "inat-app-tests",
            ["Jwt:AccessTokenMinutes"] = "15",
            ["Jwt:RefreshTokenDays"] = "7"
        };

        IConfiguration configuration = new ConfigurationBuilder().AddInMemoryCollection(settings).Build();
        return new TokenService(configuration);
    }

    private static TokenValidationParameters CreateValidationParameters(TokenService tokenService)
    {
        return new TokenValidationParameters
        {
            ValidIssuer = tokenService.Issuer,
            ValidAudience = tokenService.Audience,
            IssuerSigningKey = tokenService.SigningKey,
            ValidateLifetime = true
        };
    }

    [TestMethod]
    public void HashRefreshToken_SameToken_GivesTheSame32ByteHash()
    {
        byte[] firstHash = TokenService.HashRefreshToken("same-token");
        byte[] secondHash = TokenService.HashRefreshToken("same-token");

        CollectionAssert.AreEqual(firstHash, secondHash);
        Assert.HasCount(32, firstHash);
    }

    [TestMethod]
    public void HashRefreshToken_DifferentTokens_GiveDifferentHashes()
    {
        byte[] firstHash = TokenService.HashRefreshToken("token-one");
        byte[] secondHash = TokenService.HashRefreshToken("token-two");

        CollectionAssert.AreNotEqual(firstHash, secondHash);
    }

    [TestMethod]
    public void CreateRefreshToken_EachCall_GivesANewTokenWithItsHashAndAFutureExpiry()
    {
        TokenService tokenService = CreateTokenService();

        RefreshToken firstToken = tokenService.CreateRefreshToken();
        RefreshToken secondToken = tokenService.CreateRefreshToken();

        Assert.AreNotEqual(firstToken.Token, secondToken.Token);
        CollectionAssert.AreEqual(TokenService.HashRefreshToken(firstToken.Token), firstToken.TokenHash);
        Assert.IsTrue(firstToken.ExpiresAt > DateTime.UtcNow.AddDays(6));
    }

    [TestMethod]
    public async Task CreateAccessToken_IsValidAndCarriesTheSessionId()
    {
        TokenService tokenService = CreateTokenService();

        AccessToken accessToken = tokenService.CreateAccessToken(12345);
        TokenValidationResult validationResult =
            await new JsonWebTokenHandler().ValidateTokenAsync(accessToken.Token, CreateValidationParameters(tokenService));

        Assert.IsTrue(validationResult.IsValid);
        Assert.AreEqual("12345", validationResult.Claims[TokenService.SessionClaimType].ToString());
    }

    [TestMethod]
    public async Task CreateAccessToken_SignedWithAnotherKey_IsRejected()
    {
        TokenService realTokenService = CreateTokenService();
        TokenService otherTokenService = CreateTokenService();

        AccessToken accessTokenFromOtherKey = otherTokenService.CreateAccessToken(12345);
        TokenValidationResult validationResult =
            await new JsonWebTokenHandler().ValidateTokenAsync(accessTokenFromOtherKey.Token, CreateValidationParameters(realTokenService));

        Assert.IsFalse(validationResult.IsValid);
    }

    [TestMethod]
    public void GetSessionId_ReadsTheSidClaim()
    {
        ClaimsPrincipal user = new ClaimsPrincipal(new ClaimsIdentity(new Claim[] { new Claim("sid", "42") }));

        Assert.AreEqual<long?>(42, TokenService.GetSessionId(user));
    }

    [TestMethod]
    public void GetSessionId_WithoutTheClaim_ReturnsNull()
    {
        ClaimsPrincipal user = new ClaimsPrincipal(new ClaimsIdentity());

        Assert.IsNull(TokenService.GetSessionId(user));
    }
}