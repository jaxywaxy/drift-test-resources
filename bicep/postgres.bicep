param location string = 'australiaeast'
param environment string = 'test'
param adminUsername string = 'pgadmin'
@secure()
param adminPassword string

var serverName = 'pgflex-drift-${take(uniqueString(resourceGroup().id), 8)}'

// PostgreSQL FLEXIBLE Server (migrated from the deprecated Single Server API
// @2017-12-01, which was disabled). Burstable Standard_B1ms (~$12/mo).
//
// Only the SERVER is declared - its children (databases, firewallRules,
// configurations) are NOT expanded by the drift agent, so declaring them would
// false-flag missing_in_azure (same rule as the Service Bus topic subscriptions
// and the messaging-dns header comment). The server itself is a base Resource
// Graph row and carries the security-relevant drift surface:
//   - version
//   - network.publicNetworkAccess
//   - backup.backupRetentionDays / geoRedundantBackup
//   - authConfig.passwordAuth / activeDirectoryAuth
//   - highAvailability.mode
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    createMode: 'Default'
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    version: '16'
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    authConfig: {
      passwordAuth: 'Enabled'
      activeDirectoryAuth: 'Disabled'
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output serverName string = postgresServer.name
output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName
