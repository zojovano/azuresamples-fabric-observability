using Newtonsoft.Json;

namespace FabricObservability.IntegrationTests.Models;

public class OtelLogRecord
{
    public DateTime Timestamp { get; set; }
    public DateTime ObservedTimestamp { get; set; }
    public string TraceID { get; set; } = string.Empty;
    public string SpanID { get; set; } = string.Empty;
    public string SeverityText { get; set; } = string.Empty;
    public int SeverityNumber { get; set; }
    public string Body { get; set; } = string.Empty;
    public Dictionary<string, object> ResourceAttributes { get; set; } = new();
    public Dictionary<string, object> LogsAttributes { get; set; } = new();
}

public class OtelMetricRecord
{
    public DateTime Timestamp { get; set; }
    public string MetricName { get; set; } = string.Empty;
    public string MetricType { get; set; } = string.Empty;
    public string MetricUnit { get; set; } = string.Empty;
    public string MetricDescription { get; set; } = string.Empty;
    public double MetricValue { get; set; }
    public string Host { get; set; } = string.Empty;
    public Dictionary<string, object> ResourceAttributes { get; set; } = new();
    public Dictionary<string, object> MetricAttributes { get; set; } = new();
}

public class OtelTraceRecord
{
    public string TraceID { get; set; } = string.Empty;
    public string SpanID { get; set; } = string.Empty;
    public string ParentID { get; set; } = string.Empty;
    public string SpanName { get; set; } = string.Empty;
    public string SpanStatus { get; set; } = string.Empty;
    public string SpanKind { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public Dictionary<string, object> ResourceAttributes { get; set; } = new();
    public Dictionary<string, object> TraceAttributes { get; set; } = new();
    public List<object> Events { get; set; } = new();
    public List<object> Links { get; set; } = new();
}

public static class OtelDataGenerator
{
    private static readonly Random _random = new();
    
    private static readonly string[] ServiceNames = 
    {
        "user-service", "order-service", "payment-service", 
        "inventory-service", "notification-service", "analytics-service",
        "auth-service", "cart-service"
    };

    private static readonly string[] OperationNames =
    {
        "create_user", "process_payment", "update_inventory",
        "send_notification", "authenticate", "add_to_cart",
        "place_order", "generate_report"
    };

    private static readonly string[] HostNames =
    {
        "web-01", "web-02", "api-01", "api-02", "worker-01", "worker-02"
    };

    private static readonly (string Text, int Number)[] LogLevels =
    {
        ("INFO", 1), ("WARN", 3), ("ERROR", 4), ("DEBUG", 2)
    };

    public static string GenerateTraceId() => Guid.NewGuid().ToString("N");
    public static string GenerateSpanId() => Guid.NewGuid().ToString("N")[..16];

    public static OtelLogRecord GenerateLogRecord()
    {
        var timestamp = DateTime.UtcNow;
        var serviceName = ServiceNames[_random.Next(ServiceNames.Length)];
        var operation = OperationNames[_random.Next(OperationNames.Length)];
        var hostName = HostNames[_random.Next(HostNames.Length)];
        var logLevel = LogLevels[_random.Next(LogLevels.Length)];
        var userId = _random.Next(1, 1001);

        var messages = new[]
        {
            $"User {userId} successfully executed {operation}",
            $"Processing {operation} for user {userId} completed",
            $"Started {operation} workflow for user {userId}",
            $"Completed {operation} with response time 150ms",
            $"Cache hit for {operation} operation",
            $"Database query for {operation} took 45ms",
            $"Rate limiting applied for user {userId}",
            $"Authentication successful for user {userId}"
        };

        return new OtelLogRecord
        {
            Timestamp = timestamp,
            ObservedTimestamp = timestamp,
            TraceID = GenerateTraceId(),
            SpanID = GenerateSpanId(),
            SeverityText = logLevel.Text,
            SeverityNumber = logLevel.Number,
            Body = messages[_random.Next(messages.Length)],
            ResourceAttributes = new Dictionary<string, object>
            {
                ["service.name"] = serviceName,
                ["service.version"] = "1.0.0",
                ["service.environment"] = "production",
                ["host.name"] = hostName
            },
            LogsAttributes = new Dictionary<string, object>
            {
                ["user.id"] = userId,
                ["operation"] = operation,
                ["source"] = "application-logs"
            }
        };
    }

