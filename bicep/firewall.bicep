param location string = 'australiaeast'
param environment string = 'test'

@description('Deploy the actual Azure Firewall (~$1.25/hr Standard + own vnet/pip, ~10-15 min deploy). The policy + rules below are FREE standalone.')
param deployFirewall bool = false

// Standalone Azure Firewall Policy, deployed UNATTACHED and always.
//
// A firewall policy attached to at most one firewall is FREE - billing is on
// the Microsoft.Network/azureFirewalls resource (gated behind deployFirewall).
// Deploying the policy + rule collection groups on their own gives the estate
// the full firewall-rules drift surface at zero cost:
//   - ruleCollections           rule added/removed, action flip, port widening
//   - threatIntelMode           Alert -> Off (threat intel silently disabled)
//   - threatIntelWhitelist      out-of-band IP/FQDN exemptions from TI
//   - dnsSettings               proxy flip / custom server (resolution hijack)
// Empty allowlists are declared EXPLICITLY so exact-set comparison flags
// out-of-band additions (the empty-bicep-side vacuous-subset gap).
resource fwPolicy 'Microsoft.Network/firewallPolicies@2023-09-01' = {
  name: 'fwpol-drift-test'
  location: location
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    threatIntelWhitelist: {
      ipAddresses: []
      fqdns: []
    }
    dnsSettings: {
      enableProxy: false
      servers: []
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Network rules: the classic tamper targets (action flip, port widening,
// out-of-band rule additions).
resource networkRcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-09-01' = {
  parent: fwPolicy
  name: 'rcg-network'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'net-allow'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'allow-https-out'
            ipProtocols: ['TCP']
            sourceAddresses: ['10.99.0.0/24']
            destinationAddresses: ['*']
            destinationPorts: ['443']
          }
          {
            ruleType: 'NetworkRule'
            name: 'allow-dns-out'
            ipProtocols: ['UDP']
            sourceAddresses: ['10.99.0.0/24']
            destinationAddresses: ['*']
            destinationPorts: ['53']
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'net-deny-smb'
        priority: 4000
        action: {
          type: 'Deny'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'deny-smb-out'
            ipProtocols: ['TCP']
            sourceAddresses: ['*']
            destinationAddresses: ['*']
            destinationPorts: ['445']
          }
        ]
      }
    ]
  }
}

// Application (FQDN) rules - the second rule family.
resource appRcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-09-01' = {
  parent: fwPolicy
  name: 'rcg-application'
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'app-allow'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'allow-github'
            sourceAddresses: ['10.99.0.0/24']
            targetFqdns: ['github.com']
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [
    networkRcg // RCG writes to one policy must be serialized
  ]
}

// --- Optional: the firewall itself (cost- and time-gated) -------------------
// Self-contained vnet so the shared estate vnet needs no surgery; Standard
// SKU to match the policy tier (Basic firewalls cannot attach Standard
// policies and need a management subnet besides).

resource fwVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = if (deployFirewall) {
  name: 'vnet-fw-drift-test'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.98.0.0/24']
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet' // fixed name required by the platform
        properties: {
          addressPrefix: '10.98.0.0/26'
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

resource fwPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = if (deployFirewall) {
  name: 'pip-fw-drift-test'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-09-01' = if (deployFirewall) {
  name: 'fw-drift-test'
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: fwPolicy.id
    }
    ipConfigurations: [
      {
        name: 'fw-ipconfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'vnet-fw-drift-test', 'AzureFirewallSubnet')
          }
          publicIPAddress: {
            id: fwPip.id
          }
        }
      }
    ]
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
  dependsOn: [
    fwVnet
    appRcg // attach only after the policy's RCGs are settled
  ]
}

output fwPolicyId string = fwPolicy.id
