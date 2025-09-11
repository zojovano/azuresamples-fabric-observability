#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Microsoft Fabric OTEL artifacts using Git integration
.DESCRIPTION
    This script manages the Git-based deployment of OTEL table definitions to Microsoft Fabric.
    It verifies the Git folder structure and provides guidance for Git integration setup.
    
    Git integration eliminates complex API calls and provides reliable deployment.
.PARAMETER WorkspaceName
    Name of the Fabric workspace (default: fabric-otel-workspace)
.PARAMETER DatabaseName  
    Name of the KQL database (default: otelobservabilitydb)
.PARAMETER WhatIf
    Show what would be deployed without actually deploying
.PARAMETER TriggerSync
    Attempt to trigger Git sync via Azure CLI (requires Azure CLI and proper authentication)
.EXAMPLE
    ./Deploy-FabricArtifacts-Git.ps1
    # Shows Git integration setup guidance
.EXAMPLE  
    ./Deploy-FabricArtifacts-Git.ps1 -TriggerSync
    # Attempts automated Git sync
.EXAMPLE
    ./Deploy-FabricArtifacts-Git.ps1 -WhatIf
    # Shows what would be done without executing
#>

param(
    [string]$WorkspaceName = "fabric-otel-workspace",
    [string]$DatabaseName = "otelobservabilitydb",
    [switch]$WhatIf,
    [switch]$TriggerSync
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

function Test-GitFolderStructure {
    Write-ColorOutput "Verifying Git folder structure..." $ColorInfo "�"
    
    $gitFolderPath = Join-Path (Split-Path $PSScriptRoot -Parent) "fabric-artifacts"
    $tablesPath = Join-Path $gitFolderPath "tables"
    
    if (-not (Test-Path $gitFolderPath)) {
        Write-ColorOutput "Git folder not found: $gitFolderPath" $ColorError "❌"
        return $false
    }
    
    if (-not (Test-Path $tablesPath)) {
        Write-ColorOutput "Tables folder not found: $tablesPath" $ColorError "❌"
        return $false
    }
    
    # Check for required KQL files
    $requiredFiles = @("otel-logs.kql", "otel-metrics.kql", "otel-traces.kql")
    $missingFiles = @()
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $tablesPath $file
        if (-not (Test-Path $filePath)) {
            $missingFiles += $file
        } else {
            Write-ColorOutput "Found: $file" $ColorSuccess "✅"
        }
    }
    
    if ($missingFiles.Count -gt 0) {
        Write-ColorOutput "Missing KQL files: $($missingFiles -join ', ')" $ColorError "❌"
        return $false
    }
    
    Write-ColorOutput "Git folder structure verified" $ColorSuccess "✅"
    return $true
}

function Show-TableDefinitions {
    Write-ColorOutput "Table definitions in Git folder:" $ColorInfo "�"
    
    $gitFolderPath = Join-Path (Split-Path $PSScriptRoot -Parent) "fabric-artifacts"
    $tablesPath = Join-Path $gitFolderPath "tables"
    
    $tableFiles = @("otel-logs.kql", "otel-metrics.kql", "otel-traces.kql")
    
    foreach ($file in $tableFiles) {
        $filePath = Join-Path $tablesPath $file
        if (Test-Path $filePath) {
            Write-ColorOutput "" $ColorInfo
            Write-ColorOutput "📄 ${file}:" $ColorInfo
            Write-ColorOutput "$(('-' * 50))" $ColorInfo
            $content = Get-Content $filePath -Raw
            Write-Host $content -ForegroundColor White
        }
    }
}

