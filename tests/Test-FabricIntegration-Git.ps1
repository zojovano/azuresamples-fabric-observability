#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test Fabric OTEL integration using Git integration approach
.DESCRIPTION
    This simplified test validates that the Git integration approach is properly set up
    and provides guidance for manual verification steps.
.PARAMETER WorkspaceName
    Name of the Fabric workspace (default: fabric-otel-workspace)
.PARAMETER DatabaseName  
    Name of the KQL database (default: otelobservabilitydb)
.PARAMETER GitFolder
    Folder in the repository connected to workspace (default: fabric-artifacts, resolves to deploy/fabric-artifacts)
#>

param(
    [string]$WorkspaceName = "fabric-otel-workspace",
    [string]$DatabaseName = "otelobservabilitydb",
    [string]$GitFolder = "fabric-artifacts"
)

# Color definitions for output
$ColorSuccess = "Green"
$ColorError = "Red" 
$ColorWarning = "Yellow"
$ColorInfo = "Cyan"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color,
        [string]$Icon = ""
    )
    if ($Icon) {
        Write-Host "$Icon $Message" -ForegroundColor $Color
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Write-TestResult {
    param(
        [string]$TestName,
        [string]$Result,
        [string]$Message,
        [int]$Duration = 0
    )
    
    $status = if ($Result -eq "PASS") { "✅" } elseif ($Result -eq "FAIL") { "❌" } else { "⏭️" }
    $color = if ($Result -eq "PASS") { $ColorSuccess } elseif ($Result -eq "FAIL") { $ColorError } else { $ColorWarning }
    
    $output = "$status ${Result}: $TestName - $Message"
    if ($Duration -gt 0) {
        $output += " (${Duration}s)"
    }
    
    Write-ColorOutput $output $color
}

function Test-FabricAuthentication {
    $startTime = Get-Date
    Write-ColorOutput "Testing Fabric authentication..." $ColorInfo "🔐"
    
    try {
        $authOutput = fab auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "Fabric Authentication" "FAIL" "Not authenticated with Fabric CLI" $duration
            return $false
        }
        
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "Fabric Authentication" "PASS" "Fabric CLI authenticated successfully" $duration
        return $true
    } catch {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "Fabric Authentication" "FAIL" "Error checking authentication: $_" $duration
        return $false
    }
}

function Test-WorkspaceAccess {
    $startTime = Get-Date
    Write-ColorOutput "Testing Fabric workspace access..." $ColorInfo "🏗️"
    
    try {
        $workspaceOutput = fab ls 2>&1
        if ($LASTEXITCODE -ne 0) {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "Workspace Access" "FAIL" "Cannot list workspaces" $duration
            return $false
        }
        
        $workspaceExists = $workspaceOutput | Select-String "$WorkspaceName.Workspace" -Quiet
        if ($workspaceExists) {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "Workspace Access" "PASS" "Workspace '$WorkspaceName' found and accessible" $duration
            return $true
        } else {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "Workspace Access" "FAIL" "Workspace '$WorkspaceName' not found" $duration
            return $false
        }
    } catch {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "Workspace Access" "FAIL" "Error accessing workspace: $_" $duration
        return $false
    }
}

function Test-GitFolderStructure {
    $startTime = Get-Date
    Write-ColorOutput "Testing Git folder structure..." $ColorInfo "📁"
    
    try {
        $gitFolderPath = Join-Path (Split-Path $PSScriptRoot -Parent) "deploy/$GitFolder"
        
        if (-not (Test-Path $gitFolderPath)) {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "Git Folder Structure" "FAIL" "Git folder '$GitFolder' not found" $duration
            return $false
        }
        
        $tablesPath = Join-Path $gitFolderPath "tables"
        if (-not (Test-Path $tablesPath)) {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "Git Folder Structure" "FAIL" "Tables folder not found in Git folder" $duration
            return $false
        }
        
        # Check for required KQL files
        $requiredFiles = @("otel-logs.kql", "otel-metrics.kql", "otel-traces.kql")
        $missingFiles = @()
        
        foreach ($file in $requiredFiles) {
            $filePath = Join-Path $tablesPath $file
            if (-not (Test-Path $filePath)) {
                $missingFiles += $file
            }
        }
        
        if ($missingFiles.Count -gt 0) {
            $duration = [int]((Get-Date) - $startTime).TotalSeconds
            Write-TestResult "Git Folder Structure" "FAIL" "Missing KQL files: $($missingFiles -join ', ')" $duration
            return $false
        }
        
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "Git Folder Structure" "PASS" "All required KQL files found in Git folder" $duration
        return $true
        
    } catch {
        $duration = [int]((Get-Date) - $startTime).TotalSeconds
        Write-TestResult "Git Folder Structure" "FAIL" "Error checking Git folder: $_" $duration
        return $false
    }
}

