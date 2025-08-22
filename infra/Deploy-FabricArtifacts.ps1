#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploy Fabric Artifacts using Fabric CLI

.DESCRIPTION
    This script deploys KQL tables and other Fabric artifacts to Microsoft Fabric.
    It handles workspace creation, database setup, and table deployment.

.PARAMETER WorkspaceName
    Name of the Fabric workspace (default: fabric-otel-workspace)

.PARAMETER DatabaseName  
    Name of the KQL database (default: otelobservabilitydb)

.PARAMETER ResourceGroupName
    Azure resource group name (default: azuresamples-platformobservabilty-fabric)

.PARAMETER Location
    Azure region (default: swedencentral)

.PARAMETER SkipAuth
    Skip Fabric authentication (useful if already authenticated)

.EXAMPLE
    .\Deploy-FabricArtifacts.ps1
    
.EXAMPLE
    .\Deploy-FabricArtifacts.ps1 -WorkspaceName "my-workspace" -DatabaseName "mydb"

.NOTES
    Author: Generated for Azure Samples - Fabric Observability Project
    Requires: Microsoft Fabric CLI (fab), Azure CLI
#>

[CmdletBinding()]
param(
    [string]$WorkspaceName = $env:FABRIC_WORKSPACE_NAME ?? "fabric-otel-workspace",
    [string]$DatabaseName = $env:FABRIC_DATABASE_NAME ?? "otelobservabilitydb", 
    [string]$ResourceGroupName = $env:RESOURCE_GROUP_NAME ?? "azuresamples-platformobservabilty-fabric",
    [string]$Location = $env:LOCATION ?? "swedencentral",
    [switch]$SkipAuth
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
        [string]$Prefix = ""
    )
    if ($Prefix) {
        Write-Host "$Prefix " -NoNewline -ForegroundColor $Color
    }
    Write-Host $Message -ForegroundColor $Color
}

function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-Prerequisites {
    Write-ColorOutput "Checking prerequisites..." $ColorInfo "🔍"
    
    # Check Fabric CLI
    if (-not (Test-CommandExists "fab")) {
        Write-ColorOutput "Fabric CLI (fab) is not installed" $ColorError "❌"
        Write-ColorOutput "Installing Fabric CLI..." $ColorWarning "📦"
        
        try {
            python -m pip install ms-fabric-cli
            if (-not (Test-CommandExists "fab")) {
                throw "Fabric CLI installation failed"
            }
            
            # Configure Fabric CLI for CI/CD environment after installation
            Write-ColorOutput "Configuring Fabric CLI for CI/CD environment..." $ColorInfo "⚙️"
            fab config set encryption_fallback_enabled true
            
        } catch {
            Write-ColorOutput "Failed to install Fabric CLI: $_" $ColorError "❌"
            exit 1
        }
    }
    
    # Check Azure CLI
    if (-not (Test-CommandExists "az")) {
        Write-ColorOutput "Azure CLI is not installed" $ColorError "❌"
        exit 1
    }
    
    Write-ColorOutput "Prerequisites check passed" $ColorSuccess "✅"
}

