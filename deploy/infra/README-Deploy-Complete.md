# Unified Deployment Script

## Overview

The `Deploy-Complete.ps1` script is a single, consolidated deployment script that handles the complete Azure OTEL Observability infrastructure deployment using Key Vault for all secrets.

## Features

- ✅ **Complete Infrastructure Deployment**: Azure resources via Bicep templates
- ✅ **Fabric Artifacts Deployment**: KQL tables and workspace setup via Fabric CLI
- ✅ **Key Vault Integration**: All secrets managed through Azure Key Vault
- ✅ **Service Principal Creation**: Optional automatic creation and secret population
- ✅ **What-If Support**: Preview deployments without executing
- ✅ **Flexible Execution**: Skip infrastructure or Fabric artifacts as needed

## Prerequisites

### Required Tools
- Azure CLI (authenticated)
- PowerShell Az Module
- Microsoft Fabric CLI (for Fabric artifacts)

### Required Key Vault Secrets

Your Key Vault must contain these secrets:

| Secret Name | Description | Required |
|-------------|-------------|----------|
| `azure-subscription-id` | Azure subscription ID | ✅ |
| `azure-tenant-id` | Azure tenant ID | ✅ |
| `azure-client-id` | Service principal client ID | ⚠️ |
| `azure-client-secret` | Service principal client secret | ⚠️ |
| `fabric-workspace-name` | Fabric workspace name | ⚠️ |
| `fabric-database-name` | KQL database name | ⚠️ |
| `resource-group-name` | Azure resource group name | ✅ |
| `admin-object-id` | Admin user object ID | ⚠️ |

**Legend**: ✅ Required, ⚠️ Optional (defaults available)

## Usage Examples

### Complete Deployment
```powershell
# Deploy everything using existing Key Vault
## 🚀 Quick Start

The simplest deployment uses the centralized configuration:

```powershell
# Complete deployment (uses config/project-config.json)
./Deploy-Complete.ps1
```

The script automatically loads:
- **KeyVault name**: `azuresamplesdevopskeys` (from config)
- **All Azure settings**: Resource group, location, subscription
- **All Fabric settings**: Workspace, database, capacity names
```

### Create Service Principals and Deploy
```powershell
# Create service principals, populate secrets, then deploy
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -CreateServicePrincipals
```

### Infrastructure Only
```powershell
# Deploy only Azure infrastructure (skip Fabric artifacts)
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -SkipFabricArtifacts
```

### Fabric Artifacts Only
```powershell
# Deploy only Fabric artifacts (skip Azure infrastructure)
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -SkipInfrastructure
```

### Preview Mode
```powershell
# See what would be deployed without executing
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -WhatIf
```

### Skip Workspace Creation
```powershell
# Skip Fabric workspace creation (if tenant permissions not configured)
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -SkipWorkspaceCreation
```

## Key Vault Setup

### Option 1: Use Existing Shared Key Vault
If your organization has a shared Key Vault managed by a platform team:

1. Get the Key Vault name from your platform team
2. Ensure you have "Key Vault Secrets User" role
3. Ask platform team to populate the required secrets

### Option 2: Create Your Own Key Vault
```powershell
# Create a new Key Vault
az keyvault create --name "my-fabric-otel-kv" --resource-group "my-rg" --location "swedencentral"

# Grant yourself access
az keyvault set-policy --name "my-fabric-otel-kv" --upn "your-email@company.com" --secret-permissions get list set delete
```

### Option 3: Let the Script Create Service Principals
```powershell
# This will create service principals and populate Key Vault secrets automatically
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -CreateServicePrincipals
```

## Parameters Reference

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `KeyVaultName` | String | **Required** | Name of Azure Key Vault containing secrets |
| `Location` | String | `swedencentral` | Azure region for deployment |
| `AdminUserEmail` | String | Current user | Email of admin user for Fabric capacity |
| `SkipInfrastructure` | Switch | `$false` | Skip Azure infrastructure deployment |
| `SkipFabricArtifacts` | Switch | `$false` | Skip Fabric artifacts deployment |
| `SkipWorkspaceCreation` | Switch | `$false` | Skip Fabric workspace creation |
| `CreateServicePrincipals` | Switch | `$false` | Create service principals and populate secrets |
| `WhatIf` | Switch | `$false` | Preview deployment without executing |

## Expected Outputs

Upon successful deployment, you'll get:

- ✅ Azure resource group with all infrastructure
- ✅ Microsoft Fabric workspace and KQL database
- ✅ Three OTEL tables: `OTELLogs`, `OTELMetrics`, `OTELTraces`
- ✅ Service principals configured for automation
- ✅ All secrets properly stored in Key Vault

## Troubleshooting

### Common Issues

1. **Key Vault Access Denied**
   ```
   Solution: Ensure you have "Key Vault Secrets User" role on the Key Vault
   ```

2. **Fabric Workspace Creation Failed**
   ```
   Solution: Use -SkipWorkspaceCreation and create workspace manually
   or ask tenant admin to configure Fabric permissions
   ```

3. **Missing Fabric CLI**
   ```bash
   # Install Fabric CLI
   pip install ms-fabric-cli
   ```

4. **Azure Authentication Issues**
   ```powershell
   # Re-authenticate
   Connect-AzAccount
   ```

### Getting Help

Check deployment logs for specific error messages. The script provides color-coded output:
- 🟢 **Green**: Success
- 🟡 **Yellow**: Warnings
- 🔴 **Red**: Errors
- 🔵 **Cyan**: Information

## Migration from Old Scripts

This script replaces the following files:
- `deploy.ps1` → Use `Deploy-Complete.ps1`
- `deploy-unified.ps1` → Use `Deploy-Complete.ps1`
- `deploy-with-keyvault-legacy.ps1` → Use `Deploy-Complete.ps1 -CreateServicePrincipals`

All functionality has been consolidated into this single script with improved error handling and Key Vault integration.
