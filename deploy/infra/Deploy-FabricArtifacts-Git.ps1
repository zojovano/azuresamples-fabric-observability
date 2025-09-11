#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Microsoft Fabric OTEL artifacts using Git integration approach
.DESCRIPTION
    This script deploys Microsoft Fabric workspace and KQL database using 
    Git integration instead of complex API calls. This approach is more reliable
    and follows Microsoft's recommended patterns.
    
    Use -CompleteDeployment when the workspace is already connected to Git
    and you need to complete the table deployment process.
.PARAMETER WorkspaceName
    Name of the Fabric workspace (default: fabric-otel-workspace)
.PARAMETER DatabaseName  
    Name of the KQL database (default: otelobservabilitydb)
.PARAMETER GitFolder
    Folder in the repository to connect to (default: fabric-artifacts, resolves to deploy/fabric-artifacts)
.PARAMETER WhatIf
    Show what would be deployed without actually deploying
.PARAMETER CompleteDeployment
    Use this when workspace is already connected to Git and you need to complete table deployment
.EXAMPLE
    ./Deploy-FabricArtifacts-Git.ps1 -WhatIf
.EXAMPLE  
    ./Deploy-FabricArtifacts-Git.ps1 -WorkspaceName "my-workspace"
.EXAMPLE
    ./Deploy-FabricArtifacts-Git.ps1 -CompleteDeployment
#>

param(
    [string]$WorkspaceName = "fabric-otel-workspace",
    [string]$DatabaseName = "otelobservabilitydb", 
    [string]$GitFolder = "fabric-artifacts",
    [switch]$WhatIf,
    [switch]$CompleteDeployment
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

function Test-FabricAuthentication {
    Write-ColorOutput "Checking Fabric authentication..." $ColorInfo "🔐"
    
    $null = fab auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Not authenticated with Fabric CLI" $ColorError "❌"
        Write-ColorOutput "Please run: fab auth login" $ColorInfo "💡"
        return $false
    }
    
    Write-ColorOutput "Fabric CLI authentication successful" $ColorSuccess "✅"
    return $true
}

