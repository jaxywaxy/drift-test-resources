param location string = 'australiaeast'
param environment string = 'test'

var sbNamespaceName = 'sbdrift${uniqueString(resourceGroup().id)}'
var tmProfileName = 'tmdrift${uniqueString(resourceGroup().id)}'

// Group-1 generic-pipeline resources: namespace/profile/zone level only.
// Children (queues, endpoints, record sets) are NOT indexed by Resource Graph
// and are deliberately not declared until child expansion exists for them -
// declaring them now would produce false missing_in_azure drift.

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: sbNamespaceName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

resource trafficManager 'Microsoft.Network/trafficmanagerprofiles@2022-04-01' = {
  name: tmProfileName
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Priority'
    dnsConfig: {
      relativeName: tmProfileName
      ttl: 60
    }
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/'
    }
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

resource dnsZone 'Microsoft.Network/dnszones@2023-07-01-preview' = {
  name: 'drifttest.example.com'
  location: 'global'
  properties: {
    zoneType: 'Public'
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

output serviceBusId string = serviceBus.id
output trafficManagerId string = trafficManager.id
output dnsZoneId string = dnsZone.id