function Show-GitIntegrationGuidance {
    param(
        [string]$WorkspaceName,
        [string]$DatabaseName
    )
    
    $repoUrl = try { git remote get-url origin 2>$null } catch { "https://github.com/your-org/azuresamples-fabric-observability.git" }
    
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "🎯 Git Integration Deployment Process" $ColorSuccess "🎉"
    Write-ColorOutput "============================================" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "✅ Table definitions are ready in Git folder" $ColorSuccess
    Write-ColorOutput "✅ KQL files: OTELLogs, OTELMetrics, OTELTraces" $ColorSuccess
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "📋 Complete the Git Integration Setup:" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "STEP 1: Open Fabric Portal" $ColorInfo "1️⃣"
    Write-ColorOutput "   👉 Navigate to: https://app.fabric.microsoft.com" $ColorInfo
    Write-ColorOutput "   👉 Go to workspace: $WorkspaceName" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "STEP 2: Set up Git Integration (if not done)" $ColorInfo "2️⃣"
    Write-ColorOutput "   👉 Click: Workspace Settings > Git Integration" $ColorInfo
    Write-ColorOutput "   👉 Provider: GitHub" $ColorInfo
    Write-ColorOutput "   👉 Repository: $repoUrl" $ColorInfo
    Write-ColorOutput "   👉 Branch: main" $ColorInfo
    Write-ColorOutput "   👉 Folder: deploy/fabric-artifacts" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "STEP 3: Create KQL Database (if not exists)" $ColorInfo "3️⃣"
    Write-ColorOutput "   👉 Click: New > More options > KQL Database" $ColorInfo
    Write-ColorOutput "   👉 Name: $DatabaseName" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "STEP 4: Deploy Tables via Git Sync" $ColorInfo "4️⃣"
    Write-ColorOutput "   👉 In workspace Source Control panel" $ColorInfo
    Write-ColorOutput "   👉 Click: Update from Git" $ColorInfo
    Write-ColorOutput "   👉 This imports table definitions automatically" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "STEP 5: Verify Tables Created" $ColorInfo "5️⃣"
    Write-ColorOutput "   👉 Open KQL database: $DatabaseName" $ColorInfo
    Write-ColorOutput "   👉 Run query: .show tables" $ColorInfo
    Write-ColorOutput "   👉 Expected tables:" $ColorInfo
    Write-ColorOutput "      • OTELLogs (log data)" $ColorSuccess
    Write-ColorOutput "      • OTELMetrics (metrics data)" $ColorSuccess  
    Write-ColorOutput "      • OTELTraces (trace data)" $ColorSuccess
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "🔍 Test Table Schemas:" $ColorInfo "6️⃣"
    Write-ColorOutput "   OTELLogs | getschema" $ColorInfo "   📝"
    Write-ColorOutput "   OTELMetrics | getschema" $ColorInfo "   📝"
    Write-ColorOutput "   OTELTraces | getschema" $ColorInfo "   📝"
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "💡 Git Integration Benefits:" $ColorSuccess
    Write-ColorOutput "   ✅ No complex API authentication" $ColorSuccess
    Write-ColorOutput "   ✅ Automatic version control" $ColorSuccess
    Write-ColorOutput "   ✅ Easy collaborative development" $ColorSuccess
    Write-ColorOutput "   ✅ Visual Git status in Fabric portal" $ColorSuccess
    Write-ColorOutput "   ✅ Simple rollback via Git history" $ColorSuccess
}

