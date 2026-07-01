targetScope = 'subscription'

param location string = 'australiaeast'
param environment string = 'test'
param resourceGroupName string = 'rg-drift-test'
@secure()
param postgresAdminPassword string = 'DriftTest@${uniqueString(resourceGroup().id)}'

// Create resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

// Deploy Storage Account
module storageModule 'storage.bicep' = {
  scope: resourceGroup
  name: 'deploy-storage'
  params: {
    location: location
    environment: environment
  }
}

// Deploy App Service
module appServiceModule 'appservice.bicep' = {
  scope: resourceGroup
  name: 'deploy-appservice'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Key Vault
module keyVaultModule 'keyvault.bicep' = {
  scope: resourceGroup
  name: 'deploy-keyvault'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Logic App
module logicAppModule 'logicapp.bicep' = {
  scope: resourceGroup
  name: 'deploy-logicapp'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Log Analytics Workspace
module logAnalyticsModule 'loganalytics.bicep' = {
  scope: resourceGroup
  name: 'deploy-loganalytics'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Event Hub Namespace
module eventHubModule 'eventhub.bicep' = {
  scope: resourceGroup
  name: 'deploy-eventhub'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Cosmos DB
module cosmosDbModule 'cosmosdb.bicep' = {
  scope: resourceGroup
  name: 'deploy-cosmosdb'
  params: {
    location: location
    environment: environment
  }
}

// Deploy PostgreSQL Server
module postgresModule 'postgres.bicep' = {
  scope: resourceGroup
  name: 'deploy-postgres'
  params: {
    location: location
    environment: environment
    adminPassword: postgresAdminPassword
  }
}

output resourceGroupId string = resourceGroup.id
output resourceGroupName string = resourceGroup.name
output storageAccountId string = storageModule.outputs.storageAccountId
output appServiceId string = appServiceModule.outputs.appServiceId
output keyVaultId string = keyVaultModule.outputs.keyVaultId
output logicAppId string = logicAppModule.outputs.workflowId
output logAnalyticsId string = logAnalyticsModule.outputs.workspaceId
output eventHubNamespaceId string = eventHubModule.outputs.namespaceId
output cosmosDbAccountName string = cosmosDbModule.outputs.accountName
output postgresServerName string = postgresModule.outputs.serverName
