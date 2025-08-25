# Local Fabric Development Testing Script
# This script provides secure ways to test Fabric deployments locally

param(
    [string]$Mode = "UserSecrets", # UserSecrets, KeyVault, Environment
    [string]$KeyVaultName = "",
    [switch]$SetupSecrets,
    [switch]$TestAuth,
    [switch]$RunDeploy
)

# Color output functions
$ColorSuccess = "Green"
$ColorWarning = "Yellow" 
$ColorError = "Red"
$ColorInfo = "Cyan"

function Write-ColorOutput($Message, $Color, $Emoji = "") {
    Write-Host "$Emoji $Message" -ForegroundColor $Color
}

function Test-SecretManagerAvailable {
    $secretManagerPath = Join-Path $PSScriptRoot ".." "tools" "DevSecretManager"
    if (-not (Test-Path $secretManagerPath)) {
        Write-ColorOutput "Secret manager not found. Building it now..." $ColorWarning "⚡"
        
        # Build the secret manager
        Push-Location $secretManagerPath
        try {
            dotnet build
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to build secret manager"
            }
            Write-ColorOutput "Secret manager built successfully" $ColorSuccess "✅"
        }
        finally {
            Pop-Location
        }
    }
    return $secretManagerPath
}

function Initialize-UserSecrets {
    Write-ColorOutput "Setting up user secrets for local development..." $ColorInfo "🔧"
    
    $secretManagerPath = Test-SecretManagerAvailable
    
    Write-ColorOutput "Please provide the following values (they will be stored securely):" $ColorInfo "📝"
    
    # Get service principal details
    $clientId = Read-Host "Azure Client ID (Service Principal Application ID)"
    $clientSecret = Read-Host "Azure Client Secret" -AsSecureString
    $tenantId = Read-Host "Azure Tenant ID"
    $subscriptionId = Read-Host "Azure Subscription ID"
    $resourceGroupName = Read-Host "Resource Group Name [azuresamples-platformobservabilty-fabric]"
    $workspaceName = Read-Host "Fabric Workspace Name [fabric-otel-workspace]"
    $databaseName = Read-Host "Fabric Database Name [otelobservabilitydb]"
    
    # Set defaults
    if ([string]::IsNullOrWhiteSpace($resourceGroupName)) { $resourceGroupName = "azuresamples-platformobservabilty-fabric" }
    if ([string]::IsNullOrWhiteSpace($workspaceName)) { $workspaceName = "fabric-otel-workspace" }
    if ([string]::IsNullOrWhiteSpace($databaseName)) { $databaseName = "otelobservabilitydb" }
    
    # Convert secure string to plain text for storage
    $clientSecretPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecret))
    
    # Store secrets using the secret manager
    Push-Location $secretManagerPath
    try {
        dotnet run set --key "Azure:ClientId" --value $clientId
        dotnet run set --key "Azure:ClientSecret" --value $clientSecretPlain
        dotnet run set --key "Azure:TenantId" --value $tenantId
        dotnet run set --key "Azure:SubscriptionId" --value $subscriptionId
        dotnet run set --key "Azure:ResourceGroupName" --value $resourceGroupName
        dotnet run set --key "Fabric:WorkspaceName" --value $workspaceName
        dotnet run set --key "Fabric:DatabaseName" --value $databaseName
        
        Write-ColorOutput "User secrets configured successfully!" $ColorSuccess "✅"
        Write-ColorOutput "Run 'pwsh tools/Test-FabricLocal.ps1 -TestAuth' to verify" $ColorInfo "💡"
    }
    finally {
        Pop-Location
        # Clear the plain text secret from memory
        $clientSecretPlain = $null
    }
}

function Get-SecretsFromUserSecrets {
    $secretManagerPath = Test-SecretManagerAvailable
    
    Write-ColorOutput "Loading secrets from user secrets..." $ColorInfo "🔑"
    
    Push-Location $secretManagerPath
    try {
        # Generate environment export script
        dotnet run test
        
        # The test command creates the environment script
        $envScript = Join-Path $env:TEMP "fabric-test-env.ps1"
        if (Test-Path $envScript) {
            Write-ColorOutput "Loading environment variables..." $ColorInfo "📋"
            & $envScript
            return $true
        } else {
            Write-ColorOutput "Failed to generate environment script" $ColorError "❌"
            return $false
        }
    }
    finally {
        Pop-Location
    }
}

