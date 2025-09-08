#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Generates Bicep parameters file from centralized configuration

.DESCRIPTION
    Reads the project configuration and generates a parameters file for Bicep deployment.
    This ensures consistency between configuration and actual deployment.

.PARAMETER ConfigPath
    Path to the project configuration file

.PARAMETER OutputPath
    Path where the parameters file should be generated

.PARAMETER AdminObjectId
    Override for admin object ID (if not provided, uses current user)

.EXAMPLE
    .\Generate-BicepParameters.ps1 -AdminObjectId "f42fd94b-9842-48a0-aaa0-c9fca9882928"
#>

[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot ".." ".." ".." "config" "project-config.json"),
    [string]$OutputPath = (Join-Path $PSScriptRoot "parameters-generated.json"),
    [string]$AdminObjectId = ""
)

# Import configuration module
Import-Module (Join-Path $PSScriptRoot ".." ".." ".." "config" "ProjectConfig.psm1") -Force

try {
    Write-Host "📋 Generating Bicep parameters from configuration..." -ForegroundColor Cyan
    
    # Load configuration
    $config = Get-ProjectConfig -ConfigPath $ConfigPath
    Write-ConfigSummary -Config $config
    
    # Get admin object ID if not provided
    if ([string]::IsNullOrWhiteSpace($AdminObjectId)) {
        Write-Host "🔍 Getting current user object ID..." -ForegroundColor Yellow
        $AdminObjectId = az ad signed-in-user show --query "id" -o tsv 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get current user object ID. Please provide -AdminObjectId parameter."
        }
        Write-Host "✅ Using current user object ID: $AdminObjectId" -ForegroundColor Green
    }
    
    # Create parameters object
    $parameters = @{
        '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
        contentVersion = "1.0.0.0"
        parameters = @{
            location = @{ value = $config.azure.location }
            resourceGroupName = @{ value = $config.azure.resourceGroupName }
            fabricCapacityName = @{ value = $config.fabric.capacityName }
            fabricCapacitySku = @{ value = $config.fabric.capacitySku }
            fabricWorkspaceName = @{ value = $config.fabric.workspaceName }
            fabricDatabaseName = @{ value = $config.fabric.databaseName }
            eventHubNamespaceName = @{ value = $config.otel.eventHub.namespaceName }
            eventHubName = @{ value = $config.otel.eventHub.eventHubName }
            eventHubSku = @{ value = $config.otel.eventHub.skuName }
            containerGroupName = @{ value = $config.otel.containerInstance.containerGroupName }
            containerName = @{ value = $config.otel.containerInstance.containerName }
            containerImage = @{ value = $config.otel.containerInstance.containerImage }
            appServicePlanName = @{ value = $config.otel.appService.planName }
            appServiceName = @{ value = $config.otel.appService.appName }
            tags = @{ value = $config.azure.tags }
            adminObjectIds = @{ value = @($AdminObjectId) }
        }
    }
    
    # Convert to JSON and save
    $parametersJson = $parameters | ConvertTo-Json -Depth 10
    $parametersJson | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "✅ Bicep parameters generated successfully!" -ForegroundColor Green
    Write-Host "📄 Parameters file: $OutputPath" -ForegroundColor White
    Write-Host "" -ForegroundColor White
    Write-Host "🚀 To deploy with these parameters:" -ForegroundColor Cyan
    Write-Host "   az deployment sub create --location $($config.azure.location) --template-file main.bicep --parameters @$OutputPath" -ForegroundColor White
    
} catch {
    Write-Host "❌ Failed to generate parameters: $_" -ForegroundColor Red
    exit 1
}
