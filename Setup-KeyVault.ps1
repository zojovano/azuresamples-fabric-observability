#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup Azure Key Vault for GitHub Actions integration
    
.DESCRIPTION
    This script automates the setup of Azure Key Vault for storing secrets used by GitHub Actions.
    It creates the Key Vault, service principals, and stores the required secrets.
    
.PARAMETER KeyVaultName
    Name of the Azure Key Vault to create (must be globally unique)
    
.PARAMETER ResourceGroupName
    Name of the Azure Resource Group
    
.PARAMETER Location
    Azure region for the Key Vault
    
.PARAMETER AdminUserEmail
    Email of the admin user for Fabric capacity
    
.EXAMPLE
    .\Setup-KeyVault.ps1 -KeyVaultName "my-fabric-kv" -AdminUserEmail "admin@company.com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = "fabric-otel-keyvault",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "azuresamples-platformobservabilty-fabric",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "swedencentral",
    
    [Parameter(Mandatory = $true)]
    [string]$AdminUserEmail
)

# Color output functions
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

function New-ServicePrincipalIfNotExists {
    param($DisplayName, $Role = "Contributor", $Scope)
    
    try {
        # Check if service principal already exists
        $existingSp = Get-AzADServicePrincipal -DisplayName $DisplayName -ErrorAction SilentlyContinue
        
        if ($existingSp) {
            Write-ColorOutput "Service principal '$DisplayName' already exists" $ColorWarning "⚠️"
            
            # Get the secret (this will create a new one)
            $credential = New-AzADServicePrincipalCredential -ObjectId $existingSp.Id
            
            return @{
                AppId = $existingSp.AppId
                ObjectId = $existingSp.Id
                ClientSecret = $credential.SecretText
            }
        }
        else {
            Write-ColorOutput "Creating service principal: $DisplayName" $ColorInfo "🔧"
            $sp = New-AzADServicePrincipal -DisplayName $DisplayName -Role $Role -Scope $Scope
            
            return @{
                AppId = $sp.AppId
                ObjectId = $sp.Id
                ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.PasswordCredentials.SecretText))
            }
        }
    }
    catch {
        Write-ColorOutput "Error creating service principal: $($_.Exception.Message)" $ColorError "❌"
        throw
    }
}

# Main script execution
Write-ColorOutput "🚀 Setting up Azure Key Vault for GitHub Actions" $ColorInfo
Write-ColorOutput "Key Vault Name: $KeyVaultName" $ColorInfo
Write-ColorOutput "Resource Group: $ResourceGroupName" $ColorInfo
Write-ColorOutput "Location: $Location" $ColorInfo
Write-ColorOutput "Admin User: $AdminUserEmail" $ColorInfo
Write-Host ""

# Step 1: Check Azure connection
if (-not (Test-AzureConnection)) {
    Write-ColorOutput "Please run 'Connect-AzAccount' and try again." $ColorError "❌"
    exit 1
}

# Get current context
$context = Get-AzContext
$subscriptionId = $context.Subscription.Id
$tenantId = $context.Tenant.Id

Write-ColorOutput "Using subscription: $($context.Subscription.Name) ($subscriptionId)" $ColorInfo "📋"

# Step 2: Create or get Key Vault
try {
    Write-ColorOutput "Checking Key Vault: $KeyVaultName" $ColorInfo "🔍"
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction SilentlyContinue
    
    if (-not $keyVault) {
        Write-ColorOutput "Creating Key Vault: $KeyVaultName" $ColorInfo "🏗️"
        $keyVault = New-AzKeyVault -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -Location $Location
        
        # Enable soft delete and purge protection
        Write-ColorOutput "Enabling Key Vault protection features..." $ColorInfo "🛡️"
        Update-AzKeyVault -VaultName $KeyVaultName -EnableSoftDelete -EnablePurgeProtection
    }
    else {
        Write-ColorOutput "Key Vault already exists: $KeyVaultName" $ColorSuccess "✅"
    }
}
catch {
    Write-ColorOutput "Error with Key Vault: $($_.Exception.Message)" $ColorError "❌"
    exit 1
}

# Step 3: Create GitHub Actions service principal
try {
    Write-ColorOutput "Setting up GitHub Actions service principal..." $ColorInfo "🔧"
    $githubSp = New-ServicePrincipalIfNotExists -DisplayName "github-actions-fabric-otel" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"
    
    # Grant Key Vault access
    Write-ColorOutput "Granting Key Vault access to GitHub Actions service principal..." $ColorInfo "🔑"
    Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -ServicePrincipalName $githubSp.AppId -PermissionsToSecrets get,list
}
catch {
    Write-ColorOutput "Error setting up GitHub Actions service principal: $($_.Exception.Message)" $ColorError "❌"
    exit 1
}

