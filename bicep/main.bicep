param location string = 'australiaeast'
param environment string = 'test'
@secure()
param postgresAdminPassword string = 'DriftTest@TestAdmin123!'

// Deploy Storage Account
module storageModule 'storage.bicep' = {
  name: 'deploy-storage'
  params: {
    location: location
    environment: environment
  }
}

// Deploy App Service
module appServiceModule 'appservice.bicep' = {
  name: 'deploy-appservice'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Key Vault
module keyVaultModule 'keyvault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Logic App
module logicAppModule 'logicapp.bicep' = {
  name: 'deploy-logicapp'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Log Analytics Workspace
module logAnalyticsModule 'loganalytics.bicep' = {
  name: 'deploy-loganalytics'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Event Hub Namespace
module eventHubModule 'eventhub.bicep' = {
  name: 'deploy-eventhub'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Cosmos DB
module cosmosDbModule 'cosmosdb.bicep' = {
  name: 'deploy-cosmosdb'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Azure Container Registry
module acrModule 'acr.bicep' = {
  name: 'deploy-acr'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Azure Container Instance
module aciModule 'aci.bicep' = {
  name: 'deploy-aci'
  params: {
    location: location
    environment: environment
  }
}

// Deploy PostgreSQL Server (Temporarily disabled - @2017-12-01 API version is deprecated)
// TODO: Migrate to PostgreSQL Flexible Server (@2023-06-01 or later)
/*
module postgresModule 'postgres.bicep' = {
  name: 'deploy-postgres'
  params: {
    location: location
    environment: environment
    adminPassword: postgresAdminPassword
  }
}
*/
output storageAccountId string = storageModule.outputs.storageAccountId
output appServiceId string = appServiceModule.outputs.appServiceId
output keyVaultId string = keyVaultModule.outputs.keyVaultId
output logicAppId string = logicAppModule.outputs.workflowId
output logAnalyticsId string = logAnalyticsModule.outputs.workspaceId
output eventHubNamespaceId string = eventHubModule.outputs.namespaceId
output cosmosDbAccountName string = cosmosDbModule.outputs.accountName
output acrId string = acrModule.outputs.acrId
output aciId string = aciModule.outputs.aciId
// output postgresServerName string = postgresModule.outputs.serverName  // Disabled - PostgreSQL module commented out
