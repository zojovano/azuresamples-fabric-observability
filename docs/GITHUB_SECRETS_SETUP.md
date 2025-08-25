# GitHub Secrets Setup Guide

This guide will help you create and configure the required GitHub secrets for the Azure Infrastructure deployment workflow.

## Step 1: Create Azure Service Principal

Run the following PowerShell commands to create a service principal and get the required values:

```powershell
# Connect to Azure (if not already connected)
Connect-AzAccount

# Set your subscription (replace with your actual subscription ID)
$subscriptionId = "YOUR_SUBSCRIPTION_ID_HERE"
Set-AzContext -SubscriptionId $subscriptionId

# Create service principal for GitHub Actions
$servicePrincipalName = "fabric-observability-github-sp"
$sp = New-AzADServicePrincipal -DisplayName $servicePrincipalName -Role "Contributor" -Scope "/subscriptions/$subscriptionId"

# Display the values you need for GitHub secrets
Write-Host "GitHub Secrets Values:" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green
Write-Host "AZURE_CLIENT_ID: $($sp.AppId)" -ForegroundColor Yellow
Write-Host "AZURE_TENANT_ID: $(Get-AzContext | Select-Object -ExpandProperty Tenant | Select-Object -ExpandProperty Id)" -ForegroundColor Yellow
Write-Host "AZURE_SUBSCRIPTION_ID: $subscriptionId" -ForegroundColor Yellow
Write-Host "AZURE_CLIENT_SECRET: $($sp.PasswordCredentials.SecretText)" -ForegroundColor Yellow
Write-Host ""

# Get admin object ID (replace with your actual admin user email)
$adminEmail = "your-admin@yourcompany.com"  # Replace with actual admin email
try {
    $adminUser = Get-AzADUser -UserPrincipalName $adminEmail
    Write-Host "ADMIN_OBJECT_ID: $($adminUser.Id)" -ForegroundColor Yellow
} catch {
    Write-Host "Could not find user with email: $adminEmail" -ForegroundColor Red
    Write-Host "You can also get your own object ID:" -ForegroundColor Cyan
    $currentUser = Get-AzADUser -SignedIn
    Write-Host "Current User ADMIN_OBJECT_ID: $($currentUser.Id)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Save these values securely - you'll need them for GitHub secrets!" -ForegroundColor Red
```

## Step 2: Add Secrets to GitHub Repository

1. Go to your GitHub repository: https://github.com/zojovano/azuresamples-fabric-observability
2. Click on **Settings** tab
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret** for each of the following:

### Required Secrets:

| Secret Name | Description | Value Source |
|-------------|-------------|--------------|
| `AZURE_CLIENT_ID` | Service principal application ID | From PowerShell output above |
| `AZURE_TENANT_ID` | Azure AD tenant ID | From PowerShell output above |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID | From PowerShell output above |
| `AZURE_CLIENT_SECRET` | Service principal secret | From PowerShell output above |
| `ADMIN_OBJECT_ID` | Object ID of Fabric capacity administrator | From PowerShell output above |

## Step 3: Verify Service Principal Permissions

Ensure your service principal has the required permissions:

```powershell
# Verify the service principal has Contributor role
$sp = Get-AzADServicePrincipal -DisplayName $servicePrincipalName
$roleAssignments = Get-AzRoleAssignment -ObjectId $sp.Id
$roleAssignments | Select-Object RoleDefinitionName, Scope

# The output should show "Contributor" role at subscription scope
```

## Step 4: Test the Setup

After adding the secrets to GitHub:

1. Make a small change to any file in the `infra/Bicep/` directory
2. Commit and push the change to the `main` branch
3. Go to the **Actions** tab in your GitHub repository
4. Watch the "Deploy Azure Infrastructure" workflow run
5. Check for any authentication or permission errors

## Alternative: Using Azure CLI

If you prefer using Azure CLI instead of PowerShell:

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Create service principal
az ad sp create-for-rbac --name "fabric-observability-github-sp" \
  --role contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth

# Get current user object ID (for admin)
az ad signed-in-user show --query id -o tsv
```

## Troubleshooting

If you encounter issues:

1. **Permission Errors**: Ensure the service principal has Contributor access to your subscription
2. **Authentication Errors**: Double-check that all secret values are copied correctly (no extra spaces)
3. **Resource Errors**: Verify that the subscription has sufficient quota for Fabric capacity

## Security Best Practices

- Never commit secrets to your repository
- Rotate service principal secrets regularly
- Use the principle of least privilege for service principal permissions
- Monitor service principal usage in Azure AD audit logs
