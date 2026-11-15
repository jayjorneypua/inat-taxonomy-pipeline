using Microsoft.Extensions.Diagnostics.HealthChecks;
using StackExchange.Redis;

namespace Inat.Api.Observability;

public sealed class RedisHealthCheck : IHealthCheck
{
    private readonly IConnectionMultiplexer _redis;

    public RedisHealthCheck(IConnectionMultiplexer redis)
    {
        _redis = redis;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        if (_redis.IsConnected == false)
        {
            return new HealthCheckResult(context.Registration.FailureStatus, "Redis not connected");
        }

        try
        {
            TimeSpan latency = await _redis.GetDatabase().PingAsync();
            return HealthCheckResult.Healthy($"Redis ping {Math.Round(latency.TotalMilliseconds, 1)} ms");
        }
        catch (Exception ex)
        {
            return new HealthCheckResult(context.Registration.FailureStatus, "Redis ping failed", ex);
        }
    }
}