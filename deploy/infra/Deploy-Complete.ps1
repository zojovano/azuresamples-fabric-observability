#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Complete deployment script for Azure OTEL Observability Infrastructure
    
.DESCRIPTION
    Unified deployment script that handles:
    1. Azure infrastructure deployment via Bicep
    2. Fabric artifacts deployment via Fabric CLI
    3. Configuration management from Key Vault
    4. Optional service principal creation
    
    This script is designed for local development use and uses Key Vault for all secrets.
    
.PARAMETER Location
    Azure region for deployment (default: swedencentral)
    
.PARAMETER KeyVaultName
    Name of the Key Vault containing project secrets (optional, uses config/project-config.json if not provided)
    
.PARAMETER AdminUserEmail
    Email of the admin user for Fabric capacity (optional, uses current user if not provided)
    
.PARAMETER SkipInfrastructure
    Skip Azure infrastructure deployment (only deploy Fabric artifacts)
    
.PARAMETER SkipFabricArtifacts
    Skip Fabric artifacts deployment (only deploy Azure infrastructure)
    
.PARAMETER SkipWorkspaceCreation
    Skip Fabric workspace creation (useful when workspace already exists)
    
.PARAMETER CreateServicePrincipals
    Create service principals and populate Key Vault with secrets
    
.PARAMETER WhatIf
    Show what would be deployed without actually deploying
    
.EXAMPLE
    ./Deploy-Complete.ps1
    
.EXAMPLE
    ./Deploy-Complete.ps1 -KeyVaultName "my-project-keyvault"
    
.EXAMPLE
    ./Deploy-Complete.ps1 -KeyVaultName "my-kv" -SkipInfrastructure
    
.EXAMPLE
    ./Deploy-Complete.ps1 -CreateServicePrincipals -KeyVaultName "my-kv"
    
.EXAMPLE
    ./Deploy-Complete.ps1 -KeyVaultName "my-kv" -WhatIf
    
.NOTES
    Prerequisites:
    - Azure CLI authenticated
    - PowerShell Azure module installed
    - Fabric CLI installed (for Fabric artifacts deployment)
    - Key Vault with appropriate access permissions
    
    Expected Key Vault secrets:
    - azure-subscription-id
    - azure-tenant-id
    - azure-client-id
    - azure-client-secret
    - fabric-workspace-name
    - fabric-database-name
    - resource-group-name
    - admin-object-id (optional)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Location = "swedencentral",
    
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminUserEmail = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipInfrastructure,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipFabricArtifacts,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipWorkspaceCreation,
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateServicePrincipals,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Load centralized project configuration
Write-Host "📋 Loading project configuration..." -ForegroundColor $ColorInfo
$configModulePath = Join-Path $PSScriptRoot "../../config/ProjectConfig.psm1"
if (-not (Test-Path $configModulePath)) {
    Write-Error "❌ Configuration module not found at: $configModulePath"
    exit 1
}

Import-Module $configModulePath -Force
$projectConfig = Get-ProjectConfig

# Use KeyVault from configuration if not provided as parameter
if ([string]::IsNullOrEmpty($KeyVaultName)) {
    $KeyVaultName = $projectConfig.keyVault.vaultName
    Write-Host "✅ Using KeyVault from configuration: $KeyVaultName" -ForegroundColor $ColorSuccess
} else {
    Write-Host "✅ Using KeyVault from parameter: $KeyVaultName" -ForegroundColor $ColorSuccess
}

# Display configuration summary
Write-ConfigSummary -Config $projectConfig

# Colors for output
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "Cyan"
$ColorHeader = "Magenta"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [string]$Icon = ""
    )
    Write-Host "$Icon $Message" -ForegroundColor $Color
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-ColorOutput "=" * 80 $ColorHeader
    Write-ColorOutput $Title $ColorHeader "🎯"
    Write-ColorOutput "=" * 80 $ColorHeader
}

