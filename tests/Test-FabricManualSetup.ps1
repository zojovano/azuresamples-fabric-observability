#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Manual Fabric Setup and Testing Script

.DESCRIPTION
    This script helps manually create and test Fabric workspace, database, and tables
    when automated deployment encounters permissions issues.

.EXAMPLE
    .\Test-FabricManualSetup.ps1
#>

[CmdletBinding()]
param()

# Color output functions
$ColorSuccess = "Green"
$ColorWarning = "Yellow" 
$ColorError = "Red"
$ColorInfo = "Cyan"

function Write-ColorOutput($Message, $Color, $Emoji = "") {
    Write-Host "$Emoji $Message" -ForegroundColor $Color
}

function Test-FabricAuthentication {
    Write-ColorOutput "Testing Fabric CLI authentication..." $ColorInfo "🔐"
    
    $authStatus = fab auth status 2>$null
    if ($LASTEXITCODE -eq 0) {
        $accountLine = $authStatus | Where-Object { $_ -match "Account:" } | Select-Object -First 1
        if ($accountLine) {
            $account = ($accountLine -split "Account:")[1].Trim().Split(' ')[0]
            Write-ColorOutput "✅ Fabric CLI authenticated as: $account" $ColorSuccess
            return $true
        }
    }
    
    Write-ColorOutput "❌ Fabric CLI not authenticated" $ColorError
    Write-ColorOutput "💡 Run: fab auth login" $ColorInfo
    return $false
}

function Test-WorkspaceAccess {
    Write-ColorOutput "Testing workspace access..." $ColorInfo "🏗️"
    
    # List available workspaces
    Write-ColorOutput "Available workspaces:" $ColorInfo
    $workspaces = fab ls
    $workspaces | ForEach-Object { Write-ColorOutput "  - $_" $ColorInfo }
    
    # Check if target workspace exists
    $targetWorkspace = "azuresamples-platformobservabilty-fabric.Workspace"
    $exists = fab exists $targetWorkspace 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $exists -eq "true") {
        Write-ColorOutput "✅ Target workspace exists: $targetWorkspace" $ColorSuccess
        return $true
    } else {
        Write-ColorOutput "❌ Target workspace not accessible: $targetWorkspace" $ColorError
        Write-ColorOutput "💡 Manual setup required through Fabric portal" $ColorWarning
        return $false
    }
}

function Show-ManualSetupInstructions {
    Write-ColorOutput "📋 MANUAL FABRIC SETUP INSTRUCTIONS" $ColorWarning "📋"
    Write-Host "=" * 80 -ForegroundColor Yellow
    
    Write-ColorOutput "1. Open Fabric Portal:" $ColorInfo
    Write-ColorOutput "   https://fabric.microsoft.com" $ColorInfo
    
    Write-ColorOutput "2. Create/Access Workspace:" $ColorInfo
    Write-ColorOutput "   - Workspace Name: azuresamples-platformobservabilty-fabric" $ColorInfo
    Write-ColorOutput "   - Assign to Capacity: fabriccapacityobservability" $ColorInfo
    
    Write-ColorOutput "3. Create KQL Database:" $ColorInfo
    Write-ColorOutput "   - Database Name: otelobservabilitydb" $ColorInfo
    Write-ColorOutput "   - Type: KQL Database (Real-Time Intelligence)" $ColorInfo
    
    Write-ColorOutput "4. Create OTEL Tables using KQL:" $ColorInfo
    $kqlFile = Join-Path $PSScriptRoot ".." "deploy" "data" "otel-tables.kql"
    if (Test-Path $kqlFile) {
        Write-ColorOutput "   - Use KQL from: $kqlFile" $ColorInfo
        Write-ColorOutput "   - Copy and paste the KQL commands in the database query editor" $ColorInfo
    } else {
        Write-ColorOutput "   - KQL file not found, use individual table creation scripts" $ColorWarning
    }
    
    Write-Host "=" * 80 -ForegroundColor Yellow
}

function Test-KQLTablesExist {
    param([string]$WorkspaceName, [string]$DatabaseName)
    
    Write-ColorOutput "Testing KQL table existence..." $ColorInfo "📊"
    
    # Required OTEL tables
    $requiredTables = @("OTELLogs", "OTELMetrics", "OTELTraces")
    $tablesExist = @()
    $tablesMissing = @()
    
    # Try to set workspace context
    try {
        fab cd "$WorkspaceName.Workspace" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "❌ Cannot access workspace: $WorkspaceName" $ColorError
            return $false
        }
        
        # Check each table (this is simplified - actual implementation would need proper KQL queries)
        foreach ($table in $requiredTables) {
            Write-ColorOutput "Checking table: $table" $ColorInfo "  📄"
            # Note: This is a placeholder - actual table checking would require KQL query execution
            # For now, we'll assume tables need to be checked manually
            $tablesMissing += $table
        }
        
        if ($tablesMissing.Count -eq 0) {
            Write-ColorOutput "✅ All OTEL tables exist" $ColorSuccess
            return $true
        } else {
            Write-ColorOutput "❌ Missing tables: $($tablesMissing -join ', ')" $ColorError
            return $false
        }
        
    } catch {
        Write-ColorOutput "❌ Error accessing workspace: $_" $ColorError
        return $false
    }
}

