using FabricObservability.IntegrationTests.Infrastructure;
using FluentAssertions;
using Xunit;
using Xunit.Abstractions;

namespace FabricObservability.IntegrationTests.Tests;

public class PrerequisitesTests
{
    private readonly ITestOutputHelper _output;
    private readonly TestConfiguration _config;

    public PrerequisitesTests(ITestOutputHelper output)
    {
        _output = output;
        _config = ConfigurationHelper.GetTestConfiguration();
    }

    [Fact]
    public async Task AzureCli_Should_BeInstalled()
    {
        // Act
        var (success, output) = await ProcessHelper.RunAzureCliAsync("--version");

        // Assert
        success.Should().BeTrue("Azure CLI should be installed and accessible");
        output.Should().Contain("azure-cli", "Azure CLI version should be displayed");
        
        _output.WriteLine($"Azure CLI Output: {output}");
    }

    [Fact]
    public async Task AzureCli_Should_BeAuthenticated()
    {
        // Act
        var (success, output) = await ProcessHelper.RunAzureCliAsync("account show");

        // Assert
        success.Should().BeTrue("Azure CLI should be authenticated");
        output.Should().NotBeNullOrWhiteSpace("Should return account information");
        
        _output.WriteLine($"Azure Account: {output}");
    }

    [Fact]
    public async Task FabricCli_Should_BeInstalled()
    {
        // Act
        var (success, output) = await ProcessHelper.RunFabricCliAsync("--version");

        // Assert
        success.Should().BeTrue("Fabric CLI should be installed and accessible");
        
        _output.WriteLine($"Fabric CLI Output: {output}");
    }

    [Fact]
    public async Task ResourceGroup_Should_Exist()
    {
        // Arrange
        var resourceGroupName = _config.ResourceGroupName;
        resourceGroupName.Should().NotBeNullOrWhiteSpace("Resource group name should be configured");

        // Act
        var (success, output) = await ProcessHelper.RunAzureCliAsync($"group show --name {resourceGroupName}");

        // Assert
        success.Should().BeTrue($"Resource group '{resourceGroupName}' should exist");
        output.Should().Contain(resourceGroupName, "Resource group details should be returned");
        
        _output.WriteLine($"Resource Group: {output}");
    }

    [Theory]
    [InlineData("jq")]
    [InlineData("bc")]
    public async Task RequiredUtility_Should_BeInstalled(string utility)
    {
        // Act
        var (success, output, error) = await ProcessHelper.RunCommandAsync("which", utility);

        // Assert
        success.Should().BeTrue($"Utility '{utility}' should be installed and accessible");
        output.Should().NotBeNullOrWhiteSpace($"Should return path to {utility}");
        
        _output.WriteLine($"{utility} location: {output}");
    }
}