function Test-Prerequisites {
    Write-Section "Checking Prerequisites"
    
    $issues = @()
    
    # Check Azure CLI
    try {
        $azVersion = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "Azure CLI: $($azVersion.'azure-cli')" $ColorSuccess "✅"
    }
    catch {
        $issues += "Azure CLI not found or not working"
        Write-ColorOutput "Azure CLI: Not found" $ColorError "❌"
    }
    
    # Check PowerShell Azure module
    $azModule = Get-Module -ListAvailable -Name Az.Accounts -ErrorAction SilentlyContinue
    if ($azModule) {
        Write-ColorOutput "PowerShell Az Module: $($azModule[0].Version)" $ColorSuccess "✅"
    } else {
        $issues += "PowerShell Az module not installed"
        Write-ColorOutput "PowerShell Az Module: Not found" $ColorError "❌"
    }
    
    # Check Fabric CLI (only if not skipping Fabric artifacts)
    if (-not $SkipFabricArtifacts) {
        try {
            $fabVersion = fab --version 2>$null
            if ($fabVersion) {
                Write-ColorOutput "Fabric CLI: $fabVersion" $ColorSuccess "✅"
            } else {
                $issues += "Fabric CLI not found"
                Write-ColorOutput "Fabric CLI: Not found" $ColorError "❌"
            }
        }
        catch {
            $issues += "Fabric CLI not found or not working"
            Write-ColorOutput "Fabric CLI: Not found" $ColorError "❌"
        }
    }
    
    # Check Azure connection
    try {
        $context = Get-AzContext
        if ($context) {
            Write-ColorOutput "Azure Connection: $($context.Account.Id)" $ColorSuccess "✅"
        } else {
            $issues += "Not connected to Azure"
            Write-ColorOutput "Azure Connection: Not connected" $ColorError "❌"
        }
    }
    catch {
        $issues += "Error checking Azure connection"
        Write-ColorOutput "Azure Connection: Error" $ColorError "❌"
    }
    
    if ($issues.Count -gt 0) {
        Write-ColorOutput "Prerequisites check failed:" $ColorError "❌"
        foreach ($issue in $issues) {
            Write-ColorOutput "  • $issue" $ColorError
        }
        return $false
    }
    
    Write-ColorOutput "All prerequisites met!" $ColorSuccess "🎉"
    return $true
}

function Get-KeyVaultSecrets {
    param([string]$VaultName)
    
    Write-Section "Retrieving Configuration from Key Vault"
    
    try {
        # Test Key Vault access
        $kv = Get-AzKeyVault -VaultName $VaultName -ErrorAction Stop
        Write-ColorOutput "Key Vault found: $($kv.VaultName)" $ColorSuccess "✅"
        
        # Define expected secrets
        $secretNames = @{
            "azure-subscription-id" = "SubscriptionId"
            "azure-tenant-id" = "TenantId"
            "azure-client-id" = "ClientId"
            "azure-client-secret" = "ClientSecret"
            "fabric-workspace-name" = "WorkspaceName"
            "fabric-database-name" = "DatabaseName"
            "resource-group-name" = "ResourceGroupName"
            "admin-object-id" = "AdminObjectId"
        }
        
        $config = @{}
        $missingSecrets = @()
        
        foreach ($secretName in $secretNames.Keys) {
            try {
                $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $secretName -AsPlainText -ErrorAction SilentlyContinue
                if ($secret) {
                    $config[$secretNames[$secretName]] = $secret
                    Write-ColorOutput "Retrieved: $secretName" $ColorSuccess "  ✅"
                } else {
                    $missingSecrets += $secretName
                    Write-ColorOutput "Missing: $secretName" $ColorWarning "  ⚠️"
                }
            }
            catch {
                $missingSecrets += $secretName
                Write-ColorOutput "Failed to retrieve: $secretName" $ColorWarning "  ⚠️"
            }
        }
        
        # Check for required secrets
        $requiredSecrets = @("azure-subscription-id", "azure-tenant-id", "resource-group-name")
        $missingRequired = $requiredSecrets | Where-Object { $_ -in $missingSecrets }
        
        if ($missingRequired.Count -gt 0) {
            Write-ColorOutput "Missing required secrets: $($missingRequired -join ', ')" $ColorError "❌"
            Write-ColorOutput "Please populate these secrets in Key Vault: $VaultName" $ColorError
            return $null
        }
        
        if ($missingSecrets.Count -gt 0) {
            Write-ColorOutput "Missing optional secrets: $($missingSecrets -join ', ')" $ColorWarning "⚠️"
            Write-ColorOutput "These will use defaults or current user context" $ColorWarning
        }
        
        return $config
    }
    catch {
        Write-ColorOutput "Error accessing Key Vault: $($_.Exception.Message)" $ColorError "❌"
        Write-ColorOutput "Ensure you have 'Key Vault Secrets User' role on: $VaultName" $ColorError
        return $null
    }
}

