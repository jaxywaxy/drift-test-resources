param location string = 'australiaeast'
param environment string = 'test'

var aiAccountName = 'aidrift${uniqueString(resourceGroup().id)}'

// AI Services account (Azure OpenAI-compatible). Security-sensitive surface:
// publicNetworkAccess, disableLocalAuth (API-key auth), networkAcls.
// networkAcls declared explicitly (incl. empty allowlists) so the drift agent
// can detect hand-added firewall exceptions - comparison is bicep-driven.
resource aiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiAccountName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: aiAccountName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
    networkAcls: {
      defaultAction: 'Allow'
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

// Model deployment - the drift-prone AI state: model version (pinned, no
// auto-upgrade) and sku.capacity (TPM quota, the classic out-of-band bump).
resource gptDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: aiAccount
  name: 'gpt-4o-mini'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
}

output aiAccountId string = aiAccount.id
output aiAccountName string = aiAccount.name
