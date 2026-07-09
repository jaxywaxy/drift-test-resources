param location string = 'australiaeast'
param environment string = 'test'

@description('Resource id of the Key Vault the private endpoint targets.')
param keyVaultId string

// Reference the estate VNet/subnet (created by the messaging-dns module). The
// default subnet already has privateEndpointNetworkPolicies=Disabled.
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: 'vnet-drift-test'
}
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: 'default'
}

// Private endpoint to the Key Vault (the canonical enterprise private-connectivity
// pattern). Detaching/re-pointing the connection is high-value drift.
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-kv-drift-test'
  location: location
  properties: {
    subnet: {
      id: subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'kv-connection'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: [
            'vault'
          ]
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

// Private DNS zone for Key Vault private link + vnet link.
resource privateZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
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

// DNS zone group binds the private endpoint's records into the zone (Azure
// auto-manages the A record). Child of the private endpoint.
resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vaultcore'
        properties: {
          privateDnsZoneId: privateZone.id
        }
      }
    ]
  }
}

output privateEndpointId string = privateEndpoint.id