# Step 4: Create application service principal
try {
    Write-ColorOutput "Setting up application service principal..." $ColorInfo "🔧"
    $appSp = New-ServicePrincipalIfNotExists -DisplayName "fabric-otel-app" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"
}
catch {
    Write-ColorOutput "Error setting up application service principal: $($_.Exception.Message)" $ColorError "❌"
    exit 1
}

# Step 5: Get admin user object ID
try {
    Write-ColorOutput "Looking up admin user: $AdminUserEmail" $ColorInfo "👤"
    $adminUser = Get-AzADUser -UserPrincipalName $AdminUserEmail -ErrorAction SilentlyContinue
    
    if (-not $adminUser) {
        # Try searching by display name if UPN fails
        $adminUser = Get-AzADUser -DisplayName $AdminUserEmail -ErrorAction SilentlyContinue
    }
    
    if (-not $adminUser) {
        Write-ColorOutput "Could not find user: $AdminUserEmail" $ColorError "❌"
        Write-ColorOutput "Please verify the email address and try again." $ColorError
        exit 1
    }
    
    $adminObjectId = $adminUser.Id
    Write-ColorOutput "Found admin user: $($adminUser.DisplayName) ($adminObjectId)" $ColorSuccess "✅"
}
catch {
    Write-ColorOutput "Error looking up admin user: $($_.Exception.Message)" $ColorError "❌"
    exit 1
}

# Step 6: Store secrets in Key Vault
try {
    Write-ColorOutput "Storing secrets in Key Vault..." $ColorInfo "💾"
    
    $secrets = @{
        "AZURE-CLIENT-ID" = $appSp.AppId
        "AZURE-CLIENT-SECRET" = $appSp.ClientSecret
        "AZURE-TENANT-ID" = $tenantId
        "AZURE-SUBSCRIPTION-ID" = $subscriptionId
        "ADMIN-OBJECT-ID" = $adminObjectId
    }
    
    foreach ($secretName in $secrets.Keys) {
        $secretValue = $secrets[$secretName]
        Write-ColorOutput "Storing secret: $secretName" $ColorInfo "🔐"
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretName -SecretValue (ConvertTo-SecureString $secretValue -AsPlainText -Force) | Out-Null
    }
    
    Write-ColorOutput "All secrets stored successfully!" $ColorSuccess "✅"
}
catch {
    Write-ColorOutput "Error storing secrets: $($_.Exception.Message)" $ColorError "❌"
    exit 1
}

# Step 7: Output GitHub repository secrets
Write-Host ""
Write-ColorOutput "🎉 Setup completed successfully!" $ColorSuccess
Write-Host ""
Write-ColorOutput "==== GitHub Repository Secrets ====" $ColorInfo
Write-ColorOutput "Add these secrets to your GitHub repository (Settings → Secrets → Actions):" $ColorWarning
Write-Host ""
Write-ColorOutput "AZURE_CLIENT_ID: $($githubSp.AppId)" $ColorWarning "🔑"
Write-ColorOutput "AZURE_TENANT_ID: $tenantId" $ColorWarning "🔑"
Write-ColorOutput "AZURE_SUBSCRIPTION_ID: $subscriptionId" $ColorWarning "🔑"
Write-Host ""
Write-ColorOutput "==== Key Vault Configuration ====" $ColorInfo
Write-ColorOutput "Key Vault Name: $KeyVaultName" $ColorSuccess "🏛️"
Write-ColorOutput "Resource Group: $ResourceGroupName" $ColorSuccess "📁"
Write-ColorOutput "Location: $Location" $ColorSuccess "🌍"
Write-Host ""
Write-ColorOutput "==== Application Secrets (stored in Key Vault) ====" $ColorInfo
foreach ($secretName in $secrets.Keys) {
    Write-ColorOutput "${secretName}: ✅ Stored" $ColorSuccess "🔐"
}
Write-Host ""
Write-ColorOutput "==== Next Steps ====" $ColorInfo
Write-ColorOutput "1. Add the GitHub repository secrets shown above" $ColorWarning "📝"
Write-ColorOutput "2. Update your workflow to use Key Vault name: $KeyVaultName" $ColorWarning "⚙️"
Write-ColorOutput "3. Test the GitHub Actions workflow" $ColorWarning "🧪"
Write-ColorOutput "4. Test local development: pwsh setup-local-dev.ps1" $ColorWarning "💻"
Write-Host ""
Write-ColorOutput "Documentation: GITHUB_ACTIONS_KEYVAULT_SETUP.md" $ColorInfo "📚"
