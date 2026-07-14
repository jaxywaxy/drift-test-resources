param location string = 'australiaeast'
param environment string = 'test'

@description('Resource id of the WAF policy (owned by waf.bicep, which deploys it unattached and free).')
param wafPolicyId string

// Application Gateway WAF_v2 (self-contained: own vnet/subnet + public IP).
// NOTE: WAF_v2 runs ~$180/mo, so main.bicep gates this behind the
// deployNetworkAppliances flag. The WAF POLICY itself lives in waf.bicep and
// deploys always (a policy object is free), so WAF governance drift - mode
// Prevention->Detection, state, managed rule sets - is testable without this
// gateway. Drift-interesting surface here when it IS deployed: sslPolicy min
// version, listener protocol, and the big embedded named collections
// (httpListeners, requestRoutingRules, backendHttpSettingsCollection, ...).

resource appgwVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-appgw-drift'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.98.0.0/24'
      ]
    }
    subnets: [
      {
        name: 'appgw-subnet'
        properties: {
          addressPrefix: '10.98.0.0/26'
        }
      }
    ]
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

resource appgwPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-appgw-drift'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

// The WAF policy is declared in waf.bicep (deployed unattached and free) and
// passed in as wafPolicyId, so the policy and this gateway can never diverge
// or collide on the resource name.

var appgwName = 'appgw-drift-test'

resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: appgwName
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 2
    }
    sslPolicy: {
      policyType: 'Predefined'
      policyName: 'AppGwSslPolicy20220101'
    }
    firewallPolicy: {
      id: wafPolicyId
    }
    gatewayIPConfigurations: [
      {
        name: 'appgw-ipconfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'vnet-appgw-drift', 'appgw-subnet')
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appgw-frontend'
        properties: {
          publicIPAddress: {
            id: appgwPublicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port-80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'appgw-backend'
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'http-settings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
        }
      }
    ]
    httpListeners: [
      {
        name: 'http-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appgwName, 'appgw-frontend')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appgwName, 'port-80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routing-rule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appgwName, 'http-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appgwName, 'appgw-backend')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appgwName, 'http-settings')
          }
        }
      }
    ]
  }
  dependsOn: [
    appgwVnet
  ]
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output appGatewayId string = appGateway.id
