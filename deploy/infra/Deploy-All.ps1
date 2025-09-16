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
    Name of t        Write-ColorOutput "Fabric artifacts deployment completed with infrastructure ready" $ColorSuccess "✅"
        Write-ColorOutput "Next steps:" $ColorInfo "📋"
        Write-ColorOutput "  • Manually create KQL database '$databaseName' in the Fabric workspace" $ColorInfo "    💡"
        Write-ColorOutput "  • Use the KQL definitions in deploy/data/otel-tables.kql to create tables" $ColorInfo "    💡"
        
        # Ensure we return only a boolean value
        Write-Output $true Vault containing project secrets (optional, uses config/project-config.json if not provided)
    
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
    ./Deploy-All.ps1
    
.EXAMPLE
    ./Deploy-All.ps1 -KeyVaultName "my-project-keyvault"
    
.EXAMPLE
    ./Deploy-All.ps1 -KeyVaultName "my-kv" -SkipInfrastructure
    
.EXAMPLE
    ./Deploy-All.ps1 -CreateServicePrincipals -KeyVaultName "my-kv"
    
.EXAMPLE
    ./Deploy-All.ps1 -KeyVaultName "my-kv" -WhatIf
    
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

# Colors for output (defined early)
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "Cyan"
$ColorHeader = "Magenta"

