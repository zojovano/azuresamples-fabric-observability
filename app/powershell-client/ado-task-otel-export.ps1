# Step 1: Download and install the OpenTelemetry .NET SDK
Write-Output "Downloading OpenTelemetry .NET SDK..."
dotnet new tool-manifest --force
dotnet tool install --version 1.2.0 OpenTelemetry.Exporter.Console

# Step 2: Create a script to read the log file and convert it into OpenTelemetry logs
$logFilePath = ".\testlog.log"
$otelScriptPath = ".\otel_script.cs"

$otelScriptContent = @"
using System;
using System.IO;
using Microsoft.Extensions.Logging;
using OpenTelemetry;
using OpenTelemetry.Logs;

class Program
{
    static void Main(string[] args)
    {
        if (args.Length == 0)
        {
            Console.WriteLine("Please provide the path to the log file.");
            return;
        }

        var logFilePath = args[0];

        if (!File.Exists(logFilePath))
        {
            Console.WriteLine($"Log file not found: {logFilePath}");
            return;
        }

        using var loggerFactory = LoggerFactory.Create(builder =>
        {
            builder.AddOpenTelemetry(options =>
            {
                options.AddConsoleExporter();
            });
        });

        var logger = loggerFactory.CreateLogger<Program>();

        var logLines = File.ReadAllLines(logFilePath);

        foreach (var line in logLines)
        {
            logger.LogInformation(line);
        }
    }
}
"@

# Write the script content to a file
Set-Content -Path $otelScriptPath -Value $otelScriptContent

# Step 3: Create a new .NET console project
Write-Output "Creating .NET console project..."
dotnet new console -o otel_project

# Step 4: Move the script to the project directory
Copy-Item -Path $otelScriptPath -Destination "otel_project/Program.cs" -Force
Copy-Item -Path $logFilePath -Destination "otel_project/testlog.log" -Force

# Step 5: Add OpenTelemetry packages to the project
Write-Output "Adding OpenTelemetry packages to the project..."
cd otel_project
dotnet add package OpenTelemetry --version 1.2.0
dotnet add package OpenTelemetry.Exporter.Console --version 1.2.0
dotnet add package Microsoft.Extensions.Logging --version 5.0.0

# Step 6: Run the script to read the log file and convert it into OpenTelemetry logs
Write-Output "Running telemetry collection script..."
dotnet run -- $logFilePath