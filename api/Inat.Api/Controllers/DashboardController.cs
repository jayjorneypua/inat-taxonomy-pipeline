using Inat.Api.Data;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inat.Api.Controllers;

[ApiController]
[Route("api/dashboard")]
[Authorize]
public sealed class DashboardController(DashboardRepository dashboardRepository, QueryCache queryCache) : ControllerBase
{
    private const string DashboardViewPermission = "dashboard.view";

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
        string queryArguments = request.ParentTaxonId?.ToString() ?? "root";

        CachedResult<IReadOnlyList<TaxonChildCount>> cachedResult = await queryCache.GetOrLoadAsync(
            sessionId.Value,
            DashboardViewPermission,
            "taxon-children",
            queryArguments,
            clientIpAddress,
            (CancellationToken loadCancellationToken) => dashboardRepository.GetTaxonChildrenCountsAsync(
                sessionId.Value, request.ParentTaxonId, clientIpAddress, loadCancellationToken),
            cancellationToken);

        SetCacheHeader(cachedResult.WasCached);
        return Ok(cachedResult.Value);
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
        string queryArguments = request.TaxonId?.ToString() ?? "root";

        CachedResult<IReadOnlyList<ObservationMonthCount>> cachedResult = await queryCache.GetOrLoadAsync(
            sessionId.Value,
            DashboardViewPermission,
            "observations-by-month",
            queryArguments,
            clientIpAddress,
            (CancellationToken loadCancellationToken) => dashboardRepository.GetObservationsByMonthAsync(
                sessionId.Value, request.TaxonId, clientIpAddress, loadCancellationToken),
            cancellationToken);

        SetCacheHeader(cachedResult.WasCached);
        return Ok(cachedResult.Value);
    }

    // X-Cache: hit or miss, so you can see the cache working in the browser's network tab
    private void SetCacheHeader(bool wasCached)
    {
        if (wasCached)
        {
            Response.Headers["X-Cache"] = "hit";
        }
        else
        {
            Response.Headers["X-Cache"] = "miss";
        }
    }
}