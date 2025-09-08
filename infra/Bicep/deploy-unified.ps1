#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Unified deployment script for Azure OTEL Observability Infrastructure
    
.DESCRIPTION
    Intelligent deployment script that automatically chooses configuration source:
    1. Environment variables (default, fastest)
    2. Key Vault secrets (fallback, enterprise)
    3. Interactive prompts (last resort)
    
    Can also create service principals and Key Vault if needed.
    
.PARAMETER Location
    Azure region for deployment
    
.PARAMETER SubscriptionId
    Azure subscription ID (uses current context if not provided)
    
.PARAMETER KeyVaultName
    Key Vault name to use for secrets (auto-detected if not provided)
    
.PARAMETER AdminUserEmail
    Email of the admin user for Fabric capacity (optional, will use current user if not provided)
    
.PARAMETER CreateKeyVault
    Create new Key Vault and service principals if they don't exist
    
.PARAMETER ForceKeyVault
    Force using Key Vault even if environment variables are available
    
.PARAMETER ParameterFile
    Path to parameters file for basic deployment (default: parameters.json)
    
.PARAMETER WhatIf
    Show what would be deployed without actually deploying
    
.EXAMPLE
    ./deploy-unified.ps1
    # Uses environment variables if available, otherwise prompts
    
.EXAMPLE
    ./deploy-unified.ps1 -CreateKeyVault -AdminUserEmail "admin@company.com"
    # Creates full Key Vault setup with service principals
    
.EXAMPLE
    ./deploy-unified.ps1 -KeyVaultName "my-fabric-kv" -ForceKeyVault
    # Forces Key Vault usage even if env vars exist
    
.EXAMPLE
    ./deploy-unified.ps1 -WhatIf
    # Preview deployment without executing
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Location = "swedencentral",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "",
    
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminUserEmail = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateKeyVault,
    
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

function Find-KeyVault {
    param($PreferredName = "")
    
    try {
        if (-not [string]::IsNullOrEmpty($PreferredName)) {
            $kv = Get-AzKeyVault -VaultName $PreferredName -ErrorAction SilentlyContinue
            if ($kv) {
                Write-ColorOutput "Using specified Key Vault: $PreferredName" $ColorSuccess "✅"
                return $kv.VaultName
            }
        }
        
        # Look for fabric-related Key Vaults
        $kvs = Get-AzKeyVault | Where-Object { $_.VaultName -match "fabric|otel" }
        if ($kvs -and $kvs.Count -gt 0) {
            $selectedKv = $kvs[0].VaultName
            Write-ColorOutput "Auto-detected Key Vault: $selectedKv" $ColorSuccess "✅"
            return $selectedKv
        }
        
        Write-ColorOutput "No suitable Key Vault found" $ColorWarning "⚠️"
        return $null
    }
    catch {
        Write-ColorOutput "Error finding Key Vault: $($_.Exception.Message)" $ColorError "❌"
        return $null
    }
}