function New-ServicePrincipalsAndSecrets {
    param(
        [hashtable]$Config,
        [string]$VaultName
    )
    
    Write-Section "Creating Service Principals and Populating Key Vault"
    
    try {
        $subscriptionId = $Config.SubscriptionId
        $tenantId = $Config.TenantId
        
        # Create GitHub Actions service principal
        Write-ColorOutput "Creating GitHub Actions service principal..." $ColorInfo "🔧"
        $githubSp = New-AzADServicePrincipal -DisplayName "fabric-otel-github-actions" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"
        
        # Create Application service principal
        Write-ColorOutput "Creating Application service principal..." $ColorInfo "🔧"
        $appSp = New-AzADServicePrincipal -DisplayName "fabric-otel-application" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"
        
        # Get secrets
        $githubSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($githubSp.PasswordCredentials.SecretText))
        $appSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($appSp.PasswordCredentials.SecretText))
        
        # Populate Key Vault with secrets
        $secrets = @{
            "azure-tenant-id" = $tenantId
            "azure-subscription-id" = $subscriptionId
            "azure-client-id" = $appSp.AppId
            "azure-client-secret" = $appSecret
            "github-client-id" = $githubSp.AppId
            "github-client-secret" = $githubSecret
            "app-service-principal-object-id" = $appSp.Id
            "github-service-principal-object-id" = $githubSp.Id
        }
        
        foreach ($secretName in $secrets.Keys) {
            $secretValue = $secrets[$secretName]
            Set-AzKeyVaultSecret -VaultName $VaultName -Name $secretName -SecretValue (ConvertTo-SecureString $secretValue -AsPlainText -Force) | Out-Null
            Write-ColorOutput "Stored secret: $secretName" $ColorSuccess "  ✅"
        }
        
        # Update config with new values
        $Config.ClientId = $appSp.AppId
        $Config.ClientSecret = $appSecret
        
        Write-ColorOutput "Service principals created and secrets stored!" $ColorSuccess "🎉"
        Write-ColorOutput "GitHub Actions Service Principal: $($githubSp.AppId)" $ColorInfo "  📝"
        Write-ColorOutput "Application Service Principal: $($appSp.AppId)" $ColorInfo "  📝"
        
        return $true
    }
    catch {
        Write-ColorOutput "Error creating service principals: $($_.Exception.Message)" $ColorError "❌"
        return $false
    }
}

