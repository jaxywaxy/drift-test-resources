param location string = 'australiaeast'
param environment string = 'test'

var clusterName = 'aks-drift-test'

// AKS cluster with a system node pool (inline) + security-posture properties the
// drift agent should treat as critical: enableRBAC, apiServerAccessProfile
// (authorized IP ranges / private cluster), networkProfile. Control plane is Free
// tier; nodes are Standard_D2s_v3 (DSv3 quota; B-series has 0 quota here).
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
