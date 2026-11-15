using System.Text.Json;

namespace Inat.Api.Observability;

public static class LoggingSetup
{
    public static WebApplicationBuilder AddInatLogging(this WebApplicationBuilder builder)
    {
        builder.Logging.ClearProviders();
        builder.Logging.AddJsonConsole(options =>
        {
            options.IncludeScopes = true;
            options.UseUtcTimestamp = true;
            options.TimestampFormat = "yyyy-MM-ddTHH:mm:ss.fffZ";
            options.JsonWriterOptions = new JsonWriterOptions { Indented = false };
        });

        return builder;
    }

    public static IApplicationBuilder UseInatRequestLogging(this IApplicationBuilder app)
    {
        return app.UseMiddleware<RequestLoggingMiddleware>();
    }
}