function Connect-Fabric {
    if ($SkipAuth) {
        Write-ColorOutput "Skipping Fabric authentication" $ColorWarning "⏭️"
        return
    }
    
    Write-ColorOutput "Authenticating with Microsoft Fabric..." $ColorInfo "🔐"
    
    # Check if already authenticated
    try {
        $authStatus = fab auth status 2>$null
        if ($LASTEXITCODE -eq 0 -and $authStatus -and $authStatus -notmatch "Not logged in") {
            Write-ColorOutput "Already authenticated with Fabric" $ColorSuccess "✅"
            return
        }
    } catch {
        # Continue with authentication
    }
    
    # Use service principal authentication in CI/CD
    $clientId = $env:AZURE_CLIENT_ID
    $clientSecret = $env:AZURE_CLIENT_SECRET  
    $tenantId = $env:AZURE_TENANT_ID
    
    if ($clientId -and $clientSecret -and $tenantId) {
        Write-ColorOutput "Using service principal authentication..." $ColorInfo "🔑"
        
        # Enable plaintext auth token fallback to avoid encryption issues in CI/CD
        Write-ColorOutput "Configuring Fabric CLI for CI/CD environment..." $ColorInfo "⚙️"
        fab config set encryption_fallback_enabled true
        
        # Clear any cached authentication state first
        fab config clear-cache
        
        # Attempt authentication with service principal
        fab auth login -u $clientId -p $clientSecret -t $tenantId
        
        # Check if login command succeeded
        if ($LASTEXITCODE -ne 0) {
            throw "Fabric authentication login failed with exit code: $LASTEXITCODE"
        }
        
    } else {
        Write-ColorOutput "Using interactive authentication..." $ColorInfo "🌐"
        fab auth login
    }
    
    # Verify authentication
    try {
        Write-ColorOutput "Verifying authentication..." $ColorInfo "🔍"
        
        # Give a moment for authentication to settle
        Start-Sleep -Seconds 2
        
        $authStatus = fab auth status 2>&1
        $authExitCode = $LASTEXITCODE
        
        Write-ColorOutput "Auth status exit code: $authExitCode" $ColorInfo "🔧"
        
        if ($authExitCode -eq 0 -and $authStatus -and $authStatus -notmatch "Not logged in") {
            Write-ColorOutput "Successfully authenticated with Fabric" $ColorSuccess "✅"
            # Extract account info from status output
            $accountLine = $authStatus | Select-String "Account:" | ForEach-Object { $_.Line }
            if ($accountLine) {
                Write-ColorOutput "Auth Info: $accountLine" $ColorInfo "👤"
            }
            
            # Test a simple Fabric CLI command to ensure permissions work
            Write-ColorOutput "Testing basic Fabric CLI permissions..." $ColorInfo "🧪"
            $testOutput = fab workspace list --output json 2>&1
            $testExitCode = $LASTEXITCODE
            
            if ($testExitCode -eq 0) {
                # Try to parse as JSON to make sure it's valid
                try {
                    $testOutput | ConvertFrom-Json -ErrorAction Stop | Out-Null
                    Write-ColorOutput "Basic Fabric CLI permissions verified" $ColorSuccess "✅"
                } catch {
                    Write-ColorOutput "Fabric CLI responding but with invalid JSON - possible permission issue" $ColorWarning "⚠️"
                    Write-ColorOutput "Test output: $testOutput" $ColorWarning
                }
            } else {
                Write-ColorOutput "Basic Fabric CLI test failed (exit code: $testExitCode)" $ColorWarning "⚠️"
                Write-ColorOutput "Test output: $testOutput" $ColorWarning
                Write-ColorOutput "This may indicate limited permissions or Fabric capacity issues" $ColorWarning
            }
        } else {
            Write-ColorOutput "Authentication verification failed. Exit code: $authExitCode" $ColorError "❌"
            Write-ColorOutput "Auth Status Output:" $ColorWarning "🔍"
            $authStatus | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            
            # If auth status fails, it might be due to bad stored credentials
            if ($authExitCode -ne 0) {
                Write-ColorOutput "Clearing cached auth state and retrying..." $ColorWarning "🔄"
                fab config clear-cache
                fab auth logout 2>$null | Out-Null
                
                # Try status again after cleanup
                $authStatusRetry = fab auth status 2>&1
                $retryExitCode = $LASTEXITCODE
                
                if ($retryExitCode -eq 0 -and $authStatusRetry -match "Not logged in") {
                    Write-ColorOutput "Authentication state cleaned, but still not logged in" $ColorError "❌"
                } else {
                    Write-ColorOutput "Auth status still failing after cleanup: $authStatusRetry" $ColorError "❌"
                }
            }
            
            throw "Authentication verification failed (exit code: $authExitCode)"
        }
    } catch {
        Write-ColorOutput "Failed to authenticate with Fabric: $_" $ColorError "❌"
        Write-ColorOutput "Troubleshooting suggestions:" $ColorWarning "💡"
        Write-ColorOutput "1. Verify service principal has 'Fabric APIs' permission enabled" $ColorWarning
        Write-ColorOutput "2. Check that AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID are correct" $ColorWarning
        Write-ColorOutput "3. Ensure service principal has access to Microsoft Fabric" $ColorWarning
        Write-ColorOutput "4. Check Azure AD tenant settings allow service principals" $ColorWarning
        exit 1
    }
}

