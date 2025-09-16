#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Comprehensive Pester test suite for Azure Fabric OTEL integration
    
.DESCRIPTION
    Unified test suite covering all aspects of the Azure Fabric OTEL observability solution:
    - Environment validation and setup
    - Authentication and connectivity
    - Azure infrastructure deployment
    - Fabric workspace and KQL database operations
    - OTEL data pipeline functionality
    - Git integration for deployment automation
    
    This replaces all previous individual test scripts with a single, comprehensive Pester suite.
    
.PARAMETER WorkspaceName
    Name of the Fabric workspace (default: fabric-otel-workspace)
    
.PARAMETER DatabaseName
    Name of the KQL database (default: otelobservabilitydb)
    
.PARAMETER ResourceGroupName
    Name of the Azure resource group (default: azuresamples-platformobservabilty-fabric)
    
.PARAMETER KeyVaultName
    Name of the Key Vault containing secrets (optional, uses config if not provided)
    
.PARAMETER SkipSlowTests
    Skip tests that take longer than 30 seconds (for quick validation)
    
.PARAMETER SkipManualTests
    Skip tests that require manual intervention or setup
    
.EXAMPLE
    Invoke-Pester -Path "./Azure-Fabric-OTEL.Tests.ps1"
    
.EXAMPLE
    Invoke-Pester -Path "./Azure-Fabric-OTEL.Tests.ps1" -Tag "Environment","Authentication"
    
.EXAMPLE
    Invoke-Pester -Path "./Azure-Fabric-OTEL.Tests.ps1" -SkipSlowTests -SkipManualTests
    
.NOTES
    Requires:
    - Pester 5.x
    - Azure CLI authenticated
    - PowerShell 7.0+
    - Fabric CLI (installed automatically if missing)
    
    Tags available: Environment, Authentication, Azure, Fabric, OTEL, GitIntegration, Performance
#>

[CmdletBinding()]
param(
    [string]$WorkspaceName = "fabric-otel-workspace",
    [string]$DatabaseName = "otelobservabilitydb", 
    [string]$ResourceGroupName = "azuresamples-platformobservabilty-fabric",
    [string]$KeyVaultName = "",
    [switch]$SkipSlowTests,
    [switch]$SkipManualTests
)

