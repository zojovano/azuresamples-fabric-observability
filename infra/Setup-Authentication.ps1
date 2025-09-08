#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Authentication helper for Azure and Fabric CLI

.DESCRIPTION
    Provides convenient authentication checking and login for both Azure CLI and Fabric CLI.
    Works in DevContainer environments.

.PARAMETER CheckOnly
    Only check authentication status, don't attempt login

.PARAMETER ForceLogin
    Force re-authentication even if already logged in

.EXAMPLE
    ./Setup-Authentication.ps1
    
.EXAMPLE
    ./Setup-Authentication.ps1 -CheckOnly

.NOTES
    Author: Generated for Azure Samples - Fabric Observability Project
#>

[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [switch]$ForceLogin
)

# Colors for output
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "Cyan"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [string]$Icon = ""
    )
    if ($Icon) {
        Write-Host "$Icon $Message" -ForegroundColor $Color
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Test-AzureAuthentication {
    Write-ColorOutput "Checking Azure CLI authentication..." $ColorInfo "🔍"
    
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account -and $account.id) {
            Write-ColorOutput "Azure CLI authenticated" $ColorSuccess "✅"
            Write-ColorOutput "  Subscription: $($account.name) ($($account.id))" $ColorInfo
            Write-ColorOutput "  User: $($account.user.name)" $ColorInfo
            return $true
        }
    } catch {
        # Ignore errors, will return false
    }
    
    Write-ColorOutput "Azure CLI not authenticated" $ColorWarning "⚠️"
    return $false
}

function Test-FabricAuthentication {
    Write-ColorOutput "Checking Fabric CLI authentication..." $ColorInfo "🔍"
    
    try {
        $result = fab auth whoami 2>$null
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-ColorOutput "Fabric CLI authenticated" $ColorSuccess "✅"
            Write-ColorOutput "  User: $result" $ColorInfo
            return $true
        }
    } catch {
        # Ignore errors, will return false
    }
    
    Write-ColorOutput "Fabric CLI not authenticated" $ColorWarning "⚠️"
    return $false
}

function Start-AzureLogin {
    Write-ColorOutput "Starting Azure CLI login..." $ColorInfo "🔐"
    
    try {
        # Use device code flow which works well in DevContainers
        az login --use-device-code
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Azure CLI login successful" $ColorSuccess "✅"
            
            # Show available subscriptions
            Write-ColorOutput "Available subscriptions:" $ColorInfo
            az account list --query "[].{Name:name, SubscriptionId:id, IsDefault:isDefault}" --output table
            
            return $true
        } else {
            Write-ColorOutput "Azure CLI login failed" $ColorError "❌"
            return $false
        }
    } catch {
        Write-ColorOutput "Azure CLI login error: $_" $ColorError "❌"
        return $false
    }
}

function Start-FabricLogin {
    Write-ColorOutput "Starting Fabric CLI login..." $ColorInfo "🔐"
    
    try {
        fab auth login
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Fabric CLI login successful" $ColorSuccess "✅"
            
            # Verify authentication
            $user = fab auth whoami 2>$null
            if ($user) {
                Write-ColorOutput "Authenticated as: $user" $ColorInfo
            }
            
            return $true
        } else {
            Write-ColorOutput "Fabric CLI login failed" $ColorError "❌"
            return $false
        }
    } catch {
        Write-ColorOutput "Fabric CLI login error: $_" $ColorError "❌"
        return $false
    }
}

function Get-CurrentUserObjectId {
    Write-ColorOutput "Getting current user object ID..." $ColorInfo "🔍"
    
    try {
        $objectId = az ad signed-in-user show --query "id" -o tsv 2>$null
        if ($objectId -and $objectId -ne "null") {
            Write-ColorOutput "User Object ID: $objectId" $ColorSuccess "✅"
            return $objectId
        } else {
            Write-ColorOutput "Failed to get user object ID" $ColorError "❌"
            return $null
        }
    } catch {
        Write-ColorOutput "Error getting user object ID: $_" $ColorError "❌"
        return $null
    }
}

# Main execution
try {
    Write-ColorOutput "Azure Fabric Observability - Authentication Setup" $ColorInfo "🚀"
    Write-ColorOutput "=================================================" $ColorInfo
    Write-ColorOutput ""
    
    # Check current authentication status
    $azureAuth = Test-AzureAuthentication
    $fabricAuth = Test-FabricAuthentication
    
    if ($CheckOnly) {
        Write-ColorOutput "`nAuthentication Summary:" $ColorInfo "📋"
        Write-ColorOutput "  Azure CLI: $(if ($azureAuth) { 'Authenticated ✅' } else { 'Not authenticated ❌' })" $ColorInfo
        Write-ColorOutput "  Fabric CLI: $(if ($fabricAuth) { 'Authenticated ✅' } else { 'Not authenticated ❌' })" $ColorInfo
        
        if ($azureAuth -and $fabricAuth) {
            Write-ColorOutput "`nAll services authenticated!" $ColorSuccess "🎉"
            
            # Get user object ID for Bicep deployments
            $objectId = Get-CurrentUserObjectId
            if ($objectId) {
                Write-ColorOutput "`nFor Bicep deployments, use:" $ColorInfo "💡"
                Write-ColorOutput "  -AdminObjectId `"$objectId`"" $ColorWarning
            }
        } else {
            Write-ColorOutput "`nSome services need authentication. Run without -CheckOnly to login." $ColorWarning "⚠️"
        }
        
        exit 0
    }
    
    # Perform authentication if needed or forced
    if (-not $azureAuth -or $ForceLogin) {
        if (-not (Start-AzureLogin)) {
            Write-ColorOutput "Azure authentication failed. Cannot continue." $ColorError "❌"
            exit 1
        }
    }
    
    if (-not $fabricAuth -or $ForceLogin) {
        if (-not (Start-FabricLogin)) {
            Write-ColorOutput "Fabric authentication failed. Cannot continue." $ColorError "❌"
            exit 1
        }
    }
    
    Write-ColorOutput "`nAuthentication setup completed!" $ColorSuccess "🎉"
    
    # Get user object ID for future use
    $objectId = Get-CurrentUserObjectId
    if ($objectId) {
        Write-ColorOutput "`nYour Object ID for deployments:" $ColorInfo "💡"
        Write-ColorOutput "$objectId" $ColorWarning
        Write-ColorOutput "`nSave this for Bicep deployments:" $ColorInfo
        Write-ColorOutput "./Generate-BicepParameters.ps1 -AdminObjectId `"$objectId`"" $ColorWarning
    }
    
} catch {
    Write-ColorOutput "Authentication setup failed: $_" $ColorError "❌"
    exit 1
}
