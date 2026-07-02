param location string = 'australiaeast'
param environment string = 'test'

// Azure Container Registry (Basic SKU - PAYG, flat resource, drift-friendly)
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acr${environment}drift${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output acrId string = acr.id
output acrName string = acr.name
