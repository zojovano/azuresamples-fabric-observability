@description('The name of the KQL database')
param databaseName string

@description('The resource ID of the Fabric capacity')
param fabricCapacityId string

@description('The Azure region for deploying resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

// Fabric Workspace (requires separate deployment in Fabric portal)
// This is a workaround as direct Fabric workspace deployment is limited in Bicep
resource fabricWorkspace 'Microsoft.Fabric/workspaces@2022-07-01-preview' = {
  name: 'fabric-otel-workspace'
  location: location
  properties: {
    description: 'Microsoft Fabric workspace for OTEL Observability'
    capacityId: fabricCapacityId
  }
  tags: tags
}

// Define OTEL KQL Database parameters for manual creation
var kqlDatabaseParameters = {
  name: databaseName
  location: location
  description: 'KQL Database for OpenTelemetry data'
  tables: [
    {
      name: 'OTELLogs'
      schema: 'Timestamp:datetime, ObservedTimestamp:datetime, TraceID:string, SpanID:string, SeverityText:string, SeverityNumber:int, Body:string, ResourceAttributes:dynamic, LogsAttributes:dynamic'
    }
    {
      name: 'OTELMetrics'
      schema: 'Timestamp:datetime, MetricName:string, MetricType:string, MetricUnit:string, MetricDescription:string, MetricValue:real, Host:string, ResourceAttributes:dynamic, MetricAttributes:dynamic'
    }
    {
      name: 'OTELTraces'
      schema: 'TraceID:string, SpanID:string, ParentID:string, SpanName:string, SpanStatus:string, SpanKind:string, StartTime:datetime, EndTime:datetime, ResourceAttributes:dynamic, TraceAttributes:dynamic, Events:dynamic, Links:dynamic'
    }
  ]
}

// Output KQL Database parameters for manual configuration
output fabricWorkspaceName string = fabricWorkspace.name
output fabricWorkspaceId string = fabricWorkspace.id
output kqlDatabaseInfo object = kqlDatabaseParameters
