# Microsoft Fabric and OTEL based Platform Observability Sample


## Problem (Use Case)

The company strategy focus is to leverage Microsoft Fabric as a main data platform. Traditionally, Infra and Operations teams has leveraged various third-party technologies for collection, storing and platform telemetry analysis.
The company now wouldl like to leverage Microsoft Fabric investments 

## Solution

We will use [OTEL Gateway Deployment pattern](https://opentelemetry.io/docs/collector/deployment/gateway/) with containerized version of OTEL Collector.
![alt text](./docs/assets/image005.png)

Telemetry collection flow: Azure Resource => Azure Event Hub => Azure Container instance (with OTELContrib Collector) => Microsoft Fabric Real-Time Intelligence (KQL Database)

## Summary of Steps

- Deploy Microsoft Fabric for OTEL Observability use
- Deploy Azure Event Hub for Azure Diagnostic exports
- Deploy OTEL contrib distribution as Azure Diagnostic receiver
- Deploy telemetry sample Azure services
- Optionally, set up continuous deployment with GitHub Actions


## Deploy Microsoft Fabric for OTEL Observability

The deployment process is now fully automated using GitHub Actions and Microsoft Fabric CLI.

### Getting Started

#### DevContainer Development Environment (Recommended)

For the best development experience, use the provided DevContainer which includes all required tools:

```bash
# Open in DevContainer
git clone https://github.com/zojovano/azuresamples-fabric-observability.git
cd azuresamples-fabric-observability
code .
# Click "Reopen in Container" when prompted
```

**📖 Complete Setup Guide**: See [Local Development Setup](docs/LOCAL_DEVELOPMENT_SETUP.md) for detailed DevContainer configuration, Git setup, and local testing instructions.

### Prerequisites

#### 1. **Shared Infrastructure (Platform Team Managed)**
This project uses shared Azure Key Vault and service principal managed by the platform team:

- **Shared Azure Key Vault**: Centrally managed Key Vault for storing project secrets
- **Shared Service Principal**: Enterprise service principal with appropriate permissions

#### 2. **Azure Key Vault Secrets (Required)**
The following secrets must be manually added to the shared Key Vault (currently without project prefix):

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AZURE-CLIENT-ID` | Service principal application ID for project resources | `12345678-1234-1234-1234-123456789012` |
| `AZURE-CLIENT-SECRET` | Service principal client secret for project resources | `your-client-secret-value` |
| `AZURE-TENANT-ID` | Azure tenant ID for the project | `87654321-4321-4321-4321-210987654321` |
| `AZURE-SUBSCRIPTION-ID` | Azure subscription ID where resources will be deployed | `11111111-2222-3333-4444-555555555555` |
| `ADMIN-OBJECT-ID` | Object ID of the user who will be Fabric capacity administrator | `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee` |

> **Note**: Project prefixes (e.g., `fabric-otel-`) will be added in future iterations for multi-project support.

#### 3. **GitHub Repository Secrets (Minimal)**
Only these minimal secrets are required in your GitHub repository:

| Secret Name | Description | How to Obtain |
|-------------|-------------|---------------|
| `SHARED_KEYVAULT_NAME` | Name of the shared Key Vault | Provided by platform team |
| `AZURE_CLIENT_ID` | Shared service principal ID for Key Vault access | Provided by platform team |
| `AZURE_TENANT_ID` | Azure tenant ID for shared authentication | Provided by platform team |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID for shared authentication | Provided by platform team |

#### 4. **Azure Subscription Requirements**
- **Azure Subscription** with sufficient quota for Fabric capacity (F2 SKU minimum)
- **Contributor permissions** for the project service principal
- **Resource Group** creation permissions in the target subscription

### Automated Deployment

#### GitHub Actions Workflow (Shared Infrastructure)
The main deployment workflow uses shared infrastructure and deploys both Azure infrastructure and Fabric artifacts:

```bash
# Triggered automatically on push to main branch
# Or manually via GitHub Actions UI with project-specific parameters
```

**🔒 Security Architecture:**
- **Shared Key Vault**: Platform team managed, project secrets (prefixes to be added later)
- **Minimal GitHub Secrets**: Only basic authentication credentials for shared resources  
- **Project Isolation**: Future enhancement with project-specific naming convention

**Deployment Steps:**
1. **Fetch Secrets** - Retrieves project-specific secrets from shared Key Vault
2. **Azure Infrastructure** - Deploys Bicep templates for:
   - Fabric capacity
   - Event Hub namespace  
   - Container instances for OTEL collector
   - Supporting resources (no Key Vault - uses shared infrastructure)
3. **Fabric Artifacts** - Uses Fabric CLI to deploy:
   - Fabric workspace (`fabric-otel-workspace`)
   - KQL database (`otelobservabilitydb`)
   - OTEL tables (logs, metrics, traces)

#### Manual Deployment

For local development or manual deployment:

```bash
# Ensure project secrets are available in shared Key Vault (platform team responsibility)
# Export local environment variables (for development only):
$env:AZURE_CLIENT_ID = "your-project-client-id"        # From Key Vault: AZURE-CLIENT-ID
$env:AZURE_CLIENT_SECRET = "your-project-client-secret" # From Key Vault: AZURE-CLIENT-SECRET
$env:AZURE_TENANT_ID = "your-tenant-id"                 # From Key Vault: AZURE-TENANT-ID

# Deploy Azure infrastructure
cd infra/Bicep
./deploy.ps1

# Deploy Fabric artifacts
cd ../
.\Deploy-FabricArtifacts.ps1        # PowerShell (Cross-platform)
# or
./Deploy-FabricArtifacts.ps1        # PowerShell/Windows
```

**Note**: Manual deployment requires the same project-specific secrets that are stored in the shared Key Vault. Contact your platform team for access to these values for local development.

#### Validation
```bash
# Test deployment
.\tests\Test-FabricIntegration.ps1
```

📚 **Detailed Documentation**: See [Fabric CLI Deployment Guide](docs/FABRIC_CLI_DEPLOYMENT.md)

<details>
<summary>Manual Azure Portal Setup (Legacy)</summary>

Follow Microsoft Learn article for [configuring OTEL collection for Azure Data Explorer (or Microsoft Fabric Real-Time Intelligence)](https://learn.microsoft.com/azure/data-explorer/open-telemetry-connector). 

Create Fabric Eventhouse
![alt text](./docs/assets/image001.png)


Create OTEL tables

```kusto
.create-merge table <Logs-Table-Name> (Timestamp:datetime, ObservedTimestamp:datetime, TraceID:string, SpanID:string, SeverityText:string, SeverityNumber:int, Body:string, ResourceAttributes:dynamic, LogsAttributes:dynamic) 

.create-merge table <Metrics-Table-Name> (Timestamp:datetime, MetricName:string, MetricType:string, MetricUnit:string, MetricDescription:string, MetricValue:real, Host:string, ResourceAttributes:dynamic,MetricAttributes:dynamic) 

.create-merge table <Traces-Table-Name> (TraceID:string, SpanID:string, ParentID:string, SpanName:string, SpanStatus:string, SpanKind:string, StartTime:datetime, EndTime:datetime, ResourceAttributes:dynamic, TraceAttributes:dynamic, Events:dynamic, Links:dynamic)
```


![alt text](./docs/assets/image002.png)

</details>

<details>
<summary>Bicep</summary>

The Bicep deployment in the `infra/Bicep` folder uses Azure Verified Modules as a base to create all the necessary Azure resources.

### Prerequisites

- Azure CLI or Azure PowerShell installed
- Bicep CLI installed
- Azure subscription with contributor access

### Deployment Steps

1. Navigate to the Bicep directory
```powershell
cd infra/Bicep
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

### Sample Deployment Commands

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

### Post-Deployment Configuration

After deployment, you'll need to:

1. Configure environment variables for the OTEL collector container with actual connection strings
2. Update the diagnostic settings on any resources you want to monitor
3. Deploy your applications to the App Service
4. Complete the Microsoft Fabric workspace setup in the Fabric portal:
   - Create the KQL Database using the provided schema
   - Set up permissions for the database
   - Configure OTEL connector for ingestion from the Event Hub

</details>




## Deploy Azure Event Hub

<details>
<summary>Azure Portal</summary>


![alt text](./docs/assets/image006.png)

![alt text](./docs/assets/image007.png)

![alt text](./docs/assets/image008.png)


Sample Even Hubs diagnostic record from Azure App Service

```json
{
    "records": [
        {
            "time": "2025-03-02T20:24:00.8208182Z",
            "resourceId": "/SUBSCRIPTIONS/5F33A090-5B5B-43FF-A6DD-E912E60767EC/RESOURCEGROUPS/DEMO-OBSERVABILITY/PROVIDERS/MICROSOFT.WEB/SITES/OTELWEBAPP02",
            "category": "AppServiceHTTPLogs",
            "properties": {
                "CsMethod": "GET",
                "CsUriStem": "/",
                "SPort": "443",
                "CIp": "52.158.28.64",
                "UserAgent": "Mozilla/5.0+(compatible;+MSIE+9.0;+Windows+NT+6.1;+Trident/5.0;+AppInsights)",
                "CsHost": "otelwebapp02-b4ejc3ckb9ecd9fd.uksouth-01.azurewebsites.net",
                "ScStatus": 200,
                "ScSubStatus": "0",
                "ScWin32Status": "0",
                "ScBytes": 2140,
                "CsBytes": 1386,
                "TimeTaken": 17,
                "Result": "Success",
                "Cookie": "-",
                "CsUriQuery": "X-ARR-LOG-ID=aa4d225f-5f9d-4ad3-9ce9-3a85565c0b49",
                "CsUsername": "-",
                "Referer": "-",
                "ComputerName": "WEBWK000003"
            }
        }
    ]
}
```

</details>

<details>
<summary>Bicep</summary>

The Event Hub deployment is handled through the `eventhub.bicep` module in the Bicep directory. This module creates:

1. Event Hub Namespace with Standard tier
2. Event Hub for receiving diagnostic data
3. Default consumer group
4. Authorization rule with listen, send, and manage permissions

### Sample Deployment 

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

### Connecting Azure Resources to Event Hub

After deployment, you can configure Azure Diagnostic Settings to send logs to the Event Hub using the Azure Portal or Azure CLI:

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

</details>


## Deploy OTEL contrib distribution as Azure Diagnostic receiver

<details>
<summary>Azure Portal</summary>

[OpenTelemetry Collector Contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib) distribution will be configured and deployed as a Azure Container Instance as a OTEL Collector Gateway. 
Docker image "otel/opentelemetry-collector-contrib" 

We will use "Azure Event Hub Receiver" which is part of the "OpenTelemetry Collector Contrib" distribution. 
![alt text](./docs/assets/image010.png)

and Azure Data Explorer Exporter

![alt text](./docs/assets/image011.png)

You can search for available extensions in the [OTEL registry](https://opentelemetry.io/ecosystem/registry/).


Following is the full OTEL config.yaml content:

```yml
extensions:

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

  azureeventhub:
    connection: Endpoint=sb://namespace.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<key>;EntityPath=maindiagnosticcollection
    partition: ""
    group: $Default
    offset: ""
    format: "azure"


processors:
  batch:

exporters:
  debug:
    verbosity: basic
  azuredataexplorer:
    cluster_uri: "https://trd-sxwndfr8sm0vy6844c.z5.kusto.fabric.microsoft.com"
    application_id: "c84761b4-8a31-4cd9-baf9-bd6752190365"
    application_key: "<key>"
    tenant_id: "539d8bb1-bbd5-4f9d-836d-223c3e6d1e43"
    db_name: "OTELEventHouse"
    metrics_table_name: "OTELMetrics"
    logs_table_name: "OTELLogs"
    traces_table_name: "OTELTraces"
    ingestion_type : "managed"

service:

  pipelines:

    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug,azuredataexplorer]

    metrics:
      receivers: [otlp,azureeventhub]
      processors: [batch]
      exporters: [debug,azuredataexplorer]

    logs:
      receivers: [otlp,azureeventhub]
      processors: [batch]
      exporters: [debug,azuredataexplorer]
```

Deployed Azure Container with OTEL Collector

![alt text](./docs/assets/image009.png)

</details>

<details>
<summary>Bicep</summary>

The Bicep deployment for the OTEL Collector uses the `containerinstance.bicep` module to deploy the OpenTelemetry Collector Contrib distribution as an Azure Container Instance, acting as a gateway between Azure resources and Microsoft Fabric.

### Container Configuration

The Container Instance is configured with:

1. Public IP address for receiving telemetry
2. Exposed ports 4317 (OTLP gRPC) and 4318 (OTLP HTTP)
3. A mounted config volume for the OTEL configuration
4. Environment variables for connection strings and other configuration parameters

### Configuration File

The collector is configured through the `config.yaml` file in the `config/` directory. This configuration:

- Receives telemetry from Azure Event Hub and OTLP protocols
- Processes the telemetry using batch processing
- Exports the data to Microsoft Fabric (Azure Data Explorer)

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

### Deployment Example

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

</details>




## Deploy telemetry sample Azure services

<details>
<summary>Azure Portal</summary>

Deploy two Azure App Services and configure Diagnostic settings to send the telemetry to configured Azure Event Hub.

![alt text](./docs/assets/image012.png)

![alt text](./docs/assets/image013.png)

</details>

<details>
<summary>Bicep</summary>

The App Service deployment is handled by the `appservice.bicep` module. This module creates:

1. App Service Plan with the specified tier
2. App Service for hosting the sample application
3. Diagnostic settings to send logs and metrics to the Event Hub

### Features of the App Service

- Linux-based App Service running .NET Core
- HTTPS-only access
- Configured to run from a deployment package
- Diagnostic settings configured to send logs to Event Hub

### Deployment Example

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

### Sample Application Deployment

After the App Service is created, you can deploy your application to it using various methods:

1. Using ZIP deployment:
```powershell
Compress-Archive -Path .\app\* -DestinationPath .\app.zip
az webapp deployment source config-zip --resource-group $resourceGroupName --name "app-otel-sample-dev" --src .\app.zip
```

2. Using GitHub Actions:
Configure a GitHub Actions workflow to build and deploy your application automatically.

## Continuous Deployment with GitHub Actions

This repository includes a GitHub Actions workflow that automates the deployment of all resources using a **shared infrastructure approach**:

- Microsoft Fabric capacity and workspace
- KQL Database with OTEL tables  
- Event Hub namespace and hub
- OTEL Collector container instance
- App Service for sample telemetry

### 🔒 Enhanced Security with Shared Key Vault

The deployment uses **shared infrastructure** managed by the platform team:

- **✅ Shared Key Vault**: Platform team managed, centralized secret storage
- **✅ Project Isolation**: Future enhancement with secret naming prefixes
- **✅ Minimal GitHub Secrets**: Only basic shared authentication credentials
- **✅ Enterprise Security**: Centralized access control and governance
- **✅ Multi-Project Support**: Future enhancement with project-specific prefixes

### Setup Requirements

1. **Platform Team Prerequisites** (managed externally):
   - Shared Azure Key Vault with appropriate access policies
   - Project secrets populated (currently without prefixes)
   - Shared service principal with Key Vault read permissions

2. **Repository Configuration** (developer responsibility):
   - Configure GitHub repository secrets (4 minimal secrets)
   - Trigger workflow via push or manual dispatch

See detailed setup instructions in [`docs/GITHUB_ACTIONS_KEYVAULT_SETUP.md`](docs/GITHUB_ACTIONS_KEYVAULT_SETUP.md)

### Workflow Triggers

The workflow runs automatically when:
- Changes are pushed to the `main` branch
- Manually triggered via GitHub UI with optional parameters:
  - `location`: Azure region for deployment (default: swedencentral)
  - `skip_deployment`: Run tests only without deployment
  - `project_prefix`: Reserved for future use (default: fabric-otel)

### Manual Deployment

To trigger a manual deployment:
1. Go to the Actions tab in your repository
2. Select the "CI/CD Pipeline - Build, Deploy & Test (Shared Key Vault)" workflow  
3. Click "Run workflow"
4. Optionally specify deployment parameters
5. Click "Run workflow" to start the deployment

## References
- https://learn.microsoft.com/en-us/azure/data-explorer/open-telemetry-connector?context=%2Ffabric%2Fcontext%2Fcontext-rti&pivots=fabric&tabs=command-line
- https://github.com/open-telemetry/opentelemetry-dotnet/tree/main/docs
