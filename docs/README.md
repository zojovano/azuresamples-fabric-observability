# Documentation Index

This folder contains all documentation for the Microsoft Fabric OTEL Observability sample.

## 📋 Setup & Configuration

| Document | Description |
|----------|-------------|
| [`GITHUB_ACTIONS_KEYVAULT_SETUP.md`](GITHUB_ACTIONS_KEYVAULT_SETUP.md) | **Recommended**: Set up GitHub Actions with Azure Key Vault integration |
| [`GITHUB_ACTIONS_SETUP.md`](GITHUB_ACTIONS_SETUP.md) | Legacy: Set up GitHub Actions with repository secrets |
| [`GITHUB_SECRETS_SETUP.md`](GITHUB_SECRETS_SETUP.md) | How to configure GitHub repository secrets |
| [`LOCAL_DEVELOPMENT_SETUP.md`](LOCAL_DEVELOPMENT_SETUP.md) | Local development environment setup and testing |

## 🏗️ Deployment

| Document | Description |
|----------|-------------|
| [`CONSOLIDATED_DEPLOYMENT.md`](CONSOLIDATED_DEPLOYMENT.md) | **Recommended**: Consolidated Bicep deployment with Key Vault integration |
| [`FABRIC_CLI_DEPLOYMENT.md`](FABRIC_CLI_DEPLOYMENT.md) | Microsoft Fabric CLI deployment details |

## 🧪 Testing & Development

| Document | Description |
|----------|-------------|
| [`Professional-Testing-Integration.md`](Professional-Testing-Integration.md) | Professional testing framework with .NET xUnit |
| [`TROUBLESHOOT_GITHUB_ACTIONS.md`](TROUBLESHOOT_GITHUB_ACTIONS.md) | Troubleshooting GitHub Actions workflows |

## 📊 Implementation

| Document | Description |
|----------|-------------|
| [`IMPLEMENTATION_SUMMARY.md`](IMPLEMENTATION_SUMMARY.md) | Summary of all implementation details and decisions |

## 🎯 Quick Start Recommendations

### For New Projects
1. Start with [`CONSOLIDATED_DEPLOYMENT.md`](CONSOLIDATED_DEPLOYMENT.md)
2. Use [`GITHUB_ACTIONS_KEYVAULT_SETUP.md`](GITHUB_ACTIONS_KEYVAULT_SETUP.md) for CI/CD
3. Set up local development with [`LOCAL_DEVELOPMENT_SETUP.md`](LOCAL_DEVELOPMENT_SETUP.md)

### For Existing Projects
1. Review [`GITHUB_ACTIONS_KEYVAULT_SETUP.md`](GITHUB_ACTIONS_KEYVAULT_SETUP.md) to upgrade security
2. Use [`TROUBLESHOOT_GITHUB_ACTIONS.md`](TROUBLESHOOT_GITHUB_ACTIONS.md) for issues
3. Check [`Professional-Testing-Integration.md`](Professional-Testing-Integration.md) for testing improvements

### For Local Development
1. Use [`tools/setup-local-dev.ps1`](../tools/setup-local-dev.ps1) for interactive setup
2. Test with [`tools/Test-FabricLocal.ps1`](../tools/Test-FabricLocal.ps1)
3. Refer to [`LOCAL_DEVELOPMENT_SETUP.md`](LOCAL_DEVELOPMENT_SETUP.md) for detailed instructions
