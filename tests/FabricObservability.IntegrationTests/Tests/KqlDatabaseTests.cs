using FabricObservability.IntegrationTests.Infrastructure;
using FluentAssertions;
using Newtonsoft.Json.Linq;
using Xunit;
using Xunit.Abstractions;

namespace FabricObservability.IntegrationTests.Tests;

public class KqlDatabaseTests
{
    private readonly ITestOutputHelper _output;
    private readonly TestConfiguration _testConfig;
    private readonly FabricConfiguration _fabricConfig;

    public KqlDatabaseTests(ITestOutputHelper output)
    {
        _output = output;
        _testConfig = ConfigurationHelper.GetTestConfiguration();
        _fabricConfig = ConfigurationHelper.GetFabricConfiguration();
    }

    [Fact]
    public async Task KqlDatabase_Should_Exist()
    {
        // Arrange
        var workspaceName = _fabricConfig.WorkspaceName;
        var databaseName = _fabricConfig.DatabaseName;

        // Act
        var (success, output) = await ProcessHelper.RunFabricCliAsync(
            $"kqldatabase list --workspace \"{workspaceName}\"");

        // Assert
        success.Should().BeTrue("Should be able to list KQL databases");
        
        if (success && !string.IsNullOrWhiteSpace(output))
        {
            try
            {
                var databases = JArray.Parse(output);
                var database = databases.FirstOrDefault(db => 
                    db["displayName"]?.ToString()?.Equals(databaseName, StringComparison.OrdinalIgnoreCase) == true);
                
                database.Should().NotBeNull($"KQL database '{databaseName}' should exist");
                
                _output.WriteLine($"Found database: {database}");
            }
            catch (Exception ex)
            {
                _output.WriteLine($"Failed to parse database list: {ex.Message}");
                _output.WriteLine($"Raw output: {output}");
                
                // Fallback to string search
                output.Should().Contain(databaseName, $"Database '{databaseName}' should be in the list");
            }
        }
        else
        {
            success.Should().BeTrue("Failed to list KQL databases");
        }
    }

    [Fact]
    public async Task KqlDatabase_Should_BeAccessible()
    {
        // Arrange
        var workspaceName = _fabricConfig.WorkspaceName;
        var databaseName = _fabricConfig.DatabaseName;

        // Act - Try to show database details
        var (success, output) = await ProcessHelper.RunFabricCliAsync(
            $"kqldatabase show --workspace \"{workspaceName}\" --kql-database \"{databaseName}\"");

        // Assert
        if (success)
        {
            output.Should().Contain(databaseName, "Database details should contain the database name");
            _output.WriteLine($"Database details: {output}");
        }
        else
        {
            // Alternative approach - try a simple query to test connectivity
            var queryResult = await ExecuteKqlQuery("print 'connectivity_test'");
            queryResult.Success.Should().BeTrue("Should be able to execute simple query against database");
            
            _output.WriteLine($"Connectivity test result: {queryResult.Output}");
        }
    }

    [Fact]
    public async Task KqlDatabase_Should_SupportBasicQueries()
    {
        // Act
        var result = await ExecuteKqlQuery("print datetime_utc_now()");

        // Assert
        result.Success.Should().BeTrue("Should be able to execute basic KQL queries");
        result.Output.Should().NotBeNullOrWhiteSpace("Query should return results");
        
        _output.WriteLine($"Query result: {result.Output}");
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
}
