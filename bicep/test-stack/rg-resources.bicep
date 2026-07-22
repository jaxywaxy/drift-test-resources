targetScope = 'resourceGroup'

@description('Location for resources')
param location string

@description('SQL admin login')
param adminLogin string

@description('SQL admin password')
@secure()
param adminPassword string

@description('Suffix to make names unique')
param suffix string

@description('Whether to deploy the App Service and plan')
param deployWebApp bool = true

@description('App Service plan SKU name')
param appServiceSkuName string = 'F1'

@description('App Service plan SKU tier')
param appServiceSkuTier string = 'Free'

var storageName = toLower('drifttestsa${suffix}')
var kvName = toLower('drifttestkv${suffix}')
var vnetName = 'drifttest-vnet'
var subnetName = 'default'
var sqlServerName = toLower('drifttestsql${suffix}')
var sqlDbName = 'drifttestdb'
var appServicePlanName = 'driftAppPlan${suffix}'
var webAppName = toLower('drifttestweb${suffix}')

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.1.0.0/16' ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.1.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: kvName
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enablePurgeProtection: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pe-${kvName}'
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, subnetName)
    }
    privateLinkServiceConnections: [
      {
        name: 'kvConnection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [ 'vault' ]
        }
      }
    ]
  }
}

// A logical SQL server carries no compute SKU - that lives on the database or
// elastic pool. Azure returns sku: null on the server, so declaring one here
// only produced permanent (cosmetic) drift.
resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    version: '12.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  parent: sqlServer
  name: sqlDbName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {}
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = if (deployWebApp) {
  name: appServicePlanName
  location: location
  sku: {
    name: appServiceSkuName
    tier: appServiceSkuTier
  }
  properties: {
    reserved: false
  }
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = if (deployWebApp) {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

output storageAccountName string = storageAccount.name
output keyVaultName string = keyVault.name
output sqlServerName string = sqlServer.name
output webAppName string = (deployWebApp ? webApp.name : '')
