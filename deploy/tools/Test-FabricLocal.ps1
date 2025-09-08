# Local Fabric Development Testing Script
# This script provides secure ways to test Fabric deployments locally using KeyVault
#
# Usage:
#   .\Test-FabricLocal.ps1              # Show available options
#   .\Test-FabricLocal.ps1 -TestAuth    # Test authentication with KeyVault secrets
#   .\Test-FabricLocal.ps1 -RunDeploy   # Run full Fabric deployment
#
# Requirements:
#   - Azure CLI logged in with access to KeyVault: azuresamplesdevopskeys
#   - Fabric CLI installed (uses fab commands)
#   - Tenant permissions configured for workspace creation

param(
    [switch]$TestAuth,
    [switch]$RunDeploy
)

# Import centralized configuration
$configModulePath = Join-Path $PSScriptRoot ".." "config" "ProjectConfig.psm1"
if (Test-Path $configModulePath) {
    Import-Module $configModulePath -Force
} else {
    throw "Configuration module not found at: $configModulePath"
}

# Load project configuration
$config = Get-ProjectConfig

# Color output functions
$ColorSuccess = "Green"
$ColorWarning = "Yellow" 
$ColorError = "Red"
$ColorInfo = "Cyan"

function Write-ColorOutput($Message, $Color, $Emoji = "") {
    Write-Host "$Emoji $Message" -ForegroundColor $Color
}

function Get-SecretsFromKeyVault {
    Write-ColorOutput "Loading secrets from Key Vault..." $ColorInfo "🔐"
    
    try {
        # Use the centralized configuration function
        Get-KeyVaultSecrets -Config $config -SetEnvironmentVariables | Out-Null
        
        # Set additional environment variables from configuration
        Set-ConfigEnvironmentVariables -Config $config
        
        Write-ColorOutput "Successfully loaded secrets and configuration!" $ColorSuccess "✅"
        return $true
    } catch {
        Write-ColorOutput "Failed to load secrets from Key Vault: $_" $ColorError "❌"
        return $false
    }
}

function Show-TenantPermissionsGuide {
    Write-ColorOutput "🔒 FABRIC TENANT PERMISSIONS REQUIRED" $ColorWarning "⚠️"
    Write-Host "=" * 80 -ForegroundColor Yellow
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "Service Principal workspace creation requires Fabric Administrator to enable tenant settings:" $ColorWarning
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "📋 REQUIRED MANUAL CONFIGURATION:" $ColorError
    Write-ColorOutput "1. Go to Microsoft Fabric Admin Portal: https://fabric.microsoft.com" $ColorInfo
    Write-ColorOutput "2. Navigate: ⚙️ Settings → Admin portal → Tenant settings → Developer settings" $ColorInfo
    Write-ColorOutput "3. Enable: 'Service principals can create workspaces, connections, and deployment pipelines'" $ColorInfo
    Write-ColorOutput "4. Select: 'Specific security groups'" $ColorInfo
    Write-ColorOutput "5. Add Service Principal (ADOGenericService) to a security group" $ColorInfo
    Write-ColorOutput "6. Add that security group to the tenant setting" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "📖 Detailed guide: docs/TROUBLESHOOT_FABRIC_WORKSPACE_PERMISSIONS.md" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "💡 ALTERNATIVE: Manual workspace creation (skip tenant settings)" $ColorWarning
    Write-ColorOutput "   - Create workspace manually in Fabric portal" $ColorWarning
    Write-ColorOutput "   - Add ADOGenericService as Admin to workspace" $ColorWarning
    Write-ColorOutput "   - Use -SkipWorkspaceCreation flag in deployment" $ColorWarning
    Write-ColorOutput "" $ColorInfo
    Write-Host "=" * 80 -ForegroundColor Yellow
    
    # Prompt user to confirm they've configured tenant settings
    $choice = Read-Host "Have you configured the tenant settings above? (y/N/skip)"
    
    return $choice.ToLower() -in @('y', 'yes', 'skip')
}

