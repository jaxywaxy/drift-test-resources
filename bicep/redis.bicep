param location string = 'australiaeast'
param environment string = 'test'

// Azure Cache for Redis, Basic C0 (~$16/mo - the priciest of the new estate
// resources). Security-relevant drift surface: enableNonSslPort=true exposes a
// PLAINTEXT (non-TLS) endpoint, minimumTlsVersion is the transport floor, and
// publicNetworkAccess governs exposure - all common out-of-band changes.
resource redis 'Microsoft.Cache/redis@2023-08-01' = {
  name: 'redis-drift-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    redisConfiguration: {
      'maxmemory-policy': 'volatile-lru'
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output redisId string = redis.id
