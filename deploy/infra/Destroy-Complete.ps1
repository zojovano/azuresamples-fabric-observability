#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Complete destroy script for Azure OTEL Observability Infrastructure
    
.DESCRIPTION
    Unified destroy script that removes:
    1. Fabric artifacts (KQL tables, database, workspace)
    2. Azure infrastructure (Event Hub, Container Instance, App Service, Fabric Capacity)
    3. Azure Resource Group (containing all resources)
    4. Optionally removes service principals
    
    This script uses the centralized configuration from config/project-config.json.
    
.PARAMETER KeyVaultName
    Name of the Key Vault containing project secrets (optional, uses config/project-config.json if not provided)
    
.PARAMETER SkipFabricArtifacts
    Skip Fabric artifacts removal (only remove Azure infrastructure)
    
.PARAMETER SkipInfrastructure
    Skip Azure infrastructure removal (only remove Fabric artifacts)
    
.PARAMETER SkipServicePrincipals
    Skip service principal removal (default: skips removal for safety)
    
.PARAMETER RemoveServicePrincipals
    Remove the service principals created for this project (DESTRUCTIVE)
    
.PARAMETER Force
    Skip confirmation prompts (DANGEROUS - use with caution)
    
.PARAMETER WhatIf
    Show what would be removed without actually removing anything
    
.EXAMPLE
    ./Destroy-Complete.ps1
    
.EXAMPLE
    ./Destroy-Complete.ps1 -WhatIf
    
.EXAMPLE
    ./Destroy-Complete.ps1 -SkipFabricArtifacts
    
.EXAMPLE
    ./Destroy-Complete.ps1 -RemoveServicePrincipals -Force
    
.NOTES
    ⚠️  WARNING: This script is DESTRUCTIVE and will remove all project resources!
    
    Prerequisites:
    - Azure CLI authenticated with sufficient permissions
    - PowerShell Azure module installed
    - Fabric CLI installed and authenticated
    - Owner or Contributor permissions on the subscription
    
    The script will remove:
    - All Azure resources in the resource group
    - The resource group itself
    - Fabric workspace and all its contents
    - KQL database and tables
    - Optionally: Service principals (if -RemoveServicePrincipals specified)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipFabricArtifacts,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipInfrastructure,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipServicePrincipals = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$RemoveServicePrincipals,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Load centralized project configuration
Write-Host "📋 Loading project configuration..." -ForegroundColor Cyan
$configModulePath = Join-Path $PSScriptRoot "../../config/ProjectConfig.psm1"
if (-not (Test-Path $configModulePath)) {
    Write-Error "❌ Configuration module not found at: $configModulePath"
    exit 1
}

Import-Module $configModulePath -Force
$projectConfig = Get-ProjectConfig

# Use KeyVault from configuration if not provided as parameter
if ([string]::IsNullOrEmpty($KeyVaultName)) {
    $KeyVaultName = $projectConfig.keyVault.vaultName
    Write-Host "✅ Using KeyVault from configuration: $KeyVaultName" -ForegroundColor Green
} else {
    Write-Host "✅ Using KeyVault from parameter: $KeyVaultName" -ForegroundColor Green
}

# Colors for output
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "Cyan"
$ColorHeader = "Magenta"

function Write-ColorOutput {
    param($Message, $Color, $Icon = "")
    Write-Host "$Icon $Message" -ForegroundColor $Color
}

function Write-DestructionWarning {
    Write-Host ""
    Write-Host "⚠️  DESTRUCTIVE OPERATION WARNING ⚠️" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "====================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "This script will PERMANENTLY REMOVE the following resources:" -ForegroundColor Red
    Write-Host ""
    
    if (-not $SkipFabricArtifacts) {
        Write-Host "🏗️  FABRIC RESOURCES:" -ForegroundColor Yellow
        Write-Host "   • Workspace: $($projectConfig.fabric.workspaceName)" -ForegroundColor White
        Write-Host "   • Database: $($projectConfig.fabric.databaseName)" -ForegroundColor White
        Write-Host "   • KQL Tables: OTELLogs, OTELMetrics, OTELTraces" -ForegroundColor White
        Write-Host ""
    }
    
    if (-not $SkipInfrastructure) {
        Write-Host "☁️  AZURE RESOURCES:" -ForegroundColor Yellow
        Write-Host "   • Resource Group: $($projectConfig.azure.resourceGroupName)" -ForegroundColor White
        Write-Host "   • Fabric Capacity: $($projectConfig.fabric.capacityName)" -ForegroundColor White
        Write-Host "   • Event Hub Namespace: $($projectConfig.otel.eventHub.namespaceName)" -ForegroundColor White
        Write-Host "   • Container Instance: $($projectConfig.otel.containerInstance.containerGroupName)" -ForegroundColor White
        Write-Host "   • App Service: $($projectConfig.otel.appService.appName)" -ForegroundColor White
        Write-Host "   • App Service Plan: $($projectConfig.otel.appService.planName)" -ForegroundColor White
        Write-Host ""
    }
    
    if ($RemoveServicePrincipals) {
        Write-Host "🔐 SERVICE PRINCIPALS:" -ForegroundColor Red
        Write-Host "   • GitHub Actions Service Principal" -ForegroundColor White
        Write-Host "   • Application Service Principal" -ForegroundColor White
        Write-Host ""
    }
    
    Write-Host "💀 ALL DATA WILL BE PERMANENTLY LOST!" -ForegroundColor Red -BackgroundColor Black
    Write-Host ""
}

