param location string = 'australiaeast'
param environment string = 'test'
@secure()
param postgresAdminPassword string = 'DriftTest@TestAdmin123!'
@secure()
param sqlAdminPassword string = 'DriftTest@SqlAdmin123!'

// Load balancer + Application Gateway (WAF_v2 ~$180/mo) are OFF by default;
// set true to deploy them for network-appliance drift testing.
param deployNetworkAppliances bool = false

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
    workspaceId: logAnalyticsModule.outputs.workspaceId
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

// Deploy AI Services account + model deployment (AI resource drift testing)
module aiModule 'ai.bicep' = {
  name: 'deploy-ai'
  params: {
    location: location
    environment: environment
  }
}

// SQL Server + Basic DB (TDE policy testing + future firewall-rule children)
module sqlModule 'sql.bicep' = {
  name: 'deploy-sql'
  params: {
    location: location
    environment: environment
    sqlAdminPassword: sqlAdminPassword
  }
}

// Group-1 generic-pipeline resources: action group + metric alert
module monitoringModule 'monitoring.bicep' = {
  name: 'deploy-monitoring'
  params: {
    location: location
    environment: environment
    storageAccountId: storageModule.outputs.storageAccountId
    workspaceId: logAnalyticsModule.outputs.workspaceId
  }
}

// Group-1 generic-pipeline resources: Service Bus, Traffic Manager, DNS zone
module messagingDnsModule 'messaging-dns.bicep' = {
  name: 'deploy-messaging-dns'
  params: {
    location: location
    environment: environment
  }
}

// User-assigned identity + federated credential (child-expansion coverage)
module identityModule 'identity.bicep' = {
  name: 'deploy-identity'
  params: {
    location: location
    environment: environment
  }
}

// Container Apps (Consumption env + app - modern serverless containers)
module containerAppModule 'containerapp.bicep' = {
  name: 'deploy-containerapp'
  params: {
    location: location
    environment: environment
  }
}

// Standard Load Balancer (embedded named-collection drift: rules/probes/pools)
module lbModule 'lb.bicep' = if (deployNetworkAppliances) {
  name: 'deploy-lb'
  params: {
    location: location
    environment: environment
  }
}

// Application Gateway WAF_v2 + WAF policy (expensive - gated by the flag)
module appgwModule 'appgw.bicep' = if (deployNetworkAppliances) {
  name: 'deploy-appgw'
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
