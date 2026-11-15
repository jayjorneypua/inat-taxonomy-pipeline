using Inat.Api.Data;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Inat.Api.Controllers;

[ApiController]
[Route("api/dashboard")]
[Authorize]
public sealed class DashboardController(DashboardRepository dashboardRepository) : ControllerBase
{
    private const int InvalidSessionErrorNumber = 50020;
    private const int MissingPermissionErrorNumber = 50021;

    [HttpPost("taxon-children")]
    public async Task<ActionResult<IReadOnlyList<TaxonChildCount>>> TaxonChildren(
        TaxonChildrenRequest request,
        CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        try
        {
            IReadOnlyList<TaxonChildCount> taxonChildCounts = await dashboardRepository.GetTaxonChildrenCountsAsync(
                sessionId.Value,
                request.ParentTaxonId,
                clientIpAddress,
                cancellationToken);

            return Ok(taxonChildCounts);
        }
        catch (SqlException exception) when (exception.Number == InvalidSessionErrorNumber)
        {
            return Unauthorized(new { message = "Your session is no longer valid. Please log in again." });
        }
        catch (SqlException exception) when (exception.Number == MissingPermissionErrorNumber)
        {
            return Forbid();
        }
    }
}