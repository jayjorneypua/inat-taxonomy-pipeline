using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Infrastructure;

// turns errors into http answers in one place, so controllers don't repeat try/catch.
// the stored procedures throw 50020 for a bad session, 50021 for a missing permission and
// 50040 to 50049 for invalid grid input (unknown sort column, filter not allowed...).
// anything else is a 500 with a generic message: details go to the log, never to the client
public sealed class DatabaseExceptionHandler(ILogger<DatabaseExceptionHandler> logger) : IExceptionHandler
{
    private const int InvalidSessionErrorNumber = 50020;
    private const int MissingPermissionErrorNumber = 50021;
    private const int FirstInvalidInputErrorNumber = 50040;
    private const int LastInvalidInputErrorNumber = 50049;

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        int statusCode = StatusCodes.Status500InternalServerError;
        string title = "Something went wrong. Please try again later.";

        if (exception is SqlException sqlException)
        {
            if (sqlException.Number == InvalidSessionErrorNumber)
            {
                statusCode = StatusCodes.Status401Unauthorized;
                title = "Your session is no longer valid. Please log in again.";
            }
            else if (sqlException.Number == MissingPermissionErrorNumber)
            {
                statusCode = StatusCodes.Status403Forbidden;
                title = "You do not have permission to do this.";
            }
            else if (sqlException.Number >= FirstInvalidInputErrorNumber && sqlException.Number <= LastInvalidInputErrorNumber)
            {
                // these messages are written by our own procedures, so they are safe to show
                statusCode = StatusCodes.Status400BadRequest;
                title = sqlException.Message;
            }
        }

        if (statusCode == StatusCodes.Status500InternalServerError)
        {
            logger.LogError(exception, "Unhandled exception for {Method} {Path}", httpContext.Request.Method, httpContext.Request.Path);
        }

        ProblemDetails problemDetails = new ProblemDetails
        {
            Status = statusCode,
            Title = title
        };

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(problemDetails, cancellationToken);
        return true;
    }
}