function Test-GitFolderStructure {
    param([string]$GitFolder)
    
    Write-ColorOutput "Verifying Git folder structure..." $ColorInfo "📁"
    
    $gitFolderPath = Join-Path (Split-Path $PSScriptRoot -Parent) $GitFolder
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

function Copy-KqlDefinitionsToGitFolder {
    param(
        [string]$GitFolder
    )
    
    Write-ColorOutput "Copying KQL definitions to Git folder..." $ColorInfo "📁"
    
    $gitFolderPath = Join-Path (Split-Path $PSScriptRoot -Parent) $GitFolder
    $kqlDefinitionsPath = Join-Path $PSScriptRoot "kql-definitions"
    
    if (-not (Test-Path $gitFolderPath)) {
        New-Item -ItemType Directory -Path $gitFolderPath -Force | Out-Null
        Write-ColorOutput "Created Git folder: $gitFolderPath" $ColorSuccess "✅"
    }
    
    if (Test-Path $kqlDefinitionsPath) {
        # Copy KQL table definitions
        $tableDefinitionsPath = Join-Path $kqlDefinitionsPath "tables"
        if (Test-Path $tableDefinitionsPath) {
            $gitTablesPath = Join-Path $gitFolderPath "tables"
            if (-not (Test-Path $gitTablesPath)) {
                New-Item -ItemType Directory -Path $gitTablesPath -Force | Out-Null
            }
            
            if ($WhatIf) {
                Write-ColorOutput "[WHATIF] Would copy KQL table definitions to: $gitTablesPath" $ColorWarning "⚠️"
            } else {
                Copy-Item -Path "$tableDefinitionsPath/*" -Destination $gitTablesPath -Force
                Write-ColorOutput "Copied KQL table definitions to Git folder" $ColorSuccess "✅"
            }
        }
        
        # Create README for Git folder
        $readmeContent = @"
# Fabric OTEL Observability - Git Integration

This folder contains Microsoft Fabric artifacts that are synchronized with the workspace via Git integration.

## Structure

- `tables/` - KQL table definitions for OTEL data (Logs, Metrics, Traces)

## Deployment Process

1. KQL tables are defined in `.kql` files
2. Workspace is connected to this Git repository folder
3. Changes are committed from Fabric workspace to Git
4. Updates flow from Git to workspace automatically

## Tables

- **OTELLogs** - OpenTelemetry log data
- **OTELMetrics** - OpenTelemetry metrics data  
- **OTELTraces** - OpenTelemetry trace data

## Usage

Use Fabric portal to:
1. Edit KQL database items
2. Commit changes to Git
3. Update workspace from Git when changes are made externally
"@
        
        $readmePath = Join-Path $gitFolderPath "README.md"
        if ($WhatIf) {
            Write-ColorOutput "[WHATIF] Would create README.md in Git folder" $ColorWarning "⚠️"
        } else {
            $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
            Write-ColorOutput "Created README.md in Git folder" $ColorSuccess "✅"
        }
    }
    
    return $true
}

function Show-NextSteps {
    param(
        [string]$WorkspaceName,
        [string]$DatabaseName,
        [string]$GitFolder
    )
    
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "🎯 Git Integration Setup Complete!" $ColorSuccess "🎉"
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "Next Steps:" $ColorInfo "📋"
    Write-ColorOutput "1. Open Fabric portal: https://app.fabric.microsoft.com" $ColorInfo "👉"
    Write-ColorOutput "2. Navigate to workspace: $WorkspaceName" $ColorInfo "👉"
    Write-ColorOutput "3. Create KQL database: $DatabaseName" $ColorInfo "👉"
    Write-ColorOutput "4. Go to Workspace Settings > Git Integration" $ColorInfo "👉"
    Write-ColorOutput "5. Connect to GitHub repository: $(git remote get-url origin 2>/dev/null)" $ColorInfo "👉"
    Write-ColorOutput "6. Set folder to: deploy/$GitFolder" $ColorInfo "👉"
    Write-ColorOutput "7. Sync workspace with Git (commit/update as needed)" $ColorInfo "👉"
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "Benefits of Git Integration:" $ColorSuccess "💡"
    Write-ColorOutput "- Automatic versioning and backup" $ColorSuccess "✅"
    Write-ColorOutput "- Reliable deployment process" $ColorSuccess "✅"
    Write-ColorOutput "- No complex API calls needed" $ColorSuccess "✅"
    Write-ColorOutput "- Visual Git status in Fabric portal" $ColorSuccess "✅"
    Write-ColorOutput "- Branch-based development workflows" $ColorSuccess "✅"
}

# Main execution
try {
    Write-ColorOutput "🚀 Starting Fabric OTEL Artifacts Deployment (Git Integration)" $ColorInfo
    Write-ColorOutput "================================================================" $ColorInfo
    
    # Test authentication
    if (-not (Test-FabricAuthentication)) {
        throw "Fabric authentication failed"
    }
    
    # Verify Git folder structure
    if (-not (Test-GitFolderStructure -GitFolder $GitFolder)) {
        throw "Git folder structure verification failed"
    }
    
    if ($CompleteDeployment) {
        Write-ColorOutput "🎯 Completing table deployment..." $ColorInfo
        
        # Show table contents for review
        Show-TableContents -GitFolder $GitFolder
        
        # Show deployment instructions
        Show-GitDeploymentInstructions -WorkspaceName $WorkspaceName -DatabaseName $DatabaseName -GitFolder $GitFolder
        
    } else {
        # Original setup logic for first-time Git integration
        
        # Copy KQL definitions to Git folder (if needed)
        if (-not (Copy-KqlDefinitionsToGitFolder -GitFolder $GitFolder)) {
            throw "Failed to copy KQL definitions to Git folder"
        }
        
        # Show next steps for initial setup
        Show-NextSteps -WorkspaceName $WorkspaceName -DatabaseName $DatabaseName -GitFolder $GitFolder
    }
    
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "✅ Git integration deployment guidance complete!" $ColorSuccess "🎉"
    
} catch {
    Write-ColorOutput "❌ Deployment failed: $_" $ColorError
    exit 1
}
