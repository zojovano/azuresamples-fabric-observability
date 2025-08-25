# GitHub Actions + Azure Key Vault Setup Guide

This guide explains how to set up GitHub Actions to use Azure Key Vault for secrets instead of GitHub repository secrets.

## Architecture Overview

The updated workflow uses a hybrid approach:
- **Minimal GitHub Secrets**: Only the basic credentials needed to authenticate to Azure and access Key Vault
- **Azure Key Vault**: Stores all sensitive application secrets with proper access controls
- **Improved Security**: Centralized secret management, audit logging, and fine-grained access control

## Benefits of Key Vault Integration

✅ **Centralized Management**: All secrets managed in one place  
✅ **Audit Logging**: Track who accessed which secrets when  
✅ **Access Control**: Fine-grained permissions via Azure RBAC  
✅ **Secret Rotation**: Easy to update secrets without touching GitHub  
✅ **Compliance**: Enterprise-grade secret management  

## Step 1: Create Azure Key Vault

```powershell
# Set variables
$resourceGroupName = "azuresamples-platformobservabilty-fabric"
$keyVaultName = "fabric-otel-keyvault"  # Must be globally unique
$location = "swedencentral"

# Login to Azure
Connect-AzAccount

# Create Key Vault (if not exists)
$keyVault = Get-AzKeyVault -VaultName $keyVaultName -ErrorAction SilentlyContinue
if (-not $keyVault) {
    Write-Host "Creating Key Vault: $keyVaultName"
    New-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -Location $location
} else {
    Write-Host "Key Vault already exists: $keyVaultName"
}

# Enable soft delete and purge protection (recommended)
Update-AzKeyVault -VaultName $keyVaultName -EnableSoftDelete -EnablePurgeProtection
```

## Step 2: Create Service Principal for GitHub Actions

```powershell
# Create service principal for GitHub Actions
$subscriptionId = (Get-AzContext).Subscription.Id
$tenantId = (Get-AzContext).Tenant.Id

$sp = New-AzADServicePrincipal -DisplayName "github-actions-fabric-otel" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"

# Get the values for GitHub secrets
$clientId = $sp.AppId
$clientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.PasswordCredentials.SecretText))

Write-Host "GitHub Repository Secrets (add these to GitHub):" -ForegroundColor Green
Write-Host "AZURE_CLIENT_ID: $clientId" -ForegroundColor Yellow
Write-Host "AZURE_TENANT_ID: $tenantId" -ForegroundColor Yellow  
Write-Host "AZURE_SUBSCRIPTION_ID: $subscriptionId" -ForegroundColor Yellow
Write-Host "CLIENT_SECRET_FOR_KEYVAULT: $clientSecret" -ForegroundColor Yellow

# Grant Key Vault access to the service principal
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ServicePrincipalName $clientId -PermissionsToSecrets get,list
```

## Step 3: Store Application Secrets in Key Vault

```powershell
# Store the main application secrets in Key Vault
$keyVaultName = "fabric-otel-keyvault"  # Replace with your Key Vault name

# Create or get a service principal for the application
$appSp = New-AzADServicePrincipal -DisplayName "fabric-otel-app" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"
$appClientId = $appSp.AppId
$appClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($appSp.PasswordCredentials.SecretText))

# Get admin object ID
$adminUser = Read-Host "Enter admin user email (e.g., admin@yourdomain.com)"
$adminObjectId = (Get-AzADUser -UserPrincipalName $adminUser).Id

# Store secrets in Key Vault (note: Key Vault requires dash separators)
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AZURE-CLIENT-ID" -SecretValue (ConvertTo-SecureString $appClientId -AsPlainText -Force)
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AZURE-CLIENT-SECRET" -SecretValue (ConvertTo-SecureString $appClientSecret -AsPlainText -Force)
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AZURE-TENANT-ID" -SecretValue (ConvertTo-SecureString $tenantId -AsPlainText -Force)
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AZURE-SUBSCRIPTION-ID" -SecretValue (ConvertTo-SecureString $subscriptionId -AsPlainText -Force)
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "ADMIN-OBJECT-ID" -SecretValue (ConvertTo-SecureString $adminObjectId -AsPlainText -Force)

Write-Host "✅ All secrets stored in Key Vault successfully!" -ForegroundColor Green
```

