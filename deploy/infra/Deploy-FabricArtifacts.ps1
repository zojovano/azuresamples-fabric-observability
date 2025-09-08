#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploy Fabric Artifacts using Fabric CLI

.DESCRIPTION
    This script deploys KQL tables and other Fabric artifacts to Microsoft Fabric.
    It handles workspace creation, database setup, and table deployment.
    Uses centralized configuration from config/project-config.json.

.PARAMETER WorkspaceName
    Name of the Fabric workspace (overrides configuration)

.PARAMETER DatabaseName  
    Name of the KQL database (overrides configuration)

.PARAMETER ResourceGroupName
    Azure resource group name (ov                    $executeOutput = fab api --resource-path "v1/workspaces/${WorkspaceName}/kqldatabases/${DatabaseName}/query" --method post --body "@$tempFile" 2>&1rrides configuration)

.PARAMETER Location
    Azure region (overrides configuration)

.PARAMETER SkipAuth
    Skip Fabric authentication (useful if already authenticated)

.PARAMETER UseConfig
    Use centralized configuration (default: true)

.PARAMETER SkipWorkspaceCreation
    Skip workspace creation (useful when workspace already exists or tenant settings not configured)

.EXAMPLE
    .\Deploy-FabricArtifacts.ps1
    
.EXAMPLE
    .\Deploy-FabricArtifacts.ps1 -WorkspaceName "my-workspace" -DatabaseName "mydb"

.EXAMPLE
    .\Deploy-FabricArtifacts.ps1 -SkipWorkspaceCreation

.NOTES
    Author: Generated for Azure Samples - Fabric Observability Project
    Requires: Microsoft Fabric CLI (fab), Azure CLI
#>

[CmdletBinding()]
param(
    [string]$WorkspaceName = "",
    [string]$DatabaseName = "", 
    [string]$ResourceGroupName = "",
    [string]$Location = "",
    [switch]$SkipAuth,
    [switch]$SkipWorkspaceCreation,
    [bool]$UseConfig = $true
)

