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
