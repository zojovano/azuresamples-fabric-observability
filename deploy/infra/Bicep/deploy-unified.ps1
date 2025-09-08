#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Unified deployment script for Azure OTEL Observability Infrastructure
    
.DESCRIPTION
    Intelligent deployment script that automatically chooses configuration source:
    1. Environment variables (default, fastest)
    2. Shared Key Vault secrets (enterprise pattern)
    3. Interactive prompts (last resort)
    
    Note: This script uses existing shared infrastructure (Key Vault, service principals)
    managed by the platform         Write-ColorOutput "1. Deploy Fabric artifacts: ../Deploy-FabricArtifacts.ps1" $ColorInfo "  🔧"eam. It does not create new Key Vaults.
    
.PARAMETER Location
    Azure region for deployment
    
.PARAMETER SubscriptionId
    Azure subscription ID (uses current context if not provided)
    
.PARAMETER SharedKeyVaultName
    Name of the shared Key Vault managed by platform team (auto-detected if not provided)
    
.PARAMETER AdminUserEmail
    Email of the admin user for Fabric capacity (optional, will use current user if not provided)
    
.PARAMETER ForceKeyVault
    Force using shared Key Vault even if environment variables are available
    
.PARAMETER ParameterFile
    Path to parameters file for basic deployment (default: parameters.json)
    
.PARAMETER WhatIf
    Show what would be deployed without actually deploying
    
.EXAMPLE
    ./deploy-unified.ps1
    # Uses environment variables if available, otherwise checks shared Key Vault
    
.EXAMPLE
    ./deploy-unified.ps1 -SharedKeyVaultName "platform-shared-keyvault"
    # Uses specific shared Key Vault
    
.EXAMPLE
    ./deploy-unified.ps1 -ForceKeyVault
    # Forces shared Key Vault usage even if env vars exist
    
.EXAMPLE
    ./deploy-unified.ps1 -WhatIf
    # Preview deployment without executing
    
.NOTES
    Prerequisites (managed by platform team):
    - Shared Azure Key Vault with access policies
    - Project secrets populated in Key Vault
    - Shared service principal with Key Vault permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Location = "swedencentral",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory = $false)]
    [string]$SharedKeyVaultName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminUserEmail = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$ForceKeyVault,
    
    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = "parameters.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Colors for output
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "Cyan"

function Write-ColorOutput {
    param($Message, $Color, $Icon = "")
    Write-Host "$Icon $Message" -ForegroundColor $Color
}

function Test-AzureConnection {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-ColorOutput "Not connected to Azure. Please run Connect-AzAccount first." $ColorError "❌"
            return $false
        }
        Write-ColorOutput "Connected to Azure as: $($context.Account.Id)" $ColorSuccess "✅"
        return $true
    }
    catch {
        Write-ColorOutput "Error checking Azure connection: $($_.Exception.Message)" $ColorError "❌"
        return $false
    }
}

function Get-EnvironmentVariables {
    $envVars = @{
        SubscriptionId = $env:AZURE_SUBSCRIPTION_ID
        TenantId = $env:AZURE_TENANT_ID
        ClientId = $env:AZURE_CLIENT_ID
        ClientSecret = $env:AZURE_CLIENT_SECRET
        FabricWorkspace = $env:FABRIC_WORKSPACE_NAME
        FabricDatabase = $env:FABRIC_DATABASE_NAME
        ResourceGroup = $env:RESOURCE_GROUP_NAME
    }
    
    $hasRequired = -not [string]::IsNullOrEmpty($envVars.SubscriptionId) -and
                   -not [string]::IsNullOrEmpty($envVars.TenantId)
    
    if ($hasRequired) {
        Write-ColorOutput "Found Azure configuration in environment variables" $ColorSuccess "✅"
        return @{
            Source = "Environment"
            HasCredentials = $hasRequired
            Data = $envVars
        }
    } else {
        Write-ColorOutput "Environment variables not fully configured" $ColorWarning "⚠️"
        return @{
            Source = "Environment"
            HasCredentials = $false
            Data = $envVars
        }
    }
}

