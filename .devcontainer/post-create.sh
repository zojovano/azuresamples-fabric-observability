#!/bin/bash

# Post-create script for Azure Fabric Observability DevContainer
# Focused on .NET/PowerShell development with minimal Python for Fabric CLI only
set -e

echo "🚀 Setting up Azure Fabric Observability development environment..."
echo "� Container runtime: $(if command -v docker >/dev/null 2>&1; then echo 'Docker'; else echo 'Unknown'; fi)"
echo "🔍 Current user: $(whoami) (UID: $(id -u), GID: $(id -g))"
echo "📁 Working directory: $(pwd)"

# Update package lists
echo "📦 Updating package lists..."
sudo apt-get update

# Install essential system packages
echo "📦 Installing essential system packages..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    jq \
    unzip \
    ca-certificates \
    gnupg

# Install Azure CLI bicep extension
echo "🔧 Installing Azure CLI extensions..."
az extension add --name bicep --upgrade
az extension add --name azure-devops

# Install Microsoft Fabric CLI (minimal Python installation)
echo "🎯 Installing Microsoft Fabric CLI..."
pip3 install --user ms-fabric-cli

# Ensure the local bin directory is in PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Install Pester for PowerShell tests so tests run reliably in the container
echo "🔧 Installing Pester PowerShell module for tests..."
pwsh -Command "Install-Module -Name Pester -Force -SkipPublisherCheck -Scope AllUsers" || echo "⚠️ Pester installation failed (continuing)"

# Install .NET tools
echo "🔨 Installing .NET tools..."
dotnet tool install -g Microsoft.Web.LibraryManager.Cli

# Create useful aliases for development
echo "📝 Setting up development aliases..."
cat >> ~/.bashrc << 'EOF'

# Azure aliases
alias azlogin='az login --use-device-code'
alias azaccount='az account show'
alias azlist='az account list --output table'

# Fabric CLI aliases
alias fablogin='fab auth login'
alias fabhelp='fab help'

# Bicep aliases
alias bicepbuild='az bicep build'
alias bicepvalidate='az deployment group validate'

# Docker aliases
alias dps='docker ps'
alias dimg='docker images'
alias dlog='docker logs'

# PowerShell aliases
alias pwsh='pwsh'

EOF

# Set up Git configuration (use environment variables if available)
echo "🔧 Configuring Git..."

# Try to get git user info from various sources
GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"

# If not set via environment variables, try to detect from GitHub CLI or other sources
if [ -z "${GIT_USER_NAME}" ] && command -v gh >/dev/null 2>&1; then
    GIT_USER_NAME=$(gh api user --jq '.name' 2>/dev/null || echo "")
    GIT_USER_EMAIL=$(gh api user --jq '.email' 2>/dev/null || echo "")
fi

# If still not set, use placeholder values that indicate user should configure
if [ -z "${GIT_USER_NAME}" ]; then
    GIT_USER_NAME="DevContainer User"
    echo "⚠️  Git user.name not configured. Set GIT_USER_NAME environment variable or run: git config --global user.name 'Your Name'"
else
    git config --global user.name "${GIT_USER_NAME}"
    echo "✅ Git user.name set to: ${GIT_USER_NAME}"
fi

if [ -z "${GIT_USER_EMAIL}" ]; then
    GIT_USER_EMAIL="user@example.com"
    echo "⚠️  Git user.email not configured. Set GIT_USER_EMAIL environment variable or run: git config --global user.email 'your.email@example.com'"
else
    git config --global user.email "${GIT_USER_EMAIL}"
    echo "✅ Git user.email set to: ${GIT_USER_EMAIL}"
fi

# Configure git to use VS Code's credential helper
git config --global credential.helper store

# Create minimal development directories
echo "📁 Creating development directories..."
mkdir -p ~/.local/bin
mkdir -p ~/workspace/scripts

# Validate installations
echo "✅ Validating installations..."
echo "Azure CLI version: $(az version --output tsv --query '"azure-cli"' 2>/dev/null || echo 'Not available')"
echo ".NET version: $(dotnet --version 2>/dev/null || echo 'Not available')"
echo "PowerShell version: $(pwsh --version 2>/dev/null || echo 'Not available')"
echo "Pester version: $(pwsh -Command "(Get-InstalledModule -Name Pester -ErrorAction SilentlyContinue).Version.ToString()" 2>/dev/null || echo 'Pester not installed')"

# Check Fabric CLI with PATH update
export PATH="$HOME/.local/bin:$PATH"
echo "Fabric CLI version: $(fab --version 2>/dev/null || echo 'Installation pending - restart terminal')"

# PowerShell installation is handled via the DevContainer 'powershell' feature
echo "🔧 PowerShell is provided by the DevContainer feature (powershell). Verifying 'pwsh' presence and version..."
if command -v pwsh >/dev/null 2>&1; then
    pwshVersion=$(pwsh --version 2>/dev/null || echo "unknown")
    echo "✅ pwsh found: ${pwshVersion}"
    # Verify minimal version
    if pwsh -Command "if (\$PSVersionTable.PSVersion -ge [Version]'7.5.3') { exit 0 } else { exit 2 }" 2>/dev/null; then
        echo "✅ PowerShell 7.5.3+ confirmed"
    else
        echo "⚠️ PowerShell version is older than 7.5.3; consider rebuilding the DevContainer to pick up feature version"
    fi
else
    echo "⚠️ pwsh not found. Ensure the DevContainer feature 'powershell' was applied and rebuild the container"
fi

# Create sample configuration files
echo "📋 Creating sample configuration files..."

# Create sample Azure configuration
cat > ~/workspace/.azure-config-sample << 'EOF'
# Sample Azure Configuration
# Copy this to .azure-config and update with your values
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_RESOURCE_GROUP="azuresamples-platformobservabilty-fabric"
export AZURE_LOCATION="swedencentral"
EOF

# Create sample Fabric configuration
cat > ~/workspace/.fabric-config-sample << 'EOF'
# Sample Fabric Configuration
# Copy this to .fabric-config and update with your values
export FABRIC_WORKSPACE_NAME="fabric-otel-workspace"
export FABRIC_DATABASE_NAME="otelobservabilitydb"
EOF

# Create a welcome script
cat > ~/workspace/welcome.sh << 'EOF'
#!/bin/bash
echo "🎉 Welcome to Azure Fabric Observability DevContainer!"
echo ""
echo "Available tools:"
echo "  - Azure CLI: $(az version --output tsv --query '"azure-cli"')"
echo "  - .NET: $(dotnet --version)"
echo "  - PowerShell: $(pwsh --version)"
echo "  - Fabric CLI: $($HOME/.local/bin/fab --version 2>/dev/null || echo 'Run: fab auth login')"
echo ""
echo "Getting started:"
echo "  1. Login to Azure: az login"
echo "  2. Login to Fabric: fab auth login"
echo "  3. Deploy infrastructure: cd deploy/infra/Bicep && ./deploy.ps1"
echo "  4. Test locally: pwsh deploy/tools/Test-FabricLocal.ps1 -SetupSecrets"
echo ""
echo "Configuration samples:"
echo "  - ~/workspace/.azure-config-sample"
echo "  - ~/workspace/.fabric-config-sample"
EOF

chmod +x ~/workspace/welcome.sh

echo "🎯 DevContainer setup completed successfully!"
echo "🧹 Minimal setup: .NET/PowerShell focused with Fabric CLI only"
echo "Run '~/workspace/welcome.sh' to see available tools and getting started instructions."
