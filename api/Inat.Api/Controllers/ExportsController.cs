using Inat.Api.Data;
using Inat.Api.Infrastructure;
using Inat.Api.Models;
using Inat.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Inat.Api.Controllers;

[ApiController]
[Route("api/exports")]
[Authorize]
public sealed class ExportsController(
    ExportRepository exportRepository,
    IConfiguration configuration,
    IHostEnvironment environment) : ControllerBase
{
    // queues the export and answers right away with 202; the worker does the slow part
    [HttpPost]
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

        return AcceptedAtAction(nameof(Get), new { id = exportJobId }, ToResponse(exportJob));
    }

    // the UI polls this until Status is Done or Failed
    [HttpGet("{id:int}")]
    public async Task<ActionResult<ExportJobResponse>> Get(int id, CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        ExportJob? exportJob = await exportRepository.GetAsync(sessionId.Value, id, clientIpAddress, cancellationToken);
        if (exportJob is null)
        {
            return NotFound();
        }

        return Ok(ToResponse(exportJob));
    }

    // the finished file. only the user who asked for it gets it: spExport_Get filters on the user
    [HttpGet("{id:int}/file")]
    public async Task<IActionResult> File(int id, CancellationToken cancellationToken)
    {
        long? sessionId = TokenService.GetSessionId(User);
        if (sessionId is null)
        {
            return Unauthorized();
        }

        string? clientIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();

        ExportJob? exportJob = await exportRepository.GetAsync(sessionId.Value, id, clientIpAddress, cancellationToken);
        if (exportJob is null)
        {
            return NotFound();
        }

        if (exportJob.Status != "Done" || string.IsNullOrEmpty(exportJob.FileName))
        {
            return Conflict(new { title = "The export is not finished", status = exportJob.Status });
        }

        string path = Path.Combine(ExportSettings.GetFolder(configuration, environment), exportJob.FileName);
        if (System.IO.File.Exists(path) == false)
        {
            return NotFound();
        }

        string downloadName = $"observations-taxon-{exportJob.TaxonId}-export-{exportJob.Id}.csv";
        return PhysicalFile(path, "text/csv", downloadName);
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