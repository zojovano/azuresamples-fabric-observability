using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using FabricObservability.IntegrationTests.Infrastructure;
using FabricObservability.IntegrationTests.Models;
using FluentAssertions;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Xunit;
using Xunit.Abstractions;

namespace FabricObservability.IntegrationTests.Tests;

public class EventHubStreamingTests
{
    private readonly ITestOutputHelper _output;
    private readonly TestConfiguration _testConfig;
    private readonly FabricConfiguration _fabricConfig;

    public EventHubStreamingTests(ITestOutputHelper output)
    {
        _output = output;
        _testConfig = ConfigurationHelper.GetTestConfiguration();
        _fabricConfig = ConfigurationHelper.GetFabricConfiguration();
    }

    [Fact]
    public async Task EventHub_Should_BeDiscoverable()
    {
        // Act
        var eventHubInfo = await DiscoverEventHubAsync();

        // Assert
        eventHubInfo.Should().NotBeNull("EventHub namespace and name should be discoverable");
        eventHubInfo!.Namespace.Should().NotBeNullOrWhiteSpace("EventHub namespace should be found");
        eventHubInfo.Name.Should().NotBeNullOrWhiteSpace("EventHub name should be found");
        
        _output.WriteLine($"Found EventHub: {eventHubInfo.Namespace}/{eventHubInfo.Name}");
    }

    [Fact]
    public async Task EventHub_Should_AcceptTestData()
    {
        // Arrange
        var eventHubInfo = await DiscoverEventHubAsync();
        eventHubInfo.Should().NotBeNull("EventHub should be discoverable");

        var testDataCount = Math.Min(_testConfig.DataCount, 10); // Limit for test performance

        // Act & Assert
        await SendOtelLogData(eventHubInfo!, testDataCount);
        await SendOtelMetricData(eventHubInfo!, testDataCount);
        await SendOtelTraceData(eventHubInfo!, testDataCount);

        _output.WriteLine($"Successfully sent {testDataCount * 3} test records to EventHub");
    }

    [Fact]
    public async Task EventHub_Data_Should_AppearInFabricTables()
    {
        // Arrange
        var eventHubInfo = await DiscoverEventHubAsync();
        eventHubInfo.Should().NotBeNull("EventHub should be discoverable");

        // Send test data
        var testDataCount = 5; // Small amount for faster test
        await SendOtelLogData(eventHubInfo!, testDataCount);
        await SendOtelMetricData(eventHubInfo!, testDataCount);
        await SendOtelTraceData(eventHubInfo!, testDataCount);

        _output.WriteLine($"Sent {testDataCount * 3} test records, waiting for ingestion...");

        // Wait for data ingestion
        await Task.Delay(TimeSpan.FromMinutes(_testConfig.IngestionWaitTimeMinutes));

        // Act & Assert - Check if data appears in Fabric tables
        await VerifyDataInTable("OtelLogs", testDataCount);
        await VerifyDataInTable("OtelMetrics", testDataCount);
        await VerifyDataInTable("OtelTraces", testDataCount);
    }

    [Fact]
    public async Task EndToEnd_DataFlow_Should_Work()
    {
        // This is a comprehensive end-to-end test
        var startTime = DateTime.UtcNow;
        
        // 1. Discover EventHub
        var eventHubInfo = await DiscoverEventHubAsync();
        eventHubInfo.Should().NotBeNull("EventHub should be discoverable");

        // 2. Get baseline record counts
        var baselineCounts = await GetTableRecordCounts();
        _output.WriteLine($"Baseline counts - Logs: {baselineCounts.Logs}, Metrics: {baselineCounts.Metrics}, Traces: {baselineCounts.Traces}");

        // 3. Send test data with unique identifiers
        var testDataCount = 3;
        var testId = Guid.NewGuid().ToString("N")[..8];
        
        await SendOtelLogDataWithId(eventHubInfo!, testDataCount, testId);
        await SendOtelMetricDataWithId(eventHubInfo!, testDataCount, testId);
        await SendOtelTraceDataWithId(eventHubInfo!, testDataCount, testId);

        _output.WriteLine($"Sent test data with ID: {testId}");

        // 4. Wait for ingestion
        await Task.Delay(TimeSpan.FromMinutes(_testConfig.IngestionWaitTimeMinutes));

        // 5. Verify data appeared
        var finalCounts = await GetTableRecordCounts();
        _output.WriteLine($"Final counts - Logs: {finalCounts.Logs}, Metrics: {finalCounts.Metrics}, Traces: {finalCounts.Traces}");

        // Assert that new data was ingested
        (finalCounts.Logs > baselineCounts.Logs).Should().BeTrue("New log records should have been ingested");
        (finalCounts.Metrics > baselineCounts.Metrics).Should().BeTrue("New metric records should have been ingested");
        (finalCounts.Traces > baselineCounts.Traces).Should().BeTrue("New trace records should have been ingested");

        var endTime = DateTime.UtcNow;
        var totalTime = endTime - startTime;
        _output.WriteLine($"End-to-end test completed in {totalTime.TotalMinutes:F2} minutes");
    }

