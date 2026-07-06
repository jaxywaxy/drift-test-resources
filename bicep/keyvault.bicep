param location string = 'australiaeast'
param environment string = 'test'

var keyVaultName = 'kvdrift${uniqueString(resourceGroup().id)}'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
      // Declared empty so the drift agent can detect hand-added firewall
      // exceptions (comparison is bicep-driven; an omitted key is not compared).
      ipRules: []
      virtualNetworkRules: []
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Lock to prevent accidental deletion
resource keyVaultLock 'Microsoft.Authorization/locks@2017-04-01' = {
  scope: keyVault
  name: 'keyvault-cannotdelete'
  properties: {
    level: 'CanNotDelete'
    notes: 'Prevent accidental deletion of Key Vault - Critical resource'
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
