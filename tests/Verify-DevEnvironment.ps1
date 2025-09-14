#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Verifies the DevContainer environment is properly configured for Azure Fabric OTEL development

.DESCRIPTION
    This script validates all required tools, configurations, and environment setup
    for the Azure Fabric Observability project in the DevContainer.

.PARAMETER Detailed
    Show detailed information about each component

.PARAMETER FixIssues
    Attempt to fix common issues automatically

.EXAMPLE
    ./Verify-DevEnvironment.ps1
    
.EXAMPLE
    ./Verify-DevEnvironment.ps1 -Detailed -FixIssues

.NOTES
    This script should be run inside the DevContainer environment
#>

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$FixIssues
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

function Test-ToolInstallation {
    param(
        [string]$ToolName,
        [string]$Command,
        [string]$ExpectedPattern = "",
        [scriptblock]$DetailedCheck = $null
    )
    
    try {
        $output = Invoke-Expression $Command 2>$null
        if ($LASTEXITCODE -eq 0 -and $output) {
            if ([string]::IsNullOrEmpty($ExpectedPattern) -or $output -match $ExpectedPattern) {
                Write-ColorOutput "$ToolName is installed" $ColorSuccess "✅"
                if ($Detailed -and $DetailedCheck) {
                    $DetailedCheck.Invoke()
                } elseif ($Detailed) {
                    Write-ColorOutput "  Version: $($output -split "`n" | Select-Object -First 1)" $ColorInfo "  ℹ️"
                }
                return $true
            }
        }
        Write-ColorOutput "$ToolName is not working properly" $ColorError "❌"
        return $false
    } catch {
        Write-ColorOutput "$ToolName is not installed or not in PATH" $ColorError "❌"
        return $false
    }
}

function Test-EnvironmentVariable {
    param(
        [string]$VarName,
        [string]$Description,
        [bool]$Required = $false
    )
    
    $value = [Environment]::GetEnvironmentVariable($VarName)
    if ([string]::IsNullOrEmpty($value)) {
        if ($Required) {
            Write-ColorOutput "$Description ($VarName) is missing" $ColorError "❌"
            return $false
        } else {
            Write-ColorOutput "$Description ($VarName) is not set (optional)" $ColorWarning "⚠️"
            return $true
        }
    } else {
        Write-ColorOutput "$Description is configured" $ColorSuccess "✅"
        if ($Detailed) {
            # Mask sensitive values
            $displayValue = if ($VarName -match "(SECRET|PASSWORD|KEY)") { "***MASKED***" } else { $value }
            Write-ColorOutput "  Value: $displayValue" $ColorInfo "  ℹ️"
        }
        return $true
    }
}

function Test-GitConfiguration {
    try {
        $userName = git config --global user.name 2>$null
        $userEmail = git config --global user.email 2>$null
        
        $gitConfigured = $true
        
        if ([string]::IsNullOrEmpty($userName) -or $userName -eq "DevContainer User") {
            Write-ColorOutput "Git user.name not properly configured" $ColorWarning "⚠️"
            $gitConfigured = $false
        }
        
        if ([string]::IsNullOrEmpty($userEmail) -or $userEmail -eq "user@example.com") {
            Write-ColorOutput "Git user.email not properly configured" $ColorWarning "⚠️"
            $gitConfigured = $false
        }
        
        if ($gitConfigured) {
            Write-ColorOutput "Git configuration is complete" $ColorSuccess "✅"
            if ($Detailed) {
                Write-ColorOutput "  Name: $userName" $ColorInfo "  ℹ️"
                Write-ColorOutput "  Email: $userEmail" $ColorInfo "  ℹ️"
            }
        } else {
            Write-ColorOutput "Git configuration needs attention" $ColorWarning "⚠️"
            if ($FixIssues) {
                Write-ColorOutput "Run: git config --global user.name 'Your Name'" $ColorInfo "  🔧"
                Write-ColorOutput "Run: git config --global user.email 'your.email@example.com'" $ColorInfo "  🔧"
            }
        }
        
        return $gitConfigured
    } catch {
        Write-ColorOutput "Git configuration check failed" $ColorError "❌"
        return $false
    }
}

function Test-DevContainerEnvironment {
    # Check if we're in a DevContainer
    $isDevContainer = $env:REMOTE_CONTAINERS -eq "true" -or 
                     $env:CODESPACES -eq "true" -or 
                     (Test-Path "/.devcontainer") -or
                     $env:VSCODE_REMOTE_CONTAINERS_SESSION -eq "true"
    
    if ($isDevContainer) {
        Write-ColorOutput "Running in DevContainer environment" $ColorSuccess "✅"
        return $true
    } else {
        Write-ColorOutput "Not running in DevContainer (may affect functionality)" $ColorWarning "⚠️"
        return $false
    }
}

function Test-AzureConnectivity {
    try {
        $context = Get-AzContext -ErrorAction SilentlyContinue
        if ($context) {
            Write-ColorOutput "Azure PowerShell context is available" $ColorSuccess "✅"
            if ($Detailed) {
                Write-ColorOutput "  Account: $($context.Account.Id)" $ColorInfo "  ℹ️"
                Write-ColorOutput "  Subscription: $($context.Subscription.Name)" $ColorInfo "  ℹ️"
            }
            return $true
        } else {
            Write-ColorOutput "Azure PowerShell not authenticated" $ColorWarning "⚠️"
            if ($FixIssues) {
                Write-ColorOutput "Run: Connect-AzAccount" $ColorInfo "  🔧"
            }
            return $false
        }
    } catch {
        Write-ColorOutput "Azure PowerShell check failed" $ColorError "❌"
        return $false
    }
}

function Test-FabricCLI {
    $fabricWorking = Test-ToolInstallation -ToolName "Microsoft Fabric CLI" -Command "fab --version"
    
    if ($fabricWorking) {
        try {
            $authOutput = fab auth whoami 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "Fabric CLI is authenticated" $ColorSuccess "✅"
                if ($Detailed) {
                    Write-ColorOutput "  User: $($authOutput -split "`n" | Select-Object -First 1)" $ColorInfo "  ℹ️"
                }
            } else {
                Write-ColorOutput "Fabric CLI not authenticated" $ColorWarning "⚠️"
                if ($FixIssues) {
                    Write-ColorOutput "Run: fab auth login" $ColorInfo "  🔧"
                }
            }
        } catch {
            Write-ColorOutput "Fabric CLI authentication check failed" $ColorWarning "⚠️"
        }
    }
    
    return $fabricWorking
}

