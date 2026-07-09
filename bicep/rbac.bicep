param environment string = 'test'

@description('Principal (object) id of the workload identity to grant the role to.')
param principalId string

// Grant the estate's user-assigned identity a role at resource-group scope.
// Exercises the drift agent's RBAC role-assignment detection (identity-based
// matching, grantor provenance). guid(...) name is deterministic per (scope,
// principal, role) so redeploys are idempotent. principalId is a PARAM (known at
// this module's deploy start) so it can form the assignment name.
var monitoringReaderRoleId = '43d0d8ad-25c7-4714-9337-8ba259a9fe05' // Monitoring Reader (low-privilege built-in)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, monitoringReaderRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringReaderRoleId)
    principalId: principalId
    principalType: 'ServicePrincipal'
    description: 'drift-test: Monitoring Reader for ${environment} workload identity'
  }
}

output roleAssignmentId string = roleAssignment.id