function Find-SharedKeyVault {
    param($PreferredName = "")
    
    try {
        if (-not [string]::IsNullOrEmpty($PreferredName)) {
            $kv = Get-AzKeyVault -VaultName $PreferredName -ErrorAction SilentlyContinue
            if ($kv) {
                Write-ColorOutput "Using specified shared Key Vault: $PreferredName" $ColorSuccess "✅"
                return $kv.VaultName
            } else {
                Write-ColorOutput "Specified Key Vault not found: $PreferredName" $ColorWarning "⚠️"
            }
        }
        
        # Check environment variable for shared Key Vault
        $sharedKvName = $env:SHARED_KEYVAULT_NAME
        if (-not [string]::IsNullOrEmpty($sharedKvName)) {
            $kv = Get-AzKeyVault -VaultName $sharedKvName -ErrorAction SilentlyContinue
            if ($kv) {
                Write-ColorOutput "Using shared Key Vault from environment: $sharedKvName" $ColorSuccess "✅"
                return $kv.VaultName
            }
        }
        
        # Look for platform/shared Key Vaults (common naming patterns)
        $kvs = Get-AzKeyVault | Where-Object { 
            $_.VaultName -match "platform|shared|fabric.*otel|otel.*fabric" 
        }
        if ($kvs -and $kvs.Count -gt 0) {
            $selectedKv = $kvs[0].VaultName
            Write-ColorOutput "Auto-detected shared Key Vault: $selectedKv" $ColorSuccess "✅"
            return $selectedKv
        }
        
        Write-ColorOutput "No shared Key Vault found. Check with platform team." $ColorWarning "⚠️"
        Write-ColorOutput "Expected Key Vault naming: platform-*, shared-*, *fabric*otel*" $ColorInfo "💡"
        return $null
    }
    catch {
        Write-ColorOutput "Error finding shared Key Vault: $($_.Exception.Message)" $ColorError "❌"
        return $null
    }
}

function Get-SharedKeyVaultSecrets {
    param($VaultName)
    
    try {
        Write-ColorOutput "Retrieving secrets from shared Key Vault: $VaultName" $ColorInfo "🔐"
        
        $secrets = @{}
        # Standard secret names for fabric-otel project in shared Key Vault
        $secretNames = @(
            "fabric-otel-azure-subscription-id",
            "fabric-otel-azure-tenant-id", 
            "fabric-otel-azure-client-id",
            "fabric-otel-azure-client-secret",
            "fabric-otel-workspace-name",
            "fabric-otel-database-name",
            "fabric-otel-resource-group-name"
        )
        
        foreach ($secretName in $secretNames) {
            try {
                $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $secretName -AsPlainText -ErrorAction SilentlyContinue
                if ($secret) {
                    # Convert to internal key format
                    $key = $secretName.Replace("fabric-otel-", "").Replace("-", "").ToUpper()
                    $secrets[$key] = $secret
                    Write-ColorOutput "Retrieved: $secretName" $ColorSuccess "  ✅"
                } else {
                    Write-ColorOutput "Missing: $secretName" $ColorWarning "  ⚠️"
                }
            }
            catch {
                Write-ColorOutput "Failed to retrieve: $secretName" $ColorWarning "  ⚠️"
            }
        }
        
        $hasRequired = -not [string]::IsNullOrEmpty($secrets.AZURESUBSCRIPTIONID) -and
                       -not [string]::IsNullOrEmpty($secrets.AZURETENANTID)
        
        if (-not $hasRequired) {
            Write-ColorOutput "Platform team may need to populate project secrets in shared Key Vault" $ColorWarning "⚠️"
            Write-ColorOutput "Expected secret names: fabric-otel-azure-subscription-id, fabric-otel-azure-tenant-id, etc." $ColorInfo "💡"
        }
        
        return @{
            Source = "SharedKeyVault"
            VaultName = $VaultName
            HasCredentials = $hasRequired
            Data = $secrets
        }
    }
    catch {
        Write-ColorOutput "Error retrieving shared Key Vault secrets: $($_.Exception.Message)" $ColorError "❌"
        Write-ColorOutput "Contact platform team to verify Key Vault access permissions" $ColorInfo "💡"
        return @{
            Source = "SharedKeyVault"
            VaultName = $VaultName
            HasCredentials = $false
            Data = @{}
        }
    }
}

function Get-InteractiveConfiguration {
    Write-ColorOutput "Gathering configuration interactively..." $ColorInfo "💬"
    Write-ColorOutput "Note: For production, use environment variables or shared Key Vault" $ColorWarning "⚠️"
    
    $config = @{}
    
    # Required fields
    $config.SubscriptionId = Read-Host "Azure Subscription ID"
    $config.TenantId = Read-Host "Azure Tenant ID"
    
    # Optional fields
    $clientId = Read-Host "Azure Client ID (optional, press Enter to skip)"
    if (-not [string]::IsNullOrWhiteSpace($clientId)) {
        $config.ClientId = $clientId
        $config.ClientSecret = Read-Host "Azure Client Secret" -AsSecureString | ConvertFrom-SecureString -AsPlainText
    }
    
    $config.FabricWorkspace = Read-Host "Fabric Workspace Name (default: fabric-otel-workspace)" 
    if ([string]::IsNullOrWhiteSpace($config.FabricWorkspace)) {
        $config.FabricWorkspace = "fabric-otel-workspace"
    }
    
    $config.FabricDatabase = Read-Host "Fabric Database Name (default: otelobservabilitydb)"
    if ([string]::IsNullOrWhiteSpace($config.FabricDatabase)) {
        $config.FabricDatabase = "otelobservabilitydb"
    }
    
    return @{
        Source = "Interactive"
        HasCredentials = $true
        Data = $config
    }
}

