param location string = 'australiaeast'
param environment string = 'test'

var clusterName = 'aks-drift-test'

// AKS cluster with a system node pool (inline) + security-posture properties the
// drift agent should treat as critical: enableRBAC, apiServerAccessProfile
// (authorized IP ranges / private cluster), networkProfile, and the identity/
// governance tranche (aadProfile, azurepolicy addon, autoUpgradeProfile,
// oidcIssuerProfile). Control plane is Free tier; nodes are Standard_D2s_v3
// (DSv3 quota; B-series has 0 quota here).
//
// NOT declared here, though the agent rates them critical if a template does
// declare them: addonProfiles.omsagent (needs a workspace ID and bills log
// ingestion) and securityProfile.defender (Defender for Containers is billed).
// Left out so this estate stays cheap to stand up and tear down.
resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: 'aksdrift'
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'system'
        count: 1
        vmSize: 'Standard_D2s_v3'
        mode: 'System'
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
      }
    ]
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }
    // Identity + governance surface for the second AKS tranche. Declared on
    // purpose: these are compared as DECLARED paths (severity applies when the
    // template says something and live disagrees), not as security sentinels -
    // a sentinel needs an absent-default, and AKS absent-defaults have not been
    // read from a live cluster yet. Each is free or near-free and injectable
    // with a single `az aks update`.
    aadProfile: {
      managed: true
      enableAzureRBAC: true          // az aks update --disable-azure-rbac
      tenantID: subscription().tenantId
      adminGroupObjectIDs: []        // exact-set: an added group IS drift
    }
    addonProfiles: {
      azurepolicy: {
        enabled: true                // az aks disable-addons --addons azure-policy
      }
    }
    autoUpgradeProfile: {
      upgradeChannel: 'patch'        // az aks update --auto-upgrade-channel none
    }
    oidcIssuerProfile: {
      enabled: true                  // az aks update --disable-... (recreate)
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Separate USER node pool as a child resource — exercises the agent's agentPools
// child coverage (Microsoft.ContainerService/managedClusters/agentPools), distinct
// from the inline system pool above.
resource userPool 'Microsoft.ContainerService/managedClusters/agentPools@2024-02-01' = {
  parent: aks
  name: 'userpool'
  properties: {
    count: 1
    vmSize: 'Standard_D2s_v3'
    mode: 'User'
    osType: 'Linux'
    type: 'VirtualMachineScaleSets'
  }
}

output aksId string = aks.id
output nodeResourceGroup string = aks.properties.nodeResourceGroup
