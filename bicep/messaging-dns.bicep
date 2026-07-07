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

// --- Data-plane / child resources (ARM-REST-expanded by the drift agent) ---

resource driftQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBus
  name: 'drift-queue'
  properties: {
    maxDeliveryCount: 10
    lockDuration: 'PT1M'
  }
}

// NOTE: no topics - Basic tier supports queues only (Standard costs ~$10/mo
// for no additional drift-test value; queues exercise the same child pattern).

resource wwwRecord 'Microsoft.Network/dnszones/A@2023-07-01-preview' = {
  parent: dnsZone
  name: 'www'
  properties: {
    TTL: 300
    ARecords: [
      { ipv4Address: '203.0.113.10' }
    ]
  }
}

// Private DNS zone + vnet link + record: stale hand-added records are the
// hardest-to-debug outages, and DINE policies often create links.
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-drift-test'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.99.0.0/24'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.99.0.0/26'
        }
      }
    ]
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

resource privateZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'drifttest.internal'
  location: 'global'
  tags: {
    environment: environment
    managed: 'true'
  }
}

resource privateZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateZone
  name: 'link-vnet-drift-test'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource dbRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateZone
  name: 'db'
  properties: {
    ttl: 300
    aRecords: [
      { ipv4Address: '10.99.0.10' }
    ]
  }
}

output serviceBusId string = serviceBus.id
output trafficManagerId string = trafficManager.id
output dnsZoneId string = dnsZone.id
