# GitHub Actions Setup Guide

This guide helps you set up GitHub secrets and fix the "Deploy Bicep" step in GitHub Actions.

## Authentication Method

The GitHub Actions workflow has been updated to use the `AZURE_CREDENTIALS` approach, which is more reliable than individual secrets.

## Required GitHub Secrets

You need to create **ONE** GitHub secret:

### `AZURE_CREDENTIALS`
This should contain a JSON object with all the authentication information.

## Step 1: Create Service Principal

Run these PowerShell commands to create a service principal and get the required values:

```powershell
# Login to Azure
Connect-AzAccount

# Get your subscription ID
$subscriptionId = (Get-AzContext).Subscription.Id
Write-Output "Subscription ID: $subscriptionId"

# Get your tenant ID
$tenantId = (Get-AzContext).Tenant.Id
Write-Output "Tenant ID: $tenantId"

# Create service principal
$sp = New-AzADServicePrincipal -DisplayName "fabric-observability-github" -Role "Contributor" -Scope "/subscriptions/$subscriptionId"

# Get the values you need
$clientId = $sp.AppId
$clientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.PasswordCredentials.SecretText))

Write-Output "Client ID: $clientId"
Write-Output "Client Secret: $clientSecret"
Write-Output "Tenant ID: $tenantId"
Write-Output "Subscription ID: $subscriptionId"
```

## Step 2: Get Admin Object ID

```powershell
# Get your user's object ID (replace with the actual admin user)
$adminUser = "admin@MngEnvMCAP742925.onmicrosoft.com"  # Replace with actual admin email
$adminObjectId = (Get-AzADUser -UserPrincipalName $adminUser).Id
Write-Output "Admin Object ID: $adminObjectId"
```

## Step 3: Create GitHub Secrets

### Method 1: Single AZURE_CREDENTIALS Secret (Recommended)

Create a secret named `AZURE_CREDENTIALS` with this JSON format:

```json
{
  "clientId": "your-client-id-here",
  "clientSecret": "your-client-secret-here",
  "subscriptionId": "your-subscription-id-here",
  "tenantId": "your-tenant-id-here"
}
```

### Method 2: Individual Secrets (Alternative)

If you prefer individual secrets, create these:

- `AZURE_CLIENT_ID`: The service principal client ID
- `AZURE_CLIENT_SECRET`: The service principal client secret
- `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID
- `AZURE_TENANT_ID`: Your Azure tenant ID
- `ADMIN_OBJECT_ID`: The object ID of the Fabric capacity administrator

## Step 4: Add Secrets to GitHub

1. Go to your GitHub repository
2. Click on **Settings** tab
3. Click on **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Add the `AZURE_CREDENTIALS` secret with the JSON content
6. Add the `ADMIN_OBJECT_ID` secret with the admin object ID

## Common Issues and Fixes

### Issue 1: "Deploy Bicep" Step Fails with Authentication Error

**Solution**: Make sure the service principal has Contributor access to the subscription and the JSON in `AZURE_CREDENTIALS` is properly formatted.

### Issue 2: "Resource group not found" Error

**Solution**: The resource group is created by the Bicep deployment. Make sure the subscription-level deployment is working correctly.

### Issue 3: Fabric Resources Not Found

**Solution**: Microsoft Fabric resources may take time to be fully available. The workflow now includes better error handling for this scenario.

### Issue 4: Parameter Validation Errors

**Solution**: The workflow has been updated to pass parameters correctly without using the parameters.json file for dynamic values.

## Testing the Setup

You can test your setup by:

1. Making a small change to any file in the `infra/Bicep/` directory
2. Committing and pushing to the main branch
3. Checking the Actions tab in GitHub to see if the workflow runs successfully

## Manual Deployment Alternative

If GitHub Actions continues to have issues, you can deploy manually using:

```powershell
# Navigate to the Bicep directory
cd infra/Bicep

# Login to Azure
Connect-AzAccount

# Deploy the infrastructure
$adminObjectId = (Get-AzADUser -SignedIn).Id
New-AzDeployment -Name "manual-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
  -Location "swedencentral" `
  -TemplateFile "main.bicep" `
  -adminObjectId $adminObjectId `
  -location "swedencentral"
```
