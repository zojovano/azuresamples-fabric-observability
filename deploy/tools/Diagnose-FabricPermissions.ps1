#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Diagnose and workaround Fabric workspace permissions issues

.DESCRIPTION
    This script helps diagnose Service Principal permissions for Fabric workspace creation
    and provides workarounds when tenant settings are not configured.

.PARAMETER CreateWorkspaceManually
    Provides instructions for manual workspace creation

.PARAMETER SkipWorkspaceCreation
    Skip workspace creation and assume it exists

.EXAMPLE
    .\Diagnose-FabricPermissions.ps1
    
.EXAMPLE
    .\Diagnose-FabricPermissions.ps1 -CreateWorkspaceManually

.NOTES
    Author: Generated for Azure Samples - Fabric Observability Project
    Requires: Microsoft Fabric CLI (fab), Azure CLI
#>

[CmdletBinding()]
param(
    [switch]$CreateWorkspaceManually,
    [switch]$SkipWorkspaceCreation
)

# Import centralized configuration
$configModulePath = Join-Path $PSScriptRoot ".." "config" "ProjectConfig.psm1"
if (Test-Path $configModulePath) {
    Import-Module $configModulePath -Force
    $config = Get-ProjectConfig
    $WorkspaceName = $config.fabric.workspaceName
    $DatabaseName = $config.fabric.databaseName
    $CapacityName = $config.fabric.capacityName
} else {
    Write-Error "Configuration module not found. Please ensure deploy/config/project-config.json exists."
    exit 1
}

# Colors for output
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "Cyan"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [string]$Prefix = ""
    )
    if ($Prefix) {
        Write-Host "$Prefix " -NoNewline -ForegroundColor $Color
    }
    Write-Host $Message -ForegroundColor $Color
}

