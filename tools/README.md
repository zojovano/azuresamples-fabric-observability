# Tools Directory

This directory contains development and deployment tools for the Microsoft Fabric OTEL Observability project.

## 🛠️ Available Tools

### Interactive Setup
| Tool | Description | Usage |
|------|-------------|-------|
| [`setup-local-dev.ps1`](setup-local-dev.ps1) | Interactive local development setup wizard | `pwsh tools/setup-local-dev.ps1` |

### Testing & Validation
| Tool | Description | Usage |
|------|-------------|-------|
| [`Verify-DevEnvironment.ps1`](Verify-DevEnvironment.ps1) | DevContainer environment verification (checks all required tools) | `pwsh tools/Verify-DevEnvironment.ps1` |
| [`Test-FabricLocal.ps1`](Test-FabricLocal.ps1) | Comprehensive Fabric authentication and deployment testing | `pwsh tools/Test-FabricLocal.ps1 -TestAuth` |
| [`test-fabric-auth.ps1`](test-fabric-auth.ps1) | Quick Fabric authentication test | `pwsh tools/test-fabric-auth.ps1` |

### .NET Development
| Tool | Description | Usage |
|------|-------------|-------|
| [`DevSecretManager/`](DevSecretManager/) | .NET console app for secure credential management | `dotnet run --project tools/DevSecretManager` |

## 🚀 Quick Start

### 0. Verify DevContainer Environment (Recommended First Step)
```powershell
# Verify all required tools are installed in DevContainer
pwsh tools/Verify-DevEnvironment.ps1

# Include authentication check
pwsh tools/Verify-DevEnvironment.ps1 -CheckAuth
```

### 1. Interactive Setup (Recommended)
```powershell
# Run interactive setup wizard
pwsh tools/setup-local-dev.ps1
```

### 2. Manual Configuration
```powershell
# Set up User Secrets
pwsh tools/Test-FabricLocal.ps1 -SetupSecrets

# Test authentication
pwsh tools/Test-FabricLocal.ps1 -TestAuth

# Run deployment test
pwsh tools/Test-FabricLocal.ps1 -RunDeploy
```

### 3. Using .NET Secret Manager
```powershell
# Navigate to DevSecretManager
cd tools/DevSecretManager

# Set a secret
dotnet run set --key "Azure:ClientId" --value "your-client-id"

# Get a secret
dotnet run get --key "Azure:ClientId"

# List all secrets
dotnet run list
```

## 🔒 Authentication Methods

The tools support multiple authentication approaches:

### User Secrets (Recommended for Local Development)
- **Secure**: Secrets stored in user profile, not in repository
- **Easy**: Simple to set up and use
- **Cross-platform**: Works on Windows, macOS, and Linux

### Azure Key Vault
- **Enterprise**: Centralized secret management
- **Audit**: Full audit logging
- **RBAC**: Fine-grained access control

### Environment Variables
- **CI/CD**: Ideal for automated environments
- **Simple**: Easy to configure in scripts
- **Temporary**: Good for testing

## 📋 Tool Details

### Verify-DevEnvironment.ps1
DevContainer environment verification script that checks all required tools are properly installed and accessible.

**Features:**
- Verifies PowerShell, Azure CLI, Fabric CLI, .NET SDK, Python, and Git
- Checks workspace directory structure
- Optional authentication status checking
- Designed for DevContainer environments

**Usage:**
```powershell
# Basic verification
pwsh tools/Verify-DevEnvironment.ps1

# Include authentication check
pwsh tools/Verify-DevEnvironment.ps1 -CheckAuth
```

**Exit Codes:**
- `0`: All required tools verified successfully
- `1`: One or more required tools missing or failed verification

### setup-local-dev.ps1
Interactive wizard that guides you through:
- Choosing authentication method
- Configuring secrets
- Testing the setup
- Providing next steps

**Options:**
```powershell
pwsh tools/setup-local-dev.ps1           # Interactive mode
pwsh tools/setup-local-dev.ps1 -Help     # Show help
```

### Test-FabricLocal.ps1
Comprehensive testing tool with multiple modes:

**Basic Usage:**
```powershell
# Set up User Secrets interactively
pwsh tools/Test-FabricLocal.ps1 -SetupSecrets

# Test authentication only
pwsh tools/Test-FabricLocal.ps1 -TestAuth

# Run full deployment
pwsh tools/Test-FabricLocal.ps1 -RunDeploy
```

**Key Vault Mode:**
```powershell
# Test with Key Vault
pwsh tools/Test-FabricLocal.ps1 -Mode KeyVault -KeyVaultName "your-vault" -TestAuth
```

**Environment Variable Mode:**
```powershell
# Test with environment variables
pwsh tools/Test-FabricLocal.ps1 -Mode Environment -TestAuth
```

### DevSecretManager
.NET console application for advanced secret management:

**Features:**
- Secure secret storage using .NET User Secrets
- Azure Key Vault integration
- Secret masking for security
- Cross-platform support

**Commands:**
```powershell
cd tools/DevSecretManager

# Basic operations
dotnet run set --key "Azure:ClientId" --value "your-value"
dotnet run get --key "Azure:ClientId"
dotnet run list

# Advanced operations
dotnet run test                           # Test authentication
dotnet run import-from-keyvault --vault-name "vault" --secret-name "secret"
```

## 🔗 Related Documentation

- [`docs/LOCAL_DEVELOPMENT_SETUP.md`](../docs/LOCAL_DEVELOPMENT_SETUP.md) - Detailed setup instructions
- [`docs/GITHUB_ACTIONS_KEYVAULT_SETUP.md`](../docs/GITHUB_ACTIONS_KEYVAULT_SETUP.md) - CI/CD setup
- [`docs/TROUBLESHOOT_GITHUB_ACTIONS.md`](../docs/TROUBLESHOOT_GITHUB_ACTIONS.md) - Troubleshooting guide

## 💡 Tips

- **Start with `Verify-DevEnvironment.ps1`** to ensure your DevContainer environment is properly configured
- **Use `setup-local-dev.ps1`** for the easiest setup experience after environment verification
- **Use User Secrets** for local development (most secure and convenient)
- **Use Key Vault** for team environments and production
- **Use Environment Variables** for CI/CD and automated testing
- **Test authentication** before attempting deployments
