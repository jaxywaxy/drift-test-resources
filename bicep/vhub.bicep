param location string = 'australiaeast'
param environment string = 'test'

// Standalone-deployable: this module references no estate resources, so it can
// be deployed on its own -
//   az deployment group create -g <rg> \
//     --template-file bicep/vhub.bicep --parameters deployVirtualHub=true
// or via main.bicep (wired in, gated off by default).

@description('Deploy a Standard Virtual WAN hub for hub-routing drift testing (Tier 1: hubRouteTables, no firewall). ~$0.25/hr for the hub + minor routing-unit charges; ~30 min to deploy and ~30 min to delete. OFF by default: unlike a firewall POLICY (free while unattached), a vWAN hub bills the moment it exists - there is no free standalone form. Turn on for a test session, then tear the hub down.')
param deployVirtualHub bool = false

@description('Virtual Hub address prefix. /23 or larger recommended; must not overlap the estate.')
param hubAddressPrefix string = '10.200.0.0/23'

@description('Throwaway spoke VNet address space - gives the custom route table a real connection to use as a route nextHop.')
param spokeAddressPrefix string = '10.201.0.0/24'

var tags = {
  environment: environment
  managed: 'true'
  purpose: 'drift-detection-test'
}

// Standard Virtual WAN. Basic vWAN has NO custom routing (no hubRouteTables, no
// routingIntent), so Standard is mandatory for any routing-drift test.
resource vwan 'Microsoft.Network/virtualWans@2023-09-01' = if (deployVirtualHub) {
  name: 'vwan-drift-test'
  location: location
  properties: {
    type: 'Standard'
    allowBranchToBranchTraffic: true
  }
  tags: tags
}

// The hub itself - the billed resource. Its routing lives in children that
// Resource Graph does not index (hubRouteTables here; routingIntent in Tier 2),
// which the agent fetches via ARM REST child expansion.
resource hub 'Microsoft.Network/virtualHubs@2023-09-01' = if (deployVirtualHub) {
  name: 'vhub-drift-test'
  location: location
  properties: {
    virtualWan: {
      id: vwan.id
    }
    addressPrefix: hubAddressPrefix
    sku: 'Standard'
  }
  tags: tags
}

// Throwaway spoke VNet (free) - exists purely so the custom route table below
// has a real hubVirtualNetworkConnection to point a route's nextHop at. A hub
// route table route's nextHop must be a ResourceId (a connection), not a bare
// IP, so an empty-nextHop route table would be a much thinner drift surface.
resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = if (deployVirtualHub) {
  name: 'vnet-vhub-spoke-drift-test'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [spokeAddressPrefix]
    }
    subnets: [
      {
        name: 'workload'
        properties: {
          addressPrefix: spokeAddressPrefix
        }
      }
    ]
  }
  tags: tags
}

// Connect the spoke to the hub. Left on the default route table (no explicit
// routingConfiguration) on purpose - associating it to the custom route table
// below would create a circular dependency. This connection is only here to be
// a valid nextHop target for the route.
resource hubConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-09-01' = if (deployVirtualHub) {
  parent: hub
  name: 'conn-spoke-drift-test'
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnet.id
    }
  }
}

// The Tier-1 drift target: a custom hub route table with one real route.
//
// Drift scenarios this surfaces (inject out-of-band, confirm, revert):
//   - route's nextHop repointed off this connection  -> critical (properties.routes)
//   - route's destinations narrowed/widened          -> critical
//   - a second route added out of band               -> critical (extra route)
//   - the route table deleted                         -> missing_in_azure
//   - a second route table added out of band          -> extra_in_azure
//   - labels changed                                  -> warning
// Ownership must resolve to PLATFORM (Microsoft.Network/virtualHubs/hubRouteTables).
resource routeTable 'Microsoft.Network/virtualHubs/hubRouteTables@2023-09-01' = if (deployVirtualHub) {
  parent: hub
  name: 'rt-drift-test'
  properties: {
    labels: ['drift-test']
    routes: [
      {
        name: 'to-spoke'
        destinationType: 'CIDR'
        destinations: [spokeAddressPrefix]
        nextHopType: 'ResourceId'
        nextHop: hubConnection.id // implicit dependency: connection created first
      }
    ]
  }
}

output virtualHubId string = deployVirtualHub ? hub.id : ''
output routeTableName string = deployVirtualHub ? 'vhub-drift-test/rt-drift-test' : ''