function Get-KeyVaultSecrets {
    param($VaultName)
    
    try {
        Write-ColorOutput "Retrieving secrets from Key Vault: $VaultName" $ColorInfo "🔐"
        
        $secrets = @{}
        $secretNames = @(
            "AZURE-SUBSCRIPTION-ID",
            "AZURE-TENANT-ID", 
            "AZURE-CLIENT-ID",
            "AZURE-CLIENT-SECRET",
            "FABRIC-WORKSPACE-NAME",
            "FABRIC-DATABASE-NAME",
            "RESOURCE-GROUP-NAME"
        )
        
        foreach ($secretName in $secretNames) {
            try {
                $secret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $secretName -AsPlainText -ErrorAction SilentlyContinue
                if ($secret) {
                    $key = $secretName.Replace("-", "")
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
        
        return @{
            Source = "KeyVault"
            VaultName = $VaultName
            HasCredentials = $hasRequired
            Data = $secrets
        }
    }
    catch {
        Write-ColorOutput "Error retrieving Key Vault secrets: $($_.Exception.Message)" $ColorError "❌"
        return @{
            Source = "KeyVault"
            VaultName = $VaultName
            HasCredentials = $false
            Data = @{}
        }
    }
}

function Get-InteractiveConfiguration {
    Write-ColorOutput "Gathering configuration interactively..." $ColorInfo "💬"
    
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

function New-ServicePrincipalIfNotExists {
    param($DisplayName, $Role = "Contributor", $Scope)
    
    try {
        $existingSp = Get-AzADServicePrincipal -DisplayName $DisplayName -ErrorAction SilentlyContinue
        
        if ($existingSp) {
            Write-ColorOutput "Service principal '$DisplayName' already exists" $ColorWarning "⚠️"
            
            $credentials = Get-AzADServicePrincipalCredential -ObjectId $existingSp.Id -ErrorAction SilentlyContinue
            if (-not $credentials -or $credentials.Count -eq 0) {
                Write-ColorOutput "Creating new credential for existing service principal" $ColorInfo "🔧"
                $credential = New-AzADServicePrincipalCredential -ObjectId $existingSp.Id
                $clientSecret = $credential.SecretText
            } else {
                Write-ColorOutput "Using existing credential" $ColorWarning "⚠️"
                $clientSecret = "EXISTING_CREDENTIAL_SECRET_NOT_RETRIEVABLE"
            }
            
            return @{
                AppId = $existingSp.AppId
                ObjectId = $existingSp.Id
                ClientSecret = $clientSecret
                IsExisting = $true
            }
        }
        else {
            Write-ColorOutput "Creating service principal: $DisplayName" $ColorInfo "🔧"
            $sp = New-AzADServicePrincipal -DisplayName $DisplayName -Role $Role -Scope $Scope
            
            return @{
                AppId = $sp.AppId
                ObjectId = $sp.Id
                ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.PasswordCredentials.SecretText))
                IsExisting = $false
            }
        }
    }
    catch {
        Write-ColorOutput "Error with service principal: $($_.Exception.Message)" $ColorError "❌"
        throw
    }
}

function New-KeyVaultWithSecrets {
    param($VaultName, $Location, $AdminObjectId, $Secrets)
    
    try {
        Write-ColorOutput "Creating Key Vault: $VaultName" $ColorInfo "🏗️"
        
        # Check if Key Vault already exists
        $existingKv = Get-AzKeyVault -VaultName $VaultName -ErrorAction SilentlyContinue
        if ($existingKv) {
            Write-ColorOutput "Key Vault already exists: $VaultName" $ColorWarning "⚠️"
        } else {
            # Create resource group for Key Vault if needed
            $kvResourceGroup = "rg-keyvault-$Location"
            $rg = Get-AzResourceGroup -Name $kvResourceGroup -ErrorAction SilentlyContinue
            if (-not $rg) {
                Write-ColorOutput "Creating resource group for Key Vault: $kvResourceGroup" $ColorInfo "📁"
                New-AzResourceGroup -Name $kvResourceGroup -Location $Location | Out-Null
            }
            
            # Create Key Vault
            $kv = New-AzKeyVault -VaultName $VaultName -ResourceGroupName $kvResourceGroup -Location $Location
            Write-ColorOutput "Key Vault created successfully" $ColorSuccess "✅"
        }
        
        # Set secrets
        Write-ColorOutput "Storing secrets in Key Vault..." $ColorInfo "🔐"
        foreach ($secret in $Secrets.GetEnumerator()) {
            $secretName = $secret.Key -replace "_", "-"
            try {
                Set-AzKeyVaultSecret -VaultName $VaultName -Name $secretName -SecretValue (ConvertTo-SecureString $secret.Value -AsPlainText -Force) | Out-Null
                Write-ColorOutput "Stored: $secretName" $ColorSuccess "  ✅"
            }
            catch {
                Write-ColorOutput "Failed to store: $secretName - $($_.Exception.Message)" $ColorWarning "  ⚠️"
            }
        }
        
        return $VaultName
    }
    catch {
        Write-ColorOutput "Error creating Key Vault: $($_.Exception.Message)" $ColorError "❌"
        throw
    }
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

if ($CreateKeyVault) {
    # Create new Key Vault setup
    Write-ColorOutput "🏗️ Creating new Key Vault setup..." $ColorInfo
    
    # Generate Key Vault name if not provided
    if ([string]::IsNullOrEmpty($KeyVaultName)) {
        $uniqueString = (Get-Random -Maximum 99999).ToString().PadLeft(5, '0')
        $KeyVaultName = "fabric-otel-kv-$uniqueString"
    }
    
    # Get admin object ID
    if ([string]::IsNullOrEmpty($AdminUserEmail)) {
        $currentUser = Get-AzADUser -SignedIn -ErrorAction SilentlyContinue
        $adminObjectId = $currentUser.Id
    } else {
        $adminUser = Get-AzADUser -UserPrincipalName $AdminUserEmail -ErrorAction SilentlyContinue
        $adminObjectId = $adminUser.Id
    }
    
    # Create service principals
    $githubSp = New-ServicePrincipalIfNotExists -DisplayName "github-actions-fabric-otel" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"
    $appSp = New-ServicePrincipalIfNotExists -DisplayName "fabric-otel-app" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"
    
    # Prepare secrets for Key Vault
    $secrets = @{
        "AZURE-SUBSCRIPTION-ID" = $subscriptionId
        "AZURE-TENANT-ID" = $tenantId
        "AZURE-CLIENT-ID" = $appSp.AppId
        "AZURE-CLIENT-SECRET" = $appSp.ClientSecret
        "FABRIC-WORKSPACE-NAME" = "fabric-otel-workspace"
        "FABRIC-DATABASE-NAME" = "otelobservabilitydb"
        "RESOURCE-GROUP-NAME" = "azuresamples-platformobservabilty-fabric"
    }
    
    # Create Key Vault and store secrets
    $createdVaultName = New-KeyVaultWithSecrets -VaultName $KeyVaultName -Location $Location -AdminObjectId $adminObjectId -Secrets $secrets
    
    # Use Key Vault configuration
    $config = Get-KeyVaultSecrets -VaultName $createdVaultName
    
} elseif ($ForceKeyVault -or (-not [string]::IsNullOrEmpty($KeyVaultName))) {
    # Force Key Vault or specific Key Vault provided
    Write-ColorOutput "🔐 Using Key Vault configuration..." $ColorInfo
    
    $vaultName = if ([string]::IsNullOrEmpty($KeyVaultName)) { Find-KeyVault } else { $KeyVaultName }
    if ($vaultName) {
        $config = Get-KeyVaultSecrets -VaultName $vaultName
    }
} else {
    # Try environment variables first
    Write-ColorOutput "🌍 Checking environment variables..." $ColorInfo
    $config = Get-EnvironmentVariables
    
    if (-not $config.HasCredentials) {
        # Fallback to Key Vault
        Write-ColorOutput "🔐 Falling back to Key Vault..." $ColorInfo
        $vaultName = Find-KeyVault
        if ($vaultName) {
            $config = Get-KeyVaultSecrets -VaultName $vaultName
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
        Write-ColorOutput "2. Deploy Fabric artifacts: ./infra/Deploy-FabricArtifacts.ps1" $ColorInfo "  🔧"
    } else {
        Write-ColorOutput "1. Deploy Fabric artifacts: ./infra/Deploy-FabricArtifacts.ps1" $ColorInfo "  🔧"
        Write-ColorOutput "2. Run integration tests: ./tests/Test-FabricIntegration.ps1" $ColorInfo "  🧪"
    }
    
    exit 0
} else {
    Write-ColorOutput "Deployment failed. Please check the errors above." $ColorError "❌"
    exit 1
}
