@description('The name of the Fabric Capacity resource')
param capacityName string

@description('The Azure region for deploying resources')
param location string

@description('SKU name for the Fabric capacity')
@allowed([
  'F2'
  'F4'
  'F8'
  'F16'
  'F32'
  'F64'
  'F128'
  'F256'
  'F512'
  'F1024'
  'F2048'
])
param skuName string = 'F2'

@description('Administrator AAD object ID')
param adminObjectId string

@description('Tags to apply to all resources')
param tags object = {}

// Fabric Capacity
resource fabricCapacity 'Microsoft.Fabric/capacities@2022-07-01-preview' = {
  name: capacityName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    administration: {
      members: [
        adminObjectId
      ]
    }
  }
}

// Outputs
output capacityName string = fabricCapacity.name
output capacityId string = fabricCapacity.id
