# GitHub Actions Deployment Guide

This document explains how to set up and use the GitHub Actions workflow for automated deployment of the Azure Fabric Observability infrastructure.

## Overview

The GitHub Actions workflow automates the deployment of:
- Microsoft Fabric capacity and workspace
- KQL Database with OTEL tables
- Event Hub for diagnostic data
- Container Instance for OTEL Collector
- App Service for sample telemetry

## Prerequisites

1. **GitHub Repository**: Fork or clone this repository to your GitHub account.

2. **Service Principal**: Create an Azure service principal with Contributor access to your subscription:

```powershell
# Create service principal and capture output
$sp = az ad sp create-for-rbac --name "fabric-observability-github" --role Contributor --scopes /subscriptions/{YourSubscriptionId} | ConvertFrom-Json

# Display values for GitHub secrets
Write-Output "AZURE_CLIENT_ID: $($sp.appId)"
Write-Output "AZURE_TENANT_ID: $($sp.tenant)"
Write-Output "AZURE_SUBSCRIPTION_ID: {YourSubscriptionId}"
Write-Output "AZURE_CLIENT_SECRET: $($sp.password)"
```

3. **Admin Object ID**: Get the object ID of the user who will be the Fabric capacity administrator:

```powershell
# Get the Object ID for a user
$adminObjectId = (Get-AzADUser -UserPrincipalName "user@example.com").Id
Write-Output "ADMIN_OBJECT_ID: $adminObjectId"
```

## Setting Up GitHub Secrets

Add these secrets to your GitHub repository (Settings > Secrets and variables > Actions > New repository secret):

1. `AZURE_CLIENT_ID`: The service principal application (client) ID
2. `AZURE_TENANT_ID`: The Azure tenant ID
3. `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID
4. `AZURE_CLIENT_SECRET`: The service principal client secret
5. `ADMIN_OBJECT_ID`: The object ID of the Fabric capacity administrator

## Deployment Environments

The workflow uses GitHub environments for deployment control:

1. Create a `production` environment in your repository (Settings > Environments > New environment)
2. Configure protection rules as needed (approvals, wait times)

## Workflow Triggers

The workflow runs automatically when:
- Changes are pushed to the `main` branch in the `infra/Bicep/` directory
- The workflow file itself is modified
- Manually triggered via GitHub UI with optional parameters

## Manual Deployment

To trigger a manual deployment:

1. Go to the Actions tab in your repository
2. Select the "Deploy Azure Infrastructure" workflow
3. Click "Run workflow"
4. Optionally specify a different Azure region
5. Click "Run workflow" to start the deployment

## Monitoring Deployments

The workflow has three main jobs:
1. **validate**: Validates the Bicep files syntax
2. **deploy-infra**: Deploys the Azure resources using Bicep
3. **deploy-kql-tables**: Creates the KQL tables in the Fabric workspace
4. **report-status**: Reports the overall deployment status

Monitor the progress in the Actions tab of your repository.

## Troubleshooting

If the deployment fails:

1. Check the workflow run logs for specific error messages
2. Verify that all required secrets are correctly configured
3. Ensure the service principal has sufficient permissions
4. Check that the parameters in `parameters.json` are valid

## Additional Configuration

To customize the deployment:

1. Modify the Bicep templates in the `infra/Bicep/` directory
2. Update the `parameters.json` file with your specific parameter values
3. Adjust the GitHub workflow file as needed for additional steps or different configurations
