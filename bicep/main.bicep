param location string = 'australiaeast'
param environment string = 'test'
@secure()
param postgresAdminPassword string = 'DriftTest@TestAdmin123!'
@secure()
param sqlAdminPassword string = 'DriftTest@SqlAdmin123!'
@secure()
param vmAdminPassword string = 'DriftTest@VmAdmin123!'

// Load balancer + Application Gateway (WAF_v2 ~$180/mo) are OFF by default;
// set true to deploy them for network-appliance drift testing.
param deployNetworkAppliances bool = false

// Linux VM (Standard_B1s) + AMA extension is OFF by default; set true to deploy
// it for VM property / extension / disk-NIC-validator drift testing.
param deployVirtualMachine bool = false

// AKS cluster (2x Standard_D2s_v3 nodes ~$140/mo) is OFF by default; set true to
// deploy it for managedClusters + agentPools drift testing.
param deployAks bool = false

// Cosmos DB is OFF by default: it takes ~5-10 min to provision and slows every
// deploy. Already drift-verified (account + sqlDatabases + containers); set true
// only when re-testing Cosmos. Gated like AKS/VM so day-to-day deploys are fast.
param deployCosmos bool = false

// Deploy Storage Account
module storageModule 'storage.bicep' = {
  name: 'deploy-storage'
  params: {
    location: location
    environment: environment
  }
}

// Deploy App Service
module appServiceModule 'appservice.bicep' = {
  name: 'deploy-appservice'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Key Vault
module keyVaultModule 'keyvault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    location: location
    environment: environment
    workspaceId: logAnalyticsModule.outputs.workspaceId
  }
}