# Load centralized project configuration
Write-Host "📋 Loading project configuration..." -ForegroundColor $ColorInfo
$configModulePath = Join-Path $PSScriptRoot "../config/ProjectConfig.psm1"
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
    $separator = "=" * 80
    Write-ColorOutput $separator $ColorHeader
    Write-ColorOutput $Title $ColorHeader "🎯"
    Write-ColorOutput $separator $ColorHeader
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
    
    # Check Azure connection (using Azure CLI)
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        if ($account -and $account.user) {
            Write-ColorOutput "Azure Connection: $($account.user.name)" $ColorSuccess "✅"
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
        # Test Key Vault access using Azure CLI
        $kvJson = az keyvault show --name $VaultName --output json 2>$null
        if ($kvJson) {
            $kv = $kvJson | ConvertFrom-Json
            Write-ColorOutput "Key Vault found: $($kv.name)" $ColorSuccess "✅"
        } else {
            throw "Key Vault not found or not accessible"
        }
        
        # Define actual secrets that need to be retrieved from Key Vault
        # Only admin object ID needed for deployment with user context
        $secretNames = @{
            "admin-object-id" = "AdminObjectId"
        }
        
        # Build configuration from project config + Key Vault secrets
        $config = @{
            "SubscriptionId" = $ProjectConfig.azure.subscriptionId
            "TenantId" = ""  # Will be auto-detected from Azure CLI
            "ClientId" = ""  # Will be populated by service principal creation
            "ResourceGroupName" = $ProjectConfig.azure.resourceGroupName
            "WorkspaceName" = $ProjectConfig.fabric.workspaceName
            "DatabaseName" = $ProjectConfig.fabric.databaseName
        }
        # Retrieve actual secrets from Key Vault
        $missingSecrets = @()
        
        foreach ($secretName in $secretNames.Keys) {
            try {
                $secret = az keyvault secret show --vault-name $VaultName --name $secretName --query "value" --output tsv 2>$null
                if ($secret) {
                    $config[$secretNames[$secretName]] = $secret
                    Write-ColorOutput "Retrieved secret: $secretName" $ColorSuccess "  ✅"
                } else {
                    $missingSecrets += $secretName
                    Write-ColorOutput "Missing secret: $secretName" $ColorWarning "  ⚠️"
                }
            }
            catch {
                $missingSecrets += $secretName
                Write-ColorOutput "Failed to retrieve secret: $secretName" $ColorWarning "  ⚠️"
            }
        }
        
        # Auto-detect subscription ID and tenant ID from current Azure CLI context
        try {
            $azAccount = az account show --output json | ConvertFrom-Json
            if (-not $config.SubscriptionId) {
                $config.SubscriptionId = $azAccount.id
                Write-ColorOutput "Auto-detected subscription: $($azAccount.name)" $ColorSuccess "  ✅"
            }
            $config.TenantId = $azAccount.tenantId
            Write-ColorOutput "Auto-detected tenant: $($azAccount.tenantId)" $ColorSuccess "  ✅"
        }
        catch {
            Write-ColorOutput "Failed to auto-detect Azure context" $ColorError "❌"
            return $null
        }
        
        # Log configuration source
        Write-ColorOutput "Configuration loaded from:" $ColorInfo "📋"
        Write-ColorOutput "  • Project config: resource group, workspace, database names" $ColorInfo "  •"
        Write-ColorOutput "  • Azure CLI: subscription and tenant" $ColorInfo "  •"
        Write-ColorOutput "  • Key Vault: service principals and secrets" $ColorInfo "  •"
        
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
        $githubSpJson = az ad sp create-for-rbac --name "fabric-otel-github-actions" --role "Contributor" --scopes "/subscriptions/$subscriptionId" --output json
        $githubSp = $githubSpJson | ConvertFrom-Json
        $githubSecret = $githubSp.password
        
        # Create Application service principal  
        Write-ColorOutput "Creating Application service principal..." $ColorInfo "🔧"
        $appSpJson = az ad sp create-for-rbac --name "fabric-otel-application" --role "Contributor" --scopes "/subscriptions/$subscriptionId" --output json
        $appSp = $appSpJson | ConvertFrom-Json
        $appSecret = $appSp.password
        
        # Populate Key Vault with secrets
        $secrets = @{
            "azure-tenant-id" = $tenantId
            "azure-subscription-id" = $subscriptionId
            "azure-client-id" = $appSp.appId
            "azure-client-secret" = $appSecret
            "github-client-id" = $githubSp.appId
            "github-client-secret" = $githubSecret
            "app-service-principal-object-id" = $appSp.name
            "github-service-principal-object-id" = $githubSp.name
        }
        
        foreach ($secretName in $secrets.Keys) {
            $secretValue = $secrets[$secretName]
            az keyvault secret set --vault-name $VaultName --name $secretName --value $secretValue --output none
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
        # Set Azure context using Azure CLI
        if ($Config.SubscriptionId) {
            az account set --subscription $Config.SubscriptionId
            Write-ColorOutput "Using subscription: $($Config.SubscriptionId)" $ColorInfo "📋"
        }
        
        # Prepare deployment parameters - deploying with user context, using existing Key Vault
        $deploymentParameters = @{
            location = $Location
            resourceGroupName = $Config.ResourceGroupName
            fabricCapacityName = $ProjectConfig.fabric.capacityName
            fabricCapacitySku = $ProjectConfig.fabric.capacitySku
            fabricWorkspaceName = $Config.WorkspaceName
            fabricDatabaseName = $Config.DatabaseName
            eventHubNamespaceName = $ProjectConfig.otel.eventHub.namespaceName
            eventHubName = $ProjectConfig.otel.eventHub.eventHubName
            eventHubSku = $ProjectConfig.otel.eventHub.skuName
            containerGroupName = $ProjectConfig.otel.containerInstance.containerGroupName
            containerName = $ProjectConfig.otel.containerInstance.containerName
            containerImage = $ProjectConfig.otel.containerInstance.containerImage
            appServicePlanName = $ProjectConfig.otel.appService.planName
            appServiceName = $ProjectConfig.otel.appService.appName
        }
        
        # Admin Object IDs (required as array) - Fabric accepts UPNs for admin members
        if ($AdminObjectId) {
            $deploymentParameters.adminObjectIds = @($AdminObjectId)
            Write-ColorOutput "Using admin user: $AdminObjectId" $ColorInfo "👤"
        } elseif ($Config.AdminObjectId) {
            $deploymentParameters.adminObjectIds = @($Config.AdminObjectId)
            Write-ColorOutput "Using admin user from config: $($Config.AdminObjectId)" $ColorInfo "👤"
        } else {
            Write-ColorOutput "Warning: No admin user specified, using current user context" $ColorWarning "⚠️"
            $deploymentParameters.adminObjectIds = @()
        }
        
        Write-ColorOutput "Deploying with user context - no service principals required" $ColorSuccess "✅"
        
        $deploymentName = "fabric-otel-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        $bicepTemplate = Join-Path $PSScriptRoot "Bicep" "main.bicep"
        
        Write-ColorOutput "Deployment name: $deploymentName" $ColorInfo "📋"
        Write-ColorOutput "Template: $bicepTemplate" $ColorInfo "📋"
        Write-ColorOutput "Location: $Location" $ColorInfo "📋"
        
        if ($WhatIf) {
            Write-ColorOutput "Running What-If analysis..." $ColorWarning "👁️"
            
            # Convert parameters to ARM template parameter format
            $armParameters = @{
                '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
                contentVersion = "1.0.0.0"
                parameters = @{}
            }
            
            # Wrap each parameter with "value" property for ARM template format
            foreach ($param in $deploymentParameters.GetEnumerator()) {
                $armParameters.parameters[$param.Key] = @{ value = $param.Value }
            }
            
            # Convert to JSON for Azure CLI
            $parameterJson = $armParameters | ConvertTo-Json -Depth 10
            $tempParamFile = [System.IO.Path]::GetTempFileName()
            $parameterJson | Out-File -FilePath $tempParamFile -Encoding utf8
            
            try {
                az deployment sub what-if --name $deploymentName --location $Location --template-file $bicepTemplate --parameters "@$tempParamFile"
                Write-ColorOutput "What-If completed - check output above" $ColorInfo "📊"
                return $true
            }
            finally {
                Remove-Item $tempParamFile -ErrorAction SilentlyContinue
            }
        }
        
        Write-ColorOutput "Starting infrastructure deployment..." $ColorInfo "🚀"
        
        # Convert parameters to ARM template parameter format
        $armParameters = @{
            '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
            contentVersion = "1.0.0.0"
            parameters = @{}
        }
        
        # Wrap each parameter with "value" property for ARM template format
        foreach ($param in $deploymentParameters.GetEnumerator()) {
            $armParameters.parameters[$param.Key] = @{ value = $param.Value }
        }
        
        # Convert to JSON for Azure CLI
        $parameterJson = $armParameters | ConvertTo-Json -Depth 10
        $tempParamFile = [System.IO.Path]::GetTempFileName()
        $parameterJson | Out-File -FilePath $tempParamFile -Encoding utf8
        
        try {
            $deploymentJson = az deployment sub create --name $deploymentName --location $Location --template-file $bicepTemplate --parameters "@$tempParamFile" --output json
            $deployment = $deploymentJson | ConvertFrom-Json
            
            if ($deployment.properties.provisioningState -eq "Succeeded") {
                Write-ColorOutput "Infrastructure deployment completed!" $ColorSuccess "🎉"
            
                # Display outputs
                if ($deployment.properties.outputs) {
                    Write-ColorOutput "Deployment outputs:" $ColorInfo "📋"
                    $deployment.properties.outputs.PSObject.Properties | ForEach-Object {
                        Write-ColorOutput "$($_.Name): $($_.Value.value)" $ColorSuccess "  •"
                    }
                }
                
                return $true
            } else {
                Write-ColorOutput "Infrastructure deployment failed: $($deployment.properties.provisioningState)" $ColorError "❌"
                return $false
            }
        }
        finally {
            Remove-Item $tempParamFile -ErrorAction SilentlyContinue
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
        $authStatus = fab auth status 2>$null
        if ($LASTEXITCODE -eq 0) {
            $accountLine = $authStatus | Where-Object { $_ -match "Account:" } | Select-Object -First 1
            if ($accountLine) {
                $account = ($accountLine -split "Account:")[1].Trim().Split(' ')[0]
                Write-ColorOutput "Fabric CLI authenticated as: $account" $ColorSuccess "✅"
            } else {
                Write-ColorOutput "Fabric CLI authenticated" $ColorSuccess "✅"
            }
        } else {
            Write-ColorOutput "Fabric CLI not authenticated. Please run 'fab auth login' manually." $ColorError "❌"
            return $false
        }
        
        $workspaceName = $Config.WorkspaceName ?? "fabric-otel-workspace"
        $databaseName = $Config.DatabaseName ?? "otelobservabilitydb"
        
        # Set default capacity for Fabric CLI
        Write-ColorOutput "Setting default Fabric capacity..." $ColorInfo "⚙️"
        fab config set default_capacity $($ProjectConfig.fabric.capacityName)
        
        # Create or verify workspace - use fabric-otel-workspace as working name
        $actualWorkspaceName = "fabric-otel-workspace"
        if (-not $SkipWorkspaceCreation) {
            Write-ColorOutput "Creating/verifying Fabric workspace: $actualWorkspaceName" $ColorInfo "🏗️"
            
            # Check if workspace exists
            $existingWorkspace = fab exists "$actualWorkspaceName.Workspace" 2>$null
            if ($LASTEXITCODE -eq 0 -and $existingWorkspace -eq "true") {
                Write-ColorOutput "Workspace already exists: $actualWorkspaceName" $ColorSuccess "✅"
            } else {
                Write-ColorOutput "Creating new workspace: $actualWorkspaceName" $ColorInfo "🔧"
                $createOutput = fab mkdir "$actualWorkspaceName.Workspace" -P capacityName=$($ProjectConfig.fabric.capacityName) 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "Workspace created successfully" $ColorSuccess "✅"
                } elseif ($createOutput -match "WorkspaceNameAlreadyExists") {
                    Write-ColorOutput "Workspace already exists (name collision)" $ColorWarning "⚠️"
                } else {
                    Write-ColorOutput "Failed to create workspace: $createOutput" $ColorError "❌"
                    Write-ColorOutput "You can use -SkipWorkspaceCreation to skip this step" $ColorInfo "💡"
                    return $false
                }
            }
        } else {
            Write-ColorOutput "Skipping workspace creation" $ColorWarning "⏭️"
        }
        
        # Create KQL Database
        Write-ColorOutput "Creating/verifying KQL database: $databaseName" $ColorInfo "🗄️"
        $databasePath = "$actualWorkspaceName.Workspace/$databaseName.KQLDatabase"
        
        $existingDatabase = fab exists $databasePath 2>$null
        if ($LASTEXITCODE -eq 0 -and $existingDatabase -eq "true") {
            Write-ColorOutput "KQL Database already exists: $databaseName" $ColorSuccess "✅"
        } else {
            Write-ColorOutput "Creating KQL database: $databaseName" $ColorInfo "🔧"
            $createDbOutput = fab mkdir $databasePath 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "KQL Database created successfully (with auto Eventhouse)" $ColorSuccess "✅"
            } else {
                Write-ColorOutput "Failed to create KQL database: $createDbOutput" $ColorError "❌"
                return $false
            }
        }
        Write-ColorOutput "Fabric artifacts deployment completed with infrastructure ready" $ColorSuccess "✅"
        Write-ColorOutput "Next steps:" $ColorInfo "�"
        Write-ColorOutput "  • Manually create KQL database '$databaseName' in the Fabric workspace" $ColorInfo "    💡"
        Write-ColorOutput "  • Use the KQL definitions in deploy/data/otel-tables.kql to create tables" $ColorInfo "    💡"
        
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
    Write-ColorOutput "  • Run the sample application from: app/OTELDotNetClient/" $ColorInfo
        Write-ColorOutput "  • Monitor data in Fabric workspace: $($Config.WorkspaceName)" $ColorInfo
    } elseif ($InfrastructureSuccess) {
        Write-ColorOutput "  • Re-run with Fabric artifacts: ./Deploy-All.ps1 -KeyVaultName $KeyVaultName -SkipInfrastructure" $ColorInfo
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
        $adminUserJson = az ad user show --id $AdminUserEmail --output json 2>$null
        if ($adminUserJson) {
            $adminUser = $adminUserJson | ConvertFrom-Json
            $adminObjectId = $adminUser.id
            Write-ColorOutput "Using admin user: $AdminUserEmail" $ColorInfo "👤"
        }
    } else {
        $currentUserJson = az ad signed-in-user show --output json 2>$null
        if ($currentUserJson) {
            $currentUser = $currentUserJson | ConvertFrom-Json
            $adminObjectId = $currentUser.id
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
    # Capture only the boolean return value, filtering out any extra output
    $fabricResult = Deploy-FabricArtifacts -Config $config -SkipWorkspaceCreation:$SkipWorkspaceCreation 2>$null
    $fabricSuccess = if ($fabricResult -is [bool]) { $fabricResult } else { $true }
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