function Show-PrerequisitesInfo {
    Write-ColorOutput "📋 Platform Team Prerequisites (if using shared Key Vault):" $ColorInfo
    Write-ColorOutput "=" * 60 $ColorInfo
    Write-ColorOutput "✅ Shared Azure Key Vault with access policies" $ColorInfo "  •"
    Write-ColorOutput "✅ Project secrets populated with naming: fabric-otel-*" $ColorInfo "  •"
    Write-ColorOutput "✅ Shared service principal with Key Vault permissions" $ColorInfo "  •"
    Write-ColorOutput "✅ Required GitHub secrets configured" $ColorInfo "  •"
    Write-Host ""
    Write-ColorOutput "💡 Expected Key Vault secret names:" $ColorInfo
    Write-ColorOutput "   fabric-otel-azure-subscription-id" $ColorWarning "  •"
    Write-ColorOutput "   fabric-otel-azure-tenant-id" $ColorWarning "  •"
    Write-ColorOutput "   fabric-otel-azure-client-id" $ColorWarning "  •"
    Write-ColorOutput "   fabric-otel-azure-client-secret" $ColorWarning "  •"
    Write-ColorOutput "   fabric-otel-workspace-name" $ColorWarning "  •"
    Write-ColorOutput "   fabric-otel-database-name" $ColorWarning "  •"
    Write-ColorOutput "   fabric-otel-resource-group-name" $ColorWarning "  •"
    Write-Host ""
}

