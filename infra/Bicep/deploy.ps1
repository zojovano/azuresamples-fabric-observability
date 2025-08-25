#!/usr/bin/env pwsh

# Enhanced deployment script with Key Vault integration option
# For full Key Vault setup, use: .\deploy-with-keyvault.ps1

param (
    [Parameter(Mandatory = $false)]
    [string]$Location = "swedencentral",

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = (Get-AzContext).Subscription.Id,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipKeyVault
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Deploying Azure OTEL Observability Infrastructure" -ForegroundColor Cyan
Write-Host ""

# Check if we should use the enhanced deployment
if (-not $SkipKeyVault) {
    Write-Host "ℹ️  Enhanced deployment with Key Vault integration is now available!" -ForegroundColor Yellow
    Write-Host "   .\deploy-with-keyvault.ps1 -AdminUserEmail 'admin@company.com'" -ForegroundColor Yellow
    Write-Host ""
    
    $useEnhanced = Read-Host "Use enhanced deployment with Key Vault? (y/n) [default: y]"
    if ([string]::IsNullOrWhiteSpace($useEnhanced) -or $useEnhanced.ToLower() -eq 'y') {
        Write-Host "Redirecting to enhanced deployment..." -ForegroundColor Green
        $adminEmail = Read-Host "Enter admin user email (or press Enter to use current user)"
        
        if ([string]::IsNullOrWhiteSpace($adminEmail)) {
            .\deploy-with-keyvault.ps1 -Location $Location
        } else {
            .\deploy-with-keyvault.ps1 -Location $Location -AdminUserEmail $adminEmail
        }
        return
    }
    
    Write-Host "Continuing with legacy deployment (without Key Vault)..." -ForegroundColor Yellow
    Write-Host ""
}

# Ensure Azure context is set
if (-not $SubscriptionId) {
    Write-Error "No Azure subscription found in current context. Please run Connect-AzAccount and set a subscription context."
    exit 1
}

# Select subscription
Select-AzSubscription -SubscriptionId $SubscriptionId
Write-Host "Using subscription: $((Get-AzContext).Subscription.Name)"

# Get the current directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BicepDir = $ScriptDir

# Deploy Bicep template
$DeploymentName = "azuresamples-platformobservabilty-fabric-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"

Write-Host "Starting deployment of OTEL Observability infrastructure..."
Write-Host "Deployment name: $DeploymentName"
Write-Host "Location: $Location"

New-AzDeployment -Name $DeploymentName `
    -Location $Location `
    -TemplateFile "$BicepDir\main.bicep" `
    -TemplateParameterFile "$BicepDir\parameters.json" `
    -location $Location `
    -Verbose

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment completed successfully." -ForegroundColor Green
}
else {
    Write-Host "Deployment failed." -ForegroundColor Red
}
