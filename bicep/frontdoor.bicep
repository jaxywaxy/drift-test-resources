param environment string = 'test'

// Front Door Standard (Microsoft.Cdn/profiles). ~$35/mo base, so main.bicep
// gates it behind deployNetworkAppliances. Children are ARM-REST-expanded by
// the agent. Drift-interesting surface for testing later: an added/changed
// origin (traffic redirect), a route's forwardingProtocol/httpsRedirect (TLS
// downgrade), or a detached security policy (WAF).

resource fdProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: 'fd-drift-test'
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

resource fdEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: fdProfile
  name: 'endpoint-drift'
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource fdOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: fdProfile
  name: 'og-drift'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

resource fdOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: fdOriginGroup
  name: 'origin-drift'
  properties: {
    hostName: 'www.example.com'
    httpPort: 80
    httpsPort: 443
    originHostHeader: 'www.example.com'
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
  }
}

resource fdRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  parent: fdEndpoint
  name: 'route-drift'
  properties: {
    originGroup: {
      id: fdOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly' // downgrade to HttpOnly is the drift test
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
  dependsOn: [
    fdOrigin
  ]
}

output frontDoorProfileId string = fdProfile.id
output frontDoorEndpointHostName string = fdEndpoint.properties.hostName
