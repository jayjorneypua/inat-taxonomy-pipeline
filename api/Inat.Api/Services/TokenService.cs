using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Inat.Api.Models;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Inat.Api.Services;

// creates the short lived access token (jwt) and the long lived refresh token.
// the access token only carries the session id: every stored procedure checks the session itself
public sealed class TokenService
{
    public const string SessionClaimType = "sid";

    public SymmetricSecurityKey SigningKey { get; }
    public string Issuer { get; }
    public string Audience { get; }

    private readonly TimeSpan accessTokenLifetime;
    private readonly TimeSpan refreshTokenLifetime;

    public TokenService(IConfiguration configuration)
    {
        string? signingKeyBase64 = configuration["Jwt:SigningKey"];
        if (signingKeyBase64 == null)
        {
            throw new InvalidOperationException("Jwt:SigningKey is missing. Set it with dotnet user-secrets.");
        }

        SigningKey = new SymmetricSecurityKey(Convert.FromBase64String(signingKeyBase64));
        Issuer = configuration["Jwt:Issuer"] ?? "inat-api";
        Audience = configuration["Jwt:Audience"] ?? "inat-app";
        accessTokenLifetime = TimeSpan.FromMinutes(configuration.GetValue<int>("Jwt:AccessTokenMinutes", 15));
        refreshTokenLifetime = TimeSpan.FromDays(configuration.GetValue<int>("Jwt:RefreshTokenDays", 7));
    }

    public AccessToken CreateAccessToken(long sessionId)
    {
        DateTime expiresAt = DateTime.UtcNow.Add(accessTokenLifetime);

        SecurityTokenDescriptor tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(new Claim[] { new Claim(SessionClaimType, sessionId.ToString()) }),
            Expires = expiresAt,
            Issuer = Issuer,
            Audience = Audience,
            SigningCredentials = new SigningCredentials(SigningKey, SecurityAlgorithms.HmacSha256)
        };

        string token = new JsonWebTokenHandler().CreateToken(tokenDescriptor);
        return new AccessToken(token, expiresAt);
    }

    public RefreshToken CreateRefreshToken()
    {
        byte[] tokenBytes = RandomNumberGenerator.GetBytes(32);
        string token = Base64UrlEncoder.Encode(tokenBytes);
        return new RefreshToken(token, HashRefreshToken(token), DateTime.UtcNow.Add(refreshTokenLifetime));
    }

    // the database only ever sees this hash, never the token itself
    public static byte[] HashRefreshToken(string token)
    {
        return SHA256.HashData(Encoding.UTF8.GetBytes(token));
    }

    public static long? GetSessionId(ClaimsPrincipal user)
    {
        string? sessionIdValue = user.FindFirst(SessionClaimType)?.Value;

        if (long.TryParse(sessionIdValue, out long sessionId))
        {
            return sessionId;
        }

        return null;
    }
}