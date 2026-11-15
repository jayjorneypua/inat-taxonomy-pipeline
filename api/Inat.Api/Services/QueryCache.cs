using System.Security.Cryptography;
using System.Text;
using Inat.Api.Data;
using Inat.Api.Models;
using Microsoft.Extensions.Caching.Hybrid;

namespace Inat.Api.Services;

// caches heavy read queries safely:
//   1. access is checked in the database on every request (cheap), so logout and permission
//      changes apply immediately, even for answers that come from the cache
//   2. the key holds the scope signature, so only sessions with the same scope share an answer
//   3. the key holds the data version (last sync run), so a new sync makes old answers unreachable
// HybridCache keeps answers in memory now; a distributed cache like redis can be added as a second level
public sealed class QueryCache(HybridCache hybridCache, AccessRepository accessRepository)
{
    private static readonly HybridCacheEntryOptions entryOptions = new HybridCacheEntryOptions
    {
        Expiration = TimeSpan.FromMinutes(30),
        LocalCacheExpiration = TimeSpan.FromMinutes(30)
    };

    public async Task<CachedResult<T>> GetOrLoadAsync<T>(
        long sessionId,
        string permissionCode,
        string queryName,
        string queryArguments,
        string? clientIpAddress,
        Func<CancellationToken, Task<T>> load,
        CancellationToken cancellationToken)
    {
        AccessContext accessContext = await accessRepository.GetAccessContextAsync(
            sessionId, permissionCode, clientIpAddress, cancellationToken);

        string scopeHash = HashScopeSignature(accessContext.ScopeSignature);
        string cacheKey = $"{queryName}:v{accessContext.DataVersion}:s{scopeHash}:{queryArguments}";

        // the factory only runs on a miss, so it tells us whether the answer was cached
        bool wasLoaded = false;

        T value = await hybridCache.GetOrCreateAsync(
            cacheKey,
            async (CancellationToken factoryCancellationToken) =>
            {
                wasLoaded = true;
                return await load(factoryCancellationToken);
            },
            entryOptions,
            cancellationToken: cancellationToken);

        return new CachedResult<T>(value, wasLoaded == false);
    }

    // a scope can hold many taxon ids, the hash keeps the key short
    private static string HashScopeSignature(string scopeSignature)
    {
        byte[] hashBytes = SHA256.HashData(Encoding.UTF8.GetBytes(scopeSignature));
        return Convert.ToHexString(hashBytes).Substring(0, 16);
    }
}