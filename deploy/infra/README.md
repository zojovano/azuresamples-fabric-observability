# Infrastructure Deployment

## 🚀 Recommended: Single Unified Deployment Script

Use the **`Deploy-Complete.ps1`** script for all deployment scenarios. This script consolidates all deployment functionality into a single, easy-to-use PowerShell script.

```powershell
# Complete deployment (uses config/project-config.json for KeyVault name)
./Deploy-Complete.ps1

# Or specify a different KeyVault
./Deploy-Complete.ps1 -KeyVaultName "your-keyvault-name"
```

👉 **[Full Documentation: README-Deploy-Complete.md](./README-Deploy-Complete.md)**

## Scripts Overview

| Script | Status | Purpose |
|--------|--------|---------|
| **`Deploy-Complete.ps1`** | ✅ **RECOMMENDED** | Single script for all deployment scenarios |
| `Deploy-FabricArtifacts.ps1` | ✅ Active | Fabric-only deployment (used by Deploy-Complete.ps1) |
| `Setup-Authentication.ps1` | ✅ Active | Authentication helper |

## Quick Start

### Prerequisites
- Azure CLI (authenticated)
- PowerShell Az Module  
- Microsoft Fabric CLI
- Azure Key Vault with required secrets

### Simple Deployment
```powershell
# 1. Complete deployment (auto-detects KeyVault from config)
./Deploy-Complete.ps1

# 2. Infrastructure only
./Deploy-Complete.ps1 -SkipFabricArtifacts

# 3. Fabric artifacts only  
./Deploy-Complete.ps1 -SkipInfrastructure

# 4. Preview mode
./Deploy-Complete.ps1 -WhatIf
```

## Required Key Vault Secrets

The KeyVault name is automatically loaded from `config/project-config.json` (currently: **`azuresamplesdevopskeys`**).

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

**✅ Legacy scripts have been removed!** 

All functionality has been consolidated into the single `Deploy-Complete.ps1` script. If you were using the old scripts, simply use:

```powershell
# Replace any old deployment command with:
./Deploy-Complete.ps1
```

The script automatically loads all configuration from `config/project-config.json` including the KeyVault name.

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