# Import centralized configuration
if ($UseConfig) {
    $configModulePath = Join-Path $PSScriptRoot ".." "config" "ProjectConfig.psm1"
    if (Test-Path $configModulePath) {
        Import-Module $configModulePath -Force
        $config = Get-ProjectConfig
        
        # Use configuration values if parameters not provided
        if ([string]::IsNullOrWhiteSpace($WorkspaceName)) { $WorkspaceName = $config.fabric.workspaceName }
        if ([string]::IsNullOrWhiteSpace($DatabaseName)) { $DatabaseName = $config.fabric.databaseName }
        if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) { $ResourceGroupName = $config.azure.resourceGroupName }
        if ([string]::IsNullOrWhiteSpace($Location)) { $Location = $config.azure.location }
        
        # Set environment variables from configuration
        Set-ConfigEnvironmentVariables -Config $config
        
        Write-Host "📋 Using centralized configuration:" -ForegroundColor Cyan
        Write-ConfigSummary -Config $config
    } else {
        Write-Warning "Configuration module not found. Using environment variables or defaults."
        # Fallback to environment variables
        if ([string]::IsNullOrWhiteSpace($WorkspaceName)) { $WorkspaceName = $env:FABRIC_WORKSPACE_NAME ?? "fabric-otel-workspace" }
        if ([string]::IsNullOrWhiteSpace($DatabaseName)) { $DatabaseName = $env:FABRIC_DATABASE_NAME ?? "otelobservabilitydb" }
        if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) { $ResourceGroupName = $env:RESOURCE_GROUP_NAME ?? "azuresamples-platformobservabilty-fabric" }
        if ([string]::IsNullOrWhiteSpace($Location)) { $Location = $env:LOCATION ?? "swedencentral" }
    }
} else {
    # Use environment variables or defaults when not using config
    if ([string]::IsNullOrWhiteSpace($WorkspaceName)) { $WorkspaceName = $env:FABRIC_WORKSPACE_NAME ?? "fabric-otel-workspace" }
    if ([string]::IsNullOrWhiteSpace($DatabaseName)) { $DatabaseName = $env:FABRIC_DATABASE_NAME ?? "otelobservabilitydb" }
    if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) { $ResourceGroupName = $env:RESOURCE_GROUP_NAME ?? "azuresamples-platformobservabilty-fabric" }
    if ([string]::IsNullOrWhiteSpace($Location)) { $Location = $env:LOCATION ?? "swedencentral" }
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
        
        # Attempt authentication with service principal using explicit parameters
        Write-ColorOutput "Authenticating with service principal..." $ColorInfo "🔐"
        
        # Method 1: Try with --service-principal flag and explicit parameters  
        try {
            $authOutput = fab auth login --service-principal --client-id $clientId --client-secret $clientSecret --tenant-id $tenantId 2>&1
            $authExitCode = $LASTEXITCODE
            
            Write-ColorOutput "Auth login output: $authOutput" $ColorInfo "📋"
            Write-ColorOutput "Auth login exit code: $authExitCode" $ColorInfo "🔧"
            
            # Check if login command succeeded
            if ($authExitCode -ne 0) {
                Write-ColorOutput "Fabric authentication login failed with exit code: $authExitCode" $ColorError "❌"
                Write-ColorOutput "Auth output: $authOutput" $ColorError "📋"
                
                # Try alternative authentication method - Azure CLI token
                Write-ColorOutput "Trying Azure CLI token authentication..." $ColorWarning "🔄"
                
                # First ensure Azure CLI is authenticated
                $azAccount = az account show --query "user.name" -o tsv 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-ColorOutput "Logging in to Azure CLI first..." $ColorInfo "🔐"
                    az login --service-principal -u $clientId -p $clientSecret --tenant $tenantId
                    if ($LASTEXITCODE -ne 0) {
                        throw "Azure CLI authentication failed"
                    }
                } else {
                    Write-ColorOutput "Azure CLI already authenticated as: $azAccount" $ColorInfo "👤"
                }
                
                # Try Fabric login with Azure CLI token
                $authOutput = fab auth login --azure-cli 2>&1
                $authExitCode = $LASTEXITCODE
                
                if ($authExitCode -ne 0) {
                    throw "Both Fabric service principal and Azure CLI token authentication failed"
                }
            }
        } catch {
            Write-ColorOutput "Authentication error: $_" $ColorError "❌"
            throw "Fabric authentication failed: $_"
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
            $testOutput = fab ls 2>&1
            $testExitCode = $LASTEXITCODE
            
            if ($testExitCode -eq 0) {
                Write-ColorOutput "Basic Fabric CLI permissions verified" $ColorSuccess "✅"
                Write-ColorOutput "Available workspaces/items:" $ColorInfo "📋"
                $testOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorInfo }
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
        # List all available workspaces using fab ls (file-system style)
        Write-ColorOutput "Checking existing workspaces..." $ColorInfo "🔍"
        $workspaceOutput = fab ls 2>&1
        $listExitCode = $LASTEXITCODE
        
        Write-ColorOutput "Workspace list exit code: $listExitCode" $ColorInfo "🔧"
        
        if ($listExitCode -ne 0) {
            Write-ColorOutput "Failed to list workspaces (exit code: $listExitCode)" $ColorError "❌"
            Write-ColorOutput "Workspace list output:" $ColorWarning "🔍"
            $workspaceOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            
            # Check if it's an authentication token issue
            if ($workspaceOutput -match "Failed to get access token|AuthenticationFailed") {
                Write-ColorOutput "Token access issue detected. Attempting to refresh authentication..." $ColorWarning "🔄"
                
                # Try to refresh the token
                try {
                    # Clear any cached tokens
                    fab config clear-cache
                    
                    # Re-authenticate
                    $clientId = $env:AZURE_CLIENT_ID
                    $clientSecret = $env:AZURE_CLIENT_SECRET  
                    $tenantId = $env:AZURE_TENANT_ID
                    
                    if ($clientId -and $clientSecret -and $tenantId) {
                        Write-ColorOutput "Re-authenticating with service principal..." $ColorInfo "🔐"
                        
                        # Try Azure CLI method first as it might have better token handling
                        az login --service-principal -u $clientId -p $clientSecret --tenant $tenantId --output none
                        if ($LASTEXITCODE -eq 0) {
                            $authOutput = fab auth login --azure-cli 2>&1
                            if ($LASTEXITCODE -eq 0) {
                                Write-ColorOutput "Token refreshed successfully" $ColorSuccess "✅"
                                Write-ColorOutput "Fabric auth output: $authOutput" $ColorInfo "📋"
                                
                                # Retry the workspace listing
                                $workspaceOutput = fab ls 2>&1
                                $listExitCode = $LASTEXITCODE
                                
                                if ($listExitCode -ne 0) {
                                    throw "Workspace listing still failed after token refresh"
                                }
                            } else {
                                throw "Fabric CLI authentication failed after Azure CLI login"
                            }
                        } else {
                            throw "Azure CLI re-authentication failed"
                        }
                    } else {
                        throw "Service principal credentials not available for token refresh"
                    }
                } catch {
                    Write-ColorOutput "Token refresh failed: $_" $ColorError "❌"
                    throw "Unable to refresh authentication token: $_"
                }
            } else {
                throw "Unable to list workspaces - check Fabric CLI authentication and permissions"
            }
        }
        
        # Check if our target workspace exists in the output
        $workspaceExists = $workspaceOutput | Select-String "$WorkspaceName.Workspace" -Quiet
        
        if ($workspaceExists) {
            Write-ColorOutput "Workspace '$WorkspaceName' already exists" $ColorSuccess "✅"
            return
        }
        
        # Create new workspace using file-system style command
        Write-ColorOutput "Creating new workspace: $WorkspaceName" $ColorInfo "🆕"
        $createOutput = fab mkdir "$WorkspaceName.Workspace" -P "capacityName=$script:CapacityName" 2>&1
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
        # Navigate to workspace using file-system style command
        Write-ColorOutput "Navigating to workspace: $WorkspaceName" $ColorInfo "🔗"
        $cdOutput = fab cd "$WorkspaceName.Workspace" 2>&1
        $cdExitCode = $LASTEXITCODE
        
        if ($cdExitCode -ne 0) {
            Write-ColorOutput "Failed to navigate to workspace (exit code: $cdExitCode)" $ColorError "❌"
            Write-ColorOutput "CD output:" $ColorWarning "🔍"
            $cdOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            throw "Unable to navigate to workspace"
        }
        
        # List contents of workspace to check if database exists
        Write-ColorOutput "Checking existing databases in workspace..." $ColorInfo "🔍"
        $databaseOutput = fab ls 2>&1
        $listExitCode = $LASTEXITCODE
        
        Write-ColorOutput "Database list exit code: $listExitCode" $ColorInfo "🔧"
        
        if ($listExitCode -ne 0) {
            Write-ColorOutput "Failed to list workspace contents (exit code: $listExitCode)" $ColorError "❌"
            Write-ColorOutput "Database list output:" $ColorWarning "🔍"
            $databaseOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            throw "Unable to list workspace contents - check workspace access and permissions"
        }
        
        # Check if our target KQL database exists
        # For KQL databases, we need to look for .KQLDatabase extension
        $databaseExists = $databaseOutput | Select-String "$DatabaseName.KQLDatabase" -Quiet
        
        if ($databaseExists) {
            Write-ColorOutput "KQL database '$DatabaseName' already exists" $ColorSuccess "✅"
            return
        }
        
        # Create KQL database using full path format
        Write-ColorOutput "Creating KQL database: $DatabaseName" $ColorInfo "🆕"
        $createOutput = fab mkdir "$WorkspaceName.Workspace/$DatabaseName.KQLDatabase" 2>&1
        $createExitCode = $LASTEXITCODE
        
        if ($createExitCode -eq 0) {
            Write-ColorOutput "Successfully created KQL database: $DatabaseName" $ColorSuccess "✅"
        } elseif ($createOutput -match "AlreadyExists") {
            Write-ColorOutput "KQL database '$DatabaseName' already exists" $ColorSuccess "✅"
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
        # Navigate to the KQL database using file-system style command
        Write-ColorOutput "Navigating to KQL database: $DatabaseName" $ColorInfo "🔗"
        $cdOutput = fab cd "$WorkspaceName.Workspace/$DatabaseName.KQLDatabase" 2>&1
        $cdExitCode = $LASTEXITCODE
        
        if ($cdExitCode -ne 0) {
            Write-ColorOutput "Failed to navigate to KQL database (exit code: $cdExitCode)" $ColorError "❌"
            Write-ColorOutput "CD output:" $ColorWarning "🔍"
            $cdOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
            throw "Unable to navigate to KQL database"
        }
        
        # Determine KQL directory path
        $kqlDir = if ($env:GITHUB_WORKSPACE) {
            Join-Path $env:GITHUB_WORKSPACE "deploy/infra/kql-definitions/tables"
        } else {
            Join-Path $PSScriptRoot "kql-definitions/tables"
        }
        
        if (-not (Test-Path $kqlDir)) {
            Write-ColorOutput "KQL definitions directory not found: $kqlDir" $ColorError "❌"
            exit 1
        }
        
        # Deploy each KQL table using appropriate commands
        $kqlFiles = Get-ChildItem -Path $kqlDir -Filter "*.kql"
        
        foreach ($kqlFile in $kqlFiles) {
            $tableName = $kqlFile.BaseName
            Write-ColorOutput "Deploying table: $tableName" $ColorInfo "📋"
            
            try {
                # Read KQL commands from file
                $kqlContent = Get-Content $kqlFile.FullName -Raw
                
                # Check if table already exists by trying to query it
                $tableCheckQuery = "OTELLogs | count"
                if ($tableName -eq "otel-metrics") { $tableCheckQuery = "OTELMetrics | count" }
                if ($tableName -eq "otel-traces") { $tableCheckQuery = "OTELTraces | count" }
                
                Write-ColorOutput "Checking if table exists for $tableName" $ColorInfo "�"
                
                # Try to execute a simple count query to check if table exists
                $tableExists = $false
                try {
                    # Use the API approach to check table existence using temp file
                    $tempCheckFile = [System.IO.Path]::GetTempFileName()
                    $tableCheckQuery | Out-File -FilePath $tempCheckFile -Encoding UTF8
                    
                    $checkOutput = fab api "v1/workspaces/${WorkspaceName}/kqldatabases/${DatabaseName}/query" --method post --input "@$tempCheckFile" 2>&1
                    Remove-Item $tempCheckFile -Force -ErrorAction SilentlyContinue
                    
                    if ($LASTEXITCODE -eq 0) {
                        $tableExists = $true
                        Write-ColorOutput "Table already exists for $tableName" $ColorSuccess "✅"
                    }
                } catch {
                    # Table doesn't exist, which is expected for new deployments
                    $tableExists = $false
                }
                
                if (-not $tableExists) {
                    Write-ColorOutput "Creating table for $tableName" $ColorInfo "🔧"
                    
                    # Execute the KQL create table command using temp file to avoid pipe issues
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    $kqlContent | Out-File -FilePath $tempFile -Encoding UTF8
                    
                    $executeOutput = fab api "v1/workspaces/${WorkspaceName}/kqldatabases/${DatabaseName}/query" --method post --input "@$tempFile" 2>&1
                    $executeExitCode = $LASTEXITCODE
                    
                    # Clean up temp file
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    
                    if ($executeExitCode -eq 0) {
                        Write-ColorOutput "Successfully created table: $tableName" $ColorSuccess "✅"
                    } else {
                        Write-ColorOutput "Failed to create table: $tableName" $ColorWarning "⚠️"
                        Write-ColorOutput "Execute output:" $ColorWarning "🔍"
                        $executeOutput | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
                    }
                } else {
                    Write-ColorOutput "Skipping table creation for $tableName (already exists)" $ColorInfo "⏭️"
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
        # List all workspaces
        Write-ColorOutput "Available workspaces:" $ColorInfo "📋"
        fab ls
        
        # Navigate to workspace and list contents
        Write-ColorOutput "Contents of workspace '$WorkspaceName':" $ColorInfo "📋"
        fab cd "$WorkspaceName.Workspace"
        fab ls
        
        # Navigate to database and list tables
        Write-ColorOutput "Contents of database '$DatabaseName':" $ColorInfo "📋"
        fab cd "$DatabaseName.KQLDatabase"
        fab ls
        
        # Try to query tables using KQL
        Write-ColorOutput "Listing tables using KQL:" $ColorInfo "📋"
        Write-Output ".show tables" | fab query
        
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
    
    if ($SkipWorkspaceCreation) {
        Write-ColorOutput "Skipping workspace creation (already exists or will be created manually)" $ColorWarning "⏭️"
    } else {
        New-OrGetWorkspace
    }
    
    New-KqlDatabase
    Deploy-KqlTables
    Test-Deployment
    
    Write-ColorOutput "Fabric artifacts deployment completed successfully!" $ColorSuccess "🎉"
    Show-ConnectionInfo
    
} catch {
    Write-ColorOutput "Script failed: $_" $ColorError "❌"
    exit 1
}
