param (
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = (Get-AzContext).Subscription.Id
)

$ErrorActionPreference = "Stop"

# Ensure Azure context is set
if (-not $SubscriptionId) {
    Write-Error "No Azure subscription found in current context. Please run Connect-AzAccount and set a subscription context."
    exit 1
}

# Select subscription
Select-AzSubscription -SubscriptionId $SubscriptionId
Write-Host "Using subscription: $((Get-AzContext).Subscription.Name)"

# Get the current directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BicepDir = $ScriptDir

# Deploy Bicep template
$DeploymentName = "azuresamples-platformobservabilty-fabric-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"

Write-Host "Starting deployment of OTEL Observability infrastructure..."
Write-Host "Deployment name: $DeploymentName"
Write-Host "Location: $Location"

New-AzDeployment -Name $DeploymentName `
    -Location $Location `
    -TemplateFile "$BicepDir\main.bicep" `
    -TemplateParameterFile "$BicepDir\parameters.json" `
    -location $Location `
    -Verbose

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment completed successfully." -ForegroundColor Green
}
else {
    Write-Host "Deployment failed." -ForegroundColor Red
}