function Test-Authentication {
    Write-ColorOutput "Testing authentication with current secrets..." $ColorInfo "🧪"
    
    $clientId = $env:AZURE_CLIENT_ID
    $clientSecret = $env:AZURE_CLIENT_SECRET
    $tenantId = $env:AZURE_TENANT_ID
    
    if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret) -or [string]::IsNullOrWhiteSpace($tenantId)) {
        Write-ColorOutput "Missing required environment variables:" $ColorError "❌"
        Write-ColorOutput "  AZURE_CLIENT_ID: $(if($clientId) { 'SET' } else { 'NOT SET' })" $ColorWarning
        Write-ColorOutput "  AZURE_CLIENT_SECRET: $(if($clientSecret) { 'SET' } else { 'NOT SET' })" $ColorWarning  
        Write-ColorOutput "  AZURE_TENANT_ID: $(if($tenantId) { 'SET' } else { 'NOT SET' })" $ColorWarning
        return $false
    }
    
    Write-ColorOutput "Environment variables found:" $ColorSuccess "✅"
    Write-ColorOutput "  Client ID: $($clientId.Substring(0,8))..." $ColorInfo
    Write-ColorOutput "  Tenant ID: $tenantId" $ColorInfo
    
    # Test Azure CLI authentication
    Write-ColorOutput "Testing Azure CLI authentication..." $ColorInfo "🔐"
    az login --service-principal -u $clientId -p $clientSecret --tenant $tenantId --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Azure CLI authentication successful!" $ColorSuccess "✅"
        
        # Test Fabric CLI authentication
        Write-ColorOutput "Testing Fabric CLI authentication..." $ColorInfo "🔧"
        
        # Check if Fabric CLI is installed
        if (-not (Get-Command fab -ErrorAction SilentlyContinue)) {
            Write-ColorOutput "Installing Fabric CLI..." $ColorWarning "📦"
            & "$PSScriptRoot\..\infra\Install-FabricCLI.ps1"
        }
        
        # Configure Fabric CLI
        fab config set encryption_fallback_enabled true
        fab config clear-cache
        
        # Try Fabric authentication using service principal
        if ($env:AZURE_CLIENT_ID -and $env:AZURE_CLIENT_SECRET -and $env:AZURE_TENANT_ID) {
            Write-ColorOutput "Attempting service principal authentication..." $ColorInfo "🔐"
            $fabricAuth = fab auth login -u $env:AZURE_CLIENT_ID -p $env:AZURE_CLIENT_SECRET --tenant $env:AZURE_TENANT_ID 2>&1
        } else {
            Write-ColorOutput "Missing required environment variables for service principal auth" $ColorError "❌"
            return $false
        }
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Fabric CLI authentication successful!" $ColorSuccess "✅"
            
            # Test workspace listing
            Write-ColorOutput "Testing workspace access..." $ColorInfo "📋"
            $workspaces = fab ls 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "Workspace listing successful!" $ColorSuccess "✅"
                Write-ColorOutput "Available workspaces:" $ColorInfo
                $workspaces | ForEach-Object { Write-ColorOutput "  $_" $ColorInfo }
                return $true
            } else {
                Write-ColorOutput "Workspace listing failed (tenant permissions required):" $ColorError "❌"
                $workspaces | ForEach-Object { Write-ColorOutput "  $_" $ColorError }
                
                # Check if it's the unauthorized error
                if ($workspaces -match "Unauthorized|Access is unauthorized") {
                    Write-ColorOutput "" $ColorInfo
                    Write-ColorOutput "🔍 DIAGNOSIS: Service Principal lacks tenant-level permissions" $ColorWarning
                    Write-ColorOutput "💡 SOLUTION: Configure Fabric tenant settings for workspace creation" $ColorWarning
                    Write-ColorOutput "" $ColorInfo
                    
                    # Show tenant permissions guide
                    if (Show-TenantPermissionsGuide) {
                        Write-ColorOutput "Continuing with deployment (tenant settings configured)..." $ColorSuccess "✅"
                        return $true
                    } else {
                        Write-ColorOutput "Tenant permissions not configured. Deployment will use manual workspace creation." $ColorWarning "⚠️"
                        return $false
                    }
                }
                return $false
            }
        } else {
            Write-ColorOutput "Fabric CLI authentication failed:" $ColorError "❌"
            $fabricAuth | ForEach-Object { Write-ColorOutput "  $_" $ColorError }
            return $false
        }
    } else {
        Write-ColorOutput "Azure CLI authentication failed!" $ColorError "❌"
        return $false
    }
}

