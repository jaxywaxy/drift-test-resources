param location string = 'australiaeast'
param environment string = 'test'

@description('Existing storage account name used for AzureWebJobsStorage.')
param storageAccountName string

// Function App on a Y1 Dynamic (consumption) plan: no executions => effectively
// $0, so the estate gets the Function App drift surface for free. Distinct from
// the App Service in appservice.bicep - functions carry their OWN transport /
// exposure controls (httpsOnly, siteConfig.minTlsVersion, ftpsState,
// publicNetworkAccess) which are the drift-interesting surface here.
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource funcPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'asp-func-drift-test'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'func-drift-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: funcPlan.id
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'FtpsOnly'
      http20Enabled: true
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// App settings live in a SEPARATE config child (matching appservice.bicep):
// the drift agent reduces Microsoft.Web/sites/config appsettings to KEY SETS,
// so the storage key never reaches a drift report.
resource funcAppSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: functionApp
  name: 'appsettings'
  properties: {
    AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
    FUNCTIONS_EXTENSION_VERSION: '~4'
    FUNCTIONS_WORKER_RUNTIME: 'node'
  }
}

output functionAppId string = functionApp.id
output functionAppName string = functionApp.name
