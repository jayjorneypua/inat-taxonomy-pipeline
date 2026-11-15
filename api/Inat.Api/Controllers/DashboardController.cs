using Inat.Api.Data;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inat.Api.Controllers;

[ApiController]
[Route("api/dashboard")]
[Authorize]
public sealed class DashboardController(DashboardRepository dashboardRepository) : ControllerBase
{
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

        IReadOnlyList<TaxonChildCount> taxonChildCounts = await dashboardRepository.GetTaxonChildrenCountsAsync(
            sessionId.Value,
            request.ParentTaxonId,
            clientIpAddress,
            cancellationToken);

        return Ok(taxonChildCounts);
    }

    [HttpPost("observations-by-month")]
    public async Task<ActionResult<IReadOnlyList<ObservationMonthCount>>> ObservationsByMonth(
        ObservationsByMonthRequest request,
        CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        IReadOnlyList<ObservationMonthCount> monthCounts = await dashboardRepository.GetObservationsByMonthAsync(
            sessionId.Value,
            request.TaxonId,
            clientIpAddress,
            cancellationToken);

        return Ok(monthCounts);
    }
}