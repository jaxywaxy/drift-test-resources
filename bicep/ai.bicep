param location string = 'australiaeast'
param environment string = 'test'

var aiAccountName = 'aidrift${uniqueString(resourceGroup().id)}'

// AI Services account (Azure OpenAI-compatible). Security-sensitive surface:
// publicNetworkAccess, disableLocalAuth (API-key auth), networkAcls.
// networkAcls declared explicitly (incl. empty allowlists) so the drift agent
// can detect hand-added firewall exceptions - comparison is bicep-driven.
resource aiAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
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
    allowProjectManagement: true // enables Foundry projects under this account
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
resource gptDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: aiAccount
  name: 'gpt-5-mini'
  sku: {
    name: 'GlobalStandard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5-mini'
      version: '2025-08-07'
    }
    versionUpgradeOption: 'NoAutoUpgrade'
    raiPolicyName: customRaiPolicy.name
  }
}

// Custom content-filter policy - loosening a filter out-of-band is exactly
// the governance drift phase 2 detects (identity per entry = name + source).
resource customRaiPolicy 'Microsoft.CognitiveServices/accounts/raiPolicies@2025-06-01' = {
  parent: aiAccount
  name: 'drifttest-rai'
  properties: {
    basePolicyName: 'Microsoft.DefaultV2'
    mode: 'Blocking'
    contentFilters: [
      { name: 'Hate', source: 'Prompt', severityThreshold: 'Medium', blocking: true, enabled: true }
      { name: 'Hate', source: 'Completion', severityThreshold: 'Medium', blocking: true, enabled: true }
      { name: 'Sexual', source: 'Prompt', severityThreshold: 'Medium', blocking: true, enabled: true }
      { name: 'Sexual', source: 'Completion', severityThreshold: 'Medium', blocking: true, enabled: true }
      { name: 'Violence', source: 'Prompt', severityThreshold: 'Medium', blocking: true, enabled: true }
      { name: 'Violence', source: 'Completion', severityThreshold: 'Medium', blocking: true, enabled: true }
      { name: 'Selfharm', source: 'Prompt', severityThreshold: 'Medium', blocking: true, enabled: true }
      { name: 'Selfharm', source: 'Completion', severityThreshold: 'Medium', blocking: true, enabled: true }
    ]
  }
}

// Foundry project - out-of-band project/connection additions are new data
// channels the drift agent must surface.
resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: aiAccount
  name: 'proj-drifttest'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Drift Test Project'
    description: 'Foundry project for drift detection testing'
  }
}

output aiAccountId string = aiAccount.id
output aiAccountName string = aiAccount.name
output aiProjectId string = aiProject.id