function Get-SecretsFromKeyVault {
    param([string]$VaultName)
    
    Write-ColorOutput "Loading secrets from Key Vault: $VaultName..." $ColorInfo "🔐"
    
    try {
        # Check if authenticated with Azure
        $account = az account show --query "user.name" -o tsv 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Please authenticate with Azure CLI first: az login" $ColorError "❌"
            return $false
        }
        
        Write-ColorOutput "Authenticated as: $account" $ColorInfo "👤"
        
        # Get secrets from Key Vault
        $secrets = @{
            'AZURE_CLIENT_ID' = 'AZURE-CLIENT-ID'
            'AZURE_CLIENT_SECRET' = 'AZURE-CLIENT-SECRET'
            'AZURE_TENANT_ID' = 'AZURE-TENANT-ID'
            'AZURE_SUBSCRIPTION_ID' = 'AZURE-SUBSCRIPTION-ID'
            'ADMIN_OBJECT_ID' = 'ADMIN-OBJECT-ID'
            'RESOURCE_GROUP_NAME' = 'fabric-resource-group'
            'FABRIC_WORKSPACE_NAME' = 'fabric-workspace-name'
            'FABRIC_DATABASE_NAME' = 'fabric-database-name'
        }
        
        foreach ($envVar in $secrets.Keys) {
            $secretName = $secrets[$envVar]
            try {
                $secretValue = az keyvault secret show --vault-name $VaultName --name $secretName --query "value" -o tsv 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($secretValue)) {
                    Set-Item -Path "env:$envVar" -Value $secretValue
                    Write-ColorOutput "Loaded $envVar from Key Vault" $ColorSuccess "✅"
                } else {
                    Write-ColorOutput "Secret '$secretName' not found in Key Vault" $ColorWarning "⚠️"
                }
            } catch {
                Write-ColorOutput "Failed to get secret '$secretName': $_" $ColorWarning "⚠️"
            }
        }
        
        return $true
    } catch {
        Write-ColorOutput "Failed to load secrets from Key Vault: $_" $ColorError "❌"
        return $false
    }
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
            & "$PSScriptRoot\..\Install-FabricCLI.ps1"
        }
        
        # Configure Fabric CLI
        fab config set encryption_fallback_enabled true
        fab config clear-cache
        
        # Try Fabric authentication
        $fabricAuth = fab auth login --azure-cli 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Fabric CLI authentication successful!" $ColorSuccess "✅"
            
            # Test workspace listing
            Write-ColorOutput "Testing workspace access..." $ColorInfo "📋"
            $workspaces = fab ls 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "Workspace listing successful!" $ColorSuccess "✅"
                Write-ColorOutput "Available workspaces:" $ColorInfo
                $workspaces | ForEach-Object { Write-ColorOutput "  $_" $ColorInfo }
            } else {
                Write-ColorOutput "Workspace listing failed:" $ColorError "❌"
                $workspaces | ForEach-Object { Write-ColorOutput "  $_" $ColorError }
            }
        } else {
            Write-ColorOutput "Fabric CLI authentication failed:" $ColorError "❌"
            $fabricAuth | ForEach-Object { Write-ColorOutput "  $_" $ColorError }
        }
        
        return $true
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
    
    # Run the deployment script
    $deployScript = Join-Path $PSScriptRoot ".." "infra" "Deploy-FabricArtifacts.ps1"
    
    Write-ColorOutput "Running deployment script..." $ColorInfo "⚡"
    Write-ColorOutput "Script: $deployScript" $ColorInfo
    
    & $deployScript -SkipPrereqs
}

# Main execution logic
Write-ColorOutput "🧪 Fabric Local Development Testing" $ColorInfo "🔬"
Write-ColorOutput "Mode: $Mode" $ColorInfo

switch ($Mode.ToLower()) {
    "usersecrets" {
        if ($SetupSecrets) {
            Initialize-UserSecrets
        } elseif ($TestAuth) {
            if (Get-SecretsFromUserSecrets) {
                Test-Authentication
            }
        } elseif ($RunDeploy) {
            if (Get-SecretsFromUserSecrets) {
                Start-FabricDeployment
            }
        } else {
            Write-ColorOutput "Available options for UserSecrets mode:" $ColorInfo "📋"
            Write-ColorOutput "  -SetupSecrets : Configure user secrets interactively" $ColorInfo
            Write-ColorOutput "  -TestAuth     : Test authentication with stored secrets" $ColorInfo
            Write-ColorOutput "  -RunDeploy    : Run Fabric deployment with stored secrets" $ColorInfo
        }
    }
    
    "keyvault" {
        if ([string]::IsNullOrWhiteSpace($KeyVaultName)) {
            Write-ColorOutput "KeyVault name required for KeyVault mode" $ColorError "❌"
            Write-ColorOutput "Usage: -Mode KeyVault -KeyVaultName 'your-keyvault-name'" $ColorInfo "💡"
            exit 1
        }
        
        if ($TestAuth) {
            if (Get-SecretsFromKeyVault -VaultName $KeyVaultName) {
                Test-Authentication
            }
        } elseif ($RunDeploy) {
            if (Get-SecretsFromKeyVault -VaultName $KeyVaultName) {
                Start-FabricDeployment
            }
        } else {
            Write-ColorOutput "Available options for KeyVault mode:" $ColorInfo "📋"
            Write-ColorOutput "  -TestAuth  : Test authentication with Key Vault secrets" $ColorInfo
            Write-ColorOutput "  -RunDeploy : Run Fabric deployment with Key Vault secrets" $ColorInfo
        }
    }
    
    "environment" {
        if ($TestAuth) {
            Test-Authentication
        } elseif ($RunDeploy) {
            Start-FabricDeployment
        } else {
            Write-ColorOutput "Available options for Environment mode:" $ColorInfo "📋"
            Write-ColorOutput "  -TestAuth  : Test authentication with environment variables" $ColorInfo
            Write-ColorOutput "  -RunDeploy : Run Fabric deployment with environment variables" $ColorInfo
            Write-ColorOutput "" $ColorInfo
            Write-ColorOutput "Set these environment variables first:" $ColorWarning "⚠️"
            Write-ColorOutput "  `$env:AZURE_CLIENT_ID = 'your-client-id'" $ColorWarning
            Write-ColorOutput "  `$env:AZURE_CLIENT_SECRET = 'your-client-secret'" $ColorWarning
            Write-ColorOutput "  `$env:AZURE_TENANT_ID = 'your-tenant-id'" $ColorWarning
        }
    }
    
    default {
        Write-ColorOutput "Invalid mode: $Mode" $ColorError "❌"
        Write-ColorOutput "Available modes: UserSecrets, KeyVault, Environment" $ColorInfo "💡"
    }
}