function Get-FabricCapacity {
    Write-ColorOutput "Getting Fabric capacity information..." $ColorInfo "🔍"
    
    try {
        $capacity = az resource list --resource-group $ResourceGroupName --resource-type "Microsoft.Fabric/capacities" --query "[0].name" --output tsv 2>$null
        
        if (-not $capacity -or $capacity -eq "null" -or $capacity -eq "") {
            Write-ColorOutput "No Fabric capacity found in resource group: $ResourceGroupName" $ColorError "❌"
            Write-ColorOutput "Make sure the Azure infrastructure has been deployed first" $ColorWarning "💡"
            exit 1
        }
        
        $script:CapacityName = $capacity
        Write-ColorOutput "Found Fabric capacity: $CapacityName" $ColorSuccess "✅"
        
    } catch {
        Write-ColorOutput "Failed to get Fabric capacity: $_" $ColorError "❌"
        exit 1
    }
}

function New-OrGetWorkspace {
    Write-ColorOutput "Creating or getting Fabric workspace..." $ColorInfo "🏗️"
    
    try {
        # Check if workspace exists - capture both stdout and stderr
        Write-ColorOutput "Checking existing workspaces..." $ColorInfo "🔍"
        $workspaceOutput = fab workspace list --output json 2>&1
        $listExitCode = $LASTEXITCODE
        
        Write-ColorOutput "Workspace list exit code: $listExitCode" $ColorInfo "🔧"
        
        if ($listExitCode -ne 0) {
            Write-ColorOutput "Failed to list workspaces (exit code: $listExitCode)" $ColorError "❌"
            Write-ColorOutput "Workspace list output:" $ColorWarning "🔍"
            $workspaceOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            throw "Unable to list workspaces - check Fabric CLI authentication and permissions"
        }
        
        # Check if output is valid JSON
        try {
            $workspaces = $workspaceOutput | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-ColorOutput "Invalid JSON response from workspace list:" $ColorError "❌"
            Write-ColorOutput "Raw output:" $ColorWarning "🔍"
            $workspaceOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            
            # Check for common error patterns
            if ($workspaceOutput -match "!" -or $workspaceOutput -match "Error" -or $workspaceOutput -match "Failed") {
                Write-ColorOutput "Fabric CLI returned an error instead of JSON" $ColorError "❌"
                Write-ColorOutput "This usually indicates authentication or permission issues" $ColorWarning "💡"
                Write-ColorOutput "Troubleshooting suggestions:" $ColorWarning "💡"
                Write-ColorOutput "1. Verify you're authenticated with 'fab auth status'" $ColorWarning
                Write-ColorOutput "2. Check service principal has proper Fabric permissions" $ColorWarning
                Write-ColorOutput "3. Ensure the Fabric capacity is available and accessible" $ColorWarning
            }
            
            throw "Invalid JSON response from Fabric CLI workspace list"
        }
        
        $existingWorkspace = $workspaces | Where-Object { $_.displayName -eq $WorkspaceName }
        
        if ($existingWorkspace) {
            Write-ColorOutput "Workspace '$WorkspaceName' already exists" $ColorSuccess "✅"
            return
        }
        
        # Create new workspace
        Write-ColorOutput "Creating new workspace: $WorkspaceName" $ColorInfo "🆕"
        $createOutput = fab workspace create --display-name $WorkspaceName --description "Workspace for OpenTelemetry observability data" --capacity-id $script:CapacityName 2>&1
        $createExitCode = $LASTEXITCODE
        
        if ($createExitCode -eq 0) {
            Write-ColorOutput "Successfully created workspace: $WorkspaceName" $ColorSuccess "✅"
        } else {
            Write-ColorOutput "Workspace creation failed (exit code: $createExitCode)" $ColorError "❌"
            Write-ColorOutput "Create output:" $ColorWarning "🔍"
            $createOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            throw "Workspace creation failed"
        }
        
    } catch {
        Write-ColorOutput "Failed to create workspace: $_" $ColorError "❌"
        exit 1
    }
}

