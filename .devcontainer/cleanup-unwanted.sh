#!/bin/bash

# DevContainer Cleanup Script
# Removes unwanted monitoring components that may be auto-generated

set -e

echo "🧹 DevContainer Cleanup Script"
echo "=============================="

DEVCONTAINER_DIR=".devcontainer"

# Check if we're in the project root
if [ ! -d "$DEVCONTAINER_DIR" ]; then
    echo "❌ Error: Not in project root or .devcontainer directory not found"
    exit 1
fi

# List of unwanted files/folders to remove
UNWANTED_ITEMS=(
    "$DEVCONTAINER_DIR/grafana"
    "$DEVCONTAINER_DIR/Dockerfile"
    "$DEVCONTAINER_DIR/docker-compose.yml"
    "$DEVCONTAINER_DIR/prometheus.yml"
)

REMOVED_COUNT=0

echo "🔍 Checking for unwanted monitoring components..."

for item in "${UNWANTED_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        echo "🗑️  Removing: $item"
        rm -rf "$item"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi
done

if [ $REMOVED_COUNT -eq 0 ]; then
    echo "✅ No unwanted components found - DevContainer is clean!"
else
    echo "🧹 Removed $REMOVED_COUNT unwanted component(s)"
    echo ""
    echo "📝 Current .devcontainer contents:"
    ls -la "$DEVCONTAINER_DIR/"
fi

echo ""
echo "💡 Tip: These files are now in .gitignore to prevent tracking"
echo "🔧 If they keep reappearing, check VS Code extensions that might be creating them"

echo "✅ Cleanup complete!"