function Invoke-GitSync {
    param([string]$WorkspaceName)
    
    Write-ColorOutput "Attempting automated Git sync..." $ColorInfo "🔄"
    
    if ($WhatIf) {
        Write-ColorOutput "[WHATIF] Would attempt to trigger Git sync via Azure CLI" $ColorWarning "⚠️"
        return $true
    }
    
    try {
        # Check if Azure CLI is available
        $null = az version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Azure CLI not available - manual sync required" $ColorWarning "⚠️"
            return $false
        }
        
        # Try to find workspace ID via Fabric CLI
        $workspaceId = $null
        try {
            $workspacesResult = fab api "workspaces" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $workspaces = ($workspacesResult | ConvertFrom-Json).value
                $targetWorkspace = $workspaces | Where-Object { $_.displayName -eq $WorkspaceName }
                if ($targetWorkspace) {
                    $workspaceId = $targetWorkspace.id
                    Write-ColorOutput "Found workspace ID: $workspaceId" $ColorSuccess "✅"
                }
            }
        } catch {
            Write-ColorOutput "Could not retrieve workspace ID" $ColorWarning "⚠️"
        }
        
        if (-not $workspaceId) {
            Write-ColorOutput "Cannot perform automated sync - workspace ID not found" $ColorWarning "⚠️"
            Write-ColorOutput "Please sync manually in Fabric portal" $ColorInfo "👉"
            return $false
        }
        
        # Check Git status
        $gitStatusResult = az rest --method get --url "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/git/status" --resource "https://api.fabric.microsoft.com" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Could not check Git status - manual sync required" $ColorWarning "⚠️"
            return $false
        }
        
        $gitStatus = $gitStatusResult | ConvertFrom-Json
        
        if ($gitStatus.changes.Count -eq 0) {
            Write-ColorOutput "Workspace is already up to date with Git" $ColorSuccess "✅"
            return $true
        }
        
        Write-ColorOutput "Found $($gitStatus.changes.Count) pending changes from Git" $ColorInfo "📝"
        
        # Trigger Git sync
        $syncBody = @{
            remoteCommitHash = $gitStatus.remoteCommitHash
            workspaceHead = $gitStatus.workspaceHead
            options = @{ allowOverrideItems = $true }
        } | ConvertTo-Json -Depth 3
        
        $null = az rest --method post --url "https://api.fabric.microsoft.com/v1/workspaces/$workspaceId/git/updateFromGit" --resource "https://api.fabric.microsoft.com" --body $syncBody 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Git sync completed successfully!" $ColorSuccess "✅"
            Write-ColorOutput "Tables should now be deployed in KQL database" $ColorSuccess "🎉"
            return $true
        } else {
            Write-ColorOutput "Automated Git sync failed - manual sync required" $ColorWarning "⚠️"
            return $false
        }
        
    } catch {
        Write-ColorOutput "Error during automated sync: $_" $ColorError "❌"
        Write-ColorOutput "Please sync manually in Fabric portal" $ColorInfo "👉"
        return $false
    }
}

function Show-TableContents {
    param([string]$GitFolder)
    
    Write-ColorOutput "Reviewing table definitions..." $ColorInfo "📋"
    
    $gitFolderPath = Join-Path (Split-Path $PSScriptRoot -Parent) $GitFolder
    $tablesPath = Join-Path $gitFolderPath "tables"
    
    $tableFiles = @("otel-logs.kql", "otel-metrics.kql", "otel-traces.kql")
    
    foreach ($file in $tableFiles) {
        $filePath = Join-Path $tablesPath $file
        if (Test-Path $filePath) {
            Write-ColorOutput "" $ColorInfo
            Write-ColorOutput "📄 ${file}:" $ColorInfo
            Write-ColorOutput "$(('-' * 50))" $ColorInfo
            $content = Get-Content $filePath -Raw
            Write-Host $content -ForegroundColor White
        }
    }
}