function New-KqlDatabase {
    Write-ColorOutput "Creating KQL database..." $ColorInfo "🗄️"
    
    try {
        # Set workspace context
        Write-ColorOutput "Setting workspace context to: $WorkspaceName" $ColorInfo "🔗"
        $useWorkspaceOutput = fab workspace use --name $WorkspaceName 2>&1
        $useExitCode = $LASTEXITCODE
        
        if ($useExitCode -ne 0) {
            Write-ColorOutput "Failed to set workspace context (exit code: $useExitCode)" $ColorError "❌"
            Write-ColorOutput "Use workspace output:" $ColorWarning "🔍"
            $useWorkspaceOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            throw "Unable to set workspace context"
        }
        
        # Check if database exists - capture both stdout and stderr
        Write-ColorOutput "Checking existing databases..." $ColorInfo "🔍"
        $databaseOutput = fab kqldatabase list --output json 2>&1
        $listExitCode = $LASTEXITCODE
        
        Write-ColorOutput "Database list exit code: $listExitCode" $ColorInfo "🔧"
        
        if ($listExitCode -ne 0) {
            Write-ColorOutput "Failed to list databases (exit code: $listExitCode)" $ColorError "❌"
            Write-ColorOutput "Database list output:" $ColorWarning "🔍"
            $databaseOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            throw "Unable to list databases - check workspace access and permissions"
        }
        
        # Check if output is valid JSON
        try {
            $databases = $databaseOutput | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-ColorOutput "Invalid JSON response from database list:" $ColorError "❌"
            Write-ColorOutput "Raw output:" $ColorWarning "🔍"
            $databaseOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            throw "Invalid JSON response from Fabric CLI database list"
        }
        
        $existingDatabase = $databases | Where-Object { $_.displayName -eq $DatabaseName }
        
        if ($existingDatabase) {
            Write-ColorOutput "KQL database '$DatabaseName' already exists" $ColorSuccess "✅"
            return
        }
        
        # Create KQL database
        Write-ColorOutput "Creating KQL database: $DatabaseName" $ColorInfo "🆕"
        $createOutput = fab kqldatabase create --display-name $DatabaseName --description "KQL Database for OpenTelemetry observability data" 2>&1
        $createExitCode = $LASTEXITCODE
        
        if ($createExitCode -eq 0) {
            Write-ColorOutput "Successfully created KQL database: $DatabaseName" $ColorSuccess "✅"
        } else {
            Write-ColorOutput "Database creation failed (exit code: $createExitCode)" $ColorError "❌"
            Write-ColorOutput "Create output:" $ColorWarning "🔍"
            $createOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            throw "Database creation failed"
        }
        
    } catch {
        Write-ColorOutput "Failed to create KQL database: $_" $ColorError "❌"
        exit 1
    }
}

