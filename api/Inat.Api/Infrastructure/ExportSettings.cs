namespace Inat.Api.Infrastructure;

// where export files live and how often the worker looks for jobs.
// what goes into an export, and how many rows, is decided by the procedures.
public static class ExportSettings
{
    public static string GetFolder(IConfiguration configuration, IHostEnvironment environment)
    {
        string? configuredFolder = configuration["Export:Folder"];
        if (string.IsNullOrWhiteSpace(configuredFolder))
        {
            return Path.Combine(environment.ContentRootPath, "exports");
        }

        return configuredFolder;
    }

    public static TimeSpan GetPollInterval(IConfiguration configuration)
    {
        return TimeSpan.FromSeconds(configuration.GetValue<int>("Export:PollSeconds", 2));
    }
}