function Show-GitIntegrationGuidance {
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "🔗 Git Integration Setup Guidance" $ColorInfo "📋"
    Write-ColorOutput "=================================" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "To complete the Git integration setup:" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "1. Open Fabric Portal:" $ColorInfo "👉"
    Write-ColorOutput "   https://app.fabric.microsoft.com" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "2. Navigate to workspace:" $ColorInfo "👉"
    Write-ColorOutput "   $WorkspaceName" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "3. Create KQL database (if not exists):" $ColorInfo "👉"
    Write-ColorOutput "   Name: $DatabaseName" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "4. Set up Git integration:" $ColorInfo "👉"
    Write-ColorOutput "   - Click Workspace Settings > Git Integration" $ColorInfo
    Write-ColorOutput "   - Select GitHub as provider" $ColorInfo
    Write-ColorOutput "   - Repository: $(git remote get-url origin 2>/dev/null)" $ColorInfo
    Write-ColorOutput "   - Branch: main" $ColorInfo
    Write-ColorOutput "   - Folder: deploy/$GitFolder" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "5. Sync workspace:" $ColorInfo "👉"
    Write-ColorOutput "   - Choose sync direction (Git to workspace recommended)" $ColorInfo
    Write-ColorOutput "   - This will import KQL table definitions" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "6. Verify tables:" $ColorInfo "👉"
    Write-ColorOutput "   - Check that OTELLogs, OTELMetrics, OTELTraces tables exist" $ColorInfo
    Write-ColorOutput "   - Run test queries to verify table schemas" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "Benefits of this approach:" $ColorSuccess "💡"
    Write-ColorOutput "- No complex API calls or authentication issues" $ColorSuccess "✅"
    Write-ColorOutput "- Visual Git status in Fabric portal" $ColorSuccess "✅"
    Write-ColorOutput "- Automatic version control and backup" $ColorSuccess "✅"
    Write-ColorOutput "- Collaborative development workflows" $ColorSuccess "✅"
    Write-ColorOutput "- Reliable deployment and rollback" $ColorSuccess "✅"
}

# Main execution
try {
    Write-ColorOutput "🧪 Starting Fabric OTEL Git Integration Test Suite" $ColorInfo
    Write-ColorOutput "==================================================" $ColorInfo
    
    $allTestsPassed = $true
    
    # Test Fabric authentication
    if (-not (Test-FabricAuthentication)) {
        $allTestsPassed = $false
    }
    
    # Test workspace access  
    if (-not (Test-WorkspaceAccess)) {
        $allTestsPassed = $false
    }
    
    # Test Git folder structure
    if (-not (Test-GitFolderStructure)) {
        $allTestsPassed = $false
    }
    
    # Show Git integration guidance
    Show-GitIntegrationGuidance
    
    Write-ColorOutput "" $ColorInfo
    if ($allTestsPassed) {
        Write-ColorOutput "✅ All automated tests passed! Ready for Git integration setup." $ColorSuccess "🎉"
    } else {
        Write-ColorOutput "❌ Some tests failed. Please address issues before proceeding." $ColorError "⚠️"
    }
    
} catch {
    Write-ColorOutput "❌ Test suite failed: $_" $ColorError
    exit 1
}
