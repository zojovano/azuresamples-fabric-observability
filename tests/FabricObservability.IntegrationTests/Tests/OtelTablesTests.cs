using FabricObservability.IntegrationTests.Infrastructure;
using FabricObservability.IntegrationTests.Models;
using FluentAssertions;
using Newtonsoft.Json.Linq;
using Xunit;
using Xunit.Abstractions;

namespace FabricObservability.IntegrationTests.Tests;

public class OtelTablesTests
{
    private readonly ITestOutputHelper _output;
    private readonly TestConfiguration _testConfig;
    private readonly FabricConfiguration _fabricConfig;
    private readonly string[] _expectedTables;

    public OtelTablesTests(ITestOutputHelper output)
    {
        _output = output;
        _testConfig = ConfigurationHelper.GetTestConfiguration();
        _fabricConfig = ConfigurationHelper.GetFabricConfiguration();
        _expectedTables = ConfigurationHelper.GetExpectedTables();
    }

    [Theory]
    [InlineData("OtelLogs")]
    [InlineData("OtelMetrics")]
    [InlineData("OtelTraces")]
    public async Task OtelTable_Should_Exist(string tableName)
    {
        // Act
        var result = await ExecuteKqlQuery($".show table {tableName}");

        // Assert
        result.Success.Should().BeTrue($"Table '{tableName}' should exist and be accessible");
        result.Output.Should().Contain(tableName, $"Query result should contain table name '{tableName}'");
        
        _output.WriteLine($"Table {tableName} details: {result.Output}");
    }

    [Theory]
    [InlineData("OtelLogs")]
    [InlineData("OtelMetrics")]
    [InlineData("OtelTraces")]
    public async Task OtelTable_Should_HaveCorrectSchema(string tableName)
    {
        // Act
        var result = await ExecuteKqlQuery($".show table {tableName} schema");

        // Assert
        result.Success.Should().BeTrue($"Should be able to retrieve schema for table '{tableName}'");
        result.Output.Should().NotBeNullOrWhiteSpace("Schema information should be returned");

        // Verify common OTEL columns exist
        var expectedColumns = GetExpectedColumnsForTable(tableName);
        foreach (var column in expectedColumns)
        {
            result.Output.Should().Contain(column, $"Table '{tableName}' should have column '{column}'");
        }
        
        _output.WriteLine($"Table {tableName} schema: {result.Output}");
    }

    [Theory]
    [InlineData("OtelLogs")]
    [InlineData("OtelMetrics")]
    [InlineData("OtelTraces")]
    public async Task OtelTable_Should_BeQueryable(string tableName)
    {
        // Act - Try to query the table (limit to 1 record for performance)
        var result = await ExecuteKqlQuery($"{tableName} | limit 1");

        // Assert
        result.Success.Should().BeTrue($"Table '{tableName}' should be queryable");
        
        _output.WriteLine($"Table {tableName} query test: {result.Output}");
    }

    [Fact]
    public async Task AllExpectedTables_Should_Exist()
    {
        // Arrange
        _expectedTables.Should().NotBeEmpty("Expected tables list should be configured");

        // Act & Assert
        foreach (var tableName in _expectedTables)
        {
            var result = await ExecuteKqlQuery($".show table {tableName}");
            
            result.Success.Should().BeTrue($"Table '{tableName}' should exist");
            result.Output.Should().Contain(tableName, $"Query result should contain table name '{tableName}'");
            
            _output.WriteLine($"Verified table: {tableName}");
        }
    }

    [Fact]
    public async Task OtelTables_Should_AcceptTestData()
    {
        // This test verifies that tables can accept data insertion
        // We'll test with a simple synthetic record for each table type
        
        var tasks = _expectedTables.Select(async tableName =>
        {
            var testQuery = GetTestInsertQuery(tableName);
            if (!string.IsNullOrWhiteSpace(testQuery))
            {
                var result = await ExecuteKqlQuery(testQuery);
                result.Success.Should().BeTrue($"Table '{tableName}' should accept test data insertion");
                _output.WriteLine($"Test data insertion for {tableName}: {(result.Success ? "SUCCESS" : "FAILED")}");
            }
        });

        await Task.WhenAll(tasks);
    }

    private async Task<(bool Success, string Output)> ExecuteKqlQuery(string query)
    {
        var workspaceName = _fabricConfig.WorkspaceName;
        var databaseName = _fabricConfig.DatabaseName;

        // Create a temporary KQL file
        var tempFile = Path.GetTempFileName();
        await File.WriteAllTextAsync(tempFile, query);

        try
        {
            var (success, output) = await ProcessHelper.RunFabricCliAsync(
                $"kqldatabase query --workspace \"{workspaceName}\" --kql-database \"{databaseName}\" --file \"{tempFile}\"");

            return (success, output);
        }
        finally
        {
            if (File.Exists(tempFile))
                File.Delete(tempFile);
        }
    }

    private static string[] GetExpectedColumnsForTable(string tableName)
    {
        return tableName.ToLower() switch
        {
            "otellogs" => new[] { "Timestamp", "TraceID", "SpanID", "SeverityText", "Body" },
            "otelmetrics" => new[] { "Timestamp", "MetricName", "MetricValue", "MetricType" },
            "oteltraces" => new[] { "TraceID", "SpanID", "SpanName", "StartTime", "EndTime" },
            _ => Array.Empty<string>()
        };
    }

    private static string GetTestInsertQuery(string tableName)
    {
        var timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
        
        return tableName.ToLower() switch
        {
            "otellogs" => $".ingest inline into table OtelLogs <| print Timestamp=datetime('{timestamp}'), TraceID='test-trace', SpanID='test-span', SeverityText='INFO', Body='Test log entry'",
            "otelmetrics" => $".ingest inline into table OtelMetrics <| print Timestamp=datetime('{timestamp}'), MetricName='test.metric', MetricValue=1.0, MetricType='gauge'",
            "oteltraces" => $".ingest inline into table OtelTraces <| print TraceID='test-trace', SpanID='test-span', SpanName='test-operation', StartTime=datetime('{timestamp}'), EndTime=datetime('{timestamp}')",
            _ => string.Empty
        };
    }
}
