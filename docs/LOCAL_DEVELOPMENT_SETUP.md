# 🧪 Local Fabric Development Setup Guide

This guide helps you securely test Fabric deployments locally without relying on GitHub Actions for debugging.

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
