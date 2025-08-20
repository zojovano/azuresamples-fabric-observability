using FabricObservability.IntegrationTests.Infrastructure;
using FluentAssertions;
using Newtonsoft.Json.Linq;
using Xunit;
using Xunit.Abstractions;

namespace FabricObservability.IntegrationTests.Tests;

public class FabricWorkspaceTests
{
    private readonly ITestOutputHelper _output;
    private readonly TestConfiguration _testConfig;
    private readonly FabricConfiguration _fabricConfig;

    public FabricWorkspaceTests(ITestOutputHelper output)
    {
        _output = output;
        _testConfig = ConfigurationHelper.GetTestConfiguration();
        _fabricConfig = ConfigurationHelper.GetFabricConfiguration();
    }

    [Fact]
    public async Task FabricCli_Should_BeAuthenticated()
    {
        // Act
        var (success, output) = await ProcessHelper.RunFabricCliAsync("workspace list");

        // Assert
        success.Should().BeTrue("Fabric CLI should be authenticated and able to list workspaces");
        
        _output.WriteLine($"Fabric Workspaces: {output}");
    }

    [Fact]
    public async Task FabricWorkspace_Should_Exist()
    {
        // Arrange
        var workspaceName = _fabricConfig.WorkspaceName;
        workspaceName.Should().NotBeNullOrWhiteSpace("Workspace name should be configured");

        // Act
        var (success, output) = await ProcessHelper.RunFabricCliAsync("workspace list");

        // Assert
        success.Should().BeTrue("Should be able to list workspaces");
        
        if (success && !string.IsNullOrWhiteSpace(output))
        {
            try
            {
                var workspaces = JArray.Parse(output);
                var workspace = workspaces.FirstOrDefault(w => 
                    w["displayName"]?.ToString()?.Equals(workspaceName, StringComparison.OrdinalIgnoreCase) == true);
                
                workspace.Should().NotBeNull($"Workspace '{workspaceName}' should exist");
                
                _output.WriteLine($"Found workspace: {workspace}");
            }
            catch (Exception ex)
            {
                _output.WriteLine($"Failed to parse workspace list: {ex.Message}");
                _output.WriteLine($"Raw output: {output}");
                
                // Fallback to string search
                output.Should().Contain(workspaceName, $"Workspace '{workspaceName}' should be in the list");
            }
        }
        else
        {
            success.Should().BeTrue("Failed to list workspaces");
        }
    }

    [Fact]
    public async Task FabricWorkspace_Should_BeAccessible()
    {
        // Arrange
        var workspaceName = _fabricConfig.WorkspaceName;

        // Act - Try to get workspace details
        var (success, output) = await ProcessHelper.RunFabricCliAsync($"workspace show --workspace \"{workspaceName}\"");

        // Assert
        if (success)
        {
            output.Should().Contain(workspaceName, "Workspace details should contain the workspace name");
            _output.WriteLine($"Workspace details: {output}");
        }
        else
        {
            // Alternative approach - list workspaces and verify accessibility
            var (listSuccess, listOutput) = await ProcessHelper.RunFabricCliAsync("workspace list");
            listSuccess.Should().BeTrue("Should be able to list workspaces");
            listOutput.Should().Contain(workspaceName, $"Workspace '{workspaceName}' should be accessible");
            
            _output.WriteLine($"Workspace found in list: {listOutput}");
        }
    }
}
