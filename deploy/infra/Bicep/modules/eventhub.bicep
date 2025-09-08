@description('The Azure region for deploying resources')
param location string

@description('The name of the Event Hub namespace')
param namespaceName string

@description('The name of the Event Hub')
param eventHubName string

@description('The SKU of the Event Hub namespace')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

@description('Tags to apply to all resources')
param tags object = {}

// Event Hub Namespace
resource namespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 20
    zoneRedundant: true
  }
}

// Event Hub
resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' = {
  parent: namespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: 4
  }
}

// Consumer Group
resource consumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2022-10-01-preview' = {
  parent: eventHub
  name: '$Default'
  properties: {}
}

// Authorization Rule
resource authRule 'Microsoft.EventHub/namespaces/authorizationRules@2022-10-01-preview' = {
  parent: namespace
  name: 'RootManageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Send'
      'Manage'
    ]
  }
}

// Outputs
output namespaceName string = namespace.name
output eventHubName string = eventHub.name
output authorizationRuleId string = authRule.id
output namespaceConnectionString string = listKeys(authRule.id, authRule.apiVersion).primaryConnectionString
