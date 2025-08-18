# Podman WSL Setup Guide for Azure Fabric Observability DevContainer

This guide helps you set up and troubleshoot the DevContainer environment specifically for Podman in WSL2.

## 🔧 Prerequisites

### 1. WSL2 Setup
```powershell
# Enable WSL2 in PowerShell (as Administrator)
wsl --install
wsl --set-default-version 2

# Verify WSL2 is running
wsl --status
```

### 2. Podman Installation in WSL
```bash
# In your WSL2 distribution (Ubuntu/Debian)
sudo apt update
sudo apt install -y podman

# Alternative: Install latest Podman
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/ /' > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
wget -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_20.04/Release.key -O- | sudo apt-key add -
sudo apt update
sudo apt install -y podman
```

### 3. Podman Configuration for WSL
```bash
# Create rootless configuration
mkdir -p ~/.config/containers

# Configure storage
cat > ~/.config/containers/storage.conf << 'EOF'
[storage]
driver = "overlay"
runroot = "/tmp/podman-run-1000"
graphroot = "/home/$USER/.local/share/containers/storage"

[storage.options]
additionalimagestores = [
]

[storage.options.overlay]
mountopt = "nodev,metacopy=on"
EOF

# Configure registries
cat > ~/.config/containers/registries.conf << 'EOF'
[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io', 'registry.access.redhat.com', 'registry.centos.org']

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF

# Start Podman socket
systemctl --user enable podman.socket
systemctl --user start podman.socket
```

## 🚀 DevContainer Configuration Options

### Option 1: Podman-Optimized Configuration
Use `devcontainer-podman.json` for the best Podman WSL experience:

```bash
# Copy the Podman configuration as your main config
cp .devcontainer/devcontainer-podman.json .devcontainer/devcontainer.json
```

### Option 2: Use the Updated Main Configuration
The main `devcontainer.json` has been optimized for Podman compatibility.

## 🛠️ VS Code Setup

### 1. Install Required Extensions
- Dev Containers (ms-vscode-remote.remote-containers)
- WSL (ms-vscode-remote.remote-wsl)

### 2. Configure VS Code Settings
Add to your VS Code settings.json:
```json
{
    "dev.containers.dockerPath": "podman",
    "dev.containers.dockerComposePath": "podman-compose",
    "remote.containers.defaultExtensions": [
        "ms-vscode.azure-account"
    ]
}
```

## 🐛 Troubleshooting

### Common Issues and Solutions

#### 1. Container Won't Start
```bash
# Check Podman service
systemctl --user status podman.socket

# Restart if needed
systemctl --user restart podman.socket

# Check for running containers
podman ps -a
```

#### 2. Mount Issues
```bash
# Check SELinux context (if applicable)
ls -Z /path/to/workspace

# Disable SELinux labeling if needed
podman run --security-opt label=disable ...
```

#### 3. User Permission Issues
```bash
# Check current user mapping
id
cat /proc/self/uid_map
cat /proc/self/gid_map

# Reset Podman storage if needed
podman system reset --force
```

#### 4. Network Issues
```bash
# Check network configuration
podman network ls

# Create custom network if needed
podman network create devcontainer-net
```

### Environment Validation Script
```bash
#!/bin/bash
echo "🔍 DevContainer Environment Validation"
echo "======================================"
echo "WSL Distribution: $WSL_DISTRO_NAME"
echo "Current User: $(whoami) (UID: $(id -u), GID: $(id -g))"
echo "Container Runtime: $(if command -v podman >/dev/null 2>&1; then echo 'Podman'; podman --version; else echo 'Not found'; fi)"
echo "Podman Socket: $(systemctl --user is-active podman.socket 2>/dev/null || echo 'Not running')"
echo "Python: $(python --version 2>/dev/null || echo 'Not available')"
echo "Azure CLI: $(az --version 2>/dev/null | head -1 || echo 'Not available')"
echo "Working Directory: $(pwd)"
echo "Directory Permissions: $(ls -la . | head -3)"
```

## 🎯 Optimizations for Performance

### 1. Storage Optimization
```bash
# Use tmpfs for temporary files
mkdir -p ~/.config/containers
echo 'tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0' | sudo tee -a /etc/fstab
```

### 2. Memory Settings
```bash
# Configure cgroup v2 memory limits
echo 'memory.max 8G' | sudo tee /sys/fs/cgroup/memory.max
```

### 3. Network Performance
```bash
# Use host networking for development
podman run --network host ...
```

## 📋 Quick Start Checklist

- [ ] WSL2 is installed and running
- [ ] Podman is installed in WSL
- [ ] Podman socket is running (`systemctl --user status podman.socket`)
- [ ] VS Code has Dev Containers extension
- [ ] DevContainer configuration points to Podman
- [ ] Workspace folder permissions are correct
- [ ] Network connectivity is working

## 🔗 Useful Commands

```bash
# Test DevContainer without VS Code
devcontainer up --workspace-folder .

# Debug container issues
podman logs <container-id>

# Check resource usage
podman stats

# Clean up resources
podman system prune -a

# Reset everything
podman system reset --force
```

## 🚨 Known Limitations

1. **GPU Access**: Limited GPU support in WSL compared to native Linux
2. **Systemd**: May not work as expected in some WSL configurations
3. **File Permissions**: Can be complex with Windows filesystem integration
4. **Performance**: May be slower than native Docker Desktop on Windows

## 📞 Getting Help

If you encounter issues:
1. Check the validation script output
2. Review Podman logs: `journalctl --user -u podman.socket`
3. Test with a simple container: `podman run hello-world`
4. Check WSL integration: `wsl --status`
