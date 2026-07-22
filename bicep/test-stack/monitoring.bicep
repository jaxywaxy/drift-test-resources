targetScope = 'resourceGroup'

@description('Location for resources')
param location string

@description('Suffix to make names unique')
param suffix string

// Names use the same uniqueString-derived suffix as the rest of the estate, so
// this module exercises the nested-module name-resolution path that landing
// zones rely on (see the driftAppPlan fix).
var workspaceName = toLower('drift-law-${suffix}')
var appInsightsName = toLower('drift-ai-${suffix}')
var actionGroupName = 'drift-ag-${suffix}'
var metricAlertName = 'drift-metric-${suffix}'
var activityAlertName = 'drift-activity-${suffix}'
var queryAlertName = 'drift-query-${suffix}'

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    RetentionInDays: 90
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    DisableIpMasking: false
  }
}

// action group - the notification path the alerts below depend on.
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: 'drift'
    enabled: true
    emailReceivers: [
      {
        name: 'oncall'
        emailAddress: 'oncall@example.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

resource metricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: metricAlertName
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [ appInsights.id ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FailedRequests'
          metricName: 'requests/failed'
          metricNamespace: 'microsoft.insights/components'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

resource activityAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: activityAlertName
  location: 'global'
  properties: {
    enabled: true
    scopes: [ resourceGroup().id ]
    condition: {
      allOf: [
        { field: 'category', equals: 'Administrative' }
        { field: 'operationName', equals: 'Microsoft.KeyVault/vaults/write' }
      ]
    }
    actions: {
      actionGroups: [ { actionGroupId: actionGroup.id } ]
    }
  }
}

resource queryAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: queryAlertName
  location: location
  properties: {
    severity: 3
    enabled: true
    scopes: [ workspace.id ]
    evaluationFrequency: 'PT10M'
    windowSize: 'PT10M'
    criteria: {
      allOf: [
        {
          query: 'Heartbeat | summarize AggregatedValue = count() by bin(TimeGenerated, 5m)'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    actions: {
      actionGroups: [ actionGroup.id ]
    }
  }
}

output appInsightsName string = appInsights.name
output actionGroupName string = actionGroup.name
