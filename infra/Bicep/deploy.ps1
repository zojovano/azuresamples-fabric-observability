#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Simple deployment script - redirects to unified deployment
    
.DESCRIPTION
    This script now redirects to the unified deployment script which intelligently
    chooses between environment variables, Key Vault, or interactive configuration.
    
.PARAMETER Location
    Azure region for deployment
    
.PARAMETER SubscriptionId
    Azure subscription ID (uses current context if not provided)
    
.PARAMETER CreateKeyVault
    Create new Key Vault and service principals
    
.PARAMETER WhatIf
    Show what would be deployed without actually deploying
    
.EXAMPLE
    ./deploy.ps1
    
.EXAMPLE
    ./deploy.ps1 -CreateKeyVault
    
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
    [switch]$CreateKeyVault,
    
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

if ($CreateKeyVault) {
    $unifiedParams.CreateKeyVault = $true
}

if ($WhatIf) {
    $unifiedParams.WhatIf = $true
}

# Call unified deployment script
& (Join-Path $PSScriptRoot "deploy-unified.ps1") @unifiedParams
