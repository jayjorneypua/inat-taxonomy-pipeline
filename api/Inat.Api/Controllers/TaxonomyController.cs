using Inat.Api.Data;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inat.Api.Controllers;

[ApiController]
[Route("api/taxonomy")]
[Authorize]
public sealed class TaxonomyController(TaxonomyRepository taxonomyRepository, QueryCache queryCache) : ControllerBase
{
    private const int DefaultPageSize = 24;
    private const int MaximumPageSize = 100;
    private const string TaxonomyViewPermission = "taxonomy.view";

    // one page of the photo grid, not cached. the response's NextCursor goes into the next request,
    // null means no more pages
    [HttpPost("observations")]
    public async Task<ActionResult<ObservationsPageResponse>> Observations(
        ObservationsPageRequest request,
        CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        // same clamp as the stored procedure, so the api knows how many rows a full page has
        int pageSize = DefaultPageSize;
        if (request.PageSize.HasValue)
        {
            pageSize = Math.Clamp(request.PageSize.Value, 1, MaximumPageSize);
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        IReadOnlyList<ObservationCard> observationCards = await taxonomyRepository.GetObservationsPageAsync(
            sessionId.Value,
            request.TaxonId,
            pageSize,
            request.AfterObservedDate,
            request.AfterObservationId,
            clientIpAddress,
            cancellationToken);

        // a full page means there may be more, so hand back the last card as the cursor
        ObservationCursor? nextCursor = null;
        if (observationCards.Count == pageSize)
        {
            ObservationCard lastCard = observationCards[observationCards.Count - 1];
            nextCursor = new ObservationCursor(lastCard.ObservedDate, lastCard.ObservationId);
        }

        return Ok(new ObservationsPageResponse(observationCards, nextCursor));
    }

    // the breadcrumb, cached: it only changes when the taxonomy changes, which is a new data version
    [HttpPost("path")]
    public async Task<ActionResult<IReadOnlyList<TaxonPathItem>>> Path(
        TaxonPathRequest request,
        CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        CachedResult<IReadOnlyList<TaxonPathItem>> cachedResult = await queryCache.GetOrLoadAsync(
            sessionId.Value,
            TaxonomyViewPermission,
            "taxon-path",
            request.TaxonId.ToString(),
            clientIpAddress,
            (CancellationToken loadCancellationToken) => taxonomyRepository.GetTaxonPathAsync(
                sessionId.Value, request.TaxonId, clientIpAddress, loadCancellationToken),
            cancellationToken);

        if (cachedResult.WasCached)
        {
            Response.Headers["X-Cache"] = "hit";
        }
        else
        {
            Response.Headers["X-Cache"] = "miss";
        }

        return Ok(cachedResult.Value);
    }
}