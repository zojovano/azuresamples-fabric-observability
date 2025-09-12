@description('The name of the KQL database')
param databaseName string

@description('The resource ID of the Fabric capacity')
param fabricCapacityId string

@description('The Azure region for deploying resources')
param location string

// Note: Microsoft Fabric workspaces cannot be created directly through ARM/Bicep templates
// They must be created through the Fabric portal or REST APIs
// This module provides the configuration information needed for manual setup

// Define OTEL KQL Database parameters for manual creation
var kqlDatabaseParameters = {
  name: databaseName
  location: location
  description: 'KQL Database for OpenTelemetry data'
  capacityId: fabricCapacityId
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
  instructions: 'After deployment, manually create a Fabric workspace and KQL database using the provided parameters. Use the KQL scripts in deploy/fabric-artifacts/tables to create the required tables via Git integration.'
}

// Output KQL Database parameters for manual configuration
output fabricCapacityId string = fabricCapacityId
output kqlDatabaseInfo object = kqlDatabaseParameters
output fabricWorkspaceName string = 'fabric-otel-workspace'
output fabricWorkspaceInstructions string = 'Create workspace manually in Fabric portal using the provided capacity'
