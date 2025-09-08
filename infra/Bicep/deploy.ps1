#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Simple deployment script - redirects to unified deployment
    
.DESCRIPTION
    This script redirects to the unified deployment script which intelligently
    chooses between environment variables, shared Key Vault, or interactive configuration.
    
    Note: This project uses shared infrastructure (Key Vault, service principals)
    managed by the platform team. No Key Vault creation is performed by this script.
    
.PARAMETER Location
    Azure region for deployment
    
.PARAMETER SubscriptionId
    Azure subscription ID (uses current context if not provided)
    
.PARAMETER SharedKeyVaultName
    Name of the shared Key Vault managed by platform team
    
.PARAMETER WhatIf
    Show what would be deployed without actually deploying
    
.EXAMPLE
    ./deploy.ps1
    
.EXAMPLE
    ./deploy.ps1 -SharedKeyVaultName "platform-shared-keyvault"
    
.EXAMPLE
    ./deploy.ps1 -WhatIf
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$Location = "swedencentral",

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory = $false)]
    [string]$SharedKeyVaultName = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

Write-Host "🔄 Redirecting to unified deployment script..." -ForegroundColor Cyan

# Build parameters for unified script
$unifiedParams = @{
    Location = $Location
}

if (-not [string]::IsNullOrEmpty($SubscriptionId)) {
    $unifiedParams.SubscriptionId = $SubscriptionId
}

if (-not [string]::IsNullOrEmpty($SharedKeyVaultName)) {
    $unifiedParams.SharedKeyVaultName = $SharedKeyVaultName
}

if ($WhatIf) {
    $unifiedParams.WhatIf = $true
}

# Call unified deployment script
& (Join-Path $PSScriptRoot "deploy-unified.ps1") @unifiedParams