function Test-ProjectStructure {
    $requiredPaths = @(
        @{ Path = "deploy/infra/Bicep/main.bicep"; Description = "Main Bicep template" },
    @{ Path = "deploy/infra/Deploy-FabricArtifacts-Git.ps1"; Description = "Fabric Git integration deployment guidance" },
        @{ Path = "app/otel-eh-receiver/config.yaml"; Description = "OTEL Collector config" },

        @{ Path = ".devcontainer/devcontainer.json"; Description = "DevContainer configuration" }
    )
    
    $allPathsExist = $true
    
    foreach ($item in $requiredPaths) {
        if (Test-Path $item.Path) {
            Write-ColorOutput "$($item.Description) exists" $ColorSuccess "✅"
        } else {
            Write-ColorOutput "$($item.Description) is missing" $ColorError "❌"
            $allPathsExist = $false
        }
    }
    
    return $allPathsExist
}

# Main verification
Write-ColorOutput "🔍 Azure Fabric OTEL DevContainer Environment Verification" $ColorInfo
Write-ColorOutput "============================================================" $ColorInfo
Write-Host ""

$allChecks = @()

# DevContainer environment check
Write-ColorOutput "📦 DevContainer Environment" $ColorInfo
$allChecks += Test-DevContainerEnvironment
Write-Host ""

