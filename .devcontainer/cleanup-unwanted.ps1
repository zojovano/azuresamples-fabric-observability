# DevContainer Cleanup Script (PowerShell)
# Removes unwanted monitoring components that may be auto-generated

Write-Host "DevContainer Cleanup Script" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

$DevContainerDir = ".devcontainer"

# Check if we're in the project root
if (-not (Test-Path $DevContainerDir)) {
    Write-Host "Error: Not in project root or .devcontainer directory not found" -ForegroundColor Red
    exit 1
}

# List of unwanted files/folders to remove
$UnwantedItems = @(
    "$DevContainerDir\grafana",
    "$DevContainerDir\Dockerfile",
    "$DevContainerDir\docker-compose.yml", 
    "$DevContainerDir\prometheus.yml"
)

$RemovedCount = 0

Write-Host "Checking for unwanted monitoring components..." -ForegroundColor Yellow

foreach ($item in $UnwantedItems) {
    if (Test-Path $item) {
        Write-Host "Removing: $item" -ForegroundColor Red
        Remove-Item -Path $item -Recurse -Force
        $RemovedCount++
    }
}

if ($RemovedCount -eq 0) {
    Write-Host "No unwanted components found - DevContainer is clean!" -ForegroundColor Green
} else {
    Write-Host "Removed $RemovedCount unwanted component(s)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Current .devcontainer contents:" -ForegroundColor Cyan
    Get-ChildItem -Path $DevContainerDir | Format-Table Name, LastWriteTime -AutoSize
}

Write-Host ""
Write-Host "Tip: These files are now in .gitignore to prevent tracking" -ForegroundColor Blue
Write-Host "If they keep reappearing, check VS Code extensions that might be creating them" -ForegroundColor Blue

Write-Host "Cleanup complete!" -ForegroundColor Green