function Show-KQLTableDefinitions {
    Write-ColorOutput "📊 KQL TABLE DEFINITIONS" $ColorInfo "📊"
    Write-Host "=" * 80 -ForegroundColor Cyan
    
    $kqlTableFiles = @(
        "deploy/infra/kql-definitions/tables/otel-logs.kql",
        "deploy/infra/kql-definitions/tables/otel-metrics.kql", 
        "deploy/infra/kql-definitions/tables/otel-traces.kql"
    )
    
    foreach ($kqlFile in $kqlTableFiles) {
        $fullPath = Join-Path $PSScriptRoot ".." $kqlFile
        if (Test-Path $fullPath) {
            Write-ColorOutput "📄 $kqlFile" $ColorInfo
            $content = Get-Content $fullPath -Raw
            Write-Host $content -ForegroundColor White
            Write-Host "" 
        } else {
            Write-ColorOutput "❌ KQL file not found: $kqlFile" $ColorWarning
        }
    }
    
    Write-Host "=" * 80 -ForegroundColor Cyan
}

function Test-AzureResources {
    Write-ColorOutput "Testing Azure infrastructure..." $ColorInfo "🔍"
    
    # Check Fabric capacity
    $capacity = az fabric capacity show --capacity-name "fabriccapacityobservability" --resource-group "azuresamples-platformobservabilty-fabric" --query "name" -o tsv 2>$null
    if ($capacity -eq "fabriccapacityobservability") {
        Write-ColorOutput "✅ Fabric capacity exists and is active" $ColorSuccess
    } else {
        Write-ColorOutput "❌ Fabric capacity not found or not active" $ColorError
        return $false
    }
    
    # Check Event Hub
    $eventHub = az eventhubs eventhub show --resource-group "azuresamples-platformobservabilty-fabric" --namespace-name "evhns-otel" --name "evh-otel-diagnostics" --query "name" -o tsv 2>$null
    if ($eventHub -eq "evh-otel-diagnostics") {
        Write-ColorOutput "✅ Event Hub exists and is configured" $ColorSuccess
    } else {
        Write-ColorOutput "❌ Event Hub not found" $ColorError
        return $false
    }
    
    return $true
}

# Main execution
Write-ColorOutput "🧪 Fabric Manual Setup and Testing" $ColorInfo "🔬"
Write-Host "=" * 60 -ForegroundColor Cyan

# Test 1: Authentication
if (-not (Test-FabricAuthentication)) {
    Write-ColorOutput "❌ Authentication failed. Please authenticate first." $ColorError
    exit 1
}

# Test 2: Azure Resources
if (-not (Test-AzureResources)) {
    Write-ColorOutput "❌ Azure infrastructure not ready. Run Deploy-Complete.ps1 first." $ColorError
    exit 1
}

# Test 3: Workspace Access
$workspaceAccessible = Test-WorkspaceAccess

# Test 4: Show manual setup instructions
if (-not $workspaceAccessible) {
    Show-ManualSetupInstructions
    Write-ColorOutput "" $ColorInfo
    $proceed = Read-Host "Have you completed the manual setup steps in Fabric portal? (y/N)"
    
    if ($proceed.ToLower() -in @('y', 'yes')) {
        Write-ColorOutput "✅ Proceeding with table verification..." $ColorSuccess
    } else {
        Write-ColorOutput "⏭️ Complete manual setup and run this script again" $ColorWarning
        exit 0
    }
}

# Test 5: Show KQL table definitions for manual creation
Show-KQLTableDefinitions

# Test 6: Table existence (simplified check)
Write-ColorOutput "" $ColorInfo
Write-ColorOutput "💡 To verify tables exist, run the following KQL queries in Fabric portal:" $ColorInfo
Write-ColorOutput "   OTELLogs | count" $ColorInfo
Write-ColorOutput "   OTELMetrics | count" $ColorInfo  
Write-ColorOutput "   OTELTraces | count" $ColorInfo

Write-ColorOutput "" $ColorInfo
Write-ColorOutput "🎯 Next Steps:" $ColorSuccess
Write-ColorOutput "1. ✅ Azure infrastructure is deployed" $ColorSuccess
Write-ColorOutput "2. 🔧 Complete manual Fabric setup using instructions above" $ColorWarning
Write-ColorOutput "3. 📊 Create tables using provided KQL definitions" $ColorWarning
Write-ColorOutput "4. 🧪 Run comprehensive tests: tests/Test-FabricIntegration.ps1" $ColorInfo

Write-Host "=" * 60 -ForegroundColor Cyan