# Core tools verification
Write-ColorOutput "🛠️ Core Development Tools" $ColorInfo
$allChecks += Test-ToolInstallation -ToolName "PowerShell" -Command "pwsh --version" -DetailedCheck {
    $version = $PSVersionTable.PSVersion
    Write-ColorOutput "  PowerShell Version: $version" $ColorInfo "  ℹ️"
    if ($version -ge [Version]"7.5.0") {
        Write-ColorOutput "  PowerShell 7.5+ confirmed" $ColorSuccess "  ✅"
    } else {
        Write-ColorOutput "  PowerShell 7.5+ recommended" $ColorWarning "  ⚠️"
    }
}

$allChecks += Test-ToolInstallation -ToolName "Azure CLI" -Command "az version --output tsv --query '`"azure-cli`"'" -DetailedCheck {
    try {
        $extensions = az extension list --output json | ConvertFrom-Json
        $bicepExt = $extensions | Where-Object { $_.name -eq "bicep" }
        if ($bicepExt) {
            Write-ColorOutput "  Bicep extension: $($bicepExt.version)" $ColorSuccess "  ✅"
        } else {
            Write-ColorOutput "  Bicep extension not installed" $ColorWarning "  ⚠️"
        }
    } catch {
        Write-ColorOutput "  Could not check extensions" $ColorWarning "  ⚠️"
    }
}

$allChecks += Test-ToolInstallation -ToolName ".NET SDK" -Command "dotnet --version"
$allChecks += Test-ToolInstallation -ToolName "Git" -Command "git --version"
$allChecks += Test-FabricCLI
Write-Host ""

# Git configuration
Write-ColorOutput "📝 Git Configuration" $ColorInfo
$allChecks += Test-GitConfiguration
Write-Host ""

# Environment variables
Write-ColorOutput "🌍 Environment Variables" $ColorInfo
$allChecks += Test-EnvironmentVariable -VarName "AZURE_SUBSCRIPTION_ID" -Description "Azure Subscription ID"
$allChecks += Test-EnvironmentVariable -VarName "AZURE_TENANT_ID" -Description "Azure Tenant ID"
Test-EnvironmentVariable -VarName "GIT_USER_NAME" -Description "Git User Name"
Test-EnvironmentVariable -VarName "GIT_USER_EMAIL" -Description "Git User Email"
Write-Host ""

# Azure connectivity
Write-ColorOutput "☁️ Azure Connectivity" $ColorInfo
$allChecks += Test-AzureConnectivity
Write-Host ""

# Project structure
Write-ColorOutput "📁 Project Structure" $ColorInfo
$allChecks += Test-ProjectStructure
Write-Host ""

# Summary
$passedChecks = ($allChecks | Where-Object { $_ -eq $true }).Count
$totalChecks = $allChecks.Count
$failedChecks = $totalChecks - $passedChecks

Write-ColorOutput "📊 Verification Summary" $ColorInfo
Write-ColorOutput "======================" $ColorInfo
Write-ColorOutput "Passed: $passedChecks/$totalChecks checks" $(if ($failedChecks -eq 0) { $ColorSuccess } else { $ColorWarning })

if ($failedChecks -eq 0) {
    Write-ColorOutput "🎉 Environment is ready for development!" $ColorSuccess "🎉"
} else {
    Write-ColorOutput "⚠️ $failedChecks issues found. Please address them before proceeding." $ColorWarning "⚠️"
}

Write-Host ""
Write-ColorOutput "🚀 Next Steps:" $ColorInfo
Write-ColorOutput "1. Fix any issues shown above" $ColorInfo "  •"
Write-ColorOutput "2. Run: pwsh deploy/tools/Test-FabricLocal.ps1 -SetupSecrets" $ColorInfo "  •"
Write-ColorOutput "3. Run: cd deploy/infra/Bicep && ./deploy.ps1" $ColorInfo "  •"

exit $failedChecks