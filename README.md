# Microsoft Fabric and OTEL based Platform Observability Sample


## Problem (Use Case)

The company strategy focus is to leverage Microsoft Fabric as a main data platform. The Operations team is responsible for operating a larger number of applications across the enterprise, and as such, the team already uses Microsoft Fabric environment for a set of operational reports and dashboards. 

Traditionally, Infra and Operations teams has leveraged various third-party technologies for collection, storing and platform telemetry analysis. However, with the existing Microsoft Fabric investment and expertise, the company now would like to leverage Microsoft Fabric investments for comprehensive platform observability rather than maintaining separate monitoring infrastructure.

## Solution

We will use [OTEL Gateway Deployment pattern](https://opentelemetry.io/docs/collector/deployment/gateway/) with containerized version of OTEL Collector.

The solution implements a centralized telemetry processing architecture where Azure services send diagnostic data to Azure Event Hub, while applications emit telemetry directly via OTLP protocols. An OTEL Collector running in Azure Container Instance acts as a gateway, processing and routing all telemetry data to Microsoft Fabric Real-Time Intelligence. The data is then structured into dedicated OTEL tables (Logs, Metrics, Traces) within a KQL database for analysis and monitoring.

![alt text](./docs/assets/image005.png)

```mermaid
graph TD
    subgraph "Azure Environment"
        AS[Azure Services<br/>App Services, VMs, etc.]
        EH[Azure Event Hub<br/>Diagnostic Logs]
        ACI[Azure Container Instance<br/>OTEL Collector Gateway]
    end
    
    subgraph "Microsoft Fabric"
        direction TB
        RTI[Real-Time Intelligence<br/>Eventhouse]
        KQL[(KQL Database)]
        
        subgraph "OTEL Tables"
            direction LR
            LOGS[OTELLogs]
            METRICS[OTELMetrics] 
            TRACES[OTELTraces]
        end
        
        RTI --> KQL
        KQL --> LOGS
        KQL --> METRICS
        KQL --> TRACES
    end
    
    subgraph "Data Sources"
        APPS[Sample Applications<br/>with OTEL SDK]
        DIAG[Azure Diagnostic<br/>Settings]
    end
    
    subgraph "OTEL Collector Components"
        direction TB
        EHRCV[Azure Event Hub Receiver<br/>azureeventhubreceiver]
        ADXEXP[Azure Data Explorer Exporter<br/>azuredataexplorerexporter]
        OTLPRCV[OTLP Receiver<br/>otlp]
    end
    
    %% Data Flow
    AS -->|Diagnostic Logs| EH
    APPS -->|OTLP gRPC/HTTP| ACI
    EH -->|Event Stream| EHRCV
    DIAG -->|Configure| AS
    EHRCV -.->|Inside ACI| ADXEXP
    OTLPRCV -.->|Inside ACI| ADXEXP
    ACI -->|Contains| EHRCV
    ACI -->|Contains| ADXEXP
    ACI -->|Contains| OTLPRCV
    ADXEXP -->|Processed Telemetry| RTI
    
    %% Styling
    classDef azureService fill:#0078d4,stroke:#ffffff,stroke-width:2px,color:#ffffff
    classDef fabricService fill:#742774,stroke:#ffffff,stroke-width:2px,color:#ffffff
    classDef otelService fill:#f9ab00,stroke:#ffffff,stroke-width:2px,color:#000000
    classDef otelComponent fill:#ff6b35,stroke:#ffffff,stroke-width:2px,color:#ffffff
    classDef dataStore fill:#e1f5fe,stroke:#01579b,stroke-width:2px,color:#000000
    
    class AS,EH azureService
    class RTI,KQL fabricService
    class ACI,APPS otelService
    class EHRCV,ADXEXP,OTLPRCV otelComponent
    class LOGS,METRICS,TRACES dataStore
```


## Summary of Steps

- Deploy Microsoft Fabric for OTEL Observability use
- Deploy Azure Event Hub for Azure Diagnostic exports
- Deploy OTEL contrib distribution as Azure Diagnostic receiver
- Deploy telemetry sample Azure services

The following sections describe Azure Portal deployment and configuration based steps for manual setup and understanding of the solution components.

> **Note:** For Infrastructure as Code (Bicep) deployment, see the [Deployment Guide](./deploy/README.md#-infrastructure-as-code-bicep-deployment)


## Deploy Microsoft Fabric for OTEL Observability

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




## Deploy Azure Event Hub

Azure Event Hub serves as the central ingestion point for diagnostic logs from Azure services in this observability solution. The OTEL Collector will connect to Event Hub to receive and process diagnostic data before forwarding it to Microsoft Fabric.

> **Reference**: Follow the complete tutorial in Microsoft Learn: [Quickstart: Create an event hub using Azure portal](https://learn.microsoft.com/en-us/azure/event-hubs/event-hubs-create)

#### 1. Create Event Hub Namespace

1. In the Azure portal, select **All services** → **Analytics** → **Event Hubs**
2. On the **Event Hubs** page, select **Create**
3. On the **Create namespace** page, configure:
   - **Subscription**: Select your Azure subscription
   - **Resource group**: Select or create a resource group
   - **Namespace name**: Enter a unique name (e.g., `eh-otel-observability-{suffix}`)
   - **Location**: Select your preferred region
   - **Pricing tier**: Select **Standard** (required for diagnostic integration)
   - **Throughput units**: Set to **1** (can auto-scale up to 20)
   - **Enable Auto-Inflate**: ✅ Check this option
   - **Maximum throughput units**: Set to **20**
   - **Zone redundant**: ✅ Enable for high availability
4. Select **Review + Create** → **Create**
5. Wait for deployment completion and select **Go to resource**

#### 2. Create Event Hub

1. On the Event Hub namespace **Overview** page, select **+ Event Hub**
2. Configure the event hub:
   - **Name**: Enter `otel-diagnostics` (or your preferred name)
   - **Partition count**: Set to **4** (balances throughput and cost)
   - **Message retention**: Set to **7 days**
   - **Capture**: Leave disabled (not needed for this scenario)
3. Select **Review + create** → **Create**

#### 3. Configure Authorization Rule

1. In the Event Hub namespace, go to **Settings** → **Shared access policies**
2. Verify that **RootManageSharedAccessKey** exists with **Listen**, **Send**, and **Manage** permissions
3. Copy the **Primary Connection String** for later use in OTEL Collector configuration

#### 4. Verify Consumer Group

1. Navigate to your event hub → **Consumer groups**
2. Confirm that **$Default** consumer group exists (created automatically)
3. This will be used by the OTEL Collector to read events

### Configuration Summary

The Event Hub setup will include:
- **SKU**: Standard tier with auto-inflate enabled
- **Partitions**: 4 partitions for optimal throughput
- **Retention**: 7 days message retention
- **Throughput**: 1-20 throughput units with auto-scaling
- **Zone redundancy**: Enabled for high availability

### Sample Event Hub Record

![alt text](./docs/assets/image006.png)

![alt text](./docs/assets/image007.png)

![alt text](./docs/assets/image008.png)

Sample Event Hub diagnostic record from Azure App Service

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


## Deploy OTEL contrib distribution as Azure Diagnostic receiver

[OpenTelemetry Collector Contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib) distribution will be configured and deployed as a Azure Container Instance as a OTEL Collector Gateway. 
Docker image "otel/opentelemetry-collector-contrib" 

We will use [Azure Event Hub Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/azureeventhubreceiver/README.md) which is part of the "OpenTelemetry Collector Contrib" distribution. 
![alt text](./docs/assets/image010.png)

and [Azure Data Explorer Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/exporter/azuredataexplorerexporter/README.md)

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




## Deploy telemetry sample Azure services

Deploy two Azure App Services and configure Diagnostic settings to send the telemetry to configured Azure Event Hub.

![alt text](./docs/assets/image012.png)

![alt text](./docs/assets/image013.png)


## References
- https://learn.microsoft.com/en-us/azure/data-explorer/open-telemetry-connector?context=%2Ffabric%2Fcontext%2Fcontext-rti&pivots=fabric&tabs=command-line
- https://github.com/open-telemetry/opentelemetry-dotnet/tree/main/docs