function Invoke-Deployment {
    param($Config, $Location, $WhatIf = $false)
    
    $deploymentName = "unified-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $bicepTemplate = Join-Path $PSScriptRoot "main.bicep"
    
    # Prepare deployment parameters
    $deploymentParameters = @{
        location = $Location
    }
    
    # Add admin object ID
    if (-not [string]::IsNullOrEmpty($AdminUserEmail)) {
        $adminUser = Get-AzADUser -UserPrincipalName $AdminUserEmail -ErrorAction SilentlyContinue
        if ($adminUser) {
            $deploymentParameters.adminObjectId = $adminUser.Id
        }
    }
    
    if (-not $deploymentParameters.ContainsKey("adminObjectId")) {
        $currentUser = Get-AzADUser -SignedIn -ErrorAction SilentlyContinue
        if ($currentUser) {
            $deploymentParameters.adminObjectId = $currentUser.Id
        }
    }
    
    # Add configuration-specific parameters
    if ($Config.Data.ClientId) {
        $deploymentParameters.appServicePrincipalClientId = $Config.Data.ClientId
    }
    
    Write-ColorOutput "Deployment Configuration:" $ColorInfo "📋"
    Write-ColorOutput "  Source: $($Config.Source)" $ColorInfo "  •"
    Write-ColorOutput "  Template: main.bicep" $ColorInfo "  •"
    Write-ColorOutput "  Name: $deploymentName" $ColorInfo "  •"
    Write-ColorOutput "  Location: $Location" $ColorInfo "  •"
    
    if ($WhatIf) {
        Write-ColorOutput "What-If mode: Showing deployment preview..." $ColorWarning "👁️"
        try {
            $whatIfResult = Get-AzDeploymentWhatIfResult -Name $deploymentName `
                -Location $Location `
                -TemplateFile $bicepTemplate `
                -TemplateParameterObject $deploymentParameters
            
            Write-ColorOutput "What-If Results:" $ColorInfo "📊"
            Write-Host $whatIfResult.Changes | Out-String
            return $true
        }
        catch {
            Write-ColorOutput "What-If failed: $($_.Exception.Message)" $ColorError "❌"
            return $false
        }
    }
    
    # Execute deployment
    try {
        Write-ColorOutput "Starting deployment..." $ColorInfo "🚀"
        
        $deployment = New-AzDeployment -Name $deploymentName `
            -Location $Location `
            -TemplateFile $bicepTemplate `
            -TemplateParameterObject $deploymentParameters `
            -Verbose
        
        if ($deployment.ProvisioningState -eq "Succeeded") {
            Write-ColorOutput "Deployment completed successfully!" $ColorSuccess "🎉"
            
            # Display outputs
            if ($deployment.Outputs -and $deployment.Outputs.Count -gt 0) {
                Write-Host ""
                Write-ColorOutput "Deployment Outputs:" $ColorInfo "📋"
                foreach ($output in $deployment.Outputs.GetEnumerator()) {
                    Write-ColorOutput "$($output.Key): $($output.Value.Value)" $ColorSuccess "  •"
                }
            }
            
            return $true
        } else {
            Write-ColorOutput "Deployment failed with state: $($deployment.ProvisioningState)" $ColorError "❌"
            return $false
        }
    }
    catch {
        Write-ColorOutput "Deployment failed: $($_.Exception.Message)" $ColorError "❌"
        return $false
    }
}

# Main execution
Write-ColorOutput "🚀 Unified Azure OTEL Observability Infrastructure Deployment" $ColorInfo
Write-ColorOutput "=============================================================" $ColorInfo
Write-Host ""

# Check Azure connection
if (-not (Test-AzureConnection)) {
    Write-ColorOutput "Please run 'Connect-AzAccount' and try again." $ColorError "❌"
    exit 1
}

# Set subscription context
$context = Get-AzContext
if (-not [string]::IsNullOrEmpty($SubscriptionId) -and $context.Subscription.Id -ne $SubscriptionId) {
    Select-AzSubscription -SubscriptionId $SubscriptionId | Out-Null
    $context = Get-AzContext
}

$subscriptionId = $context.Subscription.Id
$tenantId = $context.Tenant.Id

Write-ColorOutput "Using subscription: $($context.Subscription.Name) ($subscriptionId)" $ColorInfo "📋"
Write-Host ""

# Configuration discovery and priority
$config = $null

if ($ForceKeyVault -or (-not [string]::IsNullOrEmpty($SharedKeyVaultName))) {
    # Use shared Key Vault (enterprise pattern)
    Write-ColorOutput "🔐 Using shared Key Vault configuration..." $ColorInfo
    
    $vaultName = if ([string]::IsNullOrEmpty($SharedKeyVaultName)) { 
        Find-SharedKeyVault 
    } else { 
        $SharedKeyVaultName 
    }
    
    if ($vaultName) {
        $config = Get-SharedKeyVaultSecrets -VaultName $vaultName
    } else {
        Write-ColorOutput "Contact platform team to set up shared Key Vault access" $ColorError "❌"
        Show-PrerequisitesInfo
        exit 1
    }
} else {
    # Try environment variables first (development pattern)
    Write-ColorOutput "🌍 Checking environment variables..." $ColorInfo
    $config = Get-EnvironmentVariables
    
    if (-not $config.HasCredentials) {
        # Fallback to shared Key Vault
        Write-ColorOutput "🔐 Falling back to shared Key Vault..." $ColorInfo
        $vaultName = Find-SharedKeyVault
        if ($vaultName) {
            $config = Get-SharedKeyVaultSecrets -VaultName $vaultName
            if (-not $config.HasCredentials) {
                Show-PrerequisitesInfo
            }
        }
    }
}

# Last resort: interactive
if (-not $config -or -not $config.HasCredentials) {
    Write-ColorOutput "💬 Using interactive configuration..." $ColorWarning
    $config = Get-InteractiveConfiguration
}

# Deploy infrastructure
Write-Host ""
Write-ColorOutput "Deploying infrastructure using $($config.Source) configuration..." $ColorInfo "🚀"

$deploymentSuccess = Invoke-Deployment -Config $config -Location $Location -WhatIf:$WhatIf

if ($deploymentSuccess) {
    Write-Host ""
    Write-ColorOutput "🎯 Next Steps:" $ColorInfo
    
    if ($config.Source -eq "KeyVault") {
        Write-ColorOutput "1. Configure GitHub repository secrets:" $ColorInfo "  📝"
        Write-ColorOutput "   SHARED_KEYVAULT_NAME: $($config.VaultName)" $ColorWarning "    •"
        Write-ColorOutput "2. Deploy Fabric artifacts: ../Deploy-FabricArtifacts.ps1" $ColorInfo "  🔧"
    } else {
        Write-ColorOutput "1. Deploy Fabric artifacts: ./infra/Deploy-FabricArtifacts.ps1" $ColorInfo "  🔧"
        Write-ColorOutput "2. Run integration tests: ./tests/Test-FabricIntegration.ps1" $ColorInfo "  🧪"
    }
    
    exit 0
} else {
    Write-ColorOutput "Deployment failed. Please check the errors above." $ColorError "❌"
    exit 1
}
