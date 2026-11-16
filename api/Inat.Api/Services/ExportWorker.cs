using System.Text;
using Inat.Api.Data;
using Inat.Api.Infrastructure;
using Inat.Api.Models;

namespace Inat.Api.Services;

// runs in every api instance. each loop claims at most one job; spExport_Claim makes sure two
// instances never take the same one. a job interrupted by a shutdown stays Running and is taken
// again after 10 minutes.
public sealed class ExportWorker(
    IServiceScopeFactory scopeFactory,
    IConfiguration configuration,
    IHostEnvironment environment,
    ILogger<ExportWorker> logger) : BackgroundService
{
    private readonly string _folder = ExportSettings.GetFolder(configuration, environment);
    private readonly TimeSpan _pollInterval = ExportSettings.GetPollInterval(configuration);
    private readonly string _instanceName = configuration["Instance:Name"] ?? $"{Environment.MachineName}-{Environment.ProcessId}";

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        Directory.CreateDirectory(_folder);
        logger.LogInformation("Export worker started on {InstanceName}, folder {Folder}", _instanceName, _folder);

        while (stoppingToken.IsCancellationRequested == false)
        {
            bool didWork = false;

            try
            {
                using IServiceScope scope = scopeFactory.CreateScope();
                ExportRepository exportRepository = scope.ServiceProvider.GetRequiredService<ExportRepository>();

                ClaimedExport? job = await exportRepository.ClaimAsync(_instanceName, stoppingToken);
                if (job is not null)
                {
                    didWork = true;
                    await ProcessJobAsync(exportRepository, job, stoppingToken);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                // for example sql server is down: log it, wait, try again
                logger.LogError(ex, "Export worker loop failed");
            }

            // after a job, look for the next one right away; when idle, wait
            if (didWork == false)
            {
                try
                {
                    await Task.Delay(_pollInterval, stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }
    }

    private async Task ProcessJobAsync(ExportRepository exportRepository, ClaimedExport job, CancellationToken stoppingToken)
    {
        string fileName = $"export-{job.ExportJobId}.csv";
        string finalPath = Path.Combine(_folder, fileName);
        string tempPath = finalPath + ".tmp";

        logger.LogInformation("Export {ExportJobId} started for taxon {TaxonId}", job.ExportJobId, job.TaxonId);

        try
        {
            int rowCount;

            // utf-8 with a byte order mark, so excel shows names with accents correctly
            await using (FileStream stream = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                await using (StreamWriter writer = new StreamWriter(stream, new UTF8Encoding(true)))
                {
                    rowCount = await exportRepository.WriteRowsAsync(job.ExportJobId, writer, stoppingToken);
                }
            }

            // the file only gets its real name once complete, so a download never sees half a file
            File.Move(tempPath, finalPath, true);

            await exportRepository.FinishAsync(job.ExportJobId, _instanceName, "Done", rowCount, fileName, stoppingToken);
            logger.LogInformation("Export {ExportJobId} done, {RowCount} rows", job.ExportJobId, rowCount);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            DeleteIfExists(tempPath);
            throw;
        }
        catch (Exception ex)
        {
            DeleteIfExists(tempPath);
            logger.LogError(ex, "Export {ExportJobId} failed", job.ExportJobId);

            // spExport_Finish writes the message the user sees
            await exportRepository.FinishAsync(job.ExportJobId, _instanceName, "Failed", null, null, CancellationToken.None);
        }
    }

    private static void DeleteIfExists(string path)
    {
        if (File.Exists(path))
        {
            File.Delete(path);
        }
    }
}