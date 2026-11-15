using System.Text.Json;
using Inat.Api.Data;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inat.Api.Controllers;

[ApiController]
[Route("api/admin")]
[Authorize]
public sealed class AdminController(AdminRepository adminRepository) : ControllerBase
{
    private const int DefaultPageSize = 25;
    private const int MaximumPageSize = 100;

    // the procedure reads the filters as json with lower case keys: column, operator, value
    private static readonly JsonSerializerOptions filterJsonOptions = new JsonSerializerOptions
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    [HttpPost("users/grid")]
    public async Task<ActionResult<UserGridResponse>> UsersGrid(
        UserGridRequest request,
        CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        int page = 1;
        if (request.Page.HasValue && request.Page.Value > 1)
        {
            page = request.Page.Value;
        }

        int pageSize = DefaultPageSize;
        if (request.PageSize.HasValue)
        {
            pageSize = Math.Clamp(request.PageSize.Value, 1, MaximumPageSize);
        }

        string? search = null;
        if (string.IsNullOrWhiteSpace(request.Search) == false)
        {
            search = request.Search.Trim();
        }

        string? filtersJson = null;
        if (request.Filters != null && request.Filters.Count > 0)
        {
            filtersJson = JsonSerializer.Serialize(request.Filters, filterJsonOptions);
        }

        string sortColumn = "Username";
        if (string.IsNullOrWhiteSpace(request.SortColumn) == false)
        {
            sortColumn = request.SortColumn;
        }

        string sortDirection = "asc";
        if (string.IsNullOrWhiteSpace(request.SortDirection) == false)
        {
            sortDirection = request.SortDirection;
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        UserGridResponse response = await adminRepository.GetUsersGridAsync(
            sessionId.Value,
            page,
            pageSize,
            search,
            filtersJson,
            sortColumn,
            sortDirection,
            clientIpAddress,
            cancellationToken);

        return Ok(response);
    }
}