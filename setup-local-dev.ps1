#!/usr/bin/env pwsh
# Quick setup script for local Fabric development

param(
    [switch]$Help
)

if ($Help) {
    Write-Host @"
🧪 Fabric Local Development Quick Setup

This script helps you quickly set up local development for Fabric deployments.

Usage:
  pwsh setup-local-dev.ps1           # Interactive setup
  pwsh setup-local-dev.ps1 -Help     # Show this help

What this script does:
1. Builds the secret manager tool
2. Guides you through setting up credentials
3. Tests authentication
4. Provides next steps

Requirements:
- .NET 9.0 SDK
- PowerShell 7+
- Azure CLI (optional, for Key Vault)
- Service Principal credentials
"@ -ForegroundColor Cyan
    exit 0
}

$ErrorActionPreference = "Stop"

# Color functions
function Write-Success($msg) { Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Warning($msg) { Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Write-Error($msg) { Write-Host "❌ $msg" -ForegroundColor Red }

Write-Host @"
🧪 Fabric Local Development Setup
=================================

This will help you set up secure local testing for Fabric deployments.
"@ -ForegroundColor Cyan

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check .NET
try {
    $dotnetVersion = dotnet --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success ".NET SDK found: $dotnetVersion"
    } else {
        throw "Not found"
    }
} catch {
    Write-Error ".NET SDK not found. Please install .NET 9.0 SDK"
    exit 1
}

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "PowerShell 7+ recommended. Current version: $($PSVersionTable.PSVersion)"
}

# Build secret manager
Write-Info "Building secret manager tool..."
$secretManagerPath = Join-Path $PSScriptRoot "tools" "DevSecretManager"

if (-not (Test-Path $secretManagerPath)) {
    Write-Info "Creating secret manager directory..."
    New-Item -Path $secretManagerPath -ItemType Directory -Force | Out-Null
}

Push-Location $secretManagerPath
try {
    if (Test-Path "DevSecretManager.csproj") {
        dotnet build --configuration Release
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Secret manager built successfully"
        } else {
            throw "Build failed"
        }
    } else {
        Write-Error "Secret manager project not found. Please ensure the project files exist."
        exit 1
    }
} catch {
    Write-Error "Failed to build secret manager: $_"
    exit 1
} finally {
    Pop-Location
}

# Ask user for setup preference
Write-Host ""
Write-Info "Choose your preferred method for storing secrets:"
Write-Host "1. User Secrets (Recommended) - Stores secrets securely outside source control"
Write-Host "2. Azure Key Vault - Uses existing Key Vault for secret storage"
Write-Host "3. Environment Variables - Manual environment variable setup"
Write-Host ""

do {
    $choice = Read-Host "Enter your choice (1-3)"
} while ($choice -notin @("1", "2", "3"))

switch ($choice) {
    "1" {
        Write-Info "Setting up User Secrets..."
        Write-Host ""
        Write-Host "You'll be prompted for your Azure service principal details."
        Write-Host "These will be stored securely using .NET user secrets."
        Write-Host ""
        
        & "$PSScriptRoot/Test-FabricLocal.ps1" -SetupSecrets
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "User secrets configured!"
            Write-Host ""
            Write-Info "Next steps:"
            Write-Host "1. Test authentication: pwsh Test-FabricLocal.ps1 -TestAuth"
            Write-Host "2. Run deployment: pwsh Test-FabricLocal.ps1 -RunDeploy"
        }
    }
    
    "2" {
        $vaultName = Read-Host "Enter your Azure Key Vault name"
        Write-Info "Setting up Key Vault integration..."
        Write-Host ""
        Write-Warning "Make sure you're authenticated with Azure CLI (az login)"
        Write-Host ""
        Write-Info "Expected Key Vault secrets:"
        Write-Host "- AZURE-CLIENT-ID"
        Write-Host "- AZURE-CLIENT-SECRET"
        Write-Host "- AZURE-TENANT-ID"
        Write-Host "- AZURE-SUBSCRIPTION-ID"
        Write-Host "- ADMIN-OBJECT-ID"
        Write-Host "- fabric-resource-group"
        Write-Host "- fabric-workspace-name"
        Write-Host "- fabric-database-name"
        Write-Host ""
        
        Write-Info "Next steps:"
        Write-Host "1. Test authentication: pwsh Test-FabricLocal.ps1 -Mode KeyVault -KeyVaultName '$vaultName' -TestAuth"
        Write-Host "2. Run deployment: pwsh Test-FabricLocal.ps1 -Mode KeyVault -KeyVaultName '$vaultName' -RunDeploy"
    }
    
    "3" {
        Write-Info "Setting up Environment Variables..."
        Write-Host ""
        Write-Host "Set these environment variables in your PowerShell session:"
        Write-Host @"
`$env:AZURE_CLIENT_ID = 'your-service-principal-app-id'
`$env:AZURE_CLIENT_SECRET = 'your-service-principal-secret'
`$env:AZURE_TENANT_ID = 'your-azure-tenant-id'
`$env:AZURE_SUBSCRIPTION_ID = 'your-subscription-id'
`$env:RESOURCE_GROUP_NAME = 'azuresamples-platformobservabilty-fabric'
`$env:FABRIC_WORKSPACE_NAME = 'fabric-otel-workspace'
`$env:FABRIC_DATABASE_NAME = 'otelobservabilitydb'
"@ -ForegroundColor Yellow
        
        Write-Host ""
        Write-Info "Next steps:"
        Write-Host "1. Set the environment variables above"
        Write-Host "2. Test authentication: pwsh Test-FabricLocal.ps1 -Mode Environment -TestAuth"
        Write-Host "3. Run deployment: pwsh Test-FabricLocal.ps1 -Mode Environment -RunDeploy"
    }
}

Write-Host ""
Write-Success "Setup complete!"
Write-Host ""
Write-Info "For detailed documentation, see: LOCAL_DEVELOPMENT_SETUP.md"
Write-Info "For secret management, use the tool at: tools/DevSecretManager/"
