using OpenTelemetry.Resources;
using OpenTelemetry.Exporter;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;
using OpenTelemetry.Exporter;
using System.Reflection.PortableExecutable;
using Microsoft.Extensions.Options;

namespace OTELWorker;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = Host.CreateApplicationBuilder(args);
        builder.Services.AddHostedService<Worker>();

        builder.Logging.ClearProviders();

        // Initialize OpenTelemetry
        builder.Services.AddOpenTelemetry()
            .ConfigureResource((resourceBuilder) =>
            {
                resourceBuilder.AddService(
                serviceName: builder.Configuration.GetValue("ServiceName", defaultValue: "otel-test")!,
                serviceVersion: typeof(Program).Assembly.GetName().Version?.ToString() ?? "unknown",
                serviceInstanceId: Environment.MachineName);
            });

        
        // Add OpenTelemetry logging
        builder.Logging.AddOpenTelemetry(options =>
        {
            options.IncludeFormattedMessage = true;
            options.IncludeScopes = true;
            options.ParseStateValues = true;
            //options.AddConsoleExporter();
            options.AddOtlpExporter(otlpOptions =>
            {
                // Use IConfiguration directly for Otlp exporter endpoint option.
                otlpOptions.Endpoint = new Uri("http://localhost:4317");
            });
        });
        var host = builder.Build();
        host.Run();
    }
}