## Step 4: Configure GitHub Repository Secrets

Add these **minimal** secrets to your GitHub repository (Settings → Secrets → Actions):

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `AZURE_CLIENT_ID` | Service principal client ID | Authenticate to Azure |
| `AZURE_TENANT_ID` | Azure tenant ID | Authenticate to Azure |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | Authenticate to Azure |

**Note**: We're NOT storing `AZURE_CLIENT_SECRET` in GitHub anymore - the workflow will get it from Key Vault.

## Step 5: Workflow Configuration

The updated workflow includes these key changes:

### New Job: `fetch-secrets`
```yaml
fetch-secrets:
  name: Fetch Secrets from Key Vault
  runs-on: ubuntu-latest
  outputs:
    azure-client-id: ${{ steps.fetch-secrets.outputs.azure-client-id }}
    azure-client-secret: ${{ steps.fetch-secrets.outputs.azure-client-secret }}
    # ... other secrets
```

### Updated Jobs
All deployment jobs now:
1. Depend on `fetch-secrets` job
2. Use `needs.fetch-secrets.outputs.azure-client-id` instead of `secrets.AZURE_CLIENT_ID`
3. Authenticate using secrets fetched from Key Vault

## Step 6: Testing the Setup

1. **Verify Key Vault Access**:
   ```bash
   az keyvault secret list --vault-name fabric-otel-keyvault --query "[].name"
   ```

2. **Test GitHub Actions**:
   - Push a change to trigger the workflow
   - Check the "Fetch Secrets from Key Vault" job logs
   - Verify other jobs can access the fetched secrets

3. **Local Development**:
   ```powershell
   # Test local access to Key Vault
   pwsh setup-local-dev.ps1
   # Select "Key Vault integration" option
   ```

## Troubleshooting

### Issue: "Key Vault not found"
**Solution**: Verify the Key Vault name and ensure the service principal has access:
```powershell
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultName -ServicePrincipalName $clientId -PermissionsToSecrets get,list
```

### Issue: "Secret not found in Key Vault"
**Solution**: Check secret names use dash separators (not underscores):
```powershell
az keyvault secret list --vault-name fabric-otel-keyvault --query "[].name"
```

### Issue: "GitHub Actions can't fetch secrets"
**Solution**: Verify GitHub repository secrets are correctly set and the service principal has Key Vault access.

## Security Best Practices

✅ **Principle of Least Privilege**: Service principal only has access to required Key Vault secrets  
✅ **Secret Rotation**: Regularly rotate service principal credentials  
✅ **Audit Logging**: Monitor Key Vault access logs  
✅ **Network Security**: Consider Key Vault firewall rules for production  
✅ **Backup**: Enable Key Vault soft delete and purge protection  

## Workflow Environment Variables

The workflow now supports these additional inputs:

```yaml
workflow_dispatch:
  inputs:
    key_vault_name:
      description: 'Azure Key Vault name (override)'
      required: false
      default: 'fabric-otel-keyvault'
      type: string
```

This allows you to use different Key Vaults for different environments or branches.

## Migration from Repository Secrets

If you're migrating from GitHub repository secrets:

1. ✅ Keep `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` in GitHub
2. ❌ Remove `AZURE_CLIENT_SECRET` and `ADMIN_OBJECT_ID` from GitHub
3. ✅ Store all application secrets in Key Vault with dash separators
4. ✅ Update local development tools to use Key Vault integration

## Next Steps

- Consider implementing secret rotation automation
- Set up monitoring and alerting for Key Vault access
- Explore using Managed Identity for even better security
- Implement environment-specific Key Vaults (dev/staging/prod)