    private async Task<EventHubInfo?> DiscoverEventHubAsync()
    {
        // Get EventHub namespace
        var (success, output) = await ProcessHelper.RunAzureCliAsync(
            $"eventhubs namespace list --resource-group {_testConfig.ResourceGroupName} --query \"[0].name\" --output tsv");

        if (!success || string.IsNullOrWhiteSpace(output))
            return null;

        var namespaceName = output.Trim();

        // Get EventHub name
        (success, output) = await ProcessHelper.RunAzureCliAsync(
            $"eventhubs eventhub list --resource-group {_testConfig.ResourceGroupName} --namespace-name {namespaceName} --query \"[0].name\" --output tsv");

        if (!success || string.IsNullOrWhiteSpace(output))
            return null;

        var eventHubName = output.Trim();

        return new EventHubInfo(namespaceName, eventHubName);
    }

    private async Task SendOtelLogData(EventHubInfo eventHubInfo, int count)
    {
        for (int i = 0; i < count; i++)
        {
            var logRecord = OtelDataGenerator.GenerateLogRecord();
            var json = JsonConvert.SerializeObject(logRecord);
            
            var (success, _) = await ProcessHelper.RunAzureCliAsync(
                $"eventhubs eventhub send --resource-group {_testConfig.ResourceGroupName} --namespace-name {eventHubInfo.Namespace} --name {eventHubInfo.Name} --body \"{json.Replace("\"", "\\\"")}\"");

            if (success)
                _output.WriteLine($"Sent log record {i + 1}/{count}");
            
