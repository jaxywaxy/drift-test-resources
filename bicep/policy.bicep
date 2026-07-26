param environment string = 'test'

// Audit-only built-in policy assigned at resource-group scope. Exercises the
// drift agent's policy assignment/exemption detection (identity-based matching,
// out-of-band exemption flagging). Audit effect => no managed identity or
// remediation needed, safe for a test estate.
var auditManagedDisksPolicyId = '06a78e20-9358-41c9-923c-fb736d382a4d' // "Audit VMs that do not use managed disks"

resource assignment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'drift-audit-manageddisks'
  properties: {
    displayName: 'Audit VMs that do not use managed disks (drift-test)'
    description: 'drift-test: ${environment} governance baseline'
    // Built-in definitions live at tenant scope (/providers/...), so use
    // tenantResourceId — subscriptionResourceId points at a subscription-scoped
    // (custom) definition path where built-ins are not found (PolicyDefinitionNotFound).
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', auditManagedDisksPolicyId)
    enforcementMode: 'Default'
  }
}

// ---------------------------------------------------------------------------
// Inherit-tag Modify assignments.
//
// Real client estates leave tagging to Azure Policy rather than declaring tags
// in the Bicep that deploys the resource: a mandatory set enforced on write,
// plus these inherit-from-resource-group Modify effects. That makes two agent
// behaviours worth proving on live infrastructure:
//
//   costCentre  - inherited but declared NOWHERE in this template. The agent
//                 must report NOTHING for it. Added tags are deliberately
//                 ignored; if they were not, every resource in a policy-tagged
//                 estate would be permanently drifted.
//   environment - inherited AND declared ('test' on nearly every resource
//                 here). Point the RG at a different value and policy
//                 overwrites the template's, so the tag genuinely conflicts.
//                 The agent should detect it AND attribute it to policy, which
//                 moves it to policy_enforced_drifts rather than actionable
//                 drift. Redeploying would only lose the race again next
//                 remediation cycle - the real fix is reconciling the template.
//
// Modify needs a managed identity with the definition's remediation role (see
// remediationRoleId below), and only fires on
// resource WRITE - existing resources need an explicit remediation task:
//   az policy remediation create --name <n> -g rg-drift-test --policy-assignment <name>
//
// The RG must carry the tags to inherit (harness setup, not part of the estate
// under test, so deliberately not declared as a Microsoft.Resources/tags
// resource - that type is not indexed by Resource Graph and would read as a
// permanent missing_in_azure false positive):
// The RG tags themselves are set by the deploy workflow's `az group create`:
// that call PUTs the resource group, and a PUT without --tags replaces the tag
// map with an empty one - so setting them by hand out-of-band survives only
// until the next deploy.
var inheritTagIfMissingPolicyId = 'ea3f2387-9b95-492a-a190-fcdc54f7b070' // add only
var inheritTagPolicyId = 'cd3aa116-8754-49c9-a813-ad46512ece54'          // add or REPLACE
// Contributor, NOT Tag Contributor. Azure validates the assignment identity
// against the roleDefinitionIds the DEFINITION declares, and both inherit-tag
// built-ins declare Contributor (b24988ac). Granting the narrower Tag
// Contributor looks sufficient but leaves remediation failing on permissions.
var remediationRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource inheritCostCentre 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'drift-inherit-costcentre'
  location: resourceGroup().location
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: 'Inherit costCentre from the resource group (drift-test)'
    description: 'drift-test: undeclared tag - the agent must stay silent about it'
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', inheritTagIfMissingPolicyId)
    parameters: {
      tagName: { value: 'costCentre' }
    }
  }
}

resource inheritEnvironment 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'drift-inherit-environment'
  location: resourceGroup().location
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: 'Inherit environment from the resource group (drift-test)'
    description: 'drift-test: overwrites the template tag - policy-vs-Bicep conflict'
    // Overwriting variant on purpose: the "if missing" one would leave the
    // template's value alone and never produce the conflict we want to test.
    policyDefinitionId: tenantResourceId('Microsoft.Authorization/policyDefinitions', inheritTagPolicyId)
    parameters: {
      tagName: { value: 'environment' }
    }
  }
}

// Modify remediation writes tags, so each assignment identity needs the
// definition's declared remediation role at this scope.
resource costCentreTagRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, inheritCostCentre.id, remediationRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', remediationRoleId)
    principalId: inheritCostCentre.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'drift-test: remediation role required by the inherit-tag definition'
  }
}

resource environmentTagRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, inheritEnvironment.id, remediationRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', remediationRoleId)
    principalId: inheritEnvironment.identity.principalId
    principalType: 'ServicePrincipal'
    description: 'drift-test: remediation role required by the inherit-tag definition'
  }
}

output policyAssignmentId string = assignment.id
output inheritCostCentreAssignmentName string = inheritCostCentre.name
output inheritEnvironmentAssignmentName string = inheritEnvironment.name
