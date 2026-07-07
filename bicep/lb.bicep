param location string = 'australiaeast'
param environment string = 'test'

// Standard public Load Balancer. The drift agent compares its embedded named
// collections (frontendIPConfigurations, backendAddressPools, probes,
// loadBalancingRules) as named arrays - a hand-added rule/probe is drift,
// Azure read-only augmentation (provisioningState, resolved ids) is tolerated.

resource lbPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-lb-drift-test'
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

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: 'lb-drift-test'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          publicIPAddress: {
            id: lbPublicIp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backend-pool'
      }
    ]
    probes: [
      {
        name: 'health-probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'http-rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-drift-test', 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-drift-test', 'backend-pool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'lb-drift-test', 'health-probe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 4
          enableFloatingIP: false
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

output loadBalancerId string = loadBalancer.id
