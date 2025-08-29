# PowerShell Configuration Module for Azure Fabric OTEL Observability
# This module provides centralized configuration loading for all scripts

function Get-ProjectConfig {
    <#
    .SYNOPSIS
        Loads the centralized project configuration from config/project-config.json
    
    .DESCRIPTION
        Provides a single source of truth for all configuration values used across
        Bicep deployments, Fabric artifact deployments, and testing scripts.
    
    .PARAMETER ConfigPath
        Path to the configuration file. Defaults to config/project-config.json
    
    .EXAMPLE
        $config = Get-ProjectConfig
        Write-Host "Resource Group: $($config.azure.resourceGroupName)"
        Write-Host "Workspace: $($config.fabric.workspaceName)"
    #>
    
    [CmdletBinding()]
    param(
        [string]$ConfigPath = (Join-Path $PSScriptRoot ".." "config" "project-config.json")
    )
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found at: $ConfigPath"
    }
    
    try {
        $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        return $configContent
    }
    catch {
        throw "Failed to parse configuration file: $_"
    }
}

function Set-ConfigEnvironmentVariables {
    <#
    .SYNOPSIS
        Sets environment variables from the project configuration
    
    .DESCRIPTION
        Sets standard environment variables that are expected by deployment scripts
        and testing utilities. This provides backward compatibility with existing scripts.
    
    .PARAMETER Config
        The configuration object (from Get-ProjectConfig)
    
    .EXAMPLE
        $config = Get-ProjectConfig
        Set-ConfigEnvironmentVariables -Config $config
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )
    
    # Azure configuration
    $env:AZURE_LOCATION = $Config.azure.location
    $env:RESOURCE_GROUP_NAME = $Config.azure.resourceGroupName
    
    # Fabric configuration  
    $env:FABRIC_CAPACITY_NAME = $Config.fabric.capacityName
    $env:FABRIC_CAPACITY_SKU = $Config.fabric.capacitySku
    $env:FABRIC_WORKSPACE_NAME = $Config.fabric.workspaceName
    $env:FABRIC_DATABASE_NAME = $Config.fabric.databaseName
    
    # OTEL configuration
    $env:EVENT_HUB_NAMESPACE_NAME = $Config.otel.eventHub.namespaceName
    $env:EVENT_HUB_NAME = $Config.otel.eventHub.eventHubName
    $env:CONTAINER_GROUP_NAME = $Config.otel.containerInstance.containerGroupName
    $env:APP_SERVICE_PLAN_NAME = $Config.otel.appService.planName
    $env:APP_SERVICE_NAME = $Config.otel.appService.appName
    
    # KeyVault configuration
    $env:KEYVAULT_NAME = $Config.keyVault.vaultName
    $env:KEYVAULT_RESOURCE_GROUP = $Config.keyVault.resourceGroupName
    
    Write-Verbose "Environment variables set from configuration"
}

function Get-KeyVaultSecrets {
    <#
    .SYNOPSIS
        Retrieves secrets from KeyVault using the configuration
    
    .DESCRIPTION
        Uses the current user's permissions to retrieve Service Principal
        credentials from the configured KeyVault for deployment purposes.
    
    .PARAMETER Config
        The configuration object (from Get-ProjectConfig)
        
    .PARAMETER SetEnvironmentVariables
        If specified, sets the secrets as environment variables
    
    .EXAMPLE
        $config = Get-ProjectConfig
        $secrets = Get-KeyVaultSecrets -Config $config -SetEnvironmentVariables
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        
        [switch]$SetEnvironmentVariables
    )
    
    $vaultName = $Config.keyVault.vaultName
    $secretMapping = $Config.keyVault.secrets
    
    Write-Verbose "Retrieving secrets from KeyVault: $vaultName"
    
    # Check Azure CLI authentication
    $account = az account show --query "user.name" -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Please authenticate with Azure CLI first: az login"
    }
    
    Write-Host "Authenticated as: $account" -ForegroundColor Green
    
    $secrets = @{}
    
    foreach ($envVar in $secretMapping.PSObject.Properties.Name) {
        $secretName = $secretMapping.$envVar
        try {
            $secretValue = az keyvault secret show --vault-name $vaultName --name $secretName --query "value" -o tsv 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($secretValue)) {
                $secrets[$envVar] = $secretValue
                
                if ($SetEnvironmentVariables) {
                    # Map the config keys to the correct environment variable names
                    $envVarName = switch ($envVar) {
                        'clientId' { 'AZURE_CLIENT_ID' }
                        'clientSecret' { 'AZURE_CLIENT_SECRET' }
                        'tenantId' { 'AZURE_TENANT_ID' }
                        'subscriptionId' { 'AZURE_SUBSCRIPTION_ID' }
                        'adminObjectId' { 'ADMIN_OBJECT_ID' }
                        default { "AZURE_$($envVar.ToUpper())" }
                    }
                    Set-Item -Path "env:$envVarName" -Value $secretValue
                }
                
                Write-Host "✅ Retrieved $envVar from KeyVault" -ForegroundColor Green
            } else {
                Write-Warning "Secret '$secretName' not found in KeyVault"
            }
        } catch {
            Write-Warning "Failed to get secret '$secretName': $_"
        }
    }
    
    return $secrets
}

function Write-ConfigSummary {
    <#
    .SYNOPSIS
        Displays a summary of the current configuration
    
    .PARAMETER Config
        The configuration object (from Get-ProjectConfig)
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )
    
    Write-Host "📋 Project Configuration Summary" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "🌐 Azure Settings:" -ForegroundColor Yellow
    Write-Host "  Location: $($Config.azure.location)" -ForegroundColor White
    Write-Host "  Resource Group: $($Config.azure.resourceGroupName)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🏗️ Fabric Settings:" -ForegroundColor Yellow  
    Write-Host "  Capacity: $($Config.fabric.capacityName) ($($Config.fabric.capacitySku))" -ForegroundColor White
    Write-Host "  Workspace: $($Config.fabric.workspaceName)" -ForegroundColor White
    Write-Host "  Database: $($Config.fabric.databaseName)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🔐 KeyVault Settings:" -ForegroundColor Yellow
    Write-Host "  Vault: $($Config.keyVault.vaultName)" -ForegroundColor White
    Write-Host "  Resource Group: $($Config.keyVault.resourceGroupName)" -ForegroundColor White
    Write-Host ""
}

# Export functions for use in other scripts
Export-ModuleMember -Function Get-ProjectConfig, Set-ConfigEnvironmentVariables, Get-KeyVaultSecrets, Write-ConfigSummary