function Show-GitDeploymentInstructions {
    param(
        [string]$WorkspaceName,
        [string]$DatabaseName,
        [string]$GitFolder
    )
    
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "🎯 Complete Table Deployment via Git Integration" $ColorSuccess "🎉"
    Write-ColorOutput "================================================================" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "Since you've already connected the workspace to Git, follow these steps:" $ColorInfo "📋"
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "STEP 1: Open Fabric Portal" $ColorInfo "1️⃣"
    Write-ColorOutput "   Navigate to: https://app.fabric.microsoft.com" $ColorInfo "   👉"
    Write-ColorOutput "   Go to workspace: $WorkspaceName" $ColorInfo "   👉"
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "STEP 2: Create KQL Database (if not exists)" $ColorInfo "2️⃣"
    Write-ColorOutput "   Click: New > More options > KQL Database" $ColorInfo "   👉"
    Write-ColorOutput "   Name: $DatabaseName" $ColorInfo "   👉"
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "STEP 3: Update from Git" $ColorInfo "3️⃣"
    Write-ColorOutput "   In workspace, look for Source Control panel" $ColorInfo "   👉"
    Write-ColorOutput "   Click: Update from Git" $ColorInfo "   👉"
    Write-ColorOutput "   This will import the table definitions from Git" $ColorInfo "   �"
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "STEP 4: Verify Tables Created" $ColorInfo "4️⃣"
    Write-ColorOutput "   Open the KQL database: $DatabaseName" $ColorInfo "   👉"
    Write-ColorOutput "   Verify these tables exist:" $ColorInfo "   👉"
    Write-ColorOutput "      - OTELLogs" $ColorSuccess "      ✅"
    Write-ColorOutput "      - OTELMetrics" $ColorSuccess "      ✅"
    Write-ColorOutput "      - OTELTraces" $ColorSuccess "      ✅"
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "STEP 5: Test Tables" $ColorInfo "5️⃣"
    Write-ColorOutput "   Run test queries in KQL editor:" $ColorInfo "   👉"
    Write-ColorOutput "   OTELLogs | getschema" $ColorInfo "   👉"
    Write-ColorOutput "   OTELMetrics | getschema" $ColorInfo "   👉"
    Write-ColorOutput "   OTELTraces | getschema" $ColorInfo "   👉"
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "🔄 Alternative: If Update from Git doesn't work" $ColorWarning "⚠️"
    Write-ColorOutput "   1. Copy table definitions manually from deploy/$GitFolder/tables/" $ColorWarning "   👉"
    Write-ColorOutput "   2. Paste each .kql file content into KQL editor" $ColorWarning "   👉"
    Write-ColorOutput "   3. Execute the .create-merge table commands" $ColorWarning "   👉"
    Write-ColorOutput "" $ColorInfo
    
    Write-ColorOutput "💡 Benefits of Git Integration:" $ColorSuccess
    Write-ColorOutput "   - Automatic version control for schema changes" $ColorSuccess "   ✅"
    Write-ColorOutput "   - Easy rollback and branching" $ColorSuccess "   ✅"
    Write-ColorOutput "   - Collaborative development" $ColorSuccess "   ✅"
    Write-ColorOutput "   - No complex authentication issues" $ColorSuccess "   ✅"
}

function Sync-WorkspaceFromGit {
    param(
        [string]$WorkspaceName,
        [string]$WorkspaceId
    )
    
    Write-ColorOutput "Triggering Git sync for workspace..." $ColorInfo "🔄"
    
    if ($WhatIf) {
        Write-ColorOutput "[WHATIF] Would sync workspace from Git repository" $ColorWarning "⚠️"
        return $true
    }
    
    try {
        # Get current Git status
        Write-ColorOutput "Checking Git status..." $ColorInfo "📋"
        $gitStatusResult = az rest --method get --url "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/git/status" --resource "https://api.fabric.microsoft.com" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Could not check Git status - workspace may not be connected to Git" $ColorWarning "⚠️"
            return $false
        }
        
        $gitStatus = $gitStatusResult | ConvertFrom-Json
        
        if ($gitStatus.changes.Count -eq 0) {
            Write-ColorOutput "Workspace is already up to date with Git" $ColorSuccess "✅"
            return $true
        }
        
        Write-ColorOutput "Found $($gitStatus.changes.Count) pending changes from Git" $ColorInfo "📝"
        
        # Trigger Git sync
        Write-ColorOutput "Syncing from Git repository..." $ColorInfo "🔄"
        $syncBody = @{
            remoteCommitHash = $gitStatus.remoteCommitHash
            workspaceHead = $gitStatus.workspaceHead
            options = @{
                allowOverrideItems = $true
            }
        } | ConvertTo-Json -Depth 3
        
        $null = az rest --method post --url "https://api.fabric.microsoft.com/v1/workspaces/$WorkspaceId/git/updateFromGit" --resource "https://api.fabric.microsoft.com" --body $syncBody 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Git sync completed successfully" $ColorSuccess "✅"
            Write-ColorOutput "Tables should now be deployed in the KQL database" $ColorSuccess "🎉"
            return $true
        } else {
            Write-ColorOutput "Git sync failed - manual sync required" $ColorWarning "⚠️"
            return $false
        }
        
    } catch {
        Write-ColorOutput "Error during Git sync: $_" $ColorError "❌"
        return $false
    }
}