function Test-AzureConnection {
    Write-ColorOutput "Checking Azure CLI authentication..." $ColorInfo "🔍"
    $account = az account show --query "user.name" -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Please authenticate with Azure CLI first: az login" $ColorError
        exit 1
    }
    Write-ColorOutput "✅ Authenticated as: $account" $ColorSuccess
}

function Test-FabricConnection {
    Write-ColorOutput "Checking Fabric CLI authentication..." $ColorInfo "🔍"
    $fabricAuth = fab auth status 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Please authenticate with Fabric CLI first: fab auth login" $ColorError
        exit 1
    }
    Write-ColorOutput "✅ Fabric CLI authenticated" $ColorSuccess
}

function Get-KeyVaultSecrets {
    param($VaultName)
    
    Write-ColorOutput "Retrieving configuration from Key Vault: $VaultName" $ColorInfo "🔑"
    
    $secrets = @{}
    $secretMapping = $projectConfig.keyVault.secrets
    
    foreach ($envVar in $secretMapping.PSObject.Properties.Name) {
        $secretName = $secretMapping.$envVar
        try {
            $secretValue = az keyvault secret show --vault-name $VaultName --name $secretName --query "value" -o tsv 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($secretValue)) {
                $secrets[$envVar] = $secretValue
                Write-ColorOutput "✅ Retrieved $envVar from KeyVault" $ColorSuccess
            }
        } catch {
            Write-ColorOutput "⚠️  Warning: Could not retrieve secret '$secretName': $_" $ColorWarning
        }
    }
    
    return $secrets
}

function Remove-FabricArtifacts {
    param($WorkspaceName, $DatabaseName)
    
    Write-ColorOutput "🏗️  Removing Fabric artifacts..." $ColorHeader
    
    if ($WhatIf) {
        Write-ColorOutput "WHAT-IF: Would remove Fabric workspace '$WorkspaceName' and database '$DatabaseName'" $ColorInfo "👁️"
        return
    }
    
    # Check if workspace exists
    $existingWorkspace = fab workspace show --workspace $WorkspaceName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Found workspace: $WorkspaceName" $ColorInfo "🔍"
        
        # Check if database exists
        $existingDatabase = fab kqldatabase show --database $DatabaseName --workspace $WorkspaceName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Removing KQL database: $DatabaseName" $ColorWarning "🗑️"
            fab kqldatabase delete --database $DatabaseName --workspace $WorkspaceName --yes 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Database removed successfully" $ColorSuccess
            } else {
                Write-ColorOutput "⚠️  Warning: Could not remove database (may not exist or insufficient permissions)" $ColorWarning
            }
        } else {
            Write-ColorOutput "Database '$DatabaseName' not found - skipping" $ColorInfo "ℹ️"
        }
        
        Write-ColorOutput "Removing Fabric workspace: $WorkspaceName" $ColorWarning "🗑️"
        fab workspace delete --workspace $WorkspaceName --yes 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Workspace removed successfully" $ColorSuccess
        } else {
            Write-ColorOutput "⚠️  Warning: Could not remove workspace (may not exist or insufficient permissions)" $ColorWarning
        }
    } else {
        Write-ColorOutput "Workspace '$WorkspaceName' not found - skipping" $ColorInfo "ℹ️"
    }
}

function Remove-AzureInfrastructure {
    param($ResourceGroupName, $SubscriptionId)
    
    Write-ColorOutput "☁️  Removing Azure infrastructure..." $ColorHeader
    
    if ($WhatIf) {
        Write-ColorOutput "WHAT-IF: Would remove resource group '$ResourceGroupName' and all contained resources" $ColorInfo "👁️"
        return
    }
    
    # Set subscription context
    if (-not [string]::IsNullOrEmpty($SubscriptionId)) {
        Write-ColorOutput "Setting subscription context: $SubscriptionId" $ColorInfo "🎯"
        az account set --subscription $SubscriptionId
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "❌ Failed to set subscription context" $ColorError
            exit 1
        }
    }
    
    # Check if resource group exists
    $existingRG = az group show --name $ResourceGroupName --query "name" -o tsv 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Found resource group: $ResourceGroupName" $ColorInfo "🔍"
        
        # List resources that will be deleted
        Write-ColorOutput "Resources to be deleted:" $ColorInfo "📋"
        $resources = az resource list --resource-group $ResourceGroupName --query "[].{Name:name, Type:type}" -o table 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host $resources -ForegroundColor Gray
        }
        
        Write-ColorOutput "Removing resource group: $ResourceGroupName" $ColorWarning "🗑️"
        az group delete --name $ResourceGroupName --yes --no-wait
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Resource group deletion initiated (running in background)" $ColorSuccess
            Write-ColorOutput "ℹ️  Note: Full deletion may take several minutes to complete" $ColorInfo
        } else {
            Write-ColorOutput "❌ Failed to delete resource group" $ColorError
            exit 1
        }
    } else {
        Write-ColorOutput "Resource group '$ResourceGroupName' not found - skipping" $ColorInfo "ℹ️"
    }
}