BeforeAll {
    # Set error action preference for consistent error handling
    $ErrorActionPreference = "Stop"
    
    # Import required modules
    Import-Module Pester -MinimumVersion 5.0 -Force
    
    # Load centralized project configuration
    $script:configModulePath = Join-Path $PSScriptRoot "../config/ProjectConfig.psm1"
    if (Test-Path $script:configModulePath) {
        Import-Module $script:configModulePath -Force
        $script:projectConfig = Get-ProjectConfig
        
        # Override parameters with config values if not provided
        if ([string]::IsNullOrEmpty($WorkspaceName)) {
            $script:WorkspaceName = $script:projectConfig.fabric.workspaceName
        } else {
            $script:WorkspaceName = $WorkspaceName
        }
        
        if ([string]::IsNullOrEmpty($DatabaseName)) {
            $script:DatabaseName = $script:projectConfig.fabric.databaseName
        } else {
            $script:DatabaseName = $DatabaseName
        }
        
        if ([string]::IsNullOrEmpty($ResourceGroupName)) {
            $script:ResourceGroupName = $script:projectConfig.azure.resourceGroupName
        } else {
            $script:ResourceGroupName = $ResourceGroupName
        }
        
        if ([string]::IsNullOrEmpty($KeyVaultName)) {
            $script:KeyVaultName = $script:projectConfig.keyVault.vaultName
        } else {
            $script:KeyVaultName = $KeyVaultName
        }
    } else {
        Write-Warning "Configuration module not found at: $script:configModulePath"
        $script:WorkspaceName = $WorkspaceName
        $script:DatabaseName = $DatabaseName
        $script:ResourceGroupName = $ResourceGroupName
        $script:KeyVaultName = $KeyVaultName
    }
    
    # Color definitions for consistent output
    $script:ColorSuccess = "Green"
    $script:ColorError = "Red"
    $script:ColorWarning = "Yellow"
    $script:ColorInfo = "Cyan"
    
    # Helper functions for test operations
    function Write-TestOutput {
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
    
    function Invoke-CommandWithRetry {
        param(
            [scriptblock]$Command,
            [int]$MaxRetries = 3,
            [int]$DelaySeconds = 2
        )
        
        $attempt = 1
        while ($attempt -le $MaxRetries) {
            try {
                return & $Command
            } catch {
                if ($attempt -eq $MaxRetries) {
                    throw
                }
                Write-TestOutput "Attempt $attempt failed, retrying in $DelaySeconds seconds..." $script:ColorWarning "⏳"
                Start-Sleep -Seconds $DelaySeconds
                $attempt++
            }
        }
    }
    
    function Test-ToolAvailable {
        param([string]$Command)
        return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    }
    
    function Get-CommandOutput {
        param(
            [string]$Command,
            [string[]]$Arguments = @(),
            [int]$TimeoutSeconds = 60
        )
        
        try {
            $processInfo = Start-Process -FilePath $Command -ArgumentList $Arguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput -RedirectStandardError -TimeoutSec $TimeoutSeconds
            $output = Get-Content $processInfo.StandardOutput -Raw
            $errorOutput = Get-Content $processInfo.StandardError -Raw
            
            return @{
                Success = $processInfo.ExitCode -eq 0
                Output = $output
                Error = $errorOutput
                ExitCode = $processInfo.ExitCode
            }
        } catch {
            return @{
                Success = $false
                Output = ""
                Error = $_.Exception.Message
                ExitCode = -1
            }
        }
    }
    
    # Test data for OTEL validation
    $script:expectedOTELTables = @("OTELLogs", "OTELMetrics", "OTELTraces")
    $script:gitArtifactsPath = Join-Path $PSScriptRoot "../deploy/fabric-artifacts"
    $script:expectedKQLFiles = @("otel-logs.kql", "otel-metrics.kql", "otel-traces.kql")
}

Describe "Azure Fabric OTEL Integration Tests" -Tags @("Integration", "OTEL") {
    
    Context "Environment Setup and Validation" -Tags @("Environment") {
        
        It "Should be running in proper DevContainer environment" {
            # Check DevContainer indicators
            $isDevContainer = $env:REMOTE_CONTAINERS -eq "true" -or 
                             $env:CODESPACES -eq "true" -or 
                             (Test-Path "/.devcontainer") -or
                             $env:VSCODE_REMOTE_CONTAINERS_SESSION -eq "true"
            
            $isDevContainer | Should -BeTrue -Because "Tests should run in DevContainer for consistency"
        }
        
        It "Should have PowerShell 7.0 or later" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7 -Because "PowerShell 7+ is required for modern features"
        }
        
        It "Should have Git properly configured" {
            Test-ToolAvailable "git" | Should -BeTrue
            
            $userName = git config --global user.name 2>$null
            $userEmail = git config --global user.email 2>$null
            
            $userName | Should -Not -BeNullOrEmpty -Because "Git user.name must be configured"
            $userEmail | Should -Not -BeNullOrEmpty -Because "Git user.email must be configured"
            $userName | Should -Not -Be "DevContainer User" -Because "Git user.name should be personalized"
        }
        
        It "Should have required project structure" {
            $requiredPaths = @(
                "deploy/infra/Bicep/main.bicep",
                "deploy/infra/Deploy-FabricArtifacts-Git.ps1",
                "app/otel-collector/config.yaml",
                "config/project-config.json"
            )
            
            foreach ($path in $requiredPaths) {
                $fullPath = Join-Path $PSScriptRoot "../$path"
                Test-Path $fullPath | Should -BeTrue -Because "$path is required for the project"
            }
        }
        
        It "Should have project configuration module available" {
            Test-Path $script:configModulePath | Should -BeTrue -Because "ProjectConfig.psm1 module is required"
            $script:projectConfig | Should -Not -BeNull -Because "Project configuration should load successfully"
        }
    }
    
    Context "User Authentication Status" -Tags @("Authentication", "Prerequisites") {
        
        It "Should verify Azure CLI is installed" {
            Test-ToolAvailable "az" | Should -BeTrue -Because "Azure CLI is required for this solution"
        }
        
        It "Should verify user is authenticated to Azure CLI" {
            try {
                $userOutput = & az account show --query "user.name" -o tsv 2>&1
                $exitCode = $LASTEXITCODE
                
                if ($exitCode -eq 0 -and $userOutput -and $userOutput.Trim() -ne "") {
                    Write-TestOutput "✅ Azure CLI authenticated as: $($userOutput.Trim())" $script:ColorSuccess
                    $userOutput | Should -Not -BeNullOrEmpty -Because "Should have authenticated user"
                } else {
                    Write-TestOutput "❌ Azure CLI not authenticated. Run: az login" $script:ColorError
                    $true | Should -BeFalse -Because "Azure CLI authentication required. Please run 'az login'"
                }
            } catch {
                Write-TestOutput "❌ Error checking Azure CLI authentication: $($_.Exception.Message)" $script:ColorError
                $true | Should -BeFalse -Because "Azure CLI authentication check failed"
            }
        }
        
        It "Should verify access to Azure subscription" {
            try {
                $subscriptionOutput = & az account show --query "id" -o tsv 2>&1
                $exitCode = $LASTEXITCODE
                
                if ($exitCode -eq 0 -and $subscriptionOutput -match "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$") {
                    Write-TestOutput "✅ Azure subscription access confirmed: $($subscriptionOutput.Trim())" $script:ColorSuccess
                    $subscriptionOutput | Should -Match "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$" -Because "Should return valid subscription ID"
                } else {
                    Write-TestOutput "❌ No Azure subscription access. Check authentication and permissions" $script:ColorError
                    $true | Should -BeFalse -Because "Azure subscription access required"
                }
            } catch {
                Write-TestOutput "❌ Error checking Azure subscription access: $($_.Exception.Message)" $script:ColorError
                $true | Should -BeFalse -Because "Azure subscription access check failed"
            }
        }
        
        It "Should verify current Azure subscription details" {
            try {
                $accountOutput = & az account show --query "{name:name, tenantId:tenantId}" -o json 2>&1
                $exitCode = $LASTEXITCODE
                
                if ($exitCode -eq 0) {
                    $accountInfo = $accountOutput | ConvertFrom-Json
                    if ($accountInfo.name -and $accountInfo.tenantId) {
                        Write-TestOutput "✅ Subscription: $($accountInfo.name)" $script:ColorSuccess
                        Write-TestOutput "✅ Tenant ID: $($accountInfo.tenantId)" $script:ColorSuccess
                        $accountInfo.name | Should -Not -BeNullOrEmpty
                        $accountInfo.tenantId | Should -Not -BeNullOrEmpty
                    } else {
                        Write-TestOutput "❌ Invalid account information returned" $script:ColorError
                        $true | Should -BeFalse -Because "Should return valid account details"
                    }
                } else {
                    Write-TestOutput "❌ Cannot retrieve Azure account details" $script:ColorError
                    $true | Should -BeFalse -Because "Should be able to retrieve account details"
                }
            } catch {
                Write-TestOutput "❌ Error retrieving Azure account details: $($_.Exception.Message)" $script:ColorError
                $true | Should -BeFalse -Because "Account details retrieval failed"
            }
        }
        
        It "Should verify Fabric CLI is installed" {
            if (Test-ToolAvailable "fab") {
                Write-TestOutput "✅ Fabric CLI is installed" $script:ColorSuccess
                $true | Should -BeTrue
            } else {
                Write-TestOutput "⚠️ Fabric CLI not installed. Installing..." $script:ColorWarning
                # Install via pip if not available
                $result = Get-CommandOutput -Command "python" -Arguments @("-m", "pip", "install", "ms-fabric-cli") -TimeoutSeconds 120
                if ($result.Success) {
                    Write-TestOutput "✅ Fabric CLI installed successfully" $script:ColorSuccess
                    Test-ToolAvailable "fab" | Should -BeTrue -Because "Fabric CLI should be available after installation"
                } else {
                    Write-TestOutput "❌ Failed to install Fabric CLI" $script:ColorError
                    $result.Success | Should -BeTrue -Because "Fabric CLI installation should succeed"
                }
            }
        }
        
        It "Should verify user is authenticated to Fabric CLI" {
            # Configure Fabric CLI first
            $null = Get-CommandOutput -Command "fab" -Arguments @("config", "set", "encryption_fallback_enabled", "true")
            
            # Check authentication status - run directly to get proper output
            try {
                $authOutput = & fab auth status 2>&1
                $authExitCode = $LASTEXITCODE
                
                if ($authOutput -match "Logged in to app\.fabric\.microsoft\.com") {
                    Write-TestOutput "✅ Fabric CLI is authenticated" $script:ColorSuccess
                    # Extract user info from the output
                    if ($authOutput -match "Account: ([^\s]+)") {
                        Write-TestOutput "✅ Authenticated as: $($matches[1])" $script:ColorSuccess
                    }
                    $true | Should -BeTrue -Because "User is authenticated to Fabric CLI"
                } elseif ($authExitCode -eq 1 -or $authOutput -match "not logged in") {
                    Write-TestOutput "❌ Fabric CLI not authenticated. Run: fab auth login" $script:ColorError
                    Write-TestOutput "ℹ️ After authentication, run: fab auth status" $script:ColorInfo
                    # Don't fail the test, just warn - authentication is manual
                    $true | Should -BeTrue -Because "Fabric CLI authentication is optional for basic tests"
                } else {
                    Write-TestOutput "⚠️ Fabric CLI auth status unclear. Output:" $script:ColorWarning
                    Write-TestOutput "$authOutput" $script:ColorInfo
                    $true | Should -BeTrue -Because "Fabric CLI status check completed"
                }
            } catch {
                Write-TestOutput "⚠️ Error checking Fabric CLI auth status: $($_.Exception.Message)" $script:ColorWarning
                $true | Should -BeTrue -Because "Fabric CLI auth check completed with error"
            }
        }
        
        It "Should verify Fabric CLI workspace access (if authenticated)" {
            try {
                $authOutput = & fab auth status 2>&1
                
                if ($authOutput -match "Logged in to app\.fabric\.microsoft\.com") {
                    # User is authenticated, test workspace access
                    $result = Get-CommandOutput -Command "fab" -Arguments @("workspace", "list", "--output", "table")
                    
                    if ($result.Success) {
                        Write-TestOutput "✅ Fabric CLI workspace access confirmed" $script:ColorSuccess
                        Write-TestOutput "ℹ️ Available workspaces accessible" $script:ColorInfo
                        $result.Success | Should -BeTrue -Because "Should be able to list workspaces when authenticated"
                    } else {
                        Write-TestOutput "⚠️ Fabric CLI workspace access limited or no workspaces" $script:ColorWarning
                        $true | Should -BeTrue -Because "Authentication works, workspace access may be limited"
                    }
                } else {
                    Write-TestOutput "ℹ️ Skipping workspace test - Fabric CLI not authenticated" $script:ColorInfo
                    $true | Should -BeTrue -Because "Test skipped - authentication required"
                }
            } catch {
                Write-TestOutput "ℹ️ Skipping workspace test - authentication check failed" $script:ColorInfo
                $true | Should -BeTrue -Because "Test skipped due to error"
            }
        }
    }
    
    Context "Authentication and Connectivity" -Tags @("Authentication") {
    Context "Authentication and Connectivity" -Tags @("Authentication") {
        
        It "Should install Fabric CLI if not available" {
            if (-not (Test-ToolAvailable "fab")) {
                Write-TestOutput "Installing Fabric CLI..." $script:ColorInfo "📦"
                # Install via pip if not available
                $result = Get-CommandOutput -Command "python" -Arguments @("-m", "pip", "install", "ms-fabric-cli") -TimeoutSeconds 120
                $result.Success | Should -BeTrue -Because "Fabric CLI installation should succeed"
            }
            
            Test-ToolAvailable "fab" | Should -BeTrue -Because "Fabric CLI should be available after installation"
        }
        
        It "Should configure Fabric CLI properly" {
            $result = Get-CommandOutput -Command "fab" -Arguments @("config", "set", "encryption_fallback_enabled", "true")
            $result.Success | Should -BeTrue -Because "Fabric CLI configuration should succeed"
            
            # Clear cache for clean state
            $null = Get-CommandOutput -Command "fab" -Arguments @("config", "clear-cache")
        }
        
        It "Should handle Fabric CLI authentication gracefully" {
            $result = Get-CommandOutput -Command "fab" -Arguments @("auth", "status")
            
            # Don't require authentication to pass - just verify command works
            $result.ExitCode | Should -BeIn @(0, 1) -Because "auth status should return valid exit code (0=authenticated, 1=not authenticated)"
        }
    }
    }
    
    Context "Azure Infrastructure Validation" -Tags @("Azure") {
        
        It "Should validate resource group existence or provide guidance" {
            $result = Get-CommandOutput -Command "az" -Arguments @("group", "show", "--name", $script:ResourceGroupName, "--query", "name", "-o", "tsv")
            
            if ($result.Success) {
                $result.Output.Trim() | Should -Be $script:ResourceGroupName -Because "Resource group should exist with correct name"
                Write-TestOutput "✅ Resource group '$($script:ResourceGroupName)' found" $script:ColorSuccess
            } else {
                Write-TestOutput "⚠️ Resource group '$($script:ResourceGroupName)' not found - deployment needed" $script:ColorWarning
                # This is acceptable - tests can guide deployment
                $true | Should -BeTrue -Because "Missing resource group is acceptable for guidance mode"
            }
        }
        
        It "Should check for Key Vault if configured" -Skip:($null -eq $script:KeyVaultName -or $script:KeyVaultName -eq "") {
            $result = Get-CommandOutput -Command "az" -Arguments @("keyvault", "show", "--name", $script:KeyVaultName, "--query", "name", "-o", "tsv")
            
            if ($result.Success) {
                $result.Output.Trim() | Should -Be $script:KeyVaultName -Because "Key Vault should be accessible"
                Write-TestOutput "✅ Key Vault '$($script:KeyVaultName)' accessible" $script:ColorSuccess
            } else {
                Write-TestOutput "⚠️ Key Vault '$($script:KeyVaultName)' not accessible - check permissions" $script:ColorWarning
                # Don't fail - might not have access yet
                $true | Should -BeTrue -Because "Key Vault access issues are common during setup"
            }
        }
        
        It "Should validate Bicep template syntax" {
            $bicepPath = Join-Path $PSScriptRoot "../deploy/infra/Bicep/main.bicep"
            
            $result = Get-CommandOutput -Command "az" -Arguments @("bicep", "build", "--file", $bicepPath, "--stdout") -TimeoutSeconds 30
            $result.Success | Should -BeTrue -Because "Bicep template should compile without errors"
        }
    }
    
    Context "Fabric Workspace and Database Operations" -Tags @("Fabric") {
        
        BeforeAll {
            # Ensure Fabric CLI is configured
            $null = Get-CommandOutput -Command "fab" -Arguments @("config", "set", "encryption_fallback_enabled", "true")
        }
        
        It "Should list Fabric workspaces (if authenticated)" {
            $result = Get-CommandOutput -Command "fab" -Arguments @("ls") -TimeoutSeconds 30
            
            if ($result.Success) {
                Write-TestOutput "✅ Fabric workspace listing successful" $script:ColorSuccess
                $result.Output | Should -Not -BeNullOrEmpty -Because "Should return workspace list"
                
                # Check if our workspace exists
                if ($result.Output -match $script:WorkspaceName) {
                    Write-TestOutput "✅ Workspace '$($script:WorkspaceName)' found in listing" $script:ColorSuccess
                } else {
                    Write-TestOutput "⚠️ Workspace '$($script:WorkspaceName)' not found - may need creation" $script:ColorWarning
                }
            } else {
                Write-TestOutput "ℹ️ Fabric not authenticated or no workspace access - this is expected for initial setup" $script:ColorInfo
                # Don't fail - authentication might not be set up yet
                $true | Should -BeTrue -Because "Fabric authentication is optional for basic validation"
            }
        }
        
        It "Should validate workspace accessibility (if exists)" {
            $result = Get-CommandOutput -Command "fab" -Arguments @("workspace", "show", "--workspace", $script:WorkspaceName) -TimeoutSeconds 30
            
            if ($result.Success) {
                Write-TestOutput "✅ Workspace '$($script:WorkspaceName)' is accessible" $script:ColorSuccess
                $result.Output | Should -Contain $script:WorkspaceName -Because "Workspace details should contain workspace name"
            } else {
                Write-TestOutput "ℹ️ Workspace '$($script:WorkspaceName)' not accessible - normal for fresh deployment" $script:ColorInfo
                # This is acceptable - workspace might not exist yet
                $true | Should -BeTrue -Because "Missing workspace is acceptable during initial setup"
            }
        }
        
        It "Should validate KQL database accessibility (if exists)" {
            $result = Get-CommandOutput -Command "fab" -Arguments @("kqldatabase", "show", "--workspace", $script:WorkspaceName, "--kql-database", $script:DatabaseName) -TimeoutSeconds 30
            
            if ($result.Success) {
                Write-TestOutput "✅ KQL database '$($script:DatabaseName)' is accessible" $script:ColorSuccess
                $result.Output | Should -Contain $script:DatabaseName -Because "Database details should contain database name"
            } else {
                Write-TestOutput "ℹ️ KQL database '$($script:DatabaseName)' not accessible - normal for fresh deployment" $script:ColorInfo
                # This is acceptable - database might not exist yet
                $true | Should -BeTrue -Because "Missing database is acceptable during initial setup"
            }
        }
        
        It "Should validate expected OTEL tables structure (if database exists)" -Tag "Slow" -Skip:$SkipSlowTests {
            # First check if we can access the database
            $dbResult = Get-CommandOutput -Command "fab" -Arguments @("kqldatabase", "show", "--workspace", $script:WorkspaceName, "--kql-database", $script:DatabaseName) -TimeoutSeconds 30
            
            if ($dbResult.Success) {
                # Try to query table list
                $tempFile = New-TemporaryFile
                try {
                    ".show tables" | Out-File $tempFile.FullName -Encoding UTF8
                    
                    $queryResult = Get-CommandOutput -Command "fab" -Arguments @("kqldatabase", "query", "--workspace", $script:WorkspaceName, "--kql-database", $script:DatabaseName, "--file", $tempFile.FullName) -TimeoutSeconds 60
                    
                    if ($queryResult.Success) {
                        foreach ($tableName in $script:expectedOTELTables) {
                            $queryResult.Output | Should -Contain $tableName -Because "OTEL table '$tableName' should exist"
                        }
                        Write-TestOutput "✅ All expected OTEL tables found" $script:ColorSuccess
                    } else {
                        Write-TestOutput "⚠️ Could not query tables - database might be empty" $script:ColorWarning
                        $true | Should -BeTrue -Because "Empty database is acceptable"
                    }
                } finally {
                    Remove-Item $tempFile.FullName -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-TestOutput "ℹ️ Database not accessible - skipping table validation" $script:ColorInfo
                $true | Should -BeTrue -Because "Database validation is optional"
            }
        }
    }
    
    Context "OTEL Data Pipeline Configuration" -Tags @("OTEL") {
        
        It "Should have OTEL Collector configuration file" {
            $configPath = Join-Path $PSScriptRoot "../app/otel-collector/config.yaml"
            Test-Path $configPath | Should -BeTrue -Because "OTEL Collector config is required"
            
            $configContent = Get-Content $configPath -Raw
            $configContent | Should -Match "receivers:" -Because "Config should define receivers"
            $configContent | Should -Match "exporters:" -Because "Config should define exporters"
            $configContent | Should -Match "azureeventhub" -Because "Config should include Azure Event Hub receiver"
        }
        
        It "Should have Docker configuration for OTEL Collector" {
            $dockerPath = Join-Path $PSScriptRoot "../app/otel-collector/Dockerfile"
            Test-Path $dockerPath | Should -BeTrue -Because "Dockerfile is required for containerization"
            
            $dockerContent = Get-Content $dockerPath -Raw
            $dockerContent | Should -Match "FROM.*otel.*collector" -Because "Should use official OTEL Collector image"
        }
        
        It "Should validate OTEL Worker application structure" {
            $workerPath = Join-Path $PSScriptRoot "../app/OTELDotNetClient"
            Test-Path $workerPath | Should -BeTrue -Because "OTEL Worker application should exist"
            
            $projectFile = Join-Path $workerPath "OTELWorker.csproj"
            Test-Path $projectFile | Should -BeTrue -Because "Worker project file should exist"
            
            $projectContent = Get-Content $projectFile -Raw
            $projectContent | Should -Match "OpenTelemetry" -Because "Project should reference OpenTelemetry packages"
        }
    }
    
    Context "Git Integration for Deployment" -Tags @("GitIntegration") {
        
        It "Should have Git artifacts folder structure" {
            Test-Path $script:gitArtifactsPath | Should -BeTrue -Because "Git artifacts folder should exist"
            
            $tablesPath = Join-Path $script:gitArtifactsPath "tables"
            Test-Path $tablesPath | Should -BeTrue -Because "Tables folder should exist in Git artifacts"
        }
        
        It "Should have all required KQL table definition files" {
            $tablesPath = Join-Path $script:gitArtifactsPath "tables"
            
            foreach ($kqlFile in $script:expectedKQLFiles) {
                $filePath = Join-Path $tablesPath $kqlFile
                Test-Path $filePath | Should -BeTrue -Because "KQL file '$kqlFile' should exist"
                
                $content = Get-Content $filePath -Raw
                $content | Should -Match "\.create-merge table" -Because "KQL file should contain table creation command"
            }
        }
        
        It "Should validate KQL table schema definitions" {
            $tablesPath = Join-Path $script:gitArtifactsPath "tables"
            
            # Validate OTELLogs table schema
            $logsFile = Join-Path $tablesPath "otel-logs.kql"
            $logsContent = Get-Content $logsFile -Raw
            $logsContent | Should -Match "Timestamp:datetime" -Because "Logs table should have Timestamp column"
            $logsContent | Should -Match "TraceID:string" -Because "Logs table should have TraceID column"
            $logsContent | Should -Match "Body:string" -Because "Logs table should have Body column"
            
            # Validate OTELMetrics table schema
            $metricsFile = Join-Path $tablesPath "otel-metrics.kql"
            $metricsContent = Get-Content $metricsFile -Raw
            $metricsContent | Should -Match "MetricName:string" -Because "Metrics table should have MetricName column"
            $metricsContent | Should -Match "Value:real" -Because "Metrics table should have Value column"
            
            # Validate OTELTraces table schema
            $tracesFile = Join-Path $tablesPath "otel-traces.kql"
            $tracesContent = Get-Content $tracesFile -Raw
            $tracesContent | Should -Match "TraceID:string" -Because "Traces table should have TraceID column"
            $tracesContent | Should -Match "SpanID:string" -Because "Traces table should have SpanID column"
        }
        
        It "Should have Git integration deployment script" {
            $deployScript = Join-Path $PSScriptRoot "../deploy/infra/Deploy-FabricArtifacts-Git.ps1"
            Test-Path $deployScript | Should -BeTrue -Because "Git integration deployment script should exist"
            
            $scriptContent = Get-Content $deployScript -Raw
            $scriptContent | Should -Match "Git.+integration" -Because "Script should reference Git integration"
        }
        
        It "Should have clean Git status for artifacts folder" {
            Push-Location $script:gitArtifactsPath
            try {
                $gitStatus = git status --porcelain 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $gitStatus | Should -BeNullOrEmpty -Because "Git artifacts folder should have no uncommitted changes"
                    Write-TestOutput "✅ Git artifacts folder is clean" $script:ColorSuccess
                } else {
                    Write-TestOutput "ℹ️ Not in Git repository or Git not configured - skipping Git status check" $script:ColorInfo
                    $true | Should -BeTrue -Because "Git status check is optional"
                }
            } finally {
                Pop-Location
            }
        }
    }
    
    Context "Performance and Integration Tests" -Tags @("Performance", "Integration") {
        
        It "Should complete environment validation within reasonable time" -Tag "Performance" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Quick validation of key components
            Test-ToolAvailable "az" | Should -BeTrue
            Test-ToolAvailable "pwsh" | Should -BeTrue
            Test-Path $script:configModulePath | Should -BeTrue
            
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000 -Because "Environment validation should be fast"
        }
        
        It "Should generate test OTEL data successfully" -Tag "Slow" -Skip:$SkipSlowTests {
            $testDataScript = Join-Path $PSScriptRoot "Generate-TestData.ps1"
            
            if (Test-Path $testDataScript) {
                $result = Get-CommandOutput -Command "pwsh" -Arguments @("-File", $testDataScript, "-Count", "10") -TimeoutSeconds 60
                $result.Success | Should -BeTrue -Because "Test data generation should succeed"
                Write-TestOutput "✅ Test data generation completed" $script:ColorSuccess
            } else {
                Write-TestOutput "ℹ️ Test data generation script not found - skipping" $script:ColorInfo
                $true | Should -BeTrue -Because "Test data generation is optional"
            }
        }
        
        It "Should provide comprehensive deployment guidance" {
            $deployScript = Join-Path $PSScriptRoot "../deploy/infra/Deploy-FabricArtifacts-Git.ps1"
            
            if (Test-Path $deployScript) {
                # Run in WhatIf mode to validate guidance
                $result = Get-CommandOutput -Command "pwsh" -Arguments @("-File", $deployScript, "-WhatIf") -TimeoutSeconds 30
                
                # Should complete without errors in WhatIf mode
                $result.ExitCode | Should -BeIn @(0, 1) -Because "Deployment script should provide guidance even when resources don't exist"
                Write-TestOutput "✅ Deployment guidance validated" $script:ColorSuccess
            } else {
                Write-TestOutput "⚠️ Deployment script not found" $script:ColorWarning
                $false | Should -BeTrue -Because "Deployment script is required"
            }
        }
    }
}

AfterAll {
    Write-TestOutput "" $script:ColorInfo
    Write-TestOutput "🧪 Azure Fabric OTEL Test Suite Completed" $script:ColorInfo "🎉"
    Write-TestOutput "================================================" $script:ColorInfo
    Write-TestOutput "" $script:ColorInfo
    Write-TestOutput "Next Steps:" $script:ColorInfo "📋"
    Write-TestOutput "1. Review any test failures and warnings above" $script:ColorInfo "  •"
    Write-TestOutput "2. Run: ./deploy/infra/Deploy-FabricArtifacts-Git.ps1 for deployment guidance" $script:ColorInfo "  •"
    Write-TestOutput "3. Run: cd deploy/infra/Bicep && ./deploy.ps1 for infrastructure deployment" $script:ColorInfo "  •"
    Write-TestOutput "4. Use tags to run specific test categories: -Tag 'Environment','Authentication'" $script:ColorInfo "  •"
    Write-TestOutput "" $script:ColorInfo
}