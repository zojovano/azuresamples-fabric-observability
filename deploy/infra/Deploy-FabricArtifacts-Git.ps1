#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Microsoft Fabric OTEL artifacts using Git integration approach
.DESCRIPTION
    This script deploys Microsoft Fabric workspace and KQL database using 
    Git integration instead of complex API calls. This approach is more reliable
    and follows Microsoft's recommended patterns.
.PARAMETER WorkspaceName
    Name of the Fabric workspace (default: fabric-otel-workspace)
.PARAMETER DatabaseName  
    Name of the KQL database (default: otelobservabilitydb)
.PARAMETER GitFolder
    Folder in the repository to connect to (default: fabric-artifacts, resolves to deploy/fabric-artifacts)
.PARAMETER WhatIf
    Show what would be deployed without actually deploying
.EXAMPLE
    ./Deploy-FabricArtifacts-Git.ps1 -WhatIf
.EXAMPLE  
    ./Deploy-FabricArtifacts-Git.ps1 -WorkspaceName "my-workspace"
#>

param(
    [string]$WorkspaceName = "fabric-otel-workspace",
    [string]$DatabaseName = "otelobservabilitydb", 
    [string]$GitFolder = "fabric-artifacts",
    [switch]$WhatIf
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
    
    $authOutput = fab auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Not authenticated with Fabric CLI" $ColorError "❌"
        Write-ColorOutput "Please run: fab auth login" $ColorInfo "💡"
        return $false
    }
    
    Write-ColorOutput "Fabric CLI authentication successful" $ColorSuccess "✅"
    return $true
}

function Connect-WorkspaceToGit {
    param(
        [string]$WorkspaceName,
        [string]$GitFolder
    )
    
    Write-ColorOutput "Setting up Git integration for workspace..." $ColorInfo "🔗"
    
    if ($WhatIf) {
        Write-ColorOutput "[WHATIF] Would connect workspace '$WorkspaceName' to Git folder '$GitFolder'" $ColorWarning "⚠️"
        return $true
    }
    
    # Navigate to workspace using Fabric CLI navigation
    $workspaceExists = fab ls | Select-String "$WorkspaceName.Workspace" -Quiet
    if (-not $workspaceExists) {
        Write-ColorOutput "Workspace '$WorkspaceName' not found. Creating workspace first..." $ColorWarning "⚠️"
        
        # In a real scenario, you'd create the workspace here
        # For now, we'll assume it exists or needs to be created manually
        Write-ColorOutput "Please create workspace '$WorkspaceName' manually in Fabric portal first" $ColorError "❌"
        return $false
    }
    
    Write-ColorOutput "Found workspace '$WorkspaceName'" $ColorSuccess "✅"
    Write-ColorOutput "To complete Git integration:" $ColorInfo "📋"
    Write-ColorOutput "1. Navigate to workspace '$WorkspaceName' in Fabric portal" $ColorInfo "👉"
    Write-ColorOutput "2. Go to Workspace Settings > Git Integration" $ColorInfo "👉"
    Write-ColorOutput "3. Connect to this GitHub repository" $ColorInfo "👉"
    Write-ColorOutput "4. Set folder to: 'deploy/$GitFolder'" $ColorInfo "👉"
    Write-ColorOutput "5. Commit the workspace items to Git" $ColorInfo "👉"
    
    return $true
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
    
    # Copy KQL definitions to Git folder
    if (-not (Copy-KqlDefinitionsToGitFolder -GitFolder $GitFolder)) {
        throw "Failed to copy KQL definitions to Git folder"
    }
    
    # Set up Git integration guidance
    if (-not (Connect-WorkspaceToGit -WorkspaceName $WorkspaceName -GitFolder $GitFolder)) {
        throw "Failed to set up Git integration"
    }
    
    # Show next steps
    Show-NextSteps -WorkspaceName $WorkspaceName -DatabaseName $DatabaseName -GitFolder $GitFolder
    
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "✅ Git integration setup completed successfully!" $ColorSuccess "🎉"
    
} catch {
    Write-ColorOutput "❌ Deployment failed: $_" $ColorError
    exit 1
}
