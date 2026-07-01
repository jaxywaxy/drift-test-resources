param location string = 'australiaeast'
param environment string = 'test'
param adminUsername string = 'pgadmin'
@secure()
param adminPassword string

var serverName = 'pgserver-drift-${take(uniqueString(subscription().id), 8)}'
var databaseName = 'driftdb'

// PostgreSQL Server (production-like configuration)
resource postgresServer 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
  name: serverName
  location: location
  sku: {
    name: 'B_Gen5_1'
    tier: 'Basic'
    capacity: 1
    family: 'Gen5'
  }
  properties: {
    createMode: 'Default'
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    version: '11'
    sslEnforcement: 'Enabled'
    minimalTlsVersion: 'TLS1_2'
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Database
resource database 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// Firewall rule - Allow Azure services
resource firewallRuleAzure 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Firewall rule - Allow local testing (localhost)
resource firewallRuleLocal 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = {
  parent: postgresServer
  name: 'AllowLocalhost'
  properties: {
    startIpAddress: '127.0.0.1'
    endIpAddress: '127.0.0.1'
  }
}

// Server parameters for production-like settings
resource serverParameters 'Microsoft.DBforPostgreSQL/servers/configurations@2017-12-01' = {
  parent: postgresServer
  name: 'log_slow_statement'
  properties: {
    value: '1000'
    source: 'user-override'
  }
}

output serverName string = postgresServer.name
output databaseName string = database.name
output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName
output connectionString string = 'postgresql://${adminUsername}@${serverName}:${adminPassword}@${postgresServer.properties.fullyQualifiedDomainName}:5432/${databaseName}?sslmode=require'
