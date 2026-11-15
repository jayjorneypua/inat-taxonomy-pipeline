using System.Diagnostics;

namespace Inat.Api.Observability;

public sealed class RequestLoggingMiddleware
{
    private const string RequestIDHeader = "X-Request-ID";
    private const int MaxRequestIDLength = 64;

    private readonly RequestDelegate _next;
    private readonly ILogger<RequestLoggingMiddleware> _logger;

    public RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        string requestID = context.Request.Headers[RequestIDHeader].ToString();
        if (string.IsNullOrWhiteSpace(requestID) || requestID.Length > MaxRequestIDLength)
        {
            requestID = context.TraceIdentifier;
        }

        context.TraceIdentifier = requestID;
        context.Response.Headers[RequestIDHeader] = requestID;

        string clientIP = string.Empty;
        if (context.Connection.RemoteIpAddress != null)
        {
            clientIP = context.Connection.RemoteIpAddress.ToString();
        }

        Dictionary<string, object?> scope = new Dictionary<string, object?>
        {
            ["RequestID"] = requestID,
            ["ClientIP"] = clientIP
        };

        string method = context.Request.Method;
        string path = context.Request.Path.ToString();
        Stopwatch stopwatch = Stopwatch.StartNew();

        using (_logger.BeginScope(scope))
        {
            try
            {
                await _next(context);
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                _logger.LogError(ex, "HTTP {Method} {Path} failed after {ElapsedMs} ms"
                    , method
                    , path
                    , Math.Round(stopwatch.Elapsed.TotalMilliseconds, 1));
                throw;
            }

            stopwatch.Stop();

            if (path.StartsWith("/health", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            int statusCode = context.Response.StatusCode;
            LogLevel level = LogLevel.Information;
            if (statusCode >= 500)
            {
                level = LogLevel.Error;
            }
            else if (statusCode >= 400)
            {
                level = LogLevel.Warning;
            }

            string cache = context.Response.Headers["X-Cache"].ToString();
            string instance = context.Response.Headers["X-Instance"].ToString();

            _logger.Log(level, "HTTP {Method} {Path} responded {StatusCode} in {ElapsedMs} ms (cache {Cache}, instance {Instance})"
                , method
                , path
                , statusCode
                , Math.Round(stopwatch.Elapsed.TotalMilliseconds, 1)
                , cache
                , instance);
        }
    }
}