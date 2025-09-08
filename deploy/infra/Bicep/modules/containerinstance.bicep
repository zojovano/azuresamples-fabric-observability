@description('The Azure region for deploying resources')
param location string

@description('The name of the Container Group')
param containerGroupName string

@description('The name of the container')
param containerName string

@description('The container image to deploy')
param containerImage string

@description('The OTEL config.yaml content')
param configYamlContent string

@description('CPU cores for the container')
param cpuCores int = 1

@description('Memory in GB for the container')
param memoryInGb int = 2

@description('Tags to apply to all resources')
param tags object = {}

// Container Group
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  tags: tags
  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: 4317 // OTLP gRPC port
          protocol: 'TCP'
        }
        {
          port: 4318 // OTLP HTTP port
          protocol: 'TCP'
        }
      ]
      dnsNameLabel: toLower(containerGroupName)
    }
    containers: [
      {
        name: containerName
        properties: {
          image: containerImage
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          ports: [
            {
              port: 4317
              protocol: 'TCP'
            }
            {
              port: 4318
              protocol: 'TCP'
            }
          ]
          environmentVariables: []
          volumeMounts: [
            {
              name: 'otel-config-volume'
              mountPath: '/etc/otelcol-contrib'
              readOnly: true
            }
          ]
        }
      }
    ]
    volumes: [
      {
        name: 'otel-config-volume'
        secret: {
          'config.yaml': base64(configYamlContent)
        }
      }
    ]
  }
}

// Outputs
output containerGroupName string = containerGroup.name
output containerGroupFqdn string = containerGroup.properties.ipAddress.fqdn
