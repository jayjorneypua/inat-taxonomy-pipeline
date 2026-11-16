using Inat.Api.Data;
using Inat.Api.Infrastructure;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inat.Api.Controllers;

[ApiController]
[Route("api/export")]
[Authorize]
public sealed class ExportsController(
    ExportRepository exportRepository,
    IConfiguration configuration,
    IHostEnvironment environment) : ControllerBase
{
    // queues the export and answers right away with 202; the worker does the slow part
    [HttpPost("create")]
    public async Task<ActionResult<ExportJobResponse>> Create(
        CreateExportRequest request,
        CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        int exportJobId = await exportRepository.CreateAsync(sessionId.Value, request.TaxonId, clientIpAddress, cancellationToken);
        ExportJob? exportJob = await exportRepository.GetAsync(sessionId.Value, exportJobId, clientIpAddress, cancellationToken);
        if (exportJob is null)
        {
            return NotFound();
        }

        return Accepted(ToResponse(exportJob));
    }

    // the UI polls this until Status is Done or Failed
    [HttpPost("status")]
    public async Task<ActionResult<ExportJobResponse>> Status(
        ExportStatusRequest request,
        CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        ExportJob? exportJob = await exportRepository.GetAsync(sessionId.Value, request.ExportId, clientIpAddress, cancellationToken);
        if (exportJob is null)
        {
            return NotFound();
        }

        return Ok(ToResponse(exportJob));
    }

    // the finished file. spExport_GetFile decides if this user may have it; no row means 404
    [HttpPost("file")]
    public async Task<IActionResult> File(
        ExportStatusRequest request,
        CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        ExportFile? exportFile = await exportRepository.GetFileAsync(sessionId.Value, request.ExportId, clientIpAddress, cancellationToken);
        if (exportFile is null)
        {
            return NotFound();
        }

        string path = Path.Combine(ExportSettings.GetFolder(configuration, environment), exportFile.FileName);
        if (System.IO.File.Exists(path) == false)
        {
            return NotFound();
        }

        return PhysicalFile(path, "text/csv", exportFile.DownloadName);
    }

    private static ExportJobResponse ToResponse(ExportJob exportJob)
    {
        return new ExportJobResponse(
            exportJob.Id,
            exportJob.TaxonId,
            exportJob.Status,
            exportJob.RowCount,
            exportJob.ErrorMessage,
            exportJob.CreatedDate,
            exportJob.FinishedDate);
    }
}