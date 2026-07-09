param location string = 'australiaeast'
param environment string = 'test'

// User-assigned identity + federated credential. An out-of-band federated
// credential is a persistence mechanism (workload identity federation lets an
// external issuer mint tokens as this identity) - exactly the drift the
// agent's child expansion surfaces.
resource driftIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-drift-test'
  location: location
  tags: {
    environment: environment
    managed: 'true'
  }
}

resource githubFederation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: driftIdentity
  name: 'github-main'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:jaxywaxy/drift-test-resources:ref:refs/heads/main'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

output identityId string = driftIdentity.id
output principalId string = driftIdentity.properties.principalId
