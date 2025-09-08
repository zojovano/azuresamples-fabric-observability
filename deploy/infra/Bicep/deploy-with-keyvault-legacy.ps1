#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Enhanced deployment script that creates service principals and deploys infrastructure with Key Vault integration
    
.DESCRIPTION
    This script consolidates the infrastructure deployment including:
    - Service principal creation for GitHub Actions and application
    - Key Vault deployment via Bicep
    - Complete infrastructure deployment
    - Secret population in Key Vault
    
.PARAMETER Location
    Azure region for deployment
    
.PARAMETER AdminUserEmail
    Email of the admin user for Fabric capacity (optional, will use current user if not provided)
    
.PARAMETER KeyVaultName
    Name for the Key Vault (optional, will generate unique name if not provided)
    
.PARAMETER SkipServicePrincipalCreation
    Skip service principal creation (use existing ones from parameters)
    
.EXAMPLE
    .\deploy-with-keyvault.ps1 -AdminUserEmail "admin@company.com"
    
.EXAMPLE
    .\deploy-with-keyvault.ps1 -Location "eastus" -KeyVaultName "my-fabric-kv"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Location = "swedencentral",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminUserEmail = "",
    
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipServicePrincipalCreation
)

# Import common functions if they exist
$commonFunctionsPath = Join-Path $PSScriptRoot "../../tools/Test-FabricLocal.ps1"
if (Test-Path $commonFunctionsPath) {
    . $commonFunctionsPath
} else {
    # Define basic color output functions
    $ColorSuccess = "Green"
    $ColorWarning = "Yellow" 
    $ColorError = "Red"
    $ColorInfo = "Cyan"
    
    function Write-ColorOutput {
        param($Message, $Color, $Icon = "")
        Write-Host "$Icon $Message" -ForegroundColor $Color
    }
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

function New-ServicePrincipalIfNotExists {
    param($DisplayName, $Role = "Contributor", $Scope)
    
    try {
        # Check if service principal already exists
        $existingSp = Get-AzADServicePrincipal -DisplayName $DisplayName -ErrorAction SilentlyContinue
        
        if ($existingSp) {
            Write-ColorOutput "Service principal '$DisplayName' already exists" $ColorWarning "⚠️"
            
            # Get or create new credential
            $credentials = Get-AzADServicePrincipalCredential -ObjectId $existingSp.Id -ErrorAction SilentlyContinue
            if (-not $credentials -or $credentials.Count -eq 0) {
                Write-ColorOutput "Creating new credential for existing service principal" $ColorInfo "🔧"
                $credential = New-AzADServicePrincipalCredential -ObjectId $existingSp.Id
                $clientSecret = $credential.SecretText
            } else {
                Write-ColorOutput "Using existing credential (you may need to provide the secret manually)" $ColorWarning "⚠️"
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

# Main script execution
Write-ColorOutput "🚀 Enhanced Infrastructure Deployment with Key Vault Integration" $ColorInfo
Write-ColorOutput "Location: $Location" $ColorInfo
Write-Host ""

# Check Azure connection
if (-not (Test-AzureConnection)) {
    Write-ColorOutput "Please run 'Connect-AzAccount' and try again." $ColorError "❌"
    exit 1
}

# Get current context
$context = Get-AzContext
$subscriptionId = $context.Subscription.Id
$tenantId = $context.Tenant.Id

Write-ColorOutput "Using subscription: $($context.Subscription.Name) ($subscriptionId)" $ColorInfo "📋"

# Get admin object ID
if ([string]::IsNullOrWhiteSpace($AdminUserEmail)) {
    Write-ColorOutput "No admin email provided, using current user..." $ColorInfo "👤"
    $currentUser = Get-AzADUser -SignedIn -ErrorAction SilentlyContinue
    if ($currentUser) {
        $adminObjectId = $currentUser.Id
        Write-ColorOutput "Using current user: $($currentUser.DisplayName) ($adminObjectId)" $ColorSuccess "✅"
    } else {
        Write-ColorOutput "Could not get current user, please provide -AdminUserEmail parameter" $ColorError "❌"
        exit 1
    }
} else {
    Write-ColorOutput "Looking up admin user: $AdminUserEmail" $ColorInfo "👤"
    $adminUser = Get-AzADUser -UserPrincipalName $AdminUserEmail -ErrorAction SilentlyContinue
    
    if (-not $adminUser) {
        $adminUser = Get-AzADUser -DisplayName $AdminUserEmail -ErrorAction SilentlyContinue
    }
    
    if (-not $adminUser) {
        Write-ColorOutput "Could not find user: $AdminUserEmail" $ColorError "❌"
        exit 1
    }
    
    $adminObjectId = $adminUser.Id
    Write-ColorOutput "Found admin user: $($adminUser.DisplayName) ($adminObjectId)" $ColorSuccess "✅"
}

# Generate Key Vault name if not provided
if ([string]::IsNullOrWhiteSpace($KeyVaultName)) {
    $uniqueString = (Get-Random -Maximum 99999).ToString().PadLeft(5, '0')
    $KeyVaultName = "fabric-otel-kv-$uniqueString"
    Write-ColorOutput "Generated Key Vault name: $KeyVaultName" $ColorInfo "🏗️"
}

# Create service principals if needed
if (-not $SkipServicePrincipalCreation) {
    Write-ColorOutput "Creating/checking service principals..." $ColorInfo "🔧"
    
    # GitHub Actions service principal
    $githubSp = New-ServicePrincipalIfNotExists -DisplayName "github-actions-fabric-otel" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"
    
    # Application service principal  
    $appSp = New-ServicePrincipalIfNotExists -DisplayName "fabric-otel-app" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"
    
    if ($appSp.IsExisting -and $appSp.ClientSecret -eq "EXISTING_CREDENTIAL_SECRET_NOT_RETRIEVABLE") {
        Write-ColorOutput "⚠️  WARNING: Application service principal exists but secret is not retrievable." $ColorWarning
        Write-ColorOutput "You may need to create a new credential or provide the secret manually." $ColorWarning
        $appClientSecret = Read-Host "Enter the application service principal client secret (or press Enter to create new credential)"
        
        if ([string]::IsNullOrWhiteSpace($appClientSecret)) {
            Write-ColorOutput "Creating new credential for application service principal..." $ColorInfo "🔧"
            $newCredential = New-AzADServicePrincipalCredential -ObjectId $appSp.ObjectId
            $appClientSecret = $newCredential.SecretText
        }
    } else {
        $appClientSecret = $appSp.ClientSecret
    }
} else {
    Write-ColorOutput "Skipping service principal creation as requested" $ColorWarning "⏭️"
    Write-ColorOutput "Please ensure you provide the correct object IDs in parameters" $ColorWarning "📝"
}

# Prepare deployment parameters
$deploymentParameters = @{
    location = $Location
    adminObjectId = $adminObjectId
    keyVaultName = $KeyVaultName
}

if (-not $SkipServicePrincipalCreation) {
    $deploymentParameters.githubServicePrincipalObjectId = $githubSp.ObjectId
    $deploymentParameters.appServicePrincipalClientId = $appSp.AppId
    $deploymentParameters.appServicePrincipalObjectId = $appSp.ObjectId
    $deploymentParameters.appServicePrincipalClientSecret = $appClientSecret
}

Write-ColorOutput "Deploying infrastructure via Bicep..." $ColorInfo "🏗️"

try {
    # Deploy infrastructure
    $deploymentName = "enhanced-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    $deployment = New-AzDeployment -Name $deploymentName `
        -Location $Location `
        -TemplateFile "main.bicep" `
        -TemplateParameterObject $deploymentParameters `
        -Verbose
    
    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-ColorOutput "Infrastructure deployment completed successfully!" $ColorSuccess "🎉"
        
        # Output results
        Write-Host ""
        Write-ColorOutput "==== Deployment Outputs ====" $ColorInfo
        Write-ColorOutput "Resource Group: $($deployment.Outputs.resourceGroupName.Value)" $ColorSuccess "📁"
        Write-ColorOutput "Key Vault Name: $($deployment.Outputs.keyVaultName.Value)" $ColorSuccess "🔐"
        Write-ColorOutput "Key Vault URI: $($deployment.Outputs.keyVaultUri.Value)" $ColorSuccess "🌐"
        
        if (-not $SkipServicePrincipalCreation) {
            Write-Host ""
            Write-ColorOutput "==== GitHub Repository Secrets ====" $ColorInfo  
            Write-ColorOutput "Add these to GitHub (Settings → Secrets → Actions):" $ColorWarning
            Write-ColorOutput "AZURE_CLIENT_ID: $($githubSp.AppId)" $ColorWarning "🔑"
            Write-ColorOutput "AZURE_TENANT_ID: $tenantId" $ColorWarning "🔑"
            Write-ColorOutput "AZURE_SUBSCRIPTION_ID: $subscriptionId" $ColorWarning "🔑"
        }
        
        Write-Host ""
        Write-ColorOutput "==== Next Steps ====" $ColorInfo
        Write-ColorOutput "1. Add GitHub repository secrets shown above" $ColorWarning "📝"
        Write-ColorOutput "2. Update GitHub Actions workflow to use Key Vault: $($deployment.Outputs.keyVaultName.Value)" $ColorWarning "⚙️"
        Write-ColorOutput "3. Test the deployment: pwsh deploy/tools/Test-FabricLocal.ps1 -Mode KeyVault -KeyVaultName '$($deployment.Outputs.keyVaultName.Value)'" $ColorWarning "🧪"
    } else {
        Write-ColorOutput "Deployment failed with state: $($deployment.ProvisioningState)" $ColorError "❌"
        exit 1
    }
}
catch {
    Write-ColorOutput "Deployment failed: $($_.Exception.Message)" $ColorError "❌"
    throw
}
