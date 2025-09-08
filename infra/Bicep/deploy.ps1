#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Simple deployment script for Azure OTEL Observability Infrastructure
    
.DESCRIPTION
    Basic deployment using existing service principals and manual secret management.
    For automated service principal creation and Key Vault integration, use deploy-with-keyvault.ps1
    
.PARAMETER Location
    Azure region for deployment
    
.PARAMETER SubscriptionId
    Azure subscription ID (uses current context if not provided)
    
.PARAMETER ParameterFile
    Path to parameters file (default: parameters.json)
    
.EXAMPLE
    ./deploy.ps1
    
.EXAMPLE
    ./deploy.ps1 -Location "eastus" -ParameterFile "parameters-custom.json"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$Location = "swedencentral",

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = "parameters.json"
)

$ErrorActionPreference = "Stop"

# Colors for output
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "Cyan"

function Write-ColorOutput {
    param($Message, $Color, $Icon = "")
    Write-Host "$Icon $Message" -ForegroundColor $Color
}

Write-ColorOutput "🚀 Simple Azure OTEL Observability Infrastructure Deployment" $ColorInfo
Write-ColorOutput "=============================================================" $ColorInfo
Write-Host ""

# Check if enhanced deployment is available
if (Test-Path "deploy-with-keyvault.ps1") {
    Write-ColorOutput "💡 Enhanced deployment with automatic service principal creation is available!" $ColorInfo
    Write-ColorOutput "   Use: ./deploy-with-keyvault.ps1 -AdminUserEmail 'admin@company.com'" $ColorInfo
    Write-ColorOutput "   Features: Service principal automation, Key Vault integration, secret management" $ColorInfo
    Write-Host ""
}

Write-ColorOutput "Proceeding with simple deployment (manual configuration required)" $ColorWarning "⚠️"
Write-Host ""

# Ensure Azure context is set
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-ColorOutput "No Azure context found. Please run Connect-AzAccount first." $ColorError "❌"
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($SubscriptionId)) {
        $SubscriptionId = $context.Subscription.Id
    }
    
    # Select subscription if different
    if ($context.Subscription.Id -ne $SubscriptionId) {
        Select-AzSubscription -SubscriptionId $SubscriptionId | Out-Null
        $context = Get-AzContext
    }
    
    Write-ColorOutput "Using subscription: $($context.Subscription.Name) ($SubscriptionId)" $ColorSuccess "✅"
} catch {
    Write-ColorOutput "Azure authentication failed: $($_.Exception.Message)" $ColorError "❌"
    exit 1
}

# Check parameter file exists
$parameterFilePath = Join-Path $PSScriptRoot $ParameterFile
if (-not (Test-Path $parameterFilePath)) {
    Write-ColorOutput "Parameter file not found: $parameterFilePath" $ColorError "❌"
    Write-ColorOutput "Available parameter files:" $ColorInfo
    Get-ChildItem -Path $PSScriptRoot -Name "parameters*.json" | ForEach-Object {
        Write-ColorOutput "  $_" $ColorInfo "  •"
    }
    exit 1
}

Write-ColorOutput "Using parameter file: $ParameterFile" $ColorSuccess "✅"

# Check Bicep template exists
$bicepTemplate = Join-Path $PSScriptRoot "main.bicep"
if (-not (Test-Path $bicepTemplate)) {
    Write-ColorOutput "Bicep template not found: $bicepTemplate" $ColorError "❌"
    exit 1
}

Write-ColorOutput "Using Bicep template: main.bicep" $ColorSuccess "✅"

# Deploy Bicep template
$deploymentName = "simple-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-ColorOutput "Starting deployment..." $ColorInfo "🚀"
Write-ColorOutput "Deployment name: $deploymentName" $ColorInfo "📋"
Write-ColorOutput "Location: $Location" $ColorInfo "📍"

try {
    $deployment = New-AzDeployment -Name $deploymentName `
        -Location $Location `
        -TemplateFile $bicepTemplate `
        -TemplateParameterFile $parameterFilePath `
        -Verbose
    
    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-ColorOutput "✅ Deployment completed successfully!" $ColorSuccess "🎉"
        
        # Display outputs if available
        if ($deployment.Outputs -and $deployment.Outputs.Count -gt 0) {
            Write-Host ""
            Write-ColorOutput "📋 Deployment Outputs:" $ColorInfo
            foreach ($output in $deployment.Outputs.GetEnumerator()) {
                Write-ColorOutput "$($output.Key): $($output.Value.Value)" $ColorSuccess "  •"
            }
        }
        
        Write-Host ""
        Write-ColorOutput "🎯 Next Steps:" $ColorInfo
        Write-ColorOutput "1. Configure application secrets manually" $ColorWarning "  📝"
        Write-ColorOutput "2. Deploy Fabric artifacts: ./infra/Deploy-FabricArtifacts.ps1" $ColorInfo "  🔧"
        Write-ColorOutput "3. Run integration tests: ./tests/Test-FabricIntegration.ps1" $ColorInfo "  🧪"
        
    } else {
        Write-ColorOutput "Deployment failed with state: $($deployment.ProvisioningState)" $ColorError "❌"
        exit 1
    }
    
} catch {
    Write-ColorOutput "Deployment failed: $($_.Exception.Message)" $ColorError "❌"
    if ($_.Exception.InnerException) {
        Write-ColorOutput "Inner exception: $($_.Exception.InnerException.Message)" $ColorError "  ❌"
    }
    exit 1
}