function Remove-ServicePrincipals {
    param($Secrets)
    
    Write-ColorOutput "🔐 Removing Service Principals..." $ColorHeader
    
    if ($WhatIf) {
        Write-ColorOutput "WHAT-IF: Would remove service principals" $ColorInfo "👁️"
        return
    }
    
    if ($Secrets.ContainsKey('clientId') -and -not [string]::IsNullOrEmpty($Secrets.clientId)) {
        $appId = $Secrets.clientId
        Write-ColorOutput "Removing service principal: $appId" $ColorWarning "🗑️"
        
        az ad sp delete --id $appId 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Service principal removed successfully" $ColorSuccess
        } else {
            Write-ColorOutput "⚠️  Warning: Could not remove service principal (may not exist or insufficient permissions)" $ColorWarning
        }
    } else {
        Write-ColorOutput "No service principal client ID found in secrets - skipping" $ColorInfo "ℹ️"
    }
}

function Confirm-Destruction {
    if ($Force) {
        Write-ColorOutput "⚡ Force mode enabled - skipping confirmation" $ColorWarning
        return $true
    }
    
    Write-Host ""
    $confirmation = Read-Host "Type 'DESTROY' to confirm permanent deletion of all resources"
    
    if ($confirmation -eq "DESTROY") {
        Write-ColorOutput "✅ Destruction confirmed" $ColorSuccess
        return $true
    } else {
        Write-ColorOutput "❌ Destruction cancelled - confirmation not received" $ColorInfo
        return $false
    }
}

# Main execution
try {
    Write-ColorOutput "🔥 Azure OTEL Observability - DESTROY Script" $ColorHeader
    Write-ColorOutput "============================================" $ColorHeader
    
    # Display configuration summary
    Write-ConfigSummary -Config $projectConfig
    
    # Show destruction warning
    Write-DestructionWarning
    
    # Require confirmation unless WhatIf mode
    if (-not $WhatIf) {
        if (-not (Confirm-Destruction)) {
            Write-ColorOutput "🛡️  Destruction cancelled by user" $ColorInfo
            exit 0
        }
    }
    
    # Test connections
    Test-AzureConnection
    if (-not $SkipFabricArtifacts) {
        Test-FabricConnection
    }
    
    # Get secrets from Key Vault
    $secrets = Get-KeyVaultSecrets -VaultName $KeyVaultName
    
    # Remove Fabric artifacts first (data layer)
    if (-not $SkipFabricArtifacts) {
        Remove-FabricArtifacts -WorkspaceName $projectConfig.fabric.workspaceName -DatabaseName $projectConfig.fabric.databaseName
    }
    
    # Remove Azure infrastructure (compute layer)
    if (-not $SkipInfrastructure) {
        $subscriptionId = $secrets.subscriptionId
        if ([string]::IsNullOrEmpty($subscriptionId)) {
            $subscriptionId = $projectConfig.azure.subscriptionId
        }
        Remove-AzureInfrastructure -ResourceGroupName $projectConfig.azure.resourceGroupName -SubscriptionId $subscriptionId
    }
    
    # Remove service principals (identity layer) - only if explicitly requested
    if ($RemoveServicePrincipals) {
        Remove-ServicePrincipals -Secrets $secrets
    }
    
    if ($WhatIf) {
        Write-ColorOutput "👁️  What-If mode: No actual changes were made" $ColorInfo
    } else {
        Write-ColorOutput "🎯 Destruction completed successfully!" $ColorSuccess
        Write-ColorOutput "📋 Summary of actions taken:" $ColorInfo
        
        if (-not $SkipFabricArtifacts) {
            Write-ColorOutput "   ✅ Fabric artifacts removal initiated" $ColorSuccess
        }
        
        if (-not $SkipInfrastructure) {
            Write-ColorOutput "   ✅ Azure infrastructure removal initiated" $ColorSuccess
        }
        
        if ($RemoveServicePrincipals) {
            Write-ColorOutput "   ✅ Service principals removal completed" $ColorSuccess
        }
        
        Write-ColorOutput "ℹ️  Note: Some deletions may continue in the background" $ColorInfo
    }
    
} catch {
    Write-ColorOutput "❌ Error during destruction: $_" $ColorError
    Write-ColorOutput "🛠️  Please check permissions and try again" $ColorWarning
    exit 1
}
