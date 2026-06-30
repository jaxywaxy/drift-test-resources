param location string = 'australiaeast'
param environment string = 'test'

var workflowName = 'drift-wf-${uniqueString(resourceGroup().id)}'

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: workflowName
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {}
          }
        }
      }
      actions: {
        Response: {
          runAfter: {}
          type: 'Response'
          inputs: {
            statusCode: 200
            body: 'Workflow executed'
          }
        }
      }
      outputs: {}
    }
    parameters: {}
    integrationAccount: null
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output workflowId string = logicApp.id
output workflowName string = logicApp.name
output workflowUrl string = logicApp.properties.accessEndpoint
