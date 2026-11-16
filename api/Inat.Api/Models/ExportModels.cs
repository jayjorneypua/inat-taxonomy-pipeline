namespace Inat.Api.Models;

public sealed record CreateExportRequest(int TaxonId);

public sealed record ExportStatusRequest(int ExportId);

// what the API returns to the browser: no file name, the download goes through the API
public sealed record ExportJobResponse(
    int Id,
    int TaxonId,
    string Status,
    int? RowCount,
    string? ErrorMessage,
    DateTime CreatedDate,
    DateTime? FinishedDate);

// one row of dbo.Export_Job as spExport_Get returns it
public sealed record ExportJob(
    int Id,
    int TaxonId,
    string Status,
    int? RowCount,
    string? FileName,
    string? ErrorMessage,
    DateTime CreatedDate,
    DateTime? FinishedDate);

// the job a worker just claimed
public sealed record ClaimedExport(int ExportJobId, long SessionId, int TaxonId);

// a download the procedure allowed
public sealed record ExportFile(string FileName, string DownloadName);