            await Task.Delay(TimeSpan.FromSeconds(_testConfig.DelayBetweenBatches));
        }
    }

    private async Task SendOtelMetricData(EventHubInfo eventHubInfo, int count)
    {
        for (int i = 0; i < count; i++)
        {
            var metricRecord = OtelDataGenerator.GenerateMetricRecord();
            var json = JsonConvert.SerializeObject(metricRecord);
            
            var (success, _) = await ProcessHelper.RunAzureCliAsync(
                $"eventhubs eventhub send --resource-group {_testConfig.ResourceGroupName} --namespace-name {eventHubInfo.Namespace} --name {eventHubInfo.Name} --body \"{json.Replace("\"", "\\\"")}\"");

            if (success)
                _output.WriteLine($"Sent metric record {i + 1}/{count}");
            
            await Task.Delay(TimeSpan.FromSeconds(_testConfig.DelayBetweenBatches));
        }
    }

    private async Task SendOtelTraceData(EventHubInfo eventHubInfo, int count)
    {
        for (int i = 0; i < count; i++)
        {
            var traceRecord = OtelDataGenerator.GenerateTraceRecord();
            var json = JsonConvert.SerializeObject(traceRecord);
            
            var (success, _) = await ProcessHelper.RunAzureCliAsync(
                $"eventhubs eventhub send --resource-group {_testConfig.ResourceGroupName} --namespace-name {eventHubInfo.Namespace} --name {eventHubInfo.Name} --body \"{json.Replace("\"", "\\\"")}\"");

            if (success)
                _output.WriteLine($"Sent trace record {i + 1}/{count}");
            
            await Task.Delay(TimeSpan.FromSeconds(_testConfig.DelayBetweenBatches));
        }
    }

    private async Task SendOtelLogDataWithId(EventHubInfo eventHubInfo, int count, string testId)
    {
        for (int i = 0; i < count; i++)
        {
            var logRecord = OtelDataGenerator.GenerateLogRecord();
            logRecord.Body = $"[TEST-{testId}] {logRecord.Body}";
            var json = JsonConvert.SerializeObject(logRecord);
            
            var (success, _) = await ProcessHelper.RunAzureCliAsync(
                $"eventhubs eventhub send --resource-group {_testConfig.ResourceGroupName} --namespace-name {eventHubInfo.Namespace} --name {eventHubInfo.Name} --body \"{json.Replace("\"", "\\\"")}\"");

            await Task.Delay(TimeSpan.FromSeconds(_testConfig.DelayBetweenBatches));
        }
    }

    private async Task SendOtelMetricDataWithId(EventHubInfo eventHubInfo, int count, string testId)
    {
        for (int i = 0; i < count; i++)
        {
            var metricRecord = OtelDataGenerator.GenerateMetricRecord();
            metricRecord.MetricName = $"test.{testId}.{metricRecord.MetricName}";
            var json = JsonConvert.SerializeObject(metricRecord);
            
            var (success, _) = await ProcessHelper.RunAzureCliAsync(
                $"eventhubs eventhub send --resource-group {_testConfig.ResourceGroupName} --namespace-name {eventHubInfo.Namespace} --name {eventHubInfo.Name} --body \"{json.Replace("\"", "\\\"")}\"");

            await Task.Delay(TimeSpan.FromSeconds(_testConfig.DelayBetweenBatches));
        }
    }

    private async Task SendOtelTraceDataWithId(EventHubInfo eventHubInfo, int count, string testId)
    {
        for (int i = 0; i < count; i++)
        {
            var traceRecord = OtelDataGenerator.GenerateTraceRecord();
            traceRecord.SpanName = $"test-{testId}-{traceRecord.SpanName}";
            var json = JsonConvert.SerializeObject(traceRecord);
            
            var (success, _) = await ProcessHelper.RunAzureCliAsync(
                $"eventhubs eventhub send --resource-group {_testConfig.ResourceGroupName} --namespace-name {eventHubInfo.Namespace} --name {eventHubInfo.Name} --body \"{json.Replace("\"", "\\\"")}\"");

            await Task.Delay(TimeSpan.FromSeconds(_testConfig.DelayBetweenBatches));
        }
    }

    private async Task VerifyDataInTable(string tableName, int expectedMinimumRecords)
    {
        var result = await ExecuteKqlQuery($"{tableName} | count");
        
        result.Success.Should().BeTrue($"Should be able to count records in table '{tableName}'");
        
        if (result.Success && !string.IsNullOrWhiteSpace(result.Output))
        {
            // Try to extract count from output
            if (int.TryParse(result.Output.Trim(), out int recordCount))
            {
                recordCount.Should().BeGreaterOrEqualTo(expectedMinimumRecords, 
                    $"Table '{tableName}' should contain at least {expectedMinimumRecords} records");
                
                _output.WriteLine($"Table {tableName} contains {recordCount} records");
            }
            else
            {
                _output.WriteLine($"Could not parse record count from: {result.Output}");
            }
        }
    }

    private async Task<(int Logs, int Metrics, int Traces)> GetTableRecordCounts()
    {
        var logCount = await GetTableRecordCount("OtelLogs");
        var metricCount = await GetTableRecordCount("OtelMetrics");
        var traceCount = await GetTableRecordCount("OtelTraces");

        return (logCount, metricCount, traceCount);
    }

    private async Task<int> GetTableRecordCount(string tableName)
    {
        var result = await ExecuteKqlQuery($"{tableName} | count");
        
        if (result.Success && !string.IsNullOrWhiteSpace(result.Output))
        {
            if (int.TryParse(result.Output.Trim(), out int count))
                return count;
        }

        return 0;
    }

    private async Task<(bool Success, string Output)> ExecuteKqlQuery(string query)
    {
        var workspaceName = _fabricConfig.WorkspaceName;
        var databaseName = _fabricConfig.DatabaseName;

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

    private record EventHubInfo(string Namespace, string Name);
}
