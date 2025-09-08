#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Installs Microsoft Fabric CLI on Linux/DevContainer

.DESCRIPTION
    This script installs the Microsoft Fabric CLI using Python pip.
    Designed for Linux DevContainer environments.

.PARAMETER PythonVersion
    The minimum Python version required (default: 3.10)

.PARAMETER SkipPythonCheck
    Skip checking if Python is already installed

.EXAMPLE
    ./Install-FabricCLI-Linux.ps1
    
.EXAMPLE
    ./Install-FabricCLI-Linux.ps1 -SkipPythonCheck

.NOTES
    Author: Generated for Azure Samples - Fabric Observability Project
    Platform: Linux/DevContainer
    Documentation: https://learn.microsoft.com/en-us/rest/api/fabric/articles/fabric-command-line-interface
#>

[CmdletBinding()]
param(
    [string]$PythonVersion = "3.10",
    [switch]$SkipPythonCheck
)

# Colors for output
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorInfo = "Cyan"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [string]$Icon = ""
    )
    if ($Icon) {
        Write-Host "$Icon $Message" -ForegroundColor $Color
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Test-PythonInstalled {
    param([string]$MinVersion = "3.10")
    
    try {
        # Try python3 first (common on Linux)
        $pythonCmd = "python3"
        $pythonOutput = & $pythonCmd --version 2>$null
        
        if (-not $pythonOutput) {
            # Fallback to python
            $pythonCmd = "python"
            $pythonOutput = & $pythonCmd --version 2>$null
        }
        
        if ($pythonOutput -match "Python (\d+\.\d+)") {
            $installedVersion = [version]$matches[1]
            $requiredVersion = [version]$MinVersion
            
            if ($installedVersion -ge $requiredVersion) {
                Write-ColorOutput "Python $($installedVersion) is available (meets requirement: $MinVersion+)" $ColorSuccess "✅"
                return @{
                    IsInstalled = $true
                    Command = $pythonCmd
                    Version = $installedVersion
                }
            } else {
                Write-ColorOutput "Python $($installedVersion) found but version $MinVersion+ is required" $ColorWarning "⚠️"
                return @{
                    IsInstalled = $false
                    Command = $pythonCmd
                    Version = $installedVersion
                }
            }
        }
    } catch {
        Write-ColorOutput "Python is not installed or not in PATH" $ColorWarning "⚠️"
        return @{
            IsInstalled = $false
            Command = $null
            Version = $null
        }
    }
    
    return @{
        IsInstalled = $false
        Command = $null
        Version = $null
    }
}

function Install-FabricCLI {
    param([string]$PythonCommand = "python3")
    
    Write-ColorOutput "Installing Microsoft Fabric CLI..." $ColorInfo "🔧"
    
    try {
        # Upgrade pip first
        Write-ColorOutput "Upgrading pip..." $ColorInfo
        & $PythonCommand -m pip install --upgrade pip --user
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Failed to upgrade pip" $ColorError "❌"
            return $false
        }
        
        # Install Fabric CLI
        Write-ColorOutput "Installing ms-fabric-cli..." $ColorInfo
        & $PythonCommand -m pip install ms-fabric-cli --user
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Microsoft Fabric CLI installed successfully" $ColorSuccess "✅"
            return $true
        } else {
            Write-ColorOutput "Failed to install Fabric CLI" $ColorError "❌"
            return $false
        }
        
    } catch {
        Write-ColorOutput "Failed to install Fabric CLI: $_" $ColorError "❌"
        return $false
    }
}

function Test-FabricCLI {
    Write-ColorOutput "Testing Fabric CLI installation..." $ColorInfo "🧪"
    
    try {
        # Check if fab command is available
        $fabPath = Get-Command fab -ErrorAction SilentlyContinue
        
        if ($fabPath) {
            # Test the command
            $fabOutput = fab --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "Fabric CLI is working correctly" $ColorSuccess "✅"
                Write-ColorOutput "Version: $fabOutput" $ColorInfo
                return $true
            }
        }
        
        # If fab command not found, check if it's in user's local bin
        $localBinPath = "$HOME/.local/bin"
        if (Test-Path "$localBinPath/fab") {
            Write-ColorOutput "Fabric CLI found in local bin, adding to PATH..." $ColorInfo "🔧"
            $env:PATH = "$localBinPath`:$env:PATH"
            
            # Test again
            $fabOutput = & "$localBinPath/fab" --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "Fabric CLI is working correctly" $ColorSuccess "✅"
                Write-ColorOutput "Version: $fabOutput" $ColorInfo
                Write-ColorOutput "Note: You may need to add $localBinPath to your PATH permanently" $ColorWarning "⚠️"
                return $true
            }
        }
        
        Write-ColorOutput "Fabric CLI test failed - command not found" $ColorError "❌"
        return $false
        
    } catch {
        Write-ColorOutput "Failed to test Fabric CLI: $_" $ColorError "❌"
        return $false
    }
}