// Deploy Logic App
module logicAppModule 'logicapp.bicep' = {
  name: 'deploy-logicapp'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Log Analytics Workspace
module logAnalyticsModule 'loganalytics.bicep' = {
  name: 'deploy-loganalytics'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Event Hub Namespace
module eventHubModule 'eventhub.bicep' = {
  name: 'deploy-eventhub'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Cosmos DB
module cosmosDbModule 'cosmosdb.bicep' = if (deployCosmos) {
  name: 'deploy-cosmosdb'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Azure Container Registry
module acrModule 'acr.bicep' = {
  name: 'deploy-acr'
  params: {
    location: location
    environment: environment
  }
}

// Deploy Azure Container Instance
module aciModule 'aci.bicep' = {
  name: 'deploy-aci'
  params: {
    location: location
    environment: environment
  }
}

// Deploy AI Services account + model deployment (AI resource drift testing)
module aiModule 'ai.bicep' = {
  name: 'deploy-ai'
  params: {
    location: location
    environment: environment
  }
}

// SQL Server + Basic DB (TDE policy testing + future firewall-rule children)
module sqlModule 'sql.bicep' = {
  name: 'deploy-sql'
  params: {
    location: location
    environment: environment
    sqlAdminPassword: sqlAdminPassword
  }
}

// Group-1 generic-pipeline resources: action group + metric alert
module monitoringModule 'monitoring.bicep' = {
  name: 'deploy-monitoring'
  params: {
    location: location
    environment: environment
    storageAccountId: storageModule.outputs.storageAccountId
    workspaceId: logAnalyticsModule.outputs.workspaceId
  }
}

// Group-1 generic-pipeline resources: Service Bus, Traffic Manager, DNS zone
module messagingDnsModule 'messaging-dns.bicep' = {
  name: 'deploy-messaging-dns'
  params: {
    location: location
    environment: environment
  }
}

// Recovery Services vault (~free with no protected items): backup soft-delete
// and public network access are the governance drift surface.
module recoveryServicesModule 'recoveryservices.bicep' = {
  name: 'deploy-recoveryservices'
  params: {
    location: location
    environment: environment
  }
}


// PostgreSQL Flexible Server, Burstable B1ms (~$12/mo). Migrated from the
// deprecated Single Server module (was commented out below).
module postgresModule 'postgres.bicep' = {
  name: 'deploy-postgres'
  params: {
    location: location
    environment: environment
    adminPassword: postgresAdminPassword
  }
}

// User-assigned identity + federated credential (child-expansion coverage)
module identityModule 'identity.bicep' = {
  name: 'deploy-identity'
  params: {
    location: location
    environment: environment
  }
}

// Container Apps (Consumption env + app - modern serverless containers)
module containerAppModule 'containerapp.bicep' = {
  name: 'deploy-containerapp'
  params: {
    location: location
    environment: environment
  }
}

// Standard Load Balancer (embedded named-collection drift: rules/probes/pools)
module lbModule 'lb.bicep' = if (deployNetworkAppliances) {
  name: 'deploy-lb'
  params: {
    location: location
    environment: environment
  }
}

// Application Gateway WAF_v2 + WAF policy (expensive - gated by the flag)
// WAF policy - deployed ALWAYS (unattached policy objects are free; the
// ~$180/mo WAF_v2 gateway below stays gated). Gives the estate the WAF
// governance drift surface: policySettings.mode Prevention->Detection,
// state Enabled->Disabled, managed rule sets removed.
module wafModule 'waf.bicep' = {
  name: 'deploy-waf'
  params: {
    location: location
    environment: environment
  }
}

// Azure Firewall Policy + rule collection groups - deployed ALWAYS (a policy
// attached to <=1 firewall is free; the ~$1.25/hr firewall itself stays
// gated). Gives the estate the firewall-rules drift surface: rule
// added/removed/action-flipped, threatIntelMode Alert->Off, out-of-band
// threat-intel whitelist entries, DNS proxy/server changes.
module firewallModule 'firewall.bicep' = {
  name: 'deploy-firewall'
  params: {
    location: location
    environment: environment
    deployFirewall: deployNetworkAppliances
  }
}

// Function App on a Y1 consumption plan (~$0 with no executions): functions
// carry their own transport/exposure controls (httpsOnly, minTlsVersion,
// ftpsState, publicNetworkAccess) separate from the App Service.
module functionAppModule 'functionapp.bicep' = {
  name: 'deploy-functionapp'
  params: {
    location: location
    environment: environment
    storageAccountName: storageModule.outputs.storageAccountName
  }
}

// Standalone Standard public IP (~$3.65/mo) - ddosSettings.protectionMode is
// the security control worth watching.
module publicIpModule 'publicip.bicep' = {
  name: 'deploy-publicip'
  params: {
    location: location
    environment: environment
  }
}

module appgwModule 'appgw.bicep' = if (deployNetworkAppliances) {
  name: 'deploy-appgw'
  params: {
    location: location
    environment: environment
    wafPolicyId: wafModule.outputs.wafPolicyId
  }
}

// Front Door Standard (~$35/mo - gated by the flag)
module frontdoorModule 'frontdoor.bicep' = if (deployNetworkAppliances) {
  name: 'deploy-frontdoor'
  params: {
    environment: environment
  }
}

// Event Grid: custom topic + system topic (on storage) + event subscriptions.
// Subscriptions are EXTENSION resources delivered to the existing Event Hub.
module eventGridModule 'eventgrid.bicep' = {
  name: 'deploy-eventgrid'
  params: {
    location: location
    environment: environment
    eventHubId: eventHubModule.outputs.eventHubId
    storageAccountId: storageModule.outputs.storageAccountId
  }
}

// RBAC role assignment on the workload identity (exercises rbac.py detection).
module rbacModule 'rbac.bicep' = {
  name: 'deploy-rbac'
  params: {
    environment: environment
    principalId: identityModule.outputs.principalId
  }
}

// Audit policy assignment at RG scope (exercises policy.py detection).
module policyModule 'policy.bicep' = {
  name: 'deploy-policy'
  params: {
    environment: environment
  }
}

// Linux VM + AMA extension (gated - has compute cost). References the estate
// VNet/subnet created by the messaging-dns module.
module vmModule 'vm.bicep' = if (deployVirtualMachine) {
  name: 'deploy-vm'
  params: {
    location: location
    environment: environment
    adminPassword: vmAdminPassword
  }
  dependsOn: [messagingDnsModule]
}

// VM Scale Set (capacity 0) + standalone managed disk + availability set.
// NOT gated: a scale set with no instances, an availability set and a 4 GiB
// HDD are effectively free. References the estate VNet/subnet created by the
// messaging-dns module.
module computeModule 'compute.bicep' = {
  name: 'deploy-compute'
  params: {
    location: location
    environment: environment
  }
  dependsOn: [messagingDnsModule]
}

// AKS cluster + system pool + separate user agentPool (gated - compute cost).
module aksModule 'aks.bicep' = if (deployAks) {
  name: 'deploy-aks'
  params: {
    location: location
    environment: environment
  }
}

// Private endpoint to the Key Vault + private DNS zone group. References the
// estate VNet/subnet created by the messaging-dns module.
module privateEndpointModule 'privateendpoints.bicep' = {
  name: 'deploy-privateendpoints'
  params: {
    location: location
    environment: environment
    keyVaultId: keyVaultModule.outputs.keyVaultId
  }
  dependsOn: [messagingDnsModule]
}

output storageAccountId string = storageModule.outputs.storageAccountId
output appServiceId string = appServiceModule.outputs.appServiceId
output keyVaultId string = keyVaultModule.outputs.keyVaultId
output logicAppId string = logicAppModule.outputs.workflowId
output logAnalyticsId string = logAnalyticsModule.outputs.workspaceId
output eventHubNamespaceId string = eventHubModule.outputs.namespaceId
output acrId string = acrModule.outputs.acrId
output aciId string = aciModule.outputs.aciId
// output postgresServerName string = postgresModule.outputs.serverName  // Disabled - PostgreSQL module commented out
