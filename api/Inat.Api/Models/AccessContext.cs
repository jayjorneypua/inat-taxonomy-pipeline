namespace Inat.Api.Models;

// what a cache key needs, from security.spSession_GetAccessContext
public sealed record AccessContext(string ScopeSignature, long DataVersion);

// a value and whether it came from the cache
public sealed record CachedResult<T>(T Value, bool WasCached);