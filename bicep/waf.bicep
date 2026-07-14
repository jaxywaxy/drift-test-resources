param location string = 'australiaeast'
param environment string = 'test'

// Standalone Application Gateway WAF policy, deployed UNATTACHED and always.
//
// A WAF policy object is FREE - billing is on the WAF_v2 Application Gateway
// that consumes it (~$180/mo, still gated behind deployNetworkAppliances in
// main.bicep). Deploying the policy on its own gives the estate the classic
// WAF governance drift surface at zero cost:
//   - policySettings.mode  Prevention -> Detection  (WAF silently log-only)
//   - policySettings.state Enabled    -> Disabled   (WAF off entirely)
//   - managedRules.managedRuleSets    OWASP set removed
// appgw.bicep takes this policy's id as a parameter, so gateway and policy
// never diverge or collide on the name.
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-09-01' = {
  name: 'waf-drift-test'
  location: location
  properties: {
    policySettings: {
      state: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output wafPolicyId string = wafPolicy.id
