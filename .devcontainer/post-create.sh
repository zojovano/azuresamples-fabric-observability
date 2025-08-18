#!/bin/bash

# Post-create script for Azure Fabric Observability DevContainer
set -e

echo "🚀 Setting up Azure Fabric Observability development environment..."

# Update package lists
sudo apt-get update

# Install additional system packages
echo "📦 Installing system packages..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    jq \
    unzip \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release

# Install Azure CLI bicep extension
echo "🔧 Installing Azure CLI extensions..."
az extension add --name bicep --upgrade
az extension add --name azure-devops

# Install Microsoft Fabric CLI
echo "🎯 Installing Microsoft Fabric CLI..."
pip install --upgrade pip
pip install ms-fabric-cli

# Install Python development packages
echo "🐍 Installing Python packages..."
pip install \
    azure-identity \
    azure-mgmt-resource \
    azure-mgmt-storage \
    azure-mgmt-eventhub \
    azure-mgmt-containerinstance \
    azure-monitor-opentelemetry \
    opentelemetry-api \
    opentelemetry-sdk \
    jupyter \
    pandas \
    matplotlib \
    black \
    flake8 \
    pytest

# Install .NET tools
echo "🔨 Installing .NET tools..."
dotnet tool install -g Microsoft.Web.LibraryManager.Cli
dotnet tool install -g dotnet-ef

# Install kubectl and helm (if not already installed by feature)
echo "☸️  Configuring Kubernetes tools..."
# kubectl and helm should already be installed by the feature

# Create useful aliases
echo "📝 Setting up aliases..."
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

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'

EOF

# Set up Git configuration (use environment variables if available)
echo "🔧 Configuring Git..."
if [ -n "${GIT_USER_NAME}" ]; then
    git config --global user.name "${GIT_USER_NAME}"
fi
if [ -n "${GIT_USER_EMAIL}" ]; then
    git config --global user.email "${GIT_USER_EMAIL}"
fi

# Create development directories
echo "📁 Creating development directories..."
mkdir -p ~/.local/bin
mkdir -p ~/workspace/notebooks
mkdir -p ~/workspace/scripts

# Install VS Code server extensions (if not already installed)
echo "🔌 Ensuring VS Code extensions are installed..."
code --install-extension ms-azuretools.vscode-bicep --force
code --install-extension ms-python.python --force
code --install-extension ms-vscode.azure-account --force

# Validate installations
echo "✅ Validating installations..."
echo "Azure CLI version: $(az version --output tsv --query '"azure-cli"')"
echo "Python version: $(python --version)"
echo "Fabric CLI version: $(fab --version || echo 'Not installed')"
echo "Docker version: $(docker --version)"
echo ".NET version: $(dotnet --version)"

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
export FABRIC_WORKSPACE_ID="your-workspace-id"
export FABRIC_CAPACITY_ID="your-capacity-id"
export FABRIC_DATABASE_NAME="otelobservabilitydb"
EOF

# Create a welcome script
cat > ~/workspace/welcome.sh << 'EOF'
#!/bin/bash
echo "🎉 Welcome to Azure Fabric Observability DevContainer!"
echo ""
echo "Available tools:"
echo "  - Azure CLI: $(az version --output tsv --query '"azure-cli"')"
echo "  - Python: $(python --version)"
echo "  - .NET: $(dotnet --version)"
echo "  - Docker: $(docker --version)"
echo "  - Fabric CLI: $(fab --version 2>/dev/null || echo 'Run: fab auth login')"
echo ""
echo "Getting started:"
echo "  1. Login to Azure: az login"
echo "  2. Login to Fabric: fab auth login"
echo "  3. Deploy infrastructure: cd infra/Bicep && ./deploy.ps1"
echo ""
echo "Useful directories:"
echo "  - ~/workspace/notebooks - Jupyter notebooks"
echo "  - ~/workspace/scripts - Custom scripts"
echo ""
echo "Configuration samples:"
echo "  - ~/workspace/.azure-config-sample"
echo "  - ~/workspace/.fabric-config-sample"
EOF

chmod +x ~/workspace/welcome.sh

echo "🎯 DevContainer setup completed successfully!"
echo "Run '~/workspace/welcome.sh' to see available tools and getting started instructions."
