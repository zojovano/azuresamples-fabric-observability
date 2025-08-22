#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for Fabric authentication flow

.DESCRIPTION
    This script tests the Fabric authentication flow without committing sensitive data.
    It validates the commands and error handling logic.

.PARAMETER TestMode
    Run in test mode with fake credentials to validate error handling

.EXAMPLE
    .\test-fabric-auth.ps1 -TestMode
#>

[CmdletBinding()]
param(
    [switch]$TestMode
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
        [string]$Prefix = ""
    )
    if ($Prefix) {
        Write-Host "$Prefix " -NoNewline -ForegroundColor $Color
    }
    Write-Host $Message -ForegroundColor $Color
}

function Test-FabricAuthCommands {
    Write-ColorOutput "Testing Fabric CLI commands..." $ColorInfo "🧪"
    
    # Test fab command exists
    if (-not (Get-Command "fab" -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "Fabric CLI not found - installing..." $ColorWarning "📦"
        python -m pip install ms-fabric-cli
    }
    
    # Test config command
    Write-ColorOutput "Testing config command..." $ColorInfo "⚙️"
    fab config set encryption_fallback_enabled true
    $fallbackEnabled = fab config get encryption_fallback_enabled
    Write-ColorOutput "Encryption fallback enabled: $fallbackEnabled" $ColorSuccess "✅"
    
    # Test auth status command when not logged in
    Write-ColorOutput "Testing auth status when not logged in..." $ColorInfo "🔍"
    fab auth logout 2>$null | Out-Null
    fab config clear-cache
    
    $authStatus = fab auth status 2>&1
    $authExitCode = $LASTEXITCODE
    
    Write-ColorOutput "Auth status exit code: $authExitCode" $ColorInfo
    Write-ColorOutput "Auth status output:" $ColorInfo
    $authStatus | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
    
    if ($TestMode) {
        Write-ColorOutput "Testing with fake credentials..." $ColorWarning "🔍"
        
        # Test with fake credentials to see error handling
        $fakeClientId = "12345678-1234-1234-1234-123456789012"
        $fakeSecret = "fake-secret-value"
        $fakeTenant = "12345678-1234-1234-1234-123456789012"
        
        Write-ColorOutput "Attempting login with fake credentials..." $ColorWarning "🔑"
        fab auth login -u $fakeClientId -p $fakeSecret -t $fakeTenant 2>&1
        $loginExitCode = $LASTEXITCODE
        
        Write-ColorOutput "Login exit code: $loginExitCode" $ColorInfo
        
        # Test auth status after failed login
        $authStatusAfterFail = fab auth status 2>&1
        $statusExitCode = $LASTEXITCODE
        
        Write-ColorOutput "Status after failed login - exit code: $statusExitCode" $ColorInfo
        Write-ColorOutput "Status output:" $ColorInfo
        $authStatusAfterFail | ForEach-Object { Write-ColorOutput "  $_" $ColorWarning }
    }
    
    Write-ColorOutput "Command validation complete" $ColorSuccess "✅"
}

function Test-AuthenticationLogic {
    Write-ColorOutput "Testing authentication logic patterns..." $ColorInfo "🧪"
    
    # Test the logic we use in the script
    $authStatus = fab auth status 2>&1
    $authExitCode = $LASTEXITCODE
    
    # Test the condition we use
    $isLoggedIn = ($authExitCode -eq 0 -and $authStatus -and $authStatus -notmatch "Not logged in")
    
    Write-ColorOutput "Authentication check result: $isLoggedIn" $ColorInfo
    Write-ColorOutput "Exit code: $authExitCode" $ColorInfo
    Write-ColorOutput "Status contains 'Not logged in': $($authStatus -match 'Not logged in')" $ColorInfo
    
    # Test account line extraction
    $accountLine = $authStatus | Select-String "Account:" | ForEach-Object { $_.Line }
    if ($accountLine) {
        Write-ColorOutput "Account line found: $accountLine" $ColorSuccess "✅"
    } else {
        Write-ColorOutput "No account line found (expected when not logged in)" $ColorWarning "⚠️"
    }
}

# Main execution
try {
    Write-ColorOutput "Starting Fabric authentication testing..." $ColorSuccess "🚀"
    Write-Host "=" * 50 -ForegroundColor Green
    
    Test-FabricAuthCommands
    Test-AuthenticationLogic
    
    if (-not $TestMode) {
        Write-ColorOutput "Note: Run with -TestMode to test error handling with fake credentials" $ColorInfo "💡"
    }
    
    Write-ColorOutput "Testing completed successfully!" $ColorSuccess "🎉"
    
} catch {
    Write-ColorOutput "Testing failed: $_" $ColorError "❌"
    exit 1
} finally {
    # Cleanup
    fab auth logout 2>$null | Out-Null
    fab config clear-cache 2>$null | Out-Null
    Write-ColorOutput "Cleaned up test state" $ColorInfo "🧹"
}
