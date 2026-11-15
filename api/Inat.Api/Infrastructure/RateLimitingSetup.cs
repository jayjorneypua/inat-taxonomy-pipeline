using System.Globalization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

namespace Inat.Api.Infrastructure;

public static class RateLimitingSetup
{
    private const string LoginPath = "/api/auth/login";

    public static IServiceCollection AddInatRateLimiting(this IServiceCollection services, IConfiguration configuration)
    {
        int globalPermitLimit = configuration.GetValue<int>("RateLimiting:GlobalPermitLimit", 300);
        int globalWindowSeconds = configuration.GetValue<int>("RateLimiting:GlobalWindowSeconds", 60);
        int loginPermitLimit = configuration.GetValue<int>("RateLimiting:LoginPermitLimit", 20);
        int loginWindowSeconds = configuration.GetValue<int>("RateLimiting:LoginWindowSeconds", 60);

        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            // one limiter for every request, partitioned by client ip.
            // the login path gets its own, much smaller bucket against password guessing.
            options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
            {
                string path = context.Request.Path.ToString();

                if (path.StartsWith("/health", StringComparison.OrdinalIgnoreCase))
                {
                    return RateLimitPartition.GetNoLimiter("health");
                }

                string clientIP = "unknown";
                if (context.Connection.RemoteIpAddress != null)
                {
                    clientIP = context.Connection.RemoteIpAddress.ToString();
                }

                if (path.StartsWith(LoginPath, StringComparison.OrdinalIgnoreCase))
                {
                    return RateLimitPartition.GetFixedWindowLimiter("login:" + clientIP, key => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = loginPermitLimit,
                        Window = TimeSpan.FromSeconds(loginWindowSeconds),
                        QueueLimit = 0,
                        AutoReplenishment = true
                    });
                }

                return RateLimitPartition.GetFixedWindowLimiter("all:" + clientIP, key => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = globalPermitLimit,
                    Window = TimeSpan.FromSeconds(globalWindowSeconds),
                    QueueLimit = 0,
                    AutoReplenishment = true
                });
            });

            options.OnRejected = async (OnRejectedContext context, CancellationToken cancellationToken) =>
            {
                HttpContext httpContext = context.HttpContext;

                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out TimeSpan retryAfter))
                {
                    int retryAfterSeconds = (int)Math.Ceiling(retryAfter.TotalSeconds);
                    httpContext.Response.Headers.RetryAfter = retryAfterSeconds.ToString(CultureInfo.InvariantCulture);
                }

                ILogger logger = httpContext.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("Inat.Api.RateLimiting");
                logger.LogWarning("Rate limit hit on {Path}", httpContext.Request.Path.ToString());

                await httpContext.Response.WriteAsJsonAsync(new { title = "Too many requests", status = 429 }, cancellationToken);
            };
        });

        return services;
    }
}