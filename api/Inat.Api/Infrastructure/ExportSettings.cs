namespace Inat.Api.Infrastructure;

// export settings in one place, so the worker and the controller agree on the folder
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

    public static int GetMaxRows(IConfiguration configuration)
    {
        return configuration.GetValue<int>("Export:MaxRows", 100000);
    }

    public static TimeSpan GetPollInterval(IConfiguration configuration)
    {
        return TimeSpan.FromSeconds(configuration.GetValue<int>("Export:PollSeconds", 2));
    }
}