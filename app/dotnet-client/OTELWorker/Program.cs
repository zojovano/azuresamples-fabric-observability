using OpenTelemetry.Resources;
using OpenTelemetry.Exporter;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using System.Reflection.PortableExecutable;

namespace OTELWorker;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = Host.CreateApplicationBuilder(args);
        builder.Services.AddHostedService<Worker>();

        builder.Logging.ClearProviders();

        // Initialize OpenTelemetry
        builder.Services.AddOpenTelemetry().ConfigureResource((resourceBuilder) =>
        {
        resourceBuilder.AddService(
            serviceName: builder.Configuration.GetValue("ServiceName", defaultValue: "otel-test")!,
            serviceVersion: typeof(Program).Assembly.GetName().Version?.ToString() ?? "unknown",
            serviceInstanceId: Environment.MachineName);
        });

        var host = builder.Build();
        host.Run();
    }
}
