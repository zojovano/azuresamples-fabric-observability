# 🧪 Local Development Setup Guide

This comprehensive guide covers DevContainer setup, Git configuration, and secure Fabric testing for local development.

## 🐳 DevContainer Setup

### Prerequisites
- [VS Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- Docker or Podman container runtime

### Getting Started

1. **Open in DevContainer:**
   ```bash
   # Clone and open in VS Code
   git clone https://github.com/zojovano/azuresamples-fabric-observability.git
   cd azuresamples-fabric-observability
   code .
   
   # When prompted, click "Reopen in Container"
   # Or use Command Palette: "Dev Containers: Reopen in Container"
   ```

2. **Configure Git (Required for commits):**
   
   **Option A: Environment Variables (Recommended - persists across rebuilds)**
   ```bash
   # On your HOST system (not in container):
   # Windows:
   setx GIT_USER_NAME "Your Name"
   setx GIT_USER_EMAIL "your.email@example.com"
   
   # Linux/Mac:
   export GIT_USER_NAME="Your Name"
   export GIT_USER_EMAIL="your.email@example.com"
   # Add to ~/.bashrc for persistence
   ```
   
   **Option B: Interactive Setup (run inside container after rebuild)**
   ```bash
   ./.devcontainer/setup-git-config.sh
   # Or with parameters:
   ./.devcontainer/setup-git-config.sh "Your Name" "your.email@example.com"
   ```

3. **Verify Environment:**
   ```bash
   # Run verification script
   pwsh tools/Verify-DevEnvironment.ps1
   
   # Or with authentication check
   pwsh tools/Verify-DevEnvironment.ps1 -CheckAuth
   ```

### What's Included
- **Azure CLI** with Bicep extension
- **Microsoft Fabric CLI** for Fabric management  
- **.NET 8.0** SDK for C# development
- **PowerShell 7.5.2** for scripting
- **Python 3.11** with pip
- **Git** with VS Code credential integration
- **All VS Code extensions** for Azure, .NET, PowerShell development

## 🚀 Quick Start

### Option 1: User Secrets (Recommended for Development)

1. **Setup secrets interactively:**
   ```powershell
   pwsh tools/Test-FabricLocal.ps1 -SetupSecrets
   ```

2. **Test authentication:**
   ```powershell
   pwsh tools/Test-FabricLocal.ps1 -TestAuth
   ```

3. **Run deployment:**
   ```powershell
   pwsh tools/Test-FabricLocal.ps1 -RunDeploy
   ```

### Option 2: Azure Key Vault

1. **Test with Key Vault:**
   ```powershell
   pwsh tools/Test-FabricLocal.ps1 -Mode KeyVault -KeyVaultName "your-keyvault" -TestAuth
   ```

2. **Deploy with Key Vault:**
   ```powershell
   pwsh tools/Test-FabricLocal.ps1 -Mode KeyVault -KeyVaultName "your-keyvault" -RunDeploy
   ```

### Option 3: Environment Variables

1. **Set environment variables:**
   ```powershell
   $env:AZURE_CLIENT_ID = "your-client-id"
   $env:AZURE_CLIENT_SECRET = "your-client-secret"
   $env:AZURE_TENANT_ID = "your-tenant-id"
   ```

2. **Test with environment:**
   ```powershell
   pwsh tools/Test-FabricLocal.ps1 -Mode Environment -TestAuth
   ```

## 🔧 Secret Manager Tool

The included .NET tool (`tools/DevSecretManager`) provides secure secret management:

```bash
# Build the tool
cd tools/DevSecretManager
dotnet build

# Set secrets
dotnet run set --key "Azure:ClientId" --value "your-client-id"
dotnet run set --key "Azure:ClientSecret" --value "your-client-secret"

# List configured secrets (without values)
dotnet run list

# Test authentication
dotnet run test

# Import from Key Vault
dotnet run import-from-keyvault --vault-name "your-vault" --secret-name "AZURE-CLIENT-ID" --local-key "Azure:ClientId"
```

## 🔐 Security Features

- **User Secrets**: Stored outside source control using .NET user secrets
- **Key Vault Integration**: Direct import from Azure Key Vault
- **Secret Masking**: Values are masked in output for security
- **Encrypted Storage**: Uses .NET's secure user secrets mechanism

## 📋 Required Secrets

| Secret | Description | Example |
|--------|-------------|---------|
| `Azure:ClientId` | Service Principal Application ID | `12345678-1234-1234-1234-123456789012` |
| `Azure:ClientSecret` | Service Principal Secret | `your-secret-value` |
| `Azure:TenantId` | Azure Tenant ID | `87654321-4321-4321-4321-210987654321` |
| `Azure:SubscriptionId` | Azure Subscription ID | `11111111-2222-3333-4444-555555555555` |
| `Azure:ResourceGroupName` | Resource Group Name | `azuresamples-platformobservabilty-fabric` |
| `Fabric:WorkspaceName` | Fabric Workspace Name | `fabric-otel-workspace` |
| `Fabric:DatabaseName` | Fabric Database Name | `otelobservabilitydb` |

## 🧪 Testing Workflow

1. **Setup**: Configure secrets once using your preferred method
2. **Test**: Verify authentication works locally
3. **Deploy**: Run full deployment locally to test changes
4. **Commit**: Push working changes to GitHub Actions

## 🔍 Troubleshooting

### Authentication Failures
- Verify service principal has correct permissions
- Check tenant and subscription IDs are correct
- Ensure Fabric CLI is properly installed

### Missing Secrets
- Run `dotnet run list` in the DevSecretManager to check configuration
- Use `-TestAuth` to verify all required secrets are present

### Key Vault Access
- Ensure you're authenticated with Azure CLI: `az login`
- Verify Key Vault access permissions
- Check secret names match expected values

## 🛠️ Development Benefits

- **Fast Iteration**: Test authentication changes locally
- **Secure Storage**: No secrets in source control
- **Multiple Options**: Choose the method that fits your workflow
- **Detailed Logging**: See exactly what's happening during authentication
- **Safe Testing**: Test without triggering GitHub Actions

## 📝 Next Steps

After your local testing works:
1. Verify the same service principal works in GitHub Actions
2. Ensure GitHub Secrets match your local configuration
3. Push your tested changes with confidence!
