@description('The Azure region for deploying resources')
param location string = resourceGroup().location

@description('Key Vault name (must be globally unique)')
param keyVaultName string

@description('Service principal object ID for GitHub Actions access')
param githubServicePrincipalObjectId string

@description('Application service principal object ID for storing app secrets')
param appServicePrincipalObjectId string

@description('Administrator object ID for Fabric capacity')
param adminObjectId string

@description('Azure tenant ID')
param tenantId string

@description('Azure subscription ID')
param subscriptionId string

@description('Application service principal client ID')
param appClientId string

@description('Application service principal client secret')
@secure()
param appClientSecret string

@description('Tags to apply to resources')
param tags object = {}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 90
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: githubServicePrincipalObjectId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
      {
        tenantId: tenantId
        objectId: appServicePrincipalObjectId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
        }
      }
    ]
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Store application secrets in Key Vault
resource secretAzureClientId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE-CLIENT-ID'
  properties: {
    value: appClientId
    contentType: 'text/plain'
  }
}

resource secretAzureClientSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE-CLIENT-SECRET'
  properties: {
    value: appClientSecret
    contentType: 'text/plain'
  }
}

resource secretAzureTenantId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE-TENANT-ID'
  properties: {
    value: tenantId
    contentType: 'text/plain'
  }
}

resource secretAzureSubscriptionId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'AZURE-SUBSCRIPTION-ID'
  properties: {
    value: subscriptionId
    contentType: 'text/plain'
  }
}

resource secretAdminObjectId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'ADMIN-OBJECT-ID'
  properties: {
    value: adminObjectId
    contentType: 'text/plain'
  }
}

// Optional: Store fabric configuration secrets
resource secretResourceGroupName 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'fabric-resource-group'
  properties: {
    value: resourceGroup().name
    contentType: 'text/plain'
  }
}

resource secretFabricWorkspaceName 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'fabric-workspace-name'
  properties: {
    value: 'fabric-otel-workspace'
    contentType: 'text/plain'
  }
}

resource secretFabricDatabaseName 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'fabric-database-name'
  properties: {
    value: 'otelobservabilitydb'
    contentType: 'text/plain'
  }
}

// Outputs
output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output githubSecretsRequired object = {
  AZURE_CLIENT_ID: 'GitHub Actions service principal client ID'
  AZURE_TENANT_ID: tenantId
  AZURE_SUBSCRIPTION_ID: subscriptionId
}
