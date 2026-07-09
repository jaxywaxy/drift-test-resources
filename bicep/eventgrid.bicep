param location string = 'australiaeast'
param environment string = 'test'

@description('Existing Event Hub resource id used as the event delivery destination.')
param eventHubId string

@description('Existing storage account resource id used as the system-topic source.')
param storageAccountId string

var topicName = 'evgt-drift-${uniqueString(resourceGroup().id)}'
var systemTopicName = 'evgst-storage-${uniqueString(resourceGroup().id)}'

// Custom topic — a first-class Event Grid resource (base Resource Graph row).
resource customTopic 'Microsoft.EventGrid/topics@2023-12-15-preview' = {
  name: topicName
  location: location
  properties: {
    publicNetworkAccess: 'Enabled'
    inputSchema: 'EventGridSchema'
    disableLocalAuth: false
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Event subscription on the custom topic. Event subscriptions are EXTENSION
// resources (not standard Resource Graph rows) — the drift agent must expand
// them via ARM REST, like diagnostic settings / RBAC. EventHub destination is
// used because subscription CREATION needs no delivery-RBAC handshake (only
// webhook destinations validate), so it deploys cleanly for a drift test.
resource customTopicSub 'Microsoft.EventGrid/topics/eventSubscriptions@2023-12-15-preview' = {
  parent: customTopic
  name: 'sub-drift'
  properties: {
    destination: {
      endpointType: 'EventHub'
      properties: {
        resourceId: eventHubId
      }
    }
    eventDeliverySchema: 'EventGridSchema'
  }
}

// System topic on the storage account — the canonical "react to blob events"
// enterprise pattern. topicType is fixed for the source resource provider.
resource storageSystemTopic 'Microsoft.EventGrid/systemTopics@2023-12-15-preview' = {
  name: systemTopicName
  location: location
  properties: {
    source: storageAccountId
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

resource systemTopicSub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2023-12-15-preview' = {
  parent: storageSystemTopic
  name: 'sub-drift'
  properties: {
    destination: {
      endpointType: 'EventHub'
      properties: {
        resourceId: eventHubId
      }
    }
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
        'Microsoft.Storage.BlobDeleted'
      ]
    }
  }
}

output topicId string = customTopic.id
output systemTopicId string = storageSystemTopic.id
