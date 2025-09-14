# Microsoft Fabric OTEL Deployment

This folder contains deployment scripts and artifacts for the Microsoft Fabric OTEL observability solution.

## 🎯 **Current Deployment Approach: Git Integration**

**As of September 2025, we use a Git-based deployment approach that eliminates complex API calls and provides reliable, version-controlled deployment.**

### How Git Integration Works

1. **Prepare**: Table definitions are stored in `fabric-artifacts/` folder
2. **Connect**: Fabric workspace is connected to this Git repository 
3. **Sync**: Fabric automatically syncs changes from Git to workspace
4. **Deploy**: Tables are created/updated in KQL database automatically

### Git Integration Benefits
- ✅ **No API complexity** - No authentication or API call issues
- ✅ **Automatic versioning** - All changes tracked in Git
- ✅ **Reliable deployment** - Fabric handles the sync process
- ✅ **Collaborative development** - Multiple developers can work together
- ✅ **Easy rollback** - Git history provides rollback capabilities
- ✅ **Visual feedback** - Fabric portal shows Git status

## 📁 **Folder Structure**

```
deploy/
├── fabric-artifacts/          # Git integration folder (synced with Fabric)
│   ├── README.md             # Git integration documentation
│   ├── tables/               # KQL table definitions
│   │   ├── otel-logs.kql     # OTELLogs table schema
│   │   ├── otel-metrics.kql  # OTELMetrics table schema
│   │   └── otel-traces.kql   # OTELTraces table schema
│   └── otelobservabilitydb_auto.Eventhouse/  # Fabric-generated structure
├── infra/                    # Infrastructure deployment scripts
│   ├── Deploy-FabricArtifacts-Git.ps1        # Main Git integration script
│   ├── Deploy-FabricArtifacts-Git.ps1       # Simplified Git guidance and sync script
│   ├── Deploy-Complete.ps1                   # Full infrastructure deployment
│   └── Bicep/                # Azure infrastructure templates
└── tools/                    # Development and testing tools
```

## 🚀 **Deployment Process**

### Step 1: Infrastructure Deployment
```powershell
# Deploy Azure infrastructure (Event Hub, Container Instances, etc.)
cd deploy/infra/Bicep
./deploy.ps1
```

### Step 2: Fabric Workspace Setup
```powershell
# Set up Fabric workspace and Git integration
cd deploy/infra
./Deploy-FabricArtifacts-Git.ps1
```

### Step 3: Git Integration Connection
1. **Open Fabric Portal**: https://app.fabric.microsoft.com
2. **Navigate to workspace**: `fabric-otel-workspace`
3. **Go to Settings**: Workspace Settings > Git Integration
4. **Connect repository**: 
   - Provider: GitHub
   - Repository: `azuresamples-fabric-observability`
   - Branch: `main`
   - Folder: `deploy/fabric-artifacts`

### Step 4: Sync and Deploy Tables
```powershell
# Trigger automated Git sync (optional - can be done manually in portal)
cd deploy/infra
./Deploy-FabricArtifacts-Git.ps1 -TriggerSync
```

**OR manually in Fabric portal:**
- Use Source Control panel → Update from Git

## 🔍 **Verification Steps**

After deployment, verify tables are created:

1. **Open KQL Database**: `otelobservabilitydb` in Fabric portal
2. **Run verification query**:
   ```kql
   .show tables
   ```
3. **Expected tables**:
   - `OTELLogs` - OpenTelemetry log data
   - `OTELMetrics` - OpenTelemetry metrics data
   - `OTELTraces` - OpenTelemetry trace data

4. **Test table schemas**:
   ```kql
   OTELLogs | getschema
   OTELMetrics | getschema  
   OTELTraces | getschema
   ```

## 🔄 **Making Schema Changes**

To update table schemas:

1. **Edit KQL files** in `fabric-artifacts/tables/`
2. **Commit changes** to Git repository
3. **Sync in Fabric**: Portal → Source Control → Update from Git
4. **Verify changes**: Run `.show tables` and schema queries

## 🛠️ **Development Workflow**

```bash
# 1. Make changes to table definitions
edit deploy/fabric-artifacts/tables/otel-logs.kql

# 2. Test changes locally
./tests/Test-FabricIntegration-Git.ps1 -WhatIf

# 3. Commit to Git
git add .
git commit -m "Update OTEL table schema"
git push

# 4. Sync in Fabric portal
# Or use automated sync script
./deploy/infra/Deploy-FabricArtifacts-Git.ps1 -TriggerSync
```

