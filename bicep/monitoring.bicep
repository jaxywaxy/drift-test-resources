param location string = 'australiaeast'
param environment string = 'test'
param storageAccountId string

// Action group + metric alert (group-1 generic-pipeline resources).
// Alert rule tampering (disabling, threshold changes) is classic quiet drift.
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-drift-test'
  location: 'Global' // action groups are global
  properties: {
    groupShortName: 'driftag'
    enabled: true
    emailReceivers: [
      {
        name: 'ops'
        emailAddress: 'jacqui.anker@gmail.com'
        useCommonAlertSchema: true
      }
    ]
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

resource availabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-storage-availability'
  location: 'global'
  properties: {
    description: 'Storage availability below threshold (drift-test)'
    severity: 2
    enabled: true
    scopes: [
      storageAccountId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'availability'
          metricName: 'Availability'
          metricNamespace: 'Microsoft.Storage/storageAccounts'
          operator: 'LessThan'
          threshold: 99
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

output actionGroupId string = actionGroup.id