function Deploy-AzureInfrastructure {
    param(
        [hashtable]$Config,
        [string]$Location,
        [string]$AdminObjectId,
        [bool]$WhatIf = $false
    )
    
    Write-Section "Deploying Azure Infrastructure"
    
    try {
        # Set Azure context
        if ($Config.SubscriptionId) {
            Select-AzSubscription -SubscriptionId $Config.SubscriptionId | Out-Null
            Write-ColorOutput "Using subscription: $($Config.SubscriptionId)" $ColorInfo "📋"
        }
        
        # Prepare deployment parameters
        $deploymentParameters = @{
            location = $Location
        }
        
        if ($AdminObjectId) {
            $deploymentParameters.adminObjectId = $AdminObjectId
        }
        
        if ($Config.ClientId) {
            $deploymentParameters.appServicePrincipalClientId = $Config.ClientId
        }
        
        if ($Config.ClientSecret) {
            $deploymentParameters.appServicePrincipalClientSecret = $Config.ClientSecret
        }
        
        $deploymentName = "fabric-otel-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        $bicepTemplate = Join-Path $PSScriptRoot "Bicep" "main.bicep"
        
        Write-ColorOutput "Deployment name: $deploymentName" $ColorInfo "📋"
        Write-ColorOutput "Template: $bicepTemplate" $ColorInfo "📋"
        Write-ColorOutput "Location: $Location" $ColorInfo "📋"
        
        if ($WhatIf) {
            Write-ColorOutput "Running What-If analysis..." $ColorWarning "👁️"
            $whatIfResult = Get-AzDeploymentWhatIfResult -Name $deploymentName `
                -Location $Location `
                -TemplateFile $bicepTemplate `
                -TemplateParameterObject $deploymentParameters
            
            Write-ColorOutput "What-If completed - check output above" $ColorInfo "📊"
            return $true
        }
        
        Write-ColorOutput "Starting infrastructure deployment..." $ColorInfo "🚀"
        
        $deployment = New-AzDeployment -Name $deploymentName `
            -Location $Location `
            -TemplateFile $bicepTemplate `
            -TemplateParameterObject $deploymentParameters `
            -Verbose
        
        if ($deployment.ProvisioningState -eq "Succeeded") {
            Write-ColorOutput "Infrastructure deployment completed!" $ColorSuccess "🎉"
            
            # Display outputs
            if ($deployment.Outputs -and $deployment.Outputs.Count -gt 0) {
                Write-ColorOutput "Deployment outputs:" $ColorInfo "📋"
                foreach ($output in $deployment.Outputs.GetEnumerator()) {
                    Write-ColorOutput "$($output.Key): $($output.Value.Value)" $ColorSuccess "  •"
                }
            }
            
            return $true
        } else {
            Write-ColorOutput "Infrastructure deployment failed: $($deployment.ProvisioningState)" $ColorError "❌"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Infrastructure deployment error: $($_.Exception.Message)" $ColorError "❌"
        return $false
    }
}

function Deploy-FabricArtifacts {
    param(
        [hashtable]$Config,
        [bool]$SkipWorkspaceCreation = $false
    )
    
    Write-Section "Deploying Fabric Artifacts"
    
    try {
        # Authenticate with Fabric CLI using service principal
        if ($Config.ClientId -and $Config.ClientSecret -and $Config.TenantId) {
            Write-ColorOutput "Authenticating with Fabric CLI..." $ColorInfo "🔐"
            
            $env:AZURE_CLIENT_ID = $Config.ClientId
            $env:AZURE_CLIENT_SECRET = $Config.ClientSecret
            $env:AZURE_TENANT_ID = $Config.TenantId
            
            fab auth login --service-principal --client-id $Config.ClientId --client-secret $Config.ClientSecret --tenant-id $Config.TenantId
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "Fabric CLI authentication successful" $ColorSuccess "✅"
            } else {
                Write-ColorOutput "Fabric CLI authentication failed" $ColorError "❌"
                return $false
            }
        } else {
            Write-ColorOutput "Missing credentials for Fabric CLI authentication" $ColorWarning "⚠️"
            Write-ColorOutput "Attempting to use existing authentication..." $ColorWarning
        }
        
        # Check current authentication
        $whoami = fab auth whoami 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Fabric CLI authenticated as: $whoami" $ColorSuccess "✅"
        } else {
            Write-ColorOutput "Fabric CLI not authenticated. Please run 'fab auth login' manually." $ColorError "❌"
            return $false
        }
        
        $workspaceName = $Config.WorkspaceName ?? "fabric-otel-workspace"
        $databaseName = $Config.DatabaseName ?? "otelobservabilitydb"
        
        # Create or verify workspace
        if (-not $SkipWorkspaceCreation) {
            Write-ColorOutput "Creating/verifying Fabric workspace: $workspaceName" $ColorInfo "🏗️"
            
            # Check if workspace exists
            $existingWorkspace = fab workspace show --workspace $workspaceName 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "Workspace already exists: $workspaceName" $ColorSuccess "✅"
            } else {
                Write-ColorOutput "Creating new workspace: $workspaceName" $ColorInfo "🔧"
                fab workspace create --workspace $workspaceName
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "Workspace created successfully" $ColorSuccess "✅"
                } else {
                    Write-ColorOutput "Failed to create workspace. Check tenant permissions." $ColorError "❌"
                    Write-ColorOutput "You can use -SkipWorkspaceCreation to skip this step" $ColorInfo "💡"
                    return $false
                }
            }
        } else {
            Write-ColorOutput "Skipping workspace creation" $ColorWarning "⏭️"
        }
        
        # Set workspace context
        Write-ColorOutput "Setting workspace context..." $ColorInfo "🎯"
        fab workspace use --workspace $workspaceName
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Failed to set workspace context" $ColorError "❌"
            return $false
        }
        
        # Create or verify KQL database
        Write-ColorOutput "Creating/verifying KQL database: $databaseName" $ColorInfo "🗄️"
        
        $existingDatabase = fab kqldatabase show --database $databaseName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Database already exists: $databaseName" $ColorSuccess "✅"
        } else {
            Write-ColorOutput "Creating new KQL database: $databaseName" $ColorInfo "🔧"
            fab kqldatabase create --database $databaseName
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "Database created successfully" $ColorSuccess "✅"
                Start-Sleep -Seconds 10  # Allow time for database to be ready
            } else {
                Write-ColorOutput "Failed to create database" $ColorError "❌"
                return $false
            }
        }
        
        # Deploy KQL tables
        Write-ColorOutput "Deploying KQL tables..." $ColorInfo "📊"
        
        $kqlDefinitionsPath = Join-Path $PSScriptRoot "kql-definitions" "tables"
        $tableFiles = Get-ChildItem -Path $kqlDefinitionsPath -Filter "*.kql"
        
        foreach ($tableFile in $tableFiles) {
            Write-ColorOutput "Deploying table from: $($tableFile.Name)" $ColorInfo "  📄"
            
            $kqlContent = Get-Content $tableFile.FullName -Raw
            $tempFile = [System.IO.Path]::GetTempFileName() + ".kql"
            Set-Content -Path $tempFile -Value $kqlContent
            
            try {
                fab kqldatabase execute --database $databaseName --file $tempFile
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "Table deployed successfully: $($tableFile.BaseName)" $ColorSuccess "    ✅"
                } else {
                    Write-ColorOutput "Failed to deploy table: $($tableFile.BaseName)" $ColorWarning "    ⚠️"
                }
            }
            finally {
                Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
            }
        }
        
        Write-ColorOutput "Fabric artifacts deployment completed!" $ColorSuccess "🎉"
        return $true
    }
    catch {
        Write-ColorOutput "Fabric artifacts deployment error: $($_.Exception.Message)" $ColorError "❌"
        return $false
    }
}

function Show-Summary {
    param(
        [hashtable]$Config,
        [bool]$InfrastructureSuccess,
        [bool]$FabricSuccess
    )
    
    Write-Section "Deployment Summary"
    
    Write-ColorOutput "Deployment Results:" $ColorInfo "📊"
    
    if (-not $SkipInfrastructure) {
        $infraStatus = if ($InfrastructureSuccess) { "✅ SUCCESS" } else { "❌ FAILED" }
        Write-ColorOutput "Azure Infrastructure: $infraStatus" $(if ($InfrastructureSuccess) { $ColorSuccess } else { $ColorError })
    }
    
    if (-not $SkipFabricArtifacts) {
        $fabricStatus = if ($FabricSuccess) { "✅ SUCCESS" } else { "❌ FAILED" }
        Write-ColorOutput "Fabric Artifacts: $fabricStatus" $(if ($FabricSuccess) { $ColorSuccess } else { $ColorError })
    }
    
    Write-Host ""
    Write-ColorOutput "Configuration Used:" $ColorInfo "📋"
    Write-ColorOutput "  Workspace: $($Config.WorkspaceName ?? 'default')" $ColorInfo
    Write-ColorOutput "  Database: $($Config.DatabaseName ?? 'default')" $ColorInfo
    Write-ColorOutput "  Resource Group: $($Config.ResourceGroupName ?? 'default')" $ColorInfo
    Write-ColorOutput "  Location: $Location" $ColorInfo
    
    Write-Host ""
    Write-ColorOutput "Next Steps:" $ColorInfo "🎯"
    if ($InfrastructureSuccess -and $FabricSuccess) {
        Write-ColorOutput "  • Test the deployment with: deploy/tools/Test-FabricLocal.ps1" $ColorInfo
        Write-ColorOutput "  • Run the sample application from: app/dotnet-client/OTELWorker/" $ColorInfo
        Write-ColorOutput "  • Monitor data in Fabric workspace: $($Config.WorkspaceName)" $ColorInfo
    } elseif ($InfrastructureSuccess) {
        Write-ColorOutput "  • Re-run with Fabric artifacts: ./Deploy-Complete.ps1 -KeyVaultName $KeyVaultName -SkipInfrastructure" $ColorInfo
        Write-ColorOutput "  • Check Fabric tenant permissions if workspace creation failed" $ColorInfo
    } else {
        Write-ColorOutput "  • Review the errors above and fix any configuration issues" $ColorWarning
        Write-ColorOutput "  • Ensure Key Vault contains all required secrets" $ColorWarning
    }
}

# Main execution
Write-ColorOutput "🚀 Complete Azure OTEL Observability Deployment" $ColorHeader
Write-ColorOutput "Key Vault: $KeyVaultName" $ColorInfo "🔐"
Write-ColorOutput "Location: $Location" $ColorInfo "🌍"

if ($WhatIf) {
    Write-ColorOutput "What-If Mode: No actual changes will be made" $ColorWarning "👁️"
}

Write-Host ""

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "Prerequisites check failed. Please fix the issues above." $ColorError "❌"
    exit 1
}

# Get configuration from Key Vault
$config = Get-KeyVaultSecrets -VaultName $KeyVaultName
if (-not $config) {
    Write-ColorOutput "Failed to retrieve configuration from Key Vault" $ColorError "❌"
    exit 1
}

# Create service principals if requested
if ($CreateServicePrincipals) {
    if (-not (New-ServicePrincipalsAndSecrets -Config $config -VaultName $KeyVaultName)) {
        Write-ColorOutput "Failed to create service principals" $ColorError "❌"
        exit 1
    }
}

# Determine admin object ID
$adminObjectId = $config.AdminObjectId
if ([string]::IsNullOrWhiteSpace($adminObjectId)) {
    if (-not [string]::IsNullOrWhiteSpace($AdminUserEmail)) {
        $adminUser = Get-AzADUser -UserPrincipalName $AdminUserEmail -ErrorAction SilentlyContinue
        if ($adminUser) {
            $adminObjectId = $adminUser.Id
            Write-ColorOutput "Using admin user: $AdminUserEmail" $ColorInfo "👤"
        }
    } else {
        $currentUser = Get-AzADUser -SignedIn -ErrorAction SilentlyContinue
        if ($currentUser) {
            $adminObjectId = $currentUser.Id
            Write-ColorOutput "Using current user as admin" $ColorInfo "👤"
        }
    }
}

# Execute deployments
$infrastructureSuccess = $true
$fabricSuccess = $true

if (-not $SkipInfrastructure) {
    $infrastructureSuccess = Deploy-AzureInfrastructure -Config $config -Location $Location -AdminObjectId $adminObjectId -WhatIf:$WhatIf
}

if (-not $SkipFabricArtifacts -and (-not $WhatIf)) {
    $fabricSuccess = Deploy-FabricArtifacts -Config $config -SkipWorkspaceCreation:$SkipWorkspaceCreation
}

# Show summary
Show-Summary -Config $config -InfrastructureSuccess $infrastructureSuccess -FabricSuccess $fabricSuccess

# Exit with appropriate code
$overallSuccess = $infrastructureSuccess -and $fabricSuccess
if ($overallSuccess) {
    Write-ColorOutput "🎉 Deployment completed successfully!" $ColorSuccess
    exit 0
} else {
    Write-ColorOutput "❌ Deployment completed with errors" $ColorError
    exit 1
}
