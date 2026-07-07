param location string = 'australiaeast'
param environment string = 'test'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'asp-${environment}-drift'
  location: location
  sku: {
    name: 'F1'
    tier: 'Free'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: 'app-${environment}-drift'
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|7.0'
      alwaysOn: false
      minTlsVersion: '1.2'
      http20Enabled: true
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output appServiceId string = appService.id
output appServiceName string = appService.name
output appServicePlanId string = appServicePlan.id

// App settings child (agent compares KEY SETS only - values never leave Azure)
resource appSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: appService
  name: 'appsettings'
  properties: {
    DRIFT_TEST: 'true'
    APP_ENVIRONMENT: environment
  }
}
