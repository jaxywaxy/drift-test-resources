param location string = 'australiaeast'
param environment string = 'test'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${environment}drift${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Enabled'
    // INJECTION A (schema round): added to storageAccounts AFTER 2023-01-01, so
    // this resource's pinned apiVersion does not define it. bicep build warns
    // BCP037 and compiles; ARM drops it. Expect it SUPPRESSED, not reported.
    allowSharedKeyAccessForServices: {
      blob: {
        enabled: true
      }
    }
    // INJECTION B (control): allowedCopyScope IS defined at 2023-01-01 and is
    // not set on the live account. Expect it REPORTED. If A and B behave the
    // same, the check is not discriminating - it is suppressing everything.
    allowedCopyScope: 'AAD'
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Data-plane children (ARM-REST-expanded by the drift agent): a container
// made public or a hand-added share is classic quiet drift.
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource dataContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'drift-data'
  properties: {
    publicAccess: 'None'
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource driftShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: fileService
  name: 'drift-share'
  properties: {
    shareQuota: 5
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