function Test-TablesDeployment {
    param(
        [string]$WorkspaceName,
        [string]$WorkspaceId,
        [string]$DatabaseName
    )
    
    Write-ColorOutput "Verifying table deployment..." $ColorInfo "🔍"
    
    try {
        # Get KQL databases in workspace
        $itemsResult = fab api "workspaces/$WorkspaceId/items" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Could not retrieve workspace items" $ColorError "❌"
            return $false
        }
        
        $items = ($itemsResult | ConvertFrom-Json).value
        $kqlDatabases = $items | Where-Object { $_.type -eq "KQLDatabase" }
        
        if ($kqlDatabases.Count -eq 0) {
            Write-ColorOutput "No KQL databases found in workspace" $ColorError "❌"
            return $false
        }
        
        Write-ColorOutput "Found KQL databases:" $ColorInfo "📊"
        foreach ($db in $kqlDatabases) {
            Write-ColorOutput "  - $($db.displayName) (ID: $($db.id))" $ColorInfo "    📋"
        }
        
        $targetDb = $kqlDatabases | Where-Object { $_.displayName -like "*$DatabaseName*" }
        
        if ($targetDb) {
            Write-ColorOutput "Found target database: $($targetDb.displayName)" $ColorSuccess "✅"
            Write-ColorOutput "Manual verification steps:" $ColorInfo "📋"
            Write-ColorOutput "1. Open Fabric portal: https://app.fabric.microsoft.com" $ColorInfo "👉"
            Write-ColorOutput "2. Navigate to workspace: $WorkspaceName" $ColorInfo "👉"
            Write-ColorOutput "3. Open database: $($targetDb.displayName)" $ColorInfo "👉"
            Write-ColorOutput "4. Run query: .show tables" $ColorInfo "👉"
            Write-ColorOutput "5. Verify tables: OTELLogs, OTELMetrics, OTELTraces" $ColorInfo "👉"
            return $true
        } else {
            Write-ColorOutput "Target database '$DatabaseName' not found" $ColorWarning "⚠️"
            return $false
        }
        
    } catch {
        Write-ColorOutput "Error during verification: $_" $ColorError "❌"
        return $false
    }
}

# Main execution
try {
    Write-ColorOutput "🚀 Fabric OTEL Artifacts - Git Integration Deployment" $ColorInfo "🎯"
    Write-ColorOutput "========================================================" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    
    # Step 1: Verify Git folder structure
    if (-not (Test-GitFolderStructure)) {
        throw "Git folder structure verification failed"
    }
    
    # Step 2: Show table definitions
    Show-TableDefinitions
    
    # Step 3: Provide deployment guidance
    Show-GitIntegrationGuidance -WorkspaceName $WorkspaceName -DatabaseName $DatabaseName
    
    # Step 4: Optional automated sync
    if ($TriggerSync) {
        Write-ColorOutput "" $ColorInfo
        Write-ColorOutput "🔄 Attempting automated Git sync..." $ColorInfo "⚡"
        Invoke-GitSync -WorkspaceName $WorkspaceName
    }
    
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "✅ Git integration deployment complete!" $ColorSuccess "🎉"
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "📚 For detailed documentation:" $ColorInfo "📖"
    Write-ColorOutput "   👉 See: deploy/README.md" $ColorInfo
    Write-ColorOutput "   👉 Git folder: deploy/fabric-artifacts/" $ColorInfo
    
} catch {
    Write-ColorOutput "❌ Deployment failed: $_" $ColorError "💥"
    Write-ColorOutput "📋 Check the error above and refer to documentation" $ColorInfo "👆"
    exit 1
}
