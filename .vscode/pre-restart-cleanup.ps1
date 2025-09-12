# Pre-Restart Cleanup Script
# Prevents file restoration issues when restarting VS Code/DevContainer

param(
    [switch]$Force,
    [switch]$SkipCommit,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

# Color output functions
function Write-ColorOutput($Message, $Color = "White", $Icon = "") {
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Icon $Message" -ForegroundColor $Color
}

function Write-Success($Message) { Write-ColorOutput $Message "Green" "✅" }
function Write-Warning($Message) { Write-ColorOutput $Message "Yellow" "⚠️" }
function Write-Error($Message) { Write-ColorOutput $Message "Red" "❌" }
function Write-Info($Message) { Write-ColorOutput $Message "Cyan" "ℹ️" }

try {
    Write-Info "Starting pre-restart cleanup..."
    
    # Step 1: Check for uncommitted changes
    $gitStatus = git status --porcelain 2>&1
    $hasChanges = $gitStatus -and $gitStatus.Length -gt 0
    
    if ($hasChanges -and -not $SkipCommit) {
        Write-Warning "Found uncommitted changes:"
        git status --short
        
        if ($Force -or (Read-Host "Commit and push changes? (y/N)") -match '^[Yy]') {
            Write-Info "Committing changes..."
            git add -A
            $commitMessage = "Auto-commit before restart: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            git commit -m $commitMessage
            git push
            Write-Success "Changes committed and pushed"
        } else {
            Write-Warning "Skipping commit - changes will remain uncommitted"
        }
    } elseif ($hasChanges) {
        Write-Warning "Uncommitted changes detected but commit skipped"
    } else {
        Write-Success "No uncommitted changes found"
    }
    
    # Step 2: Clear GitHub Copilot cache
    Write-Info "Clearing GitHub Copilot cache..."
    $copilotPaths = @(
        "~/.vscode-server/data/User/globalStorage/github.copilot*",
        "~/.vscode-server/data/User/globalStorage/GitHub.copilot*"
    )
    
    foreach ($path in $copilotPaths) {
        $expandedPath = [Environment]::ExpandEnvironmentVariables($path)
        if (Test-Path $expandedPath) {
            Remove-Item $expandedPath -Recurse -Force -ErrorAction SilentlyContinue
            if ($Verbose) { Write-Info "Removed: $expandedPath" }
        }
    }
    Write-Success "GitHub Copilot cache cleared"
    
    # Step 3: Clear VS Code workspace storage
    Write-Info "Clearing VS Code workspace storage..."
    $workspaceStoragePath = "~/.vscode-server/data/User/workspaceStorage/*"
    $expandedWorkspacePath = [Environment]::ExpandEnvironmentVariables($workspaceStoragePath)
    if (Test-Path (Split-Path $expandedWorkspacePath)) {
        Remove-Item $expandedWorkspacePath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Success "VS Code workspace storage cleared"
    } else {
        Write-Info "No workspace storage found"
    }
    
    # Step 4: Clear extension caches
    Write-Info "Clearing extension caches..."
    $cachePaths = @(
        "~/.vscode-server/data/User/globalStorage/*/cache",
        "~/.vscode-server/extensions/*/cache"
    )
    
    foreach ($path in $cachePaths) {
        $expandedPath = [Environment]::ExpandEnvironmentVariables($path)
        Get-ChildItem (Split-Path $expandedPath) -Recurse -Directory -Name "cache" -ErrorAction SilentlyContinue | 
            ForEach-Object { 
                $fullCachePath = Join-Path (Split-Path $expandedPath) $_
                Remove-Item $fullCachePath -Recurse -Force -ErrorAction SilentlyContinue
                if ($Verbose) { Write-Info "Removed cache: $fullCachePath" }
            }
    }
    Write-Success "Extension caches cleared"
    
    # Step 5: Verify VS Code settings
    Write-Info "Verifying VS Code anti-restoration settings..."
    $settingsPath = ".vscode/settings.json"
    if (Test-Path $settingsPath) {
        $settings = Get-Content $settingsPath | ConvertFrom-Json
        $requiredSettings = @{
            "files.hotExit" = "off"
            "workbench.editor.restoreViewState" = $false
            "git.autofetch" = $false
        }
        
        $needsUpdate = $false
        foreach ($key in $requiredSettings.Keys) {
            if (-not $settings.PSObject.Properties[$key] -or $settings.$key -ne $requiredSettings[$key]) {
                $needsUpdate = $true
                break
            }
        }
        
        if ($needsUpdate) {
            Write-Warning "VS Code settings need updating for anti-restoration"
            Write-Info "Run the 'Configure Anti-Restoration Settings' task to fix this"
        } else {
            Write-Success "VS Code anti-restoration settings are configured"
        }
    } else {
        Write-Warning "No VS Code settings.json found"
    }
    
    # Step 6: Final verification
    Write-Info "Performing final verification..."
    $finalGitStatus = git status --porcelain 2>&1
    if ($finalGitStatus -and $finalGitStatus.Length -gt 0) {
        Write-Warning "There are still uncommitted changes"
        git status --short
    } else {
        Write-Success "Git repository is clean"
    }
    
    Write-Success "Pre-restart cleanup completed successfully!"
    Write-Info "You can now safely restart VS Code/DevContainer"
    
} catch {
    Write-Error "Cleanup failed: $($_.Exception.Message)"
    exit 1
}
