param location string = 'australiaeast'
param environment string = 'test'

// Standalone Standard public IP (~$3.65/mo). Thin but real drift surface: the
// DDoS protection mode is a security control that can be turned off out-of-band
// (VirtualNetworkInherited -> Disabled), and the allocation method / idle
// timeout are ordinary config. Unattached on purpose - the exposure drift this
// estate already proves is an UNMANAGED public IP appearing (extra_in_azure).
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-drift-test'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    ddosSettings: {
      protectionMode: 'VirtualNetworkInherited'
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output publicIpId string = publicIp.id
