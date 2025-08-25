# Consolidated Infrastructure Deployment with Key Vault

This document explains the consolidated approach for deploying infrastructure with integrated Key Vault secret management.

## Overview

Instead of having separate setup scripts, the infrastructure deployment is now consolidated into a single Bicep-based approach that includes:

- ✅ **Service Principal Creation**: Automated via PowerShell (since Bicep can't create Azure AD resources)
- ✅ **Key Vault Deployment**: Managed via Bicep module with proper access policies
- ✅ **Secret Population**: Automatically populated during deployment
- ✅ **Infrastructure Deployment**: All resources deployed via single Bicep template
- ✅ **GitHub Actions Integration**: Updated to use consolidated approach

## Architecture

```
[Service Principal Creation] → [Bicep Deployment] → [Key Vault + Secrets] → [Infrastructure]
         (PowerShell)              (Bicep)            (Bicep Module)        (Bicep Modules)
```

## Deployment Options

### Option 1: Enhanced Local Deployment (Recommended)

```powershell
cd infra/Bicep
.\deploy-with-keyvault.ps1 -AdminUserEmail "admin@company.com"
```

This script:
1. Creates or validates service principals
2. Deploys all infrastructure including Key Vault
3. Populates secrets automatically
4. Outputs GitHub secrets needed

### Option 2: Manual Bicep Deployment

If you already have service principals:

```powershell
# Deploy with existing service principals
az deployment sub create \
  --location swedencentral \
  --template-file main.bicep \
  --parameters @parameters.json \
  --parameters githubServicePrincipalObjectId="sp-object-id" \
               appServicePrincipalClientId="app-client-id" \
               appServicePrincipalObjectId="app-object-id" \
               appServicePrincipalClientSecret="app-secret" \
               keyVaultName="your-keyvault-name"
```

### Option 3: GitHub Actions (Automated)

The GitHub Actions workflow automatically handles the deployment using the consolidated approach.

## Bicep Module Structure

### Key Vault Module (`modules/keyvault.bicep`)

- Creates Azure Key Vault with security best practices
- Configures access policies for GitHub Actions and application service principals
- Stores all required secrets with proper naming conventions
- Outputs GitHub secrets configuration

### Main Template (`main.bicep`)

- Orchestrates all resource deployments
- Includes Key Vault as first deployment (dependency for other resources)
- Maintains existing fabric, event hub, and container deployments
- Updated with new parameters for service principal integration

## Required Parameters

The consolidated deployment requires these parameters:

| Parameter | Description | Source |
|-----------|-------------|---------|
| `adminObjectId` | Fabric capacity administrator | User lookup or parameter |
| `githubServicePrincipalObjectId` | GitHub Actions SP object ID | Created by script |
| `appServicePrincipalClientId` | Application SP client ID | Created by script |
| `appServicePrincipalObjectId` | Application SP object ID | Created by script |
| `appServicePrincipalClientSecret` | Application SP secret | Created by script |
| `keyVaultName` | Key Vault name (globally unique) | Generated or provided |

## GitHub Actions Integration

### Required GitHub Secrets (Minimal)

Only these secrets are needed in GitHub repository:

```yaml
AZURE_CLIENT_ID: "github-actions-service-principal-client-id"
AZURE_TENANT_ID: "azure-tenant-id"  
AZURE_SUBSCRIPTION_ID: "azure-subscription-id"
GITHUB_SP_OBJECT_ID: "github-sp-object-id"    # NEW
APP_SP_OBJECT_ID: "app-sp-object-id"           # NEW
```

### Workflow Changes

The workflow now:
1. Uses minimal GitHub secrets for authentication
2. Deploys infrastructure including Key Vault via Bicep
3. Fetches application secrets from the newly created Key Vault
4. Uses those secrets for Fabric CLI operations

## Security Benefits

✅ **Infrastructure as Code**: All resources defined in Bicep  
✅ **Least Privilege**: Service principals have minimal required permissions  
✅ **Secret Lifecycle**: Secrets managed through infrastructure deployment  
✅ **Audit Trail**: All changes tracked through git and Azure deployment logs  
✅ **Consistency**: Same deployment process for all environments  

## Migration from Separate Scripts

### Old Approach (Deprecated)
- ❌ `Setup-KeyVault.ps1` - Separate script for Key Vault setup
- ❌ Manual service principal creation
- ❌ Separate secret management
- ❌ Multiple deployment steps

### New Approach (Current)  
- ✅ `deploy-with-keyvault.ps1` - Consolidated deployment
- ✅ Integrated service principal management
- ✅ Bicep-managed Key Vault and secrets
- ✅ Single deployment command

## Local Development Integration

Local development tools automatically work with the new approach:

```powershell
# Test with the deployed Key Vault
pwsh Test-FabricLocal.ps1 -Mode KeyVault -KeyVaultName "fabric-otel-kv-12345" -TestAuth

# Use DevSecretManager with deployed Key Vault
cd tools/DevSecretManager
dotnet run import-from-keyvault --vault-name "fabric-otel-kv-12345" --secret-name "AZURE-CLIENT-ID" --local-key "Azure:ClientId"
```

## Troubleshooting

### Service Principal Issues
- The script handles existing service principals gracefully
- Creates new credentials if existing ones are not accessible
- Provides clear instructions for manual secret entry

### Key Vault Permissions
- Access policies are automatically configured during deployment
- GitHub Actions SP gets read-only access to secrets
- Application SP gets full secret management access

### Deployment Failures
- Check Azure permissions for service principal creation
- Verify Key Vault name is globally unique
- Ensure all required parameters are provided

## Best Practices

1. **Use the consolidated script** for consistent deployments
2. **Version control all Bicep templates** for change tracking
3. **Rotate service principal credentials** regularly
4. **Monitor Key Vault access logs** for security
5. **Use different Key Vaults** for different environments (dev/staging/prod)

## Environment Management

For multiple environments, use different parameter files:

```powershell
# Development
.\deploy-with-keyvault.ps1 -Location "eastus" -KeyVaultName "fabric-dev-kv"

# Production  
.\deploy-with-keyvault.ps1 -Location "swedencentral" -KeyVaultName "fabric-prod-kv"
```

This consolidated approach follows infrastructure-as-code best practices while maintaining the security benefits of Azure Key Vault integration.
