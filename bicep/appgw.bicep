param location string = 'australiaeast'
param environment string = 'test'

// Application Gateway WAF_v2 (self-contained: own vnet/subnet + public IP +
// WAF policy). NOTE: WAF_v2 runs ~$180/mo, so main.bicep gates this behind
// the deployNetworkAppliances flag. Drift-interesting surface for testing
// later: WAF policy mode (Prevention->Detection), sslPolicy min version,
// listener protocol, and the big embedded named collections (httpListeners,
// requestRoutingRules, backendHttpSettingsCollection, ...).

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

// WAF policy - mode flips (Prevention->Detection) and disabled managed rule
// sets are exactly the governance drift to detect later.
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-09-01' = {
  name: 'waf-drift-test'
  location: location
  properties: {
    policySettings: {
      state: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

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
      id: wafPolicy.id
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
output wafPolicyId string = wafPolicy.id
