param location string = 'australiaeast'
param environment string = 'test'
@secure()
param sqlAdminPassword string

var sqlServerName = 'sqldrift${uniqueString(resourceGroup().id)}'

// SQL Server + Basic DB (~$5/mo). Security surface for drift testing:
// minimalTlsVersion, publicNetworkAccess, TDE (on by default for new DBs -
// the DINE 'deploy TDE if not exists' policy test flips it off out-of-band).
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: 'driftadmin'
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: 'driftdb'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    maxSizeBytes: 104857600 // 100 MB - smallest Basic size
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

// Firewall rules (ARM-REST-expanded children). A hand-added rule - especially
// an AllowAll 0.0.0.0-255.255.255.255 range - opening the DB to the internet
// is the classic drift the agent should catch as an extra.
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