## 📋 **Key Files**

| File | Purpose | Usage |
|------|---------|-------|
| `Deploy-FabricArtifacts-Git.ps1` | Main Git integration setup | Initial setup and guidance |
| `Deploy-FabricArtifacts-Git.ps1` | Git guidance & sync | Verify Git structure, provide setup guidance, optional automated sync |
| `fabric-artifacts/tables/*.kql` | Table definitions | Schema definitions synced to Fabric |
| `fabric-artifacts/README.md` | Git integration docs | Setup and usage guidance |

## 🔧 **Troubleshooting**

**Git sync not working?**
- Check workspace Git integration settings
- Verify repository permissions
- Ensure correct folder path: `deploy/fabric-artifacts`

**Tables not created?**
- Check if Git sync completed successfully
- Verify KQL syntax in table definition files
- Check Fabric portal for error messages

**Authentication issues?**
- Run: `fab auth login`
- Verify Fabric workspace access permissions
- Check Azure CLI authentication: `az login`

## 📚 **Migration from API-Based Approach**

Previous versions used complex API-based deployment. The Git integration approach:
- **Eliminates authentication complexity**
- **Provides better reliability**
- **Enables collaborative development**
- **Offers built-in version control**

For legacy API scripts, see commit history before September 2025.

---

## 🏗️ **Infrastructure as Code (Bicep) Deployment**

This section provides comprehensive Bicep-based deployment instructions for automating the entire Azure infrastructure setup.

### Prerequisites

- Azure CLI or Azure PowerShell installed
- Bicep CLI installed
- Azure subscription with contributor access

### Bicep Files Structure

- `main.bicep` - Main orchestration template
- `modules/` - Individual resource modules
  - `fabriccapacity.bicep` - Microsoft Fabric capacity
  - `kqldatabase.bicep` - Microsoft Fabric workspace and KQL database parameters
  - `eventhub.bicep` - Event Hub namespace and hub
  - `containerinstance.bicep` - Container Instance for OTEL Collector
  - `appservice.bicep` - App Service for sample telemetry
- `config/` - Configuration files
  - `otel-config.yaml` - OTEL Collector configuration
- `parameters.json` - Parameter values for deployment

### Full Infrastructure Deployment

1. Navigate to the Bicep directory
```powershell
cd deploy/infra/Bicep
```

2. Login to Azure
```powershell
Connect-AzAccount
# Or using Azure CLI
# az login
```

3. Set your subscription
```powershell
Set-AzContext -SubscriptionId "<your-subscription-id>"
# Or using Azure CLI
# az account set --subscription "<your-subscription-id>"
```

4. Deploy using the provided script
```powershell
./deploy.ps1 -EnvironmentName "dev" -Location "eastus"
```

### Individual Component Deployment

#### Microsoft Fabric Capacity

```powershell
# Deploy just the Fabric capacity
$resourceGroupName = "azuresamples-platformobservabilty-fabric"
$adminObjectId = (Get-AzADUser -UserPrincipalName "admin@contoso.com").Id

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile ./modules/fabriccapacity.bicep `
  -capacityName "fabric-capacity-observability" `
  -skuName "F2" `
  -adminObjectId $adminObjectId `
  -location "eastus"
```

#### Event Hub Deployment

The Event Hub deployment creates:

1. Event Hub Namespace with Standard tier
2. Event Hub for receiving diagnostic data
3. Default consumer group
4. Authorization rule with listen, send, and manage permissions

```powershell
# Deploy just the Event Hub resources
$resourceGroupName = "azuresamples-platformobservabilty-fabric"
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile ./modules/eventhub.bicep `
  -namespaceName "evhns-otel" `
  -eventHubName "evh-otel-diagnostics" `
  -skuName "Standard" `
  -location "eastus"
```

**Connecting Azure Resources to Event Hub:**

After deployment, configure Azure Diagnostic Settings to send logs to the Event Hub:

