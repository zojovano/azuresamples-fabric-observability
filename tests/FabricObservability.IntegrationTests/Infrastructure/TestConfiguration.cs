using Microsoft.Extensions.Configuration;
using System.Diagnostics;

namespace FabricObservability.IntegrationTests.Infrastructure;

public class TestConfiguration
{
    public string ResourceGroupName { get; set; } = string.Empty;
    public int DataCount { get; set; } = 50;
    public int DelayBetweenBatches { get; set; } = 2;
    public int PerformanceThresholdMs { get; set; } = 5000;
    public int TestTimeoutMinutes { get; set; } = 10;
    public int IngestionWaitTimeMinutes { get; set; } = 5;
}

public class FabricConfiguration
{
    public string WorkspaceName { get; set; } = string.Empty;
    public string DatabaseName { get; set; } = string.Empty;
}

public static class ConfigurationHelper
{
    private static IConfiguration? _configuration;

    public static IConfiguration Configuration
    {
        get
        {
            if (_configuration == null)
            {
                var builder = new ConfigurationBuilder()
                    .SetBasePath(Directory.GetCurrentDirectory())
                    .AddJsonFile("appsettings.json", optional: false)
                    .AddJsonFile("appsettings.Development.json", optional: true)
                    .AddEnvironmentVariables();

                _configuration = builder.Build();
            }
            return _configuration;
        }
    }

    public static TestConfiguration GetTestConfiguration()
    {
        var config = new TestConfiguration();
        Configuration.GetSection("TestConfiguration").Bind(config);
        
        // Override with environment variables if present
        config.ResourceGroupName = Environment.GetEnvironmentVariable("RESOURCE_GROUP_NAME") ?? config.ResourceGroupName;
        
        if (int.TryParse(Environment.GetEnvironmentVariable("DATA_COUNT"), out int dataCount))
            config.DataCount = dataCount;
            
        if (int.TryParse(Environment.GetEnvironmentVariable("PERFORMANCE_THRESHOLD_MS"), out int threshold))
            config.PerformanceThresholdMs = threshold;

        return config;
    }

    public static FabricConfiguration GetFabricConfiguration()
    {
        var config = new FabricConfiguration();
        Configuration.GetSection("FabricConfiguration").Bind(config);
        return config;
    }

    public static string[] GetExpectedTables()
    {
        return Configuration.GetSection("ExpectedTables").Get<string[]>() ?? Array.Empty<string>();
    }
}

public static class ProcessHelper
{
    public static async Task<(bool Success, string Output, string Error)> RunCommandAsync(
        string command, 
        string arguments, 
        int timeoutSeconds = 300)
    {
        using var process = new Process();
        process.StartInfo = new ProcessStartInfo
        {
            FileName = command,
            Arguments = arguments,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        var outputBuilder = new System.Text.StringBuilder();
        var errorBuilder = new System.Text.StringBuilder();

        process.OutputDataReceived += (sender, e) =>
        {
            if (e.Data != null)
                outputBuilder.AppendLine(e.Data);
        };

        process.ErrorDataReceived += (sender, e) =>
        {
            if (e.Data != null)
                errorBuilder.AppendLine(e.Data);
        };

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        var completed = await Task.Run(() => process.WaitForExit(timeoutSeconds * 1000));

        if (!completed)
        {
            process.Kill();
            return (false, string.Empty, "Process timed out");
        }

        return (process.ExitCode == 0, outputBuilder.ToString(), errorBuilder.ToString());
    }

    public static async Task<(bool Success, string Output)> RunAzureCliAsync(string arguments)
    {
        var (success, output, error) = await RunCommandAsync("az", arguments);
        return (success, success ? output : error);
    }

    public static async Task<(bool Success, string Output)> RunFabricCliAsync(string arguments)
    {
        var (success, output, error) = await RunCommandAsync("fabric", arguments);
        return (success, success ? output : error);
    }
}
