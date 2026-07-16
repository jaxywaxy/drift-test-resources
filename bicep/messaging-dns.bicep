param location string = 'australiaeast'
param environment string = 'test'

var sbNamespaceName = 'sbdrift${uniqueString(resourceGroup().id)}'
var tmProfileName = 'tmdrift${uniqueString(resourceGroup().id)}'

// Group-1 generic-pipeline resources: namespace/profile/zone level only.
// Children (queues, endpoints, record sets) are NOT indexed by Resource Graph
// and are deliberately not declared until child expansion exists for them -
// declaring them now would produce false missing_in_azure drift.

// Standard tier (was Basic): topics require Standard. Basic supports queues
// only. ~$10/mo. The namespace's own security surface (minimumTlsVersion,
// publicNetworkAccess, disableLocalAuth) is unchanged.
resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: sbNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
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

// Service Bus topic (Standard-tier only). Expanded by the agent (namespaces ->
// topics), so declaring it is safe. Property drift surface: requiresDuplicate-
// Detection, defaultMessageTimeToLive, maxSizeInMegabytes, status, enable-
// BatchedOperations. NOTE: topic SUBSCRIPTIONS/rules are deliberately NOT
// declared yet - they are grandchildren under a dynamically-named topic and the
// agent has no expansion spec for them, so declaring one would false-flag
// missing_in_azure (see the header comment). Add them once the agent gains
// namespaces/topics/subscriptions expansion (mirrors EG subs, PR #207).
resource driftTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBus
  name: 'drift-topic'
  properties: {
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    enableBatchedOperations: true
    status: 'Active'
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

// NSG with explicit baseline rules: an out-of-band allow-any inbound rule is
// the classic real-world unauthorized change. Rules are declared inline so
// rule add/modify/delete all surface as property drift on securityRules.
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-drift-test'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-https-from-vnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'deny-ssh-from-internet'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Route table forcing egress through a (notional) firewall appliance: changing
// the next hop out-of-band silently bypasses inspection - the classic network
// security drift alongside NSG rule tampering.
resource routeTable 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-drift-test'
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default-via-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.99.0.62'
        }
      }
    ]
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
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
          networkSecurityGroup: {
            id: nsg.id
          }
          routeTable: {
            id: routeTable.id
          }
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