```powershell
# Example: Connect App Service to Event Hub
$resourceId = (Get-AzWebApp -Name "your-app-name" -ResourceGroupName "your-rg").Id
$eventhubAuthorizationRuleId = (Get-AzEventHubNamespaceAuthorizationRule -ResourceGroupName $resourceGroupName -NamespaceName "evhns-otel-dev" -Name "RootManageSharedAccessKey").Id
$eventhubName = "evh-otel-diagnostics"

Set-AzDiagnosticSetting -ResourceId $resourceId `
  -Name "otel-diagnostics" `
  -EventHubAuthorizationRuleId $eventhubAuthorizationRuleId `
  -EventHubName $eventhubName `
  -Enabled $true `
  -Category "AppServiceHTTPLogs","AppServiceConsoleLogs","AppServiceAppLogs","AppServiceAuditLogs" `
  -MetricCategory "AllMetrics"
```

#### OTEL Collector Container Instance

The Container Instance is configured with:

1. Public IP address for receiving telemetry
2. Exposed ports 4317 (OTLP gRPC) and 4318 (OTLP HTTP)
3. A mounted config volume for the OTEL configuration
4. Environment variables for connection strings and other configuration parameters

**Configuration File Structure:**

```yaml
# Sample config.yaml structure
extensions:
  health_check:
    endpoint: 0.0.0.0:13133

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

  azureeventhub:
    connection: ${EVENTHUB_CONNECTION_STRING}
    format: "azure"

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024

exporters:
  debug:
    verbosity: basic
  
  azuredataexplorer:
    cluster: ${ADX_CLUSTER_URI}
    database: ${ADX_DATABASE}
    routing_tables:
      logs_table: "${LOGS_TABLE_NAME}"
      metrics_table: "${METRICS_TABLE_NAME}"
      traces_table: "${TRACES_TABLE_NAME}"
    auth:
      application_id: ${AAD_APP_ID}
      application_key: ${AAD_APP_SECRET}
      tenant_id: ${AAD_TENANT_ID}
```

**Deployment Example:**

```powershell
# Deploy just the OTEL Collector Container Instance
$resourceGroupName = "azuresamples-platformobservabilty-fabric"
$configContent = Get-Content -Path "./config/otel-config.yaml" -Raw

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile ./modules/containerinstance.bicep `
  -containerGroupName "ci-otel-collector" `
  -containerName "otel-collector" `
  -containerImage "otel/opentelemetry-collector-contrib:latest" `
  -configYamlContent $configContent `
  -location "eastus"
```

#### Sample Application Services

The App Service deployment creates:

1. App Service Plan with the specified tier
2. App Service for hosting the sample application
3. Diagnostic settings to send logs and metrics to the Event Hub

**Features:**

- Linux-based App Service running .NET Core
- HTTPS-only access
- Configured to run from a deployment package
- Diagnostic settings configured to send logs to Event Hub

**Deployment Example:**

```powershell
# Deploy just the App Service
$resourceGroupName = "azuresamples-platformobservabilty-fabric"
$eventhubNamespace = "evhns-otel"
$eventhubName = "evh-otel-diagnostics"

$eventhubAuthRuleId = (Get-AzEventHubNamespaceAuthorizationRule -ResourceGroupName $resourceGroupName -NamespaceName $eventhubNamespace -Name "RootManageSharedAccessKey").Id

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile ./modules/appservice.bicep `
  -appServicePlanName "asp-otel-sample" `
  -appServiceName "app-otel-sample" `
  -sku @{name="B1"; tier="Basic"} `
  -diagnosticEventHubName $eventhubName `
  -diagnosticEventHubAuthorizationRuleId $eventhubAuthRuleId `
  -location "eastus"
```

**Sample Application Deployment:**

After the App Service is created, deploy your application using:

1. **ZIP deployment:**
```powershell
Compress-Archive -Path .\app\* -DestinationPath .\app.zip
az webapp deployment source config-zip --resource-group $resourceGroupName --name "app-otel-sample-dev" --src .\app.zip
```

2. **GitHub Actions:**
Configure a GitHub Actions workflow to build and deploy your application automatically.

### Post-Deployment Configuration

After Bicep deployment, you'll need to:

1. Configure environment variables for the OTEL collector container with actual connection strings
2. Update the diagnostic settings on any resources you want to monitor
3. Deploy your applications to the App Service
4. Complete the Microsoft Fabric workspace setup in the Fabric portal:
   - Create the KQL Database using the provided schema
   - Set up permissions for the database
   - Configure OTEL connector for ingestion from the Event Hub
