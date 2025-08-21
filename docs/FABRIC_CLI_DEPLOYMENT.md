# Microsoft Fabric Deployment with Fabric CLI

This document explains how to deploy Microsoft Fabric artifacts using the Fabric CLI as part of the Azure Samples Fabric Observability project.

## Overview

The deployment process uses the Microsoft Fabric CLI (`fab`) to automate the creation and configuration of:
- Fabric workspace
- KQL database for OpenTelemetry data
- KQL tables for logs, metrics, and traces

## Prerequisites

### 1. Azure Resources
Ensure the Azure infrastructure has been deployed first using the Bicep templates:
- Fabric capacity
- Event Hub
- Container instances
- Other supporting resources

### 2. Authentication
The deployment requires proper authentication to both Azure and Microsoft Fabric:
- **Azure CLI**: Must be logged in with appropriate permissions
- **Fabric CLI**: Will be authenticated automatically during deployment

### 3. Required Permissions
The service principal or user account needs:
- **Azure**: Contributor access to the resource group
- **Fabric**: Capacity admin permissions for the Fabric capacity

## Deployment Scripts

### PowerShell Script (Cross-platform)
```powershell
.\infra\Deploy-FabricArtifacts.ps1
```

## Configuration

### Environment Variables
The scripts use the following environment variables (with defaults):

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `FABRIC_WORKSPACE_NAME` | `fabric-otel-workspace` | Name of the Fabric workspace |
| `FABRIC_DATABASE_NAME` | `otelobservabilitydb` | Name of the KQL database |
| `RESOURCE_GROUP_NAME` | `azuresamples-platformobservabilty-fabric` | Azure resource group |
| `LOCATION` | `swedencentral` | Azure region |

### Script Parameters (PowerShell)
```powershell
# Use custom names
.\Deploy-FabricArtifacts.ps1 -WorkspaceName "my-workspace" -DatabaseName "mydb"

# Skip authentication (if already logged in)
.\Deploy-FabricArtifacts.ps1 -SkipAuth
```

## Deployment Process

### 1. Prerequisites Check
- Verifies Fabric CLI installation
- Installs Fabric CLI if missing
- Checks Azure CLI availability

### 2. Authentication
- **Interactive**: Opens browser for user login
- **Service Principal**: Uses environment variables in CI/CD:
  - `AZURE_CLIENT_ID`
  - `AZURE_CLIENT_SECRET`
  - `AZURE_TENANT_ID`

### 3. Infrastructure Discovery
- Finds Fabric capacity from Azure deployment
- Validates resource group existence

### 4. Workspace Setup
- Creates or finds existing workspace
- Links workspace to Fabric capacity

### 5. Database Creation
- Creates KQL database in workspace
- Sets up database for OpenTelemetry data

### 6. Table Deployment
- Deploys OTEL tables from KQL definitions:
  - `OTELLogs` - Application and system logs
  - `OTELMetrics` - Performance metrics
  - `OTELTraces` - Distributed tracing data

### 7. Verification
- Lists deployed resources
- Validates table creation
- Provides connection information

## GitHub Actions Integration

The deployment is integrated into the main workflow in `.github/workflows/deploy-infra.yml`:

```yaml
deploy-fabric-artifacts:
  name: Deploy Fabric Artifacts
  needs: deploy-infra
  runs-on: ubuntu-latest
  steps:
    # ... Azure login and setup
    - name: Deploy Fabric Artifacts
      shell: pwsh
      run: .\infra\Deploy-FabricArtifacts.ps1
```

### Workflow Triggers
- **Push to main**: When infrastructure or KQL files change
- **Manual dispatch**: Can be triggered manually with custom parameters

## Troubleshooting

### Common Issues

#### 1. Authentication Failures
```bash
# Check current authentication status
fab auth whoami

# Re-authenticate
fab auth logout
fab auth login
```

#### 2. Capacity Not Found
- Ensure Azure infrastructure is fully deployed
- Check resource group name matches deployment
- Verify Fabric capacity was created successfully

#### 3. Permission Issues
- Confirm service principal has Fabric capacity admin role
- Check Azure RBAC permissions on resource group
- Ensure the capacity is in the correct tenant

#### 4. Table Already Exists Warnings
This is normal behavior. The scripts use `.create-merge` commands that:
- Create tables if they don't exist
- Update schema if tables exist with different structure
- Leave existing tables unchanged if schema matches

### Manual Verification

#### Connect to Fabric Portal
1. Open [Microsoft Fabric portal](https://fabric.microsoft.com)
2. Navigate to your workspace: `fabric-otel-workspace`
3. Open KQL database: `otelobservabilitydb`
4. Verify tables exist:
   - `OTELLogs`
   - `OTELMetrics`
   - `OTELTraces`

#### Test with KQL Queries
```kql
// List all tables
.show tables

// Check table schemas
.show table OTELLogs schema
.show table OTELMetrics schema
.show table OTELTraces schema

// Count records (should be 0 initially)
OTELLogs | count
OTELMetrics | count
OTELTraces | count
```

## Local Development

### Manual Deployment
```powershell
# Set environment variables
$env:FABRIC_WORKSPACE_NAME = "dev-workspace"
$env:FABRIC_DATABASE_NAME = "devdb"

# Run deployment
.\infra\Deploy-FabricArtifacts.ps1
```

### Testing Scripts
```bash
# Test authentication only
fab auth login
fab auth whoami

# Test workspace operations
fab workspace list
fab workspace create --display-name "test-workspace"

# Test database operations
fab kqldatabase list
fab kqldatabase create --display-name "test-db"
```

## Architecture

```
Azure Resources (Bicep) → Fabric CLI → Fabric Workspace
                                   ↳ KQL Database
                                     ↳ OTEL Tables
```

## Security Considerations

1. **Service Principal**: Use dedicated service principal for CI/CD
2. **Least Privilege**: Grant minimum required permissions
3. **Secret Management**: Store credentials in GitHub secrets
4. **Network Security**: Consider private endpoints for production

## References

- [Microsoft Fabric CLI Documentation](https://learn.microsoft.com/en-us/rest/api/fabric/articles/fabric-command-line-interface)
- [Fabric REST API](https://learn.microsoft.com/en-us/rest/api/fabric/)
- [OpenTelemetry with Azure Data Explorer](https://learn.microsoft.com/azure/data-explorer/open-telemetry-connector)
- [KQL Language Reference](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
