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

output policyAssignmentId string = assignment.id
