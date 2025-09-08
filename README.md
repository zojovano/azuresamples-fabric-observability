# Microsoft Fabric and OTEL based Platform Observability Sample

This Azure sample demonstrates how to implement platform observability using Microsoft Fabric Real-Time Intelligence and OpenTelemetry (OTEL) with a gateway deployment pattern.

## 🎯 Sample Overview

### Problem Statement
Organizations want to leverage Microsoft Fabric as their main data platform for observability and telemetry analysis, moving away from traditional third-party solutions to a unified Microsoft ecosystem.

### Solution Architecture
This sample implements the [OTEL Gateway Deployment pattern](https://opentelemetry.io/docs/collector/deployment/gateway/) using:

![Architecture Diagram](./docs/assets/image005.png)

**Data Flow**: Azure Resources → Azure Event Hub → OTEL Collector (Container) → Microsoft Fabric Real-Time Intelligence

### Key Components
- **Microsoft Fabric**: Real-Time Intelligence KQL database with OTEL tables
- **Azure Event Hub**: Centralized telemetry ingestion point
- **OTEL Collector**: Containerized gateway for telemetry processing
- **Azure Services**: Sample applications generating telemetry
- **GitHub Actions**: Automated deployment and testing

## 🏗️ Sample Implementation

### Infrastructure Components

#### 1. Microsoft Fabric Real-Time Intelligence
```kql
// Sample KQL tables for OTEL data
.create-merge table OTELLogs (
    Timestamp:datetime, 
    ObservedTimestamp:datetime, 
    TraceID:string, 
    SpanID:string, 
    SeverityText:string, 
    SeverityNumber:int, 
    Body:string, 
    ResourceAttributes:dynamic, 
    LogsAttributes:dynamic
)

.create-merge table OTELMetrics (
    Timestamp:datetime, 
    MetricName:string, 
    MetricType:string, 
    MetricUnit:string, 
    MetricDescription:string, 
    MetricValue:real, 
    Host:string, 
    ResourceAttributes:dynamic,
    MetricAttributes:dynamic
)

.create-merge table OTELTraces (
    TraceID:string, 
    SpanID:string, 
    ParentID:string, 
    SpanName:string, 
    SpanStatus:string, 
    SpanKind:string, 
    StartTime:datetime, 
    EndTime:datetime, 
    ResourceAttributes:dynamic, 
    TraceAttributes:dynamic, 
    Events:dynamic, 
    Links:dynamic
)
```

#### 2. OTEL Collector Configuration
```yaml
# Sample OTEL Gateway Configuration (app/otel-eh-receiver/config.yaml)
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
  azuredataexplorer:
    cluster_uri: ${FABRIC_CLUSTER_URI}
    db_name: ${FABRIC_DATABASE_NAME}
    logs_table_name: "OTELLogs"
    metrics_table_name: "OTELMetrics"
    traces_table_name: "OTELTraces"
    auth:
      application_id: ${AZURE_CLIENT_ID}
      application_key: ${AZURE_CLIENT_SECRET}
      tenant_id: ${AZURE_TENANT_ID}

service:
  pipelines:
    logs:
      receivers: [otlp, azureeventhub]
      processors: [batch]
      exporters: [azuredataexplorer]
    metrics:
      receivers: [otlp, azureeventhub]
      processors: [batch]
      exporters: [azuredataexplorer]
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [azuredataexplorer]
```

#### 3. Azure Infrastructure (Bicep)
The sample uses Azure Verified Modules for consistent deployment:

```bicep
// Sample Fabric Capacity Deployment
module fabricCapacity 'modules/fabriccapacity.bicep' = {
  name: 'fabricCapacity'
  params: {
    capacityName: 'fabric-${projectPrefix}-${environmentName}'
    skuName: 'F2'
    adminObjectId: adminObjectId
    location: location
  }
}

// Sample Event Hub for telemetry ingestion
module eventHub 'modules/eventhub.bicep' = {
  name: 'eventHub'
  params: {
    namespaceName: 'evhns-${projectPrefix}-${environmentName}'
    eventHubName: 'evh-otel-diagnostics'
    location: location
  }
}

// Sample OTEL Collector Container Instance
module otelCollector 'modules/containerinstance.bicep' = {
  name: 'otelCollector'
  params: {
    containerGroupName: 'ci-otel-collector-${environmentName}'
    configYamlContent: loadTextContent('config/otel-config.yaml')
    location: location
  }
}
```

### Sample Applications

#### .NET Worker Service with OTEL Instrumentation
```csharp
// Sample .NET application with OTEL (app/dotnet-client/OTELWorker/Program.cs)
using OpenTelemetry;
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

var builder = Host.CreateApplicationBuilder(args);

// Configure OpenTelemetry
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddSource("OTELWorker")
        .AddOtlpExporter(options => 
        {
            options.Endpoint = new Uri("http://your-otel-collector:4317");
        }))
    .WithMetrics(metrics => metrics
        .AddMeter("OTELWorker")
        .AddOtlpExporter(options => 
        {
            options.Endpoint = new Uri("http://your-otel-collector:4317");
        }));

// Configure logging
builder.Logging.AddOpenTelemetry(logging => logging
    .AddOtlpExporter(options => 
    {
        options.Endpoint = new Uri("http://your-otel-collector:4317");
    }));

builder.Services.AddHostedService<Worker>();
var host = builder.Build();
host.Run();
```

### Automated Deployment Pipeline

#### GitHub Actions Workflow
```yaml
# Sample workflow for automated deployment (.github/workflows/ci-cd-pipeline.yml)
name: Azure Fabric OTEL Sample Deployment

on:
  push:
    branches: [ main ]
  workflow_dispatch:
    inputs:
      location:
        description: 'Azure region'
        default: 'swedencentral'

jobs:
  deploy-infrastructure:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Bicep Templates
        run: |
          az deployment sub create \
            --location ${{ github.event.inputs.location || 'swedencentral' }} \
            --template-file infra/Bicep/main.bicep \
            --parameters environmentName=sample

  deploy-fabric-artifacts:
    needs: deploy-infrastructure
    runs-on: ubuntu-latest
    steps:
      - name: Deploy Fabric Resources
        shell: pwsh
        run: ./infra/Deploy-FabricArtifacts.ps1
```

## 🚀 Quick Start

### Prerequisites
- Azure subscription with Fabric capacity quota
- GitHub repository for automation (optional)
- Service principal with appropriate permissions

### Option 1: DevContainer (Recommended)
```bash
# Clone and open in DevContainer
git clone https://github.com/zojovano/azuresamples-fabric-observability.git
cd azuresamples-fabric-observability
code .
# Click "Reopen in Container" when prompted
```

### Option 2: Manual Setup
```powershell
# Simple deployment (uses environment variables or prompts)
cd infra/Bicep
./deploy.ps1

# Or create full Key Vault setup with service principals
./deploy.ps1 -CreateKeyVault

# Preview deployment without executing
./deploy.ps1 -WhatIf
```

### Option 3: GitHub Actions
1. Fork this repository
2. Configure GitHub secrets (see setup documentation)
3. Push to main branch or trigger workflow manually

## 📊 Sample Queries

Once deployed, you can query the telemetry data in Microsoft Fabric:

```kql
// View recent logs
OTELLogs 
| where Timestamp > ago(1h)
| project Timestamp, SeverityText, Body, ResourceAttributes
| order by Timestamp desc

// Analyze application metrics
OTELMetrics
| where MetricName == "http_requests_total"
| summarize RequestCount = sum(MetricValue) by bin(Timestamp, 5m), tostring(ResourceAttributes.service_name)
| render timechart

// Trace analysis
OTELTraces
| where StartTime > ago(1h)
| project TraceID, SpanName, duration = EndTime - StartTime
| order by duration desc
```

## 🏛️ Architecture Patterns

### Gateway Deployment Pattern
This sample demonstrates the OTEL Gateway pattern where:
- **Centralized Collection**: Single OTEL Collector receives all telemetry
- **Protocol Translation**: Converts Azure diagnostic logs to OTEL format
- **Batching & Processing**: Optimizes data flow to Fabric
- **Reliability**: Provides retry logic and error handling

### Shared Infrastructure Pattern
The sample implements enterprise patterns:
- **Shared Key Vault**: Centralized secret management
- **Service Principal**: Dedicated identity for automation
- **Resource Isolation**: Project-specific resource groups
- **Cost Optimization**: Shared Fabric capacity

## 📁 Sample Structure

```
azuresamples-fabric-observability/
├── app/                          # Sample applications
│   ├── dotnet-client/           # .NET worker with OTEL
│   └── otel-eh-receiver/        # OTEL Collector container
├── infra/                       # Infrastructure as Code
│   ├── Bicep/                   # Azure Bicep templates
│   ├── kql-definitions/         # Fabric table schemas
│   └── Deploy-FabricArtifacts.ps1  # Fabric deployment script
├── tests/                       # Integration tests
├── docs/                        # Setup and troubleshooting
└── .devcontainer/              # Development environment
```

## 🔗 Documentation

- **[Environment Setup](docs/LOCAL_DEVELOPMENT_SETUP.md)**: DevContainer, local development, testing
- **[Development Setup & Troubleshooting](docs/LOCAL_DEVELOPMENT_SETUP.md)**: Complete development environment setup
- **[API Reference](docs/LOCAL_DEVELOPMENT_SETUP.md#additional-resources)**: External documentation links

## 🤝 Contributing

This is an Azure sample repository. To contribute:
1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request with detailed description

## 📜 License

This sample is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## 🏷️ Tags

`azure-samples` `microsoft-fabric` `opentelemetry` `observability` `real-time-intelligence` `bicep` `github-actions`
