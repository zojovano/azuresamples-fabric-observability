# GitHub Actions + Azure Key Vault Setup Guide

This guide explains how to set up GitHub Actions to use an existing Azure Key Vault for secrets. This approach treats Key Vault and the main service principal as shared infrastructure (external dependencies).

## Architecture Overview

The workflow uses a **shared infrastructure** approach:
- **Shared Key Vault**: Pre-existing Key Vault managed by platform/DevOps team
- **Shared Service Principal**: Pre-existing service principal with access to Key Vault and Azure subscriptions
- **Project-Specific Secrets**: Only application-specific secrets stored in the shared Key Vault
- **Minimal GitHub Secrets**: Only the credentials needed to access the shared infrastructure

## Benefits of Shared Infrastructure

✅ **Enterprise Architecture**: Centralized secret management across multiple projects  
✅ **Separation of Concerns**: Platform team manages infrastructure, project teams manage applications  
✅ **Security**: Consistent security policies and access controls  
✅ **Cost Efficiency**: Shared resources across multiple projects  
✅ **Compliance**: Centralized audit logging and governance  

## Prerequisites (Managed by Platform Team)

These are **external dependencies** that should be set up once and shared across projects:

### 1. Shared Azure Key Vault
```powershell
# Platform team creates shared Key Vault (one-time setup)
$sharedResourceGroup = "shared-platform-resources"
$sharedKeyVault = "company-shared-keyvault"
$location = "swedencentral"

New-AzKeyVault -VaultName $sharedKeyVault -ResourceGroupName $sharedResourceGroup -Location $location
Update-AzKeyVault -VaultName $sharedKeyVault -EnableSoftDelete -EnablePurgeProtection
```

### 2. Shared Service Principal  
```powershell
# Platform team creates shared service principal (one-time setup)
$sharedSpName = "shared-github-actions-sp"
$subscriptionId = (Get-AzContext).Subscription.Id

$sharedSp = New-AzADServicePrincipal -DisplayName $sharedSpName -Role "Contributor" -Scope "/subscriptions/$subscriptionId"

# Grant Key Vault access
Set-AzKeyVaultAccessPolicy -VaultName $sharedKeyVault -ServicePrincipalName $sharedSp.AppId -PermissionsToSecrets get,list
```

## Project Setup (Per Project)

## Project Setup (Per Project)

### Step 1: Get Shared Infrastructure Details

Contact your platform team to get:
- **Shared Key Vault Name**: e.g., `company-shared-keyvault`
- **Shared Service Principal Credentials**: Client ID, Tenant ID, Subscription ID
- **Key Vault Access**: Ensure your project's secrets can be stored

### Step 2: Store Project-Specific Secrets

Store your project's secrets in the shared Key Vault with a project prefix:

```powershell
# Use project-specific naming convention
$projectPrefix = "fabric-otel"
$keyVaultName = "company-shared-keyvault"  # Provided by platform team

# Store project-specific application secrets
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "$projectPrefix-AZURE-CLIENT-ID" -SecretValue (ConvertTo-SecureString $appClientId -AsPlainText -Force)
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "$projectPrefix-AZURE-CLIENT-SECRET" -SecretValue (ConvertTo-SecureString $appClientSecret -AsPlainText -Force)
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "$projectPrefix-AZURE-TENANT-ID" -SecretValue (ConvertTo-SecureString $tenantId -AsPlainText -Force)
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "$projectPrefix-AZURE-SUBSCRIPTION-ID" -SecretValue (ConvertTo-SecureString $subscriptionId -AsPlainText -Force)
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "$projectPrefix-ADMIN-OBJECT-ID" -SecretValue (ConvertTo-SecureString $adminObjectId -AsPlainText -Force)
```

### Step 3: Configure GitHub Repository Secrets

Add these **shared infrastructure** secrets to your GitHub repository (provided by platform team):

| Secret Name | Value | Source |
|-------------|-------|--------|
| `AZURE_CLIENT_ID` | Shared service principal client ID | Platform team |
| `AZURE_TENANT_ID` | Azure tenant ID | Platform team |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | Platform team |
| `SHARED_KEYVAULT_NAME` | Shared Key Vault name | Platform team |

### Step 4: Update Workflow Configuration

Update your workflow to use the shared Key Vault and project-specific secret names:

```yaml
env:
  SHARED_KEYVAULT_NAME: ${{ secrets.SHARED_KEYVAULT_NAME }}
  PROJECT_PREFIX: "fabric-otel"  # Your project's unique prefix
```

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
   pwsh tools/setup-local-dev.ps1
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
