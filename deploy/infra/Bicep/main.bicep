targetScope = 'subscription'

@description('The Azure region for deploying resources')
param location string = 'swedencentral'

@description('Administrator object IDs for Fabric capacity (service principals and/or users)')
param adminObjectIds array

@description('Tags to apply to all resources')
param tags object = {
  environment: 'prod'
  project: 'OTEL Observability'
}

@description('Resource group name for the project')
param resourceGroupName string = 'azuresamples-platformobservabilty-fabric'

// Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

@description('Fabric capacity name')
param fabricCapacityName string = 'fabriccapacityobservability'

@description('Fabric capacity SKU')
param fabricCapacitySku string = 'F2'

@description('Fabric workspace name')
param fabricWorkspaceName string = 'fabric-otel-workspace'

@description('Fabric database name')
param fabricDatabaseName string = 'otelobservabilitydb'

// Deploy Fabric Capacity
module fabricCapacity './modules/fabriccapacity.bicep' = {
  name: 'fabricCapacityDeploy'
  scope: resourceGroup
  params: {
    location: location
    capacityName: fabricCapacityName
    skuName: fabricCapacitySku
    adminObjectIds: adminObjectIds
    tags: tags
  }
}

// Deploy KQL Database for OpenTelemetry
module fabricWorkspace './modules/kqldatabase.bicep' = {
  name: 'fabricWorkspaceDeploy'
  scope: resourceGroup
  params: {
    location: location
    databaseName: fabricDatabaseName
    fabricCapacityId: fabricCapacity.outputs.capacityId
  }
}

// Deploy Event Hub

// Deploy Fabric Workspace (Note: Fabric deployments require ARM template - limited Bicep support)
// This is a placeholder as direct Fabric workspace deployment requires special considerations

@description('Event Hub namespace name')
param eventHubNamespaceName string = 'evhns-otel'

@description('Event Hub name')
param eventHubName string = 'evh-otel-diagnostics'

@description('Event Hub SKU')
param eventHubSku string = 'Standard'

// Deploy Event Hub
module eventHubNamespace './modules/eventhub.bicep' = {
  name: 'eventHubDeploy'
  scope: resourceGroup
  params: {
    location: location
    namespaceName: eventHubNamespaceName
    eventHubName: eventHubName
    skuName: eventHubSku
    tags: tags
  }
}

@description('Container instance parameters')
param containerGroupName string = 'ci-otel-collector'
param containerName string = 'otel-collector'
param containerImage string = 'otel/opentelemetry-collector-contrib:latest'

// Deploy Container Instance for OTEL Collector
module containerInstance './modules/containerinstance.bicep' = {
  name: 'otelCollectorDeploy'
  scope: resourceGroup
  params: {
    location: location
    containerGroupName: containerGroupName
    containerName: containerName
    containerImage: containerImage
    configYamlContent: loadTextContent('./config/otel-config.yaml')
    tags: tags
  }
  dependsOn: [
    eventHubNamespace
  ]
}

@description('App Service parameters')
param appServicePlanName string = 'asp-otel-sample'
param appServiceName string = 'app-otel-sample'

// Deploy App Service for sample telemetry
module appService './modules/appservice.bicep' = {
  name: 'appServiceDeploy'
  scope: resourceGroup
  params: {
    location: location
    appServicePlanName: appServicePlanName
    appServiceName: appServiceName
    sku: {
      name: 'B1'
      tier: 'Basic'
    }
    diagnosticEventHubName: eventHubNamespace.outputs.eventHubName
    diagnosticEventHubAuthorizationRuleId: eventHubNamespace.outputs.authorizationRuleId
    tags: tags
  }
}

// Outputs
output resourceGroupName string = resourceGroup.name
output fabricCapacityName string = fabricCapacity.outputs.capacityName
output fabricWorkspaceName string = fabricWorkspaceName
output fabricDatabaseName string = fabricDatabaseName
output eventHubNamespaceName string = eventHubNamespace.outputs.namespaceName
output eventHubName string = eventHubNamespace.outputs.eventHubName
output containerGroupName string = containerInstance.outputs.containerGroupName
output appServiceName string = appService.outputs.appServiceName
