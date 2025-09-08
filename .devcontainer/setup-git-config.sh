#!/bin/bash
#
# Setup Git Configuration for DevContainer
# 
# This script helps configure git user credentials in the DevContainer
# without storing them in the repository.
#
# Usage:
#   1. Interactive mode: ./setup-git-config.sh
#   2. With parameters: ./setup-git-config.sh "Your Name" "your.email@example.com"
#   3. From environment: GIT_USER_NAME="Your Name" GIT_USER_EMAIL="your@email.com" ./setup-git-config.sh
#

set -e

echo "🔧 Git Configuration Setup for DevContainer"
echo "============================================"

# Check if parameters were provided
if [ $# -eq 2 ]; then
    GIT_USER_NAME="$1"
    GIT_USER_EMAIL="$2"
    echo "📝 Using provided parameters"
elif [ -n "${GIT_USER_NAME}" ] && [ -n "${GIT_USER_EMAIL}" ]; then
    echo "📝 Using environment variables"
else
    echo "📝 Interactive configuration mode"
    echo ""
    echo "Please enter your git configuration:"
    
    read -p "Git user name (e.g., 'John Doe'): " GIT_USER_NAME
    read -p "Git email (e.g., 'john.doe@example.com'): " GIT_USER_EMAIL
fi

# Validate inputs
if [ -z "${GIT_USER_NAME}" ] || [ -z "${GIT_USER_EMAIL}" ]; then
    echo "❌ Error: Both name and email are required"
    echo ""
    echo "Usage examples:"
    echo "  ./setup-git-config.sh \"Your Name\" \"your.email@example.com\""
    echo "  GIT_USER_NAME=\"Your Name\" GIT_USER_EMAIL=\"your@email.com\" ./setup-git-config.sh"
    exit 1
fi

# Configure git
echo ""
echo "🔧 Configuring git globally..."
git config --global user.name "${GIT_USER_NAME}"
git config --global user.email "${GIT_USER_EMAIL}"

# Configure credential helper for VS Code integration
git config --global credential.helper store

echo "✅ Git configuration completed!"
echo ""
echo "Configuration summary:"
echo "  Name:  ${GIT_USER_NAME}"
echo "  Email: ${GIT_USER_EMAIL}"
echo ""
echo "💡 Tips:"
echo "  - This configuration is stored locally in the container only"
echo "  - It will be lost when the container is rebuilt"
echo "  - To persist across rebuilds, set GIT_USER_NAME and GIT_USER_EMAIL"
echo "    environment variables on your host system"
echo ""
echo "🧪 Test your configuration:"
echo "  git config --global --list | grep user"
