param location string = 'australiaeast'
param environment string = 'test'

var accountName = 'cosmos-drift-${uniqueString(resourceGroup().id)}'
var databaseName = 'driftdb'
var containerName = 'events'

// Cosmos DB Account (production-like configuration)
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: accountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    publicNetworkAccess: 'Enabled'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-11-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

// Container with throughput and indexing policy
resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  parent: sqlDatabase
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/eventType'
        ]
        kind: 'Hash'
      }
      defaultTtl: 86400 // 24 hours
      indexingPolicy: {
        indexingMode: 'Consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
    }
    options: {
      throughput: 400
    }
  }
}

// Firewall rule (IP-based access control)
resource firewallRule 'Microsoft.DocumentDB/databaseAccounts/ipAddressFilters@2023-11-15' = {
  parent: cosmosAccount
  name: 'AllowAzureServices'
  properties: {
    ipAddressOrRange: '0.0.0.0'
  }
}

output accountName string = cosmosAccount.name
output databaseName string = sqlDatabase.name
output containerName string = container.name
output connectionString string = cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