function Deploy-KqlTables {
    Write-ColorOutput "Deploying KQL tables..." $ColorInfo "📊"
    
    try {
        # Set database context
        fab kqldatabase use --name $DatabaseName
        
        # Determine KQL directory path
        $kqlDir = if ($env:GITHUB_WORKSPACE) {
            Join-Path $env:GITHUB_WORKSPACE "infra/kql-definitions/tables"
        } else {
            Join-Path $PSScriptRoot "../kql-definitions/tables"
        }
        
        if (-not (Test-Path $kqlDir)) {
            Write-ColorOutput "KQL definitions directory not found: $kqlDir" $ColorError "❌"
            exit 1
        }
        
        # Deploy each KQL table
        $kqlFiles = Get-ChildItem -Path $kqlDir -Filter "*.kql"
        
        foreach ($kqlFile in $kqlFiles) {
            $tableName = $kqlFile.BaseName
            Write-ColorOutput "Deploying table: $tableName" $ColorInfo "📋"
            
            try {
                fab kql execute --file $kqlFile.FullName
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "Successfully deployed table: $tableName" $ColorSuccess "✅"
                } else {
                    Write-ColorOutput "Table deployment may have failed for: $tableName (table might already exist)" $ColorWarning "⚠️"
                }
            } catch {
                Write-ColorOutput "Failed to deploy table $tableName : $_" $ColorWarning "⚠️"
            }
        }
        
    } catch {
        Write-ColorOutput "Failed to deploy KQL tables: $_" $ColorError "❌"
        exit 1
    }
}

function Test-Deployment {
    Write-ColorOutput "Verifying deployment..." $ColorInfo "🔍"
    
    try {
        # List workspaces
        Write-ColorOutput "Available workspaces:" $ColorInfo "📋"
        fab workspace list --output table
        
        # List databases in workspace
        Write-ColorOutput "Databases in workspace '$WorkspaceName':" $ColorInfo "📋"
        fab workspace use --name $WorkspaceName
        fab kqldatabase list --output table
        
        # List tables in database
        Write-ColorOutput "Tables in database '$DatabaseName':" $ColorInfo "📋"
        fab kqldatabase use --name $DatabaseName
        fab kql execute --query ".show tables"
        
        Write-ColorOutput "Verification completed" $ColorSuccess "✅"
        
    } catch {
        Write-ColorOutput "Verification failed: $_" $ColorWarning "⚠️"
    }
}

function Show-ConnectionInfo {
    Write-ColorOutput "Connection Information:" $ColorInfo "🔗"
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "Workspace Name: $WorkspaceName" -ForegroundColor White
    Write-Host "Database Name: $DatabaseName" -ForegroundColor White
    Write-Host "Capacity Name: $($script:CapacityName)" -ForegroundColor White
    Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "────────────────────────────────────────" -ForegroundColor Gray
    
    Write-ColorOutput "To connect to this database:" $ColorWarning "💡"
    Write-ColorOutput "1. Open Microsoft Fabric portal: https://fabric.microsoft.com" $ColorWarning
    Write-ColorOutput "2. Navigate to workspace: $WorkspaceName" $ColorWarning
    Write-ColorOutput "3. Open KQL database: $DatabaseName" $ColorWarning
    Write-ColorOutput "4. Use the OTEL tables: OTELLogs, OTELMetrics, OTELTraces" $ColorWarning
}

# Main execution
try {
    Write-ColorOutput "Starting Fabric artifacts deployment..." $ColorSuccess "🚀"
    Write-Host "==========================================" -ForegroundColor Green
    
    # Show configuration
    Show-ConnectionInfo
    
    # Execute deployment steps
    Test-Prerequisites
    Connect-Fabric
    Get-FabricCapacity
    New-OrGetWorkspace
    New-KqlDatabase
    Deploy-KqlTables
    Test-Deployment
    
    Write-ColorOutput "Fabric artifacts deployment completed successfully!" $ColorSuccess "🎉"
    Show-ConnectionInfo
    
} catch {
    Write-ColorOutput "Script failed: $_" $ColorError "❌"
    exit 1
}
