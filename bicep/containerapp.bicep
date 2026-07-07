param location string = 'australiaeast'
param environment string = 'test'

// Container Apps (Consumption). Both the managed environment and the app are
// Resource Graph rows, so the generic pipeline compares them. Drift surface:
// ingress.external (public exposure) and ingress.allowInsecure are flagged
// critical by the agent; scale rules are a mild self-mutating noise source.
// minReplicas 0 keeps it near-free at idle.

resource containerEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-drift-test'
  location: location
  properties: {}
  tags: {
    environment: environment
    managed: 'true'
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-drift-test'
  location: location
  properties: {
    managedEnvironmentId: containerEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false // baseline internal; flipping to true is the drift test
        targetPort: 80
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: 'hello'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output containerAppId string = containerApp.id
output containerEnvId string = containerEnv.id
