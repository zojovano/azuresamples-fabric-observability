#!/bin/bash

# DevContainer Podman WSL Validation Script
# This script validates your environment for running DevContainers with Podman in WSL

set -e

echo "🔍 DevContainer Podman WSL Environment Validation"
echo "================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${RED}❌ FAIL${NC}"
        VALIDATION_FAILED=true
    fi
}

# Initialize validation status
VALIDATION_FAILED=false

# 1. Check WSL Environment
echo -n "🪟 WSL Environment: "
if [ -n "$WSL_DISTRO_NAME" ]; then
    echo -e "${GREEN}✅ PASS${NC} - Running in $WSL_DISTRO_NAME"
else
    echo -e "${YELLOW}⚠️  WARN${NC} - Not running in WSL (this is OK if using native Linux)"
fi

# 2. Check User Context
echo -n "👤 User Context: "
CURRENT_USER=$(whoami)
USER_ID=$(id -u)
GROUP_ID=$(id -g)
echo -e "${BLUE}$CURRENT_USER (UID: $USER_ID, GID: $GROUP_ID)${NC}"

# 3. Check Podman Installation
echo -n "🐋 Podman Installation: "
if command -v podman >/dev/null 2>&1; then
    PODMAN_VERSION=$(podman --version)
    echo -e "${GREEN}✅ PASS${NC} - $PODMAN_VERSION"
else
    echo -e "${RED}❌ FAIL${NC} - Podman not found"
    VALIDATION_FAILED=true
fi

# 4. Check Podman Socket
echo -n "🔌 Podman Socket: "
if systemctl --user is-active podman.socket >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC} - Active"
else
    echo -e "${YELLOW}⚠️  WARN${NC} - Not running, attempting to start..."
    systemctl --user start podman.socket >/dev/null 2>&1
    check_status
fi

# 5. Check Container Runtime
echo -n "🏃 Container Runtime Test: "
if podman run --rm hello-world >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC} - Cannot run test container"
    VALIDATION_FAILED=true
fi

# 6. Check Podman Configuration
echo -n "⚙️  Podman Configuration: "
if [ -f ~/.config/containers/storage.conf ]; then
    echo -e "${GREEN}✅ PASS${NC} - Custom storage configuration found"
else
    echo -e "${YELLOW}⚠️  WARN${NC} - Using default configuration"
fi

# 7. Check Workspace Permissions
echo -n "📁 Workspace Permissions: "
WORKSPACE_DIR=$(pwd)
if [ -r "$WORKSPACE_DIR" ] && [ -w "$WORKSPACE_DIR" ]; then
    echo -e "${GREEN}✅ PASS${NC} - Read/Write access to $WORKSPACE_DIR"
else
    echo -e "${RED}❌ FAIL${NC} - No read/write access to workspace"
    VALIDATION_FAILED=true
fi

# 8. Check Required Tools
echo ""
echo "🛠️  Development Tools:"
echo "--------------------"

tools=("python" "az" "dotnet" "node" "npm" "git")
for tool in "${tools[@]}"; do
    echo -n "  $tool: "
    if command -v $tool >/dev/null 2>&1; then
        VERSION=$(eval "$tool --version 2>/dev/null | head -1" || echo "Available")
        echo -e "${GREEN}✅${NC} $VERSION"
    else
        echo -e "${YELLOW}⚠️${NC} Not installed (will be installed in DevContainer)"
    fi
done

# 9. Check DevContainer Requirements
echo ""
echo "📦 DevContainer Requirements:"
echo "----------------------------"

echo -n "  DevContainer CLI: "
if command -v devcontainer >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${YELLOW}⚠️  INFO${NC} - Install with: npm install -g @devcontainers/cli"
fi

echo -n "  VS Code Extensions: "
if command -v code >/dev/null 2>&1; then
    if code --list-extensions | grep -q "ms-vscode-remote.remote-containers"; then
        echo -e "${GREEN}✅ PASS${NC} - Dev Containers extension found"
    else
        echo -e "${YELLOW}⚠️  WARN${NC} - Install Dev Containers extension"
    fi
else
    echo -e "${YELLOW}⚠️  INFO${NC} - VS Code not available in PATH"
fi

# 10. Network Connectivity Test
echo ""
echo -n "🌐 Network Connectivity: "
if ping -c 1 google.com >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC} - No internet connectivity"
    VALIDATION_FAILED=true
fi

# 11. Container Registry Access
echo -n "📦 Container Registry Access: "
if podman pull hello-world >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC}"
    podman rmi hello-world >/dev/null 2>&1
else
    echo -e "${RED}❌ FAIL${NC} - Cannot pull from container registry"
    VALIDATION_FAILED=true
fi

# Summary
echo ""
echo "📋 Summary:"
echo "==========="

if [ "$VALIDATION_FAILED" = true ]; then
    echo -e "${RED}❌ Validation Failed${NC} - Some issues need to be resolved"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Review the failed checks above"
    echo "  2. Follow the Podman WSL setup guide: .devcontainer/PODMAN_WSL_SETUP.md"
    echo "  3. Run this script again after fixing issues"
    exit 1
else
    echo -e "${GREEN}✅ Validation Successful${NC} - Your environment is ready for DevContainers!"
    echo ""
    echo "🚀 You can now:"
    echo "  1. Open this folder in VS Code"
    echo "  2. Select 'Reopen in Container' when prompted"
    echo "  3. Choose the Podman-optimized configuration if available"
    echo ""
    echo "📄 Available DevContainer Configurations:"
    ls -la .devcontainer/devcontainer*.json 2>/dev/null | sed 's/^/  /'
fi

echo ""
echo "📞 For help and troubleshooting, see: .devcontainer/PODMAN_WSL_SETUP.md"