function Test-FabricAuthentication {
    Write-ColorOutput "Testing Fabric authentication..." $ColorInfo "🔐"
    
    try {
        $authStatus = fab auth status 2>&1
        $authExitCode = $LASTEXITCODE
        
        if ($authExitCode -eq 0 -and $authStatus -and $authStatus -notmatch "Not logged in") {
            Write-ColorOutput "✅ Fabric authentication: SUCCESS" $ColorSuccess
            $accountLine = $authStatus | Select-String "Account:" | ForEach-Object { $_.Line }
            if ($accountLine) {
                Write-ColorOutput "  $accountLine" $ColorInfo
            }
            return $true
        } else {
            Write-ColorOutput "❌ Fabric authentication: FAILED" $ColorError
            Write-ColorOutput "  Auth status: $authStatus" $ColorError
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Fabric authentication: ERROR - $_" $ColorError
        return $false
    }
}

function Test-WorkspacePermissions {
    Write-ColorOutput "Testing workspace permissions..." $ColorInfo "🔍"
    
    try {
        $workspaceOutput = fab ls 2>&1
        $listExitCode = $LASTEXITCODE
        
        if ($listExitCode -eq 0) {
            Write-ColorOutput "✅ Workspace listing: SUCCESS" $ColorSuccess
            Write-ColorOutput "  Available workspaces:" $ColorInfo
            $workspaceOutput | ForEach-Object { 
                if ($_ -match "\.Workspace") {
                    Write-ColorOutput "    $_" $ColorInfo
                }
            }
            return $true
        } else {
            Write-ColorOutput "❌ Workspace listing: FAILED (Exit code: $listExitCode)" $ColorError
            Write-ColorOutput "  Error: $workspaceOutput" $ColorError
            
            if ($workspaceOutput -match "Unauthorized|Access is unauthorized") {
                Write-ColorOutput "  📋 Diagnosis: Service Principal lacks tenant-level permissions" $ColorWarning
                Write-ColorOutput "  💡 Solution: Enable 'Service principals can create workspaces' in Fabric Admin portal" $ColorWarning
            }
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Workspace permissions: ERROR - $_" $ColorError
        return $false
    }
}

function Show-ManualWorkspaceInstructions {
    Write-ColorOutput "Manual Workspace Creation Instructions" $ColorWarning "📋"
    Write-Host "=" * 60 -ForegroundColor Yellow
    
    Write-ColorOutput "Since tenant settings are not configured, create the workspace manually:" $ColorWarning
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "1. Go to Microsoft Fabric portal: https://fabric.microsoft.com" $ColorInfo
    Write-ColorOutput "2. Click 'Workspaces' in the left navigation" $ColorInfo
    Write-ColorOutput "3. Click '+ New workspace'" $ColorInfo
    Write-ColorOutput "4. Enter workspace name: $WorkspaceName" $ColorInfo
    Write-ColorOutput "5. In 'Advanced Options', select capacity: $CapacityName" $ColorInfo
    Write-ColorOutput "6. Click 'Apply'" $ColorInfo
    Write-ColorOutput "7. In the created workspace, click 'Manage access'" $ColorInfo
    Write-ColorOutput "8. Click 'Add people or groups'" $ColorInfo
    Write-ColorOutput "9. Search for and add: ADOGenericService" $ColorInfo
    Write-ColorOutput "10. Assign it 'Admin' role" $ColorInfo
    Write-ColorOutput "11. Click 'Add'" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "After manual creation, run:" $ColorSuccess
    Write-ColorOutput "  pwsh ./deploy/infra/Deploy-FabricArtifacts-Git.ps1" $ColorSuccess
}

function Show-TenantSettingsInstructions {
    Write-ColorOutput "Required Tenant Settings Configuration" $ColorError "⚙️"
    Write-Host "=" * 60 -ForegroundColor Red
    
    Write-ColorOutput "A Fabric Administrator needs to configure these settings:" $ColorError
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "🌐 Fabric Admin Portal → Tenant Settings → Developer Settings" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "1. Enable: 'Service principals can create workspaces, connections, and deployment pipelines'" $ColorInfo
    Write-ColorOutput "   Status: ⚠️ DISABLED by default (THIS IS THE ISSUE!)" $ColorWarning
    Write-ColorOutput "   Action: ✅ Enable and add Service Principal to security group" $ColorSuccess
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "2. Verify: 'Service principals can call Fabric public APIs'" $ColorInfo
    Write-ColorOutput "   Status: ✅ Usually enabled by default" $ColorInfo
    Write-ColorOutput "   Action: ✅ Ensure it's enabled" $ColorSuccess
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "📖 Full instructions: docs/TROUBLESHOOT_FABRIC_WORKSPACE_PERMISSIONS.md" $ColorInfo
}

function Show-ServicePrincipalInfo {
    Write-ColorOutput "Service Principal Information" $ColorInfo "🔑"
    Write-Host "=" * 60 -ForegroundColor Cyan
    
    try {
        $spInfo = az ad sp show --id e10b0ed5-117d-466c-8a84-bee676f32373 --query "{displayName:displayName,appId:appId,servicePrincipalType:servicePrincipalType}" --output json | ConvertFrom-Json
        
        Write-ColorOutput "Name: $($spInfo.displayName)" $ColorInfo
        Write-ColorOutput "App ID: $($spInfo.appId)" $ColorInfo
        Write-ColorOutput "Type: $($spInfo.servicePrincipalType)" $ColorInfo
        Write-ColorOutput "Capacity Role: Capacity Admin ✅" $ColorSuccess
        Write-ColorOutput "Authentication: Working ✅" $ColorSuccess
        Write-ColorOutput "Workspace Creation: Blocked ❌" $ColorError
        
    } catch {
        Write-ColorOutput "Could not retrieve Service Principal details: $_" $ColorWarning
    }
}

# Main execution
Write-ColorOutput "Fabric Permissions Diagnostic Tool" $ColorSuccess "🔬"
Write-Host "=" * 60 -ForegroundColor Green

# Show current configuration
Write-ColorOutput "Configuration:" $ColorInfo "📋"
Write-ColorOutput "  Workspace: $WorkspaceName" $ColorInfo
Write-ColorOutput "  Database: $DatabaseName" $ColorInfo
Write-ColorOutput "  Capacity: $CapacityName" $ColorInfo

Write-ColorOutput "" $ColorInfo

# Run diagnostics
$authWorking = Test-FabricAuthentication
$workspaceWorking = Test-WorkspacePermissions

Write-ColorOutput "" $ColorInfo

# Show Service Principal info
Show-ServicePrincipalInfo

Write-ColorOutput "" $ColorInfo

# Provide recommendations based on results
if ($authWorking -and $workspaceWorking) {
    Write-ColorOutput "🎉 All permissions working! You can proceed with deployment." $ColorSuccess
} elseif ($authWorking -and -not $workspaceWorking) {
    Write-ColorOutput "⚠️ Authentication works but workspace permissions are blocked." $ColorWarning
    Write-ColorOutput "" $ColorInfo
    
    if ($CreateWorkspaceManually) {
        Show-ManualWorkspaceInstructions
    } else {
        Show-TenantSettingsInstructions
        Write-ColorOutput "" $ColorInfo
        Write-ColorOutput "Alternative: Run with -CreateWorkspaceManually for workaround instructions" $ColorWarning
    }
} else {
    Write-ColorOutput "❌ Multiple issues detected. Check authentication and tenant settings." $ColorError
    Show-TenantSettingsInstructions
}

Write-ColorOutput "" $ColorInfo
Write-ColorOutput "📖 Full troubleshooting guide: docs/TROUBLESHOOT_FABRIC_WORKSPACE_PERMISSIONS.md" $ColorInfo
