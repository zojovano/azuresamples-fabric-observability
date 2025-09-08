# Infrastructure Deployment

## 🚀 Recommended: Single Unified Deployment Script

Use the **`Deploy-Complete.ps1`** script for all deployment scenarios. This script consolidates all deployment functionality into a single, easy-to-use PowerShell script.

```powershell
# Complete deployment using Key Vault
./Deploy-Complete.ps1 -KeyVaultName "your-keyvault-name"
```

👉 **[Full Documentation: README-Deploy-Complete.md](./README-Deploy-Complete.md)**

## Scripts Overview

| Script | Status | Purpose |
|--------|--------|---------|
| **`Deploy-Complete.ps1`** | ✅ **RECOMMENDED** | Single script for all deployment scenarios |
| `Deploy-FabricArtifacts.ps1` | ✅ Active | Fabric-only deployment (used by Deploy-Complete.ps1) |
| `Setup-Authentication.ps1` | ✅ Active | Authentication helper |
| `Bicep/deploy.ps1` | ⚠️ Legacy | Redirects to deploy-unified.ps1 |
| `Bicep/deploy-unified.ps1` | ⚠️ Legacy | Replaced by Deploy-Complete.ps1 |
| `Bicep/deploy-with-keyvault-legacy.ps1` | ⚠️ Legacy | Replaced by Deploy-Complete.ps1 |

## Quick Start

### Prerequisites
- Azure CLI (authenticated)
- PowerShell Az Module  
- Microsoft Fabric CLI
- Azure Key Vault with required secrets

### Simple Deployment
```powershell
# 1. Complete deployment
./Deploy-Complete.ps1 -KeyVaultName "my-project-kv"

# 2. Infrastructure only
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -SkipFabricArtifacts

# 3. Fabric artifacts only  
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -SkipInfrastructure

# 4. Preview mode
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -WhatIf
```

## Required Key Vault Secrets

Your Key Vault must contain:
- `azure-subscription-id` (required)
- `azure-tenant-id` (required) 
- `azure-client-id` (optional - can be created)
- `azure-client-secret` (optional - can be created)
- `fabric-workspace-name` (optional - defaults available)
- `fabric-database-name` (optional - defaults available)
- `resource-group-name` (required)

## Advanced Scenarios

### Create Service Principals Automatically
```powershell
# Creates service principals and populates Key Vault secrets
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -CreateServicePrincipals
```

### Skip Workspace Creation (Tenant Permissions Issues)
```powershell
# Skip if tenant admin hasn't configured Fabric permissions
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -SkipWorkspaceCreation
```

### Custom Admin User
```powershell
# Specify admin user for Fabric capacity
./Deploy-Complete.ps1 -KeyVaultName "my-kv" -AdminUserEmail "admin@company.com"
```

## Migration from Legacy Scripts

If you were using the old scripts:

| Old Script | New Command |
|------------|-------------|
| `./Bicep/deploy.ps1` | `./Deploy-Complete.ps1 -KeyVaultName "your-kv"` |
| `./Bicep/deploy-unified.ps1` | `./Deploy-Complete.ps1 -KeyVaultName "your-kv"` |
| `./Bicep/deploy-with-keyvault-legacy.ps1` | `./Deploy-Complete.ps1 -CreateServicePrincipals -KeyVaultName "your-kv"` |

## Directory Structure

```
deploy/infra/
├── Deploy-Complete.ps1              # 🎯 Single unified deployment script
├── README-Deploy-Complete.md        # 📖 Detailed documentation
├── Deploy-FabricArtifacts.ps1      # Fabric-specific deployment
├── Setup-Authentication.ps1        # Authentication helper
├── Bicep/                          # Infrastructure templates
│   ├── main.bicep                  # Main Bicep template
│   ├── modules/                    # Bicep modules
│   └── deploy*.ps1                 # Legacy deployment scripts
├── kql-definitions/                # KQL table definitions
│   └── tables/                     # OTEL table schemas
└── data/                          # Sample data files
```

## Support

- 📖 **Full Documentation**: [README-Deploy-Complete.md](./README-Deploy-Complete.md)
- 🔧 **Troubleshooting**: Check the detailed README for common issues
- 🧪 **Testing**: Use `deploy/tools/Test-FabricLocal.ps1` after deployment
- 💬 **DevContainer**: This project is designed for DevContainer development
