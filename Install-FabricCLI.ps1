#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs Python and Microsoft Fabric CLI

.DESCRIPTION
    This script installs Python 3.10+ (if not already installed) and the Microsoft Fabric CLI.
    The Fabric CLI is a Python-based command line interface for Microsoft Fabric.

.PARAMETER PythonVersion
    The minimum Python version required (default: 3.10)

.PARAMETER SkipPythonCheck
    Skip checking if Python is already installed

.EXAMPLE
    .\Install-FabricCLI.ps1
    
.EXAMPLE
    .\Install-FabricCLI.ps1 -SkipPythonCheck

.NOTES
    Author: Generated for Azure Samples - Fabric Observability Project
    Requires: Administrator privileges
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
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-PythonInstalled {
    param([string]$MinVersion = "3.10")
    
    try {
        $pythonOutput = python --version 2>$null
        if ($pythonOutput -match "Python (\d+\.\d+)") {
            $installedVersion = [version]$matches[1]
            $requiredVersion = [version]$MinVersion
            
            if ($installedVersion -ge $requiredVersion) {
                Write-ColorOutput "✅ Python $($installedVersion) is already installed (meets requirement: $MinVersion+)" $ColorSuccess
                return $true
            } else {
                Write-ColorOutput "⚠️  Python $($installedVersion) is installed but version $MinVersion+ is required" $ColorWarning
                return $false
            }
        }
    } catch {
        Write-ColorOutput "❌ Python is not installed or not in PATH" $ColorWarning
        return $false
    }
    return $false
}

function Install-Python {
    Write-ColorOutput "📦 Installing Python..." $ColorInfo
    
    try {
        # Check if winget is available
        $wingetExists = Get-Command winget -ErrorAction SilentlyContinue
        
        if ($wingetExists) {
            Write-ColorOutput "Using winget to install Python..." $ColorInfo
            winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✅ Python installed successfully via winget" $ColorSuccess
                
                # Refresh PATH
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                
                return $true
            }
        }
        
        # Fallback: Download and install Python manually
        Write-ColorOutput "Downloading Python installer..." $ColorInfo
        $pythonUrl = "https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"
        $tempPath = "$env:TEMP\python-installer.exe"
        
        Invoke-WebRequest -Uri $pythonUrl -OutFile $tempPath -UseBasicParsing
        
        Write-ColorOutput "Installing Python (this may take a few minutes)..." $ColorInfo
        Start-Process -FilePath $tempPath -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait
        
        # Clean up
        Remove-Item $tempPath -Force
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        Write-ColorOutput "✅ Python installed successfully" $ColorSuccess
        return $true
        
    } catch {
        Write-ColorOutput "❌ Failed to install Python: $_" $ColorError
        return $false
    }
}

function Install-FabricCLI {
    Write-ColorOutput "📦 Installing Microsoft Fabric CLI..." $ColorInfo
    
    try {
        # Upgrade pip first
        Write-ColorOutput "Upgrading pip..." $ColorInfo
        python -m pip install --upgrade pip
        
        # Install Fabric CLI
        Write-ColorOutput "Installing ms-fabric-cli..." $ColorInfo
        python -m pip install ms-fabric-cli
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Microsoft Fabric CLI installed successfully" $ColorSuccess
            return $true
        } else {
            Write-ColorOutput "❌ Failed to install Fabric CLI" $ColorError
            return $false
        }
        
    } catch {
        Write-ColorOutput "❌ Failed to install Fabric CLI: $_" $ColorError
        return $false
    }
}

function Test-FabricCLI {
    Write-ColorOutput "🧪 Testing Fabric CLI installation..." $ColorInfo
    
    try {
        fab --help 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Fabric CLI is working correctly" $ColorSuccess
            Write-ColorOutput "💡 To get started, run: fab auth login" $ColorInfo
            return $true
        } else {
            Write-ColorOutput "❌ Fabric CLI test failed" $ColorError
            return $false
        }
    } catch {
        Write-ColorOutput "❌ Failed to test Fabric CLI: $_" $ColorError
        return $false
    }
}

function Show-UsageInstructions {
    Write-ColorOutput "`n📋 Microsoft Fabric CLI Usage Instructions:" $ColorInfo
    Write-ColorOutput "==========================================" $ColorInfo
    Write-ColorOutput ""
    Write-ColorOutput "1. Login to Fabric:" $ColorInfo
    Write-ColorOutput "   fab auth login" $ColorWarning
    Write-ColorOutput ""
    Write-ColorOutput "2. See available commands:" $ColorInfo
    Write-ColorOutput "   fab help" $ColorWarning
    Write-ColorOutput ""
    Write-ColorOutput "3. Get help for a specific command:" $ColorInfo
    Write-ColorOutput "   fab <command> --help" $ColorWarning
    Write-ColorOutput ""
    Write-ColorOutput "4. Logout from Fabric:" $ColorInfo
    Write-ColorOutput "   fab auth logout" $ColorWarning
    Write-ColorOutput ""
    Write-ColorOutput "📖 Documentation: https://learn.microsoft.com/en-us/rest/api/fabric/articles/fabric-command-line-interface" $ColorInfo
    Write-ColorOutput "🐙 GitHub: https://aka.ms/FabricCLI" $ColorInfo
}

# Main execution
try {
    Write-ColorOutput "🚀 Microsoft Fabric CLI Installation Script" $ColorInfo
    Write-ColorOutput "===========================================" $ColorInfo
    Write-ColorOutput ""
    
    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-ColorOutput "❌ This script requires administrator privileges. Please run as administrator." $ColorError
        exit 1
    }
    
    # Check Python installation
    if (-not $SkipPythonCheck) {
        $pythonInstalled = Test-PythonInstalled -MinVersion $PythonVersion
        
        if (-not $pythonInstalled) {
            $installPython = Install-Python
            if (-not $installPython) {
                Write-ColorOutput "❌ Failed to install Python. Exiting." $ColorError
                exit 1
            }
            
            # Verify Python installation
            if (-not (Test-PythonInstalled -MinVersion $PythonVersion)) {
                Write-ColorOutput "❌ Python installation verification failed. Please restart your terminal and try again." $ColorError
                exit 1
            }
        }
    } else {
        Write-ColorOutput "⏭️  Skipping Python installation check" $ColorWarning
    }
    
    # Install Fabric CLI
    $fabricInstalled = Install-FabricCLI
    if (-not $fabricInstalled) {
        Write-ColorOutput "❌ Failed to install Fabric CLI. Exiting." $ColorError
        exit 1
    }
    
    # Test Fabric CLI
    $fabricWorking = Test-FabricCLI
    if (-not $fabricWorking) {
        Write-ColorOutput "⚠️  Fabric CLI installed but test failed. You may need to restart your terminal." $ColorWarning
    }
    
    # Show usage instructions
    Show-UsageInstructions
    
    Write-ColorOutput "`n✅ Installation completed successfully!" $ColorSuccess
    Write-ColorOutput "You may need to restart your terminal for all changes to take effect." $ColorWarning
    
} catch {
    Write-ColorOutput "❌ Installation failed: $_" $ColorError
    exit 1
}
