targetScope = 'resourceGroup'

@description('Location for the resource group and child resources')
param location string = 'australiaeast'

@description('Administrator login for the SQL server')
param adminLogin string = 'sqladminuser'

@description('Administrator password for the SQL server (secure)')
@secure()
param adminPassword string

var suffix = uniqueString(resourceGroup().id)

@description('Whether to deploy the App Service and plan')
param deployWebApp bool = true

@description('App Service plan SKU name')
param appServiceSkuName string = 'F1'

@description('App Service plan SKU tier')
param appServiceSkuTier string = 'Free'

module rgResources 'rg-resources.bicep' = {
  name: 'deployRgResources'
  params: {
    location: location
    adminLogin: adminLogin
    adminPassword: adminPassword
    suffix: suffix
    deployWebApp: deployWebApp
    appServiceSkuName: appServiceSkuName
    appServiceSkuTier: appServiceSkuTier
  }
}

@description('Whether to deploy the monitoring/alerting stack')
param deployMonitoring bool = true

// Second module in the estate - deliberately a SEPARATE nested deployment so the
// drift engine's module extraction is exercised across more than one module,
// as in a real landing zone.
module monitoring 'monitoring.bicep' = if (deployMonitoring) {
  name: 'deployMonitoring'
  params: {
    location: location
    suffix: suffix
  }
}

output storageAccountName string = rgResources.outputs.storageAccountName
output keyVaultName string = rgResources.outputs.keyVaultName
output sqlServerName string = rgResources.outputs.sqlServerName
output webAppName string = rgResources.outputs.webAppName
