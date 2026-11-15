using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace Inat.Api.Observability;

public static class HealthCheckSetup
{
    private const string ReadyTag = "ready";

    public static IServiceCollection AddInatHealthChecks(this IServiceCollection services, bool isRedisEnabled)
    {
        IHealthChecksBuilder healthChecks = services.AddHealthChecks();

        healthChecks.AddCheck<SqlServerHealthCheck>("sqlserver", HealthStatus.Unhealthy, new[] { ReadyTag }, TimeSpan.FromSeconds(3));

        if (isRedisEnabled)
        {
            // redis is only the level 2 cache, the API still answers without it, so degraded instead of unhealthy
            healthChecks.AddCheck<RedisHealthCheck>("redis", HealthStatus.Degraded, new[] { ReadyTag }, TimeSpan.FromSeconds(2));
        }

        return services;
    }

    public static WebApplication MapInatHealthChecks(this WebApplication app)
    {
        HealthCheckOptions liveOptions = new HealthCheckOptions
        {
            Predicate = registration => false,
            ResponseWriter = WriteResponse
        };

        HealthCheckOptions readyOptions = new HealthCheckOptions
        {
            Predicate = registration => registration.Tags.Contains(ReadyTag),
            ResponseWriter = WriteResponse
        };

        app.MapHealthChecks("/health/live", liveOptions);
        app.MapHealthChecks("/health/ready", readyOptions);

        return app;
    }

    // status and timing only, no exception messages, so nothing internal leaks to callers.
    // failures are still logged in full by the health check service.
    private static Task WriteResponse(HttpContext context, HealthReport report)
    {
        context.Response.ContentType = "application/json";
        context.Response.Headers.CacheControl = "no-store";

        Dictionary<string, object> checks = new Dictionary<string, object>();
        foreach (KeyValuePair<string, HealthReportEntry> entry in report.Entries)
        {
            checks[entry.Key] = new
            {
                status = entry.Value.Status.ToString(),
                description = entry.Value.Description,
                durationMs = Math.Round(entry.Value.Duration.TotalMilliseconds, 1)
            };
        }

        object body = new
        {
            status = report.Status.ToString(),
            totalDurationMs = Math.Round(report.TotalDuration.TotalMilliseconds, 1),
            checks = checks
        };

        return context.Response.WriteAsJsonAsync(body);
    }
}