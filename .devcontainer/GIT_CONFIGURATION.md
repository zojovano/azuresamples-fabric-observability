# Git Configuration in DevContainer

This document explains how to configure Git in the DevContainer environment without storing personal credentials in the repository.

## 🔧 The Problem

DevContainers start fresh each time they're rebuilt, which means any git configuration (user.name, user.email) gets lost. This causes commit failures with messages like:

```
fatal: unable to auto-detect email address (got 'vscode@container.(none)')
```

## ✅ Solutions

### Option 1: Environment Variables (Recommended)

Set environment variables on your **host system** to automatically configure git in the DevContainer:

**Windows (PowerShell):**
```powershell
$env:GIT_USER_NAME = "Your Name"
$env:GIT_USER_EMAIL = "your.email@example.com"
# Or permanently:
[Environment]::SetEnvironmentVariable("GIT_USER_NAME", "Your Name", "User")
[Environment]::SetEnvironmentVariable("GIT_USER_EMAIL", "your.email@example.com", "User")
```

**Windows (Command Prompt):**
```cmd
setx GIT_USER_NAME "Your Name"
setx GIT_USER_EMAIL "your.email@example.com"
```

**Linux/Mac:**
```bash
export GIT_USER_NAME="Your Name"
export GIT_USER_EMAIL="your.email@example.com"
# Add to ~/.bashrc or ~/.zshrc for persistence:
echo 'export GIT_USER_NAME="Your Name"' >> ~/.bashrc
echo 'export GIT_USER_EMAIL="your.email@example.com"' >> ~/.bashrc
```

### Option 2: Interactive Setup Script

Run the setup script **inside the DevContainer** each time:

```bash
# Interactive mode
./.devcontainer/setup-git-config.sh

# With parameters
./.devcontainer/setup-git-config.sh "Your Name" "your.email@example.com"
```

### Option 3: Manual Configuration

Configure git manually **inside the DevContainer**:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## 🔄 How It Works

1. **DevContainer Build**: The `post-create.sh` script automatically checks for `GIT_USER_NAME` and `GIT_USER_EMAIL` environment variables
2. **Auto-Configuration**: If found, it configures git automatically
3. **Fallback**: If not found, it sets placeholder values and shows instructions
4. **VS Code Integration**: The container is configured to use VS Code's credential helper for authentication

## 🛡️ Security

- **No credentials in repo**: Personal git information is never stored in the repository
- **Local only**: Configuration exists only in the container
- **Temporary**: Lost when container is rebuilt (by design)
- **Environment-based**: Safely passed from host environment variables

## 🧪 Testing Your Configuration

```bash
# Check current git config
git config --global --list | grep user

# Test a commit
git add .
git commit -m "Test commit"
```

## 🚨 Troubleshooting

### "Unable to auto-detect email address"
**Solution**: Git user information is not configured. Use one of the options above.

### "Authentication failed"
**Solution**: This is about git credentials (passwords/tokens), not user info:
- Use `git config --global credential.helper store` 
- VS Code will prompt for credentials when needed
- Or use GitHub CLI: `gh auth login`

### Environment variables not working
**Solution**: 
1. Verify environment variables are set on **host system** (not in container)
2. Restart VS Code after setting environment variables
3. Rebuild the DevContainer: "Dev Containers: Rebuild Container"

### Configuration lost after rebuild
**Solution**: This is expected behavior. Use Option 1 (environment variables) for persistence.

## 📁 Files Involved

- `.devcontainer/devcontainer.json`: Passes environment variables to container
- `.devcontainer/post-create.sh`: Auto-configures git during container setup
- `.devcontainer/setup-git-config.sh`: Interactive setup script for manual configuration

## 💡 Best Practices

1. **Use environment variables** for automatic configuration across rebuilds
2. **Never commit** git credentials or personal information to the repository
3. **Test your setup** with a small commit before doing major work
4. **Document your team's preferred approach** in your project README
