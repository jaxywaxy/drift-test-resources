param location string = 'australiaeast'
param environment string = 'test'

// Azure Container Instance (serverless container group - PAYG per-second, flat resource)
resource aci 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: 'aci-${environment}-drift-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    osType: 'Linux'
    restartPolicy: 'OnFailure'
    containers: [
      {
        name: 'hello'
        properties: {
          image: 'mcr.microsoft.com/azuredocs/aci-helloworld:latest'
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
        }
      }
    ]
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output aciId string = aci.id
output aciName string = aci.name