    public static OtelMetricRecord GenerateMetricRecord()
    {
        var metrics = new[]
        {
            ("cpu.usage.percent", "gauge", "percent", "CPU usage percentage"),
            ("memory.usage.bytes", "gauge", "bytes", "Memory usage in bytes"),
            ("request.duration.ms", "histogram", "milliseconds", "Request duration"),
            ("request.count", "counter", "count", "Number of requests"),
            ("error.count", "counter", "count", "Number of errors"),
            ("cache.hit.ratio", "gauge", "ratio", "Cache hit ratio"),
            ("database.connections", "gauge", "count", "Active database connections"),
            ("queue.size", "gauge", "count", "Queue size")
        };

        var metric = metrics[_random.Next(metrics.Length)];
        var serviceName = ServiceNames[_random.Next(ServiceNames.Length)];
        var hostName = HostNames[_random.Next(HostNames.Length)];

        var metricValue = metric.Item1 switch
        {
            "cpu.usage.percent" => Math.Round(_random.NextDouble() * 100, 2),
            "memory.usage.bytes" => _random.NextInt64(1_000_000_000, 8_000_000_000),
            "request.duration.ms" => Math.Round(_random.NextDouble() * 500 + 10, 2),
            "cache.hit.ratio" => Math.Round(_random.NextDouble(), 3),
            _ => _random.Next(1, 1001)
        };

        return new OtelMetricRecord
        {
            Timestamp = DateTime.UtcNow,
            MetricName = metric.Item1,
            MetricType = metric.Item2,
            MetricUnit = metric.Item3,
            MetricDescription = metric.Item4,
            MetricValue = metricValue,
            Host = hostName,
            ResourceAttributes = new Dictionary<string, object>
            {
                ["service.name"] = serviceName,
                ["service.version"] = "1.0.0",
                ["host.name"] = hostName
            },
            MetricAttributes = new Dictionary<string, object>
            {
                ["environment"] = "production",
                ["datacenter"] = "us-east-1"
            }
        };
    }

    public static OtelTraceRecord GenerateTraceRecord()
    {
        var traceId = GenerateTraceId();
        var spanId = GenerateSpanId();
        var parentId = _random.Next(0, 3) == 0 ? GenerateSpanId() : string.Empty;
        var serviceName = ServiceNames[_random.Next(ServiceNames.Length)];
        var operation = OperationNames[_random.Next(OperationNames.Length)];
        var startTime = DateTime.UtcNow;
        var endTime = startTime.AddMilliseconds(_random.Next(10, 500));

        var spanKinds = new[] { "INTERNAL", "SERVER", "CLIENT", "PRODUCER", "CONSUMER" };
        var spanStatuses = new[] { "OK", "ERROR", "TIMEOUT" };

        return new OtelTraceRecord
        {
            TraceID = traceId,
            SpanID = spanId,
            ParentID = parentId,
            SpanName = operation,
            SpanStatus = spanStatuses[_random.Next(spanStatuses.Length)],
            SpanKind = spanKinds[_random.Next(spanKinds.Length)],
            StartTime = startTime,
            EndTime = endTime,
            ResourceAttributes = new Dictionary<string, object>
            {
                ["service.name"] = serviceName,
                ["service.version"] = "1.0.0",
                ["telemetry.sdk.name"] = "opentelemetry",
                ["telemetry.sdk.version"] = "1.0.0"
            },
            TraceAttributes = new Dictionary<string, object>
            {
                ["http.method"] = "POST",
                ["http.status_code"] = _random.Next(200, 300),
                ["user.id"] = _random.Next(1, 1001)
            }
        };
    }
}