function Start-FabricDeployment {
    Write-ColorOutput "Starting Fabric deployment with current environment..." $ColorInfo "🚀"
    
    # Verify environment variables are set
    $requiredVars = @('AZURE_CLIENT_ID', 'AZURE_CLIENT_SECRET', 'AZURE_TENANT_ID', 'RESOURCE_GROUP_NAME')
    $missingVars = @()
    
    foreach ($var in $requiredVars) {
        if ([string]::IsNullOrWhiteSpace((Get-Item "env:$var" -ErrorAction SilentlyContinue).Value)) {
            $missingVars += $var
        }
    }
    
    if ($missingVars.Count -gt 0) {
        Write-ColorOutput "Missing required environment variables:" $ColorError "❌"
        $missingVars | ForEach-Object { Write-ColorOutput "  $_" $ColorError }
        Write-ColorOutput "Run with -SetupSecrets first to configure them" $ColorWarning "💡"
        return
    }
    
    # Check tenant permissions before deployment
    Write-ColorOutput "Checking Fabric workspace permissions..." $ColorInfo "🔍"
    
    # Test workspace listing to check permissions
    try {
        $null = fab ls 2>&1
        $hasWorkspacePermissions = $LASTEXITCODE -eq 0
    } catch {
        $hasWorkspacePermissions = $false
    }
    
    $deployScript = Join-Path $PSScriptRoot ".." "infra" "Deploy-FabricArtifacts.ps1"
    
    if ($hasWorkspacePermissions) {
        Write-ColorOutput "Workspace permissions verified! Running full deployment..." $ColorSuccess "✅"
        Write-ColorOutput "Script: $deployScript" $ColorInfo
        & $deployScript
    } else {
        Write-ColorOutput "Workspace creation permissions not available." $ColorWarning "⚠️"
        Write-ColorOutput "This can happen if tenant settings are not configured." $ColorWarning
        Write-ColorOutput "" $ColorInfo
        
        # Show tenant permissions guide and get user choice
        $tenantConfigured = Show-TenantPermissionsGuide
        
        if ($tenantConfigured) {
            Write-ColorOutput "Running deployment with workspace creation..." $ColorSuccess "✅"
            Write-ColorOutput "Script: $deployScript" $ColorInfo
            & $deployScript
        } else {
            Write-ColorOutput "Running deployment with manual workspace creation required..." $ColorWarning "⚠️"
            Write-ColorOutput "" $ColorInfo
            Write-ColorOutput "📋 MANUAL STEPS REQUIRED:" $ColorWarning
            Write-ColorOutput "1. Go to https://fabric.microsoft.com" $ColorInfo
            Write-ColorOutput "2. Create workspace: '$($config.fabric.workspaceName)'" $ColorInfo
            Write-ColorOutput "3. Assign capacity: '$($config.fabric.capacityName)'" $ColorInfo
            Write-ColorOutput "4. Add 'ADOGenericService' as Admin to workspace" $ColorInfo
            Write-ColorOutput "" $ColorInfo
            
            $proceed = Read-Host "Have you completed the manual workspace creation steps? (y/N)"
            if ($proceed.ToLower() -in @('y', 'yes')) {
                Write-ColorOutput "Running deployment with existing workspace..." $ColorSuccess "✅"
                Write-ColorOutput "Script: $deployScript -SkipWorkspaceCreation" $ColorInfo
                & $deployScript -SkipWorkspaceCreation
            } else {
                Write-ColorOutput "Deployment cancelled. Complete manual steps and try again." $ColorWarning "⏭️"
                Write-ColorOutput "Or configure tenant settings and run without -SkipWorkspaceCreation" $ColorInfo
            }
        }
    }
}

# Main execution logic
Write-ColorOutput "🧪 Fabric Local Development Testing" $ColorInfo "🔬"
Write-ColorOutput "Mode: $Mode" $ColorInfo

# Display configuration summary
Write-ConfigSummary -Config $config

# Override KeyVault name from config if not provided
if ([string]::IsNullOrWhiteSpace($KeyVaultName)) {
    $KeyVaultName = $config.keyVault.vaultName
    Write-ColorOutput "Using KeyVault from configuration: $KeyVaultName" $ColorInfo "🔑"
}

# Main execution
if ($TestAuth) {
    if (Get-SecretsFromKeyVault -VaultName $KeyVaultName) {
        Test-Authentication
    }
} elseif ($RunDeploy) {
    if (Get-SecretsFromKeyVault -VaultName $KeyVaultName) {
        Start-FabricDeployment
    }
} else {
    Write-ColorOutput "Available options:" $ColorInfo "📋"
    Write-ColorOutput "  -TestAuth  : Test authentication with Key Vault secrets" $ColorInfo
    Write-ColorOutput "  -RunDeploy : Run Fabric deployment with Key Vault secrets" $ColorInfo
    Write-ColorOutput "" $ColorInfo
    Write-ColorOutput "Using Key Vault: $KeyVaultName" $ColorInfo "�"
}