function Add-ToPathPermanently {
    $localBinPath = "$HOME/.local/bin"
    
    if (Test-Path "$localBinPath/fab") {
        Write-ColorOutput "Adding $localBinPath to PATH in shell profile..." $ColorInfo "🔧"
        
        # Add to .bashrc if it exists
        $bashrc = "$HOME/.bashrc"
        if (Test-Path $bashrc) {
            $pathEntry = "export PATH=`"$localBinPath`:`$PATH`""
            $bashrcContent = Get-Content $bashrc -ErrorAction SilentlyContinue
            
            if ($bashrcContent -notcontains $pathEntry) {
                Add-Content -Path $bashrc -Value "`n# Microsoft Fabric CLI"
                Add-Content -Path $bashrc -Value $pathEntry
                Write-ColorOutput "Added to .bashrc" $ColorSuccess "✅"
            }
        }
        
        # Add to current session
        $env:PATH = "$localBinPath`:$env:PATH"
    }
}

function Show-UsageInstructions {
    Write-ColorOutput "`nMicrosoft Fabric CLI Usage Instructions:" $ColorInfo "📖"
    Write-ColorOutput "==========================================" $ColorInfo
    Write-ColorOutput ""
    Write-ColorOutput "1. Login to Fabric:" $ColorInfo
    Write-ColorOutput "   fab auth login" $ColorWarning
    Write-ColorOutput ""
    Write-ColorOutput "2. Check authentication status:" $ColorInfo
    Write-ColorOutput "   fab auth whoami" $ColorWarning
    Write-ColorOutput ""
    Write-ColorOutput "3. See available commands:" $ColorInfo
    Write-ColorOutput "   fab help" $ColorWarning
    Write-ColorOutput ""
    Write-ColorOutput "4. List workspaces:" $ColorInfo
    Write-ColorOutput "   fab workspace list" $ColorWarning
    Write-ColorOutput ""
    Write-ColorOutput "5. List KQL databases:" $ColorInfo
    Write-ColorOutput "   fab kqldatabase list" $ColorWarning
    Write-ColorOutput ""
    Write-ColorOutput "Documentation: https://learn.microsoft.com/en-us/rest/api/fabric/articles/fabric-command-line-interface" $ColorInfo
    Write-ColorOutput "GitHub: https://aka.ms/FabricCLI" $ColorInfo
}

# Main execution
try {
    Write-ColorOutput "Microsoft Fabric CLI Installation Script (Linux)" $ColorInfo "🚀"
    Write-ColorOutput "=================================================" $ColorInfo
    Write-ColorOutput ""
    
    # Check Python installation
    if (-not $SkipPythonCheck) {
        $pythonInfo = Test-PythonInstalled -MinVersion $PythonVersion
        
        if (-not $pythonInfo.IsInstalled) {
            Write-ColorOutput "Python $PythonVersion+ is required but not found." $ColorError "❌"
            Write-ColorOutput "In this DevContainer, Python should already be installed." $ColorInfo
            Write-ColorOutput "Please check your DevContainer configuration." $ColorInfo
            exit 1
        }
        
        $pythonCmd = $pythonInfo.Command
    } else {
        Write-ColorOutput "Skipping Python installation check" $ColorWarning "⚠️"
        $pythonCmd = "python3"
    }
    
    # Install Fabric CLI
    $fabricInstalled = Install-FabricCLI -PythonCommand $pythonCmd
    if (-not $fabricInstalled) {
        Write-ColorOutput "Failed to install Fabric CLI. Exiting." $ColorError "❌"
        exit 1
    }
    
    # Test Fabric CLI
    $fabricWorking = Test-FabricCLI
    if ($fabricWorking) {
        # Add to PATH permanently if needed
        Add-ToPathPermanently
    } else {
        Write-ColorOutput "Fabric CLI installed but test failed." $ColorWarning "⚠️"
        Write-ColorOutput "You may need to restart your terminal or check your PATH." $ColorInfo
    }
    
    # Show usage instructions
    Show-UsageInstructions
    
    Write-ColorOutput "`nInstallation completed!" $ColorSuccess "🎉"
    
    if ($fabricWorking) {
        Write-ColorOutput "Ready to use: fab auth login" $ColorSuccess "✅"
    } else {
        Write-ColorOutput "Please restart your terminal and try: fab --version" $ColorWarning "⚠️"
    }
    
} catch {
    Write-ColorOutput "Installation failed: $_" $ColorError "❌"
    exit 1
}
