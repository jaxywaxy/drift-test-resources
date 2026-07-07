param location string = 'australiaeast'
param environment string = 'test'

var namespaceName = 'eh-${uniqueString(resourceGroup().id)}'
var eventHubName = 'drift-hub'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: namespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
    kafkaEnabled: true
    zoneRedundant: false
    disableLocalAuth: false
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Add an Event Hub to the namespace
resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    partitionCount: 4
    messageRetentionInDays: 1
    status: 'Active'
  }
}

// Add authorization rule to Event Hub
resource authRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationrules@2021-11-01' = {
  parent: eventHub
  name: 'RootManageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}

// Consumer group (expanded child; $Default is auto-created and filtered)
resource driftConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2021-11-01' = {
  parent: eventHub
  name: 'driftcg'
}

output namespaceId string = eventHubNamespace.id
output namespaceName string = eventHubNamespace.name
output eventHubId string = eventHub.id
output eventHubName string = eventHub.name
output skuName string = eventHubNamespace.sku.name
output skuCapacity string = string(eventHubNamespace.sku.capacity)
