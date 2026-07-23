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

@description('Tier 2: deploy an Azure Firewall INTO the hub (Secured Hub) + routing intent that forces Internet/Private traffic through it - the real firewall-bypass drift target. REQUIRES deployVirtualHub=true (set BOTH). Firewall bills separately: Basic ~$0.40/hr, Standard ~$1.25/hr, plus ~30 min extra deploy/delete. OFF by default.')
param deployHubFirewall bool = false

@description('Tier of the in-hub Azure Firewall (and its policy). Basic is cheapest and matches the Tier-2 cost story; see the WARNING above the firewall resource for two deploy-time risks and why Standard is the safe fallback.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param hubFirewallTier string = 'Basic'

var tags = {
  environment: environment
  managed: 'true'
  purpose: 'drift-detection-test'
}

// Tier-2 resources gate directly on deployHubFirewall (a simple, resolvable
// param condition) rather than a compound `deployVirtualHub && deployHubFirewall`
// variable: the drift agent resolves `if(param)` conditions but not `and()` in a
// variable, so the compound form made the gated-off firewall/routing-intent
// false-flag as missing_in_azure during a Tier-1 scan. deployHubFirewall implies
// deployVirtualHub=true (the firewall references hub.id); setting it alone fails
// the deploy on that reference, which is the intended clear error.

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
//
// MUTUALLY EXCLUSIVE WITH ROUTING INTENT: Azure rejects routingIntent on a hub
// that has any custom route table (CantConfigureRoutingIntentIfCustomRouteTables
// Present). So this deploys in Tier-1 mode only - when the firewall/routingIntent
// (Tier 2) is off. A hub is either custom-route-table mode or routing-intent
// mode, never both. (The drift agent resolves if(param) but not this compound
// condition until the and()/not() resolver fix lands - a Tier-2 scan may show
// this route table as phantom-missing until then.)
resource routeTable 'Microsoft.Network/virtualHubs/hubRouteTables@2023-09-01' = if (deployVirtualHub && !deployHubFirewall) {
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

// --- Tier 2: Secured Hub (Azure Firewall in the hub) + routing intent --------
//
// The real firewall-bypass drift surface. Routing intent forces Internet and
// Private traffic through the hub firewall; the critical drift the engine now
// catches (properties.routingpolicies) is a routingPolicy nextHop repointed off
// the firewall, or a policy removed, so spoke traffic silently skips inspection.
//
// Drift scenarios (inject out-of-band, confirm, revert):
//   - a routingPolicy nextHop repointed off the firewall  -> critical
//   - a routingPolicy's destinations narrowed              -> critical
//   - the whole routingIntent deleted                      -> missing_in_azure
// Ownership must resolve to PLATFORM (Microsoft.Network/virtualHubs/routingIntent).
//
// !!! DEPLOY-TIME WARNING - not yet live-verified !!!
// Two things to confirm on first deploy, both pushing toward Standard if Basic
// is rejected (cost delta over a short torn-down session is only ~$0.85/hr):
//   1. Basic-tier Azure Firewall has stricter IP requirements than Standard; a
//      Secured-Hub Basic firewall may demand a management IP the hub model does
//      not auto-provide here. If the deploy rejects it, set hubFirewallTier=Standard.
//   2. Routing intent's supported firewall tiers: confirm Basic is accepted as a
//      routingPolicy nextHop. If not, Standard/Premium is the fallback.

// Firewall policy for the hub firewall. Tier must match the firewall tier.
resource hubFwPolicy 'Microsoft.Network/firewallPolicies@2023-09-01' = if (deployHubFirewall) {
  name: 'fwpol-vhub-drift-test'
  location: location
  properties: {
    sku: {
      tier: hubFirewallTier
    }
  }
  tags: tags
}

// Azure Firewall deployed INTO the hub (AZFW_Hub) - this is what makes it a
// Secured Virtual Hub and gives routing intent a next hop to point at.
resource hubFirewall 'Microsoft.Network/azureFirewalls@2023-09-01' = if (deployHubFirewall) {
  name: 'azfw-vhub-drift-test'
  location: location
  properties: {
    sku: {
      name: 'AZFW_Hub'
      tier: hubFirewallTier
    }
    virtualHub: {
      id: hub.id
    }
    firewallPolicy: {
      id: hubFwPolicy.id
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1 // data IPs auto-allocated by the hub; see Basic caveat above
      }
    }
  }
  tags: tags
}

// Routing intent: the security control. Forces Internet + Private traffic to the
// hub firewall. Coexists with the Tier-1 custom route table (that route points
// at the spoke connection, independent of these policies). If a deploy conflict
// surfaces, the two are independently testable.
resource routingIntent 'Microsoft.Network/virtualHubs/routingIntent@2023-09-01' = if (deployHubFirewall) {
  parent: hub
  name: 'hub-routing-intent'
  properties: {
    routingPolicies: [
      {
        name: 'InternetTraffic'
        destinations: [
          'Internet'
        ]
        nextHop: hubFirewall.id
      }
      {
        name: 'PrivateTraffic'
        destinations: [
          'PrivateTraffic'
        ]
        nextHop: hubFirewall.id
      }
    ]
  }
}

output virtualHubId string = deployVirtualHub ? hub.id : ''
output routeTableName string = deployVirtualHub ? 'vhub-drift-test/rt-drift-test' : ''
output hubFirewallId string = deployHubFirewall ? hubFirewall.id : ''
