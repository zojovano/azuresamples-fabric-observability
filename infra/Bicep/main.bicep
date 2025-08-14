targetScope = 'subscription'

@description('The Azure region for deploying resources')
param location string = 'swedencentral'

@description('Administrator object ID for Fabric capacity (service principal or user)')
param adminObjectId string

@description('Tags to apply to all resources')
param tags object = {
  environment: 'prod'
  project: 'OTEL Observability'
}

// Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'azuresamples-platformobservabilty-fabric'
  location: location
  tags: tags
}

// Deploy Fabric Capacity
module fabricCapacity './modules/fabriccapacity.bicep' = {
  name: 'fabricCapacityDeploy'
  scope: resourceGroup
  params: {
    location: location
    capacityName: 'fabriccapacityobservability'
    skuName: 'F2'
    adminObjectId: adminObjectId
    tags: tags
  }
}

// Deploy KQL Database for OpenTelemetry
module fabricWorkspace './modules/kqldatabase.bicep' = {
  name: 'fabricWorkspaceDeploy'
  scope: resourceGroup
  params: {
    location: location
    databaseName: 'otelobservabilitydb'
    fabricCapacityId: fabricCapacity.outputs.capacityId
  }
}

// Deploy Event Hub

// Deploy Fabric Workspace (Note: Fabric deployments require ARM template - limited Bicep support)
// This is a placeholder as direct Fabric workspace deployment requires special considerations

// Deploy Event Hub
module eventHubNamespace './modules/eventhub.bicep' = {
  name: 'eventHubDeploy'
  scope: resourceGroup
  params: {
    location: location
    namespaceName: 'evhns-otel'
    eventHubName: 'evh-otel-diagnostics'
    skuName: 'Standard'
    tags: tags
  }
}

// Deploy Container Instance for OTEL Collector
module containerInstance './modules/containerinstance.bicep' = {
  name: 'otelCollectorDeploy'
  scope: resourceGroup
  params: {
    location: location
    containerGroupName: 'ci-otel-collector'
    containerName: 'otel-collector'
    containerImage: 'otel/opentelemetry-collector-contrib:latest'
    configYamlContent: loadTextContent('./config/otel-config.yaml')
    tags: tags
  }
  dependsOn: [
    eventHubNamespace
  ]
}

// Deploy App Service for sample telemetry
module appService './modules/appservice.bicep' = {
  name: 'appServiceDeploy'
  scope: resourceGroup
  params: {
    location: location
    appServicePlanName: 'asp-otel-sample'
    appServiceName: 'app-otel-sample'
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
output fabricWorkspaceName string = fabricWorkspace.outputs.fabricWorkspaceName
output eventHubNamespaceName string = eventHubNamespace.outputs.namespaceName
output eventHubName string = eventHubNamespace.outputs.eventHubName
output containerGroupName string = containerInstance.outputs.containerGroupName
output appServiceName string = appService.outputs.appServiceName
