param location string = 'australiaeast'
param environment string = 'test'

// Recovery Services vault. A vault with no protected items is effectively free,
// but carries the governance-critical backup controls: turning soft-delete off,
// weakening immutability, or opening public network access are exactly the
// out-of-band compliance drifts this estate should catch.
resource vault 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: 'rsv-drift-test'
  location: location
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Backup config child: soft-delete state is the headline backup security
// control (disabling it lets backups be deleted immediately). Declared inline
// so a flip to 'Disabled' surfaces as property drift.
resource backupConfig 'Microsoft.RecoveryServices/vaults/backupconfig@2023-06-01' = {
  parent: vault
  name: 'vaultconfig'
  properties: {
    enhancedSecurityState: 'Enabled'
    softDeleteFeatureState: 'Enabled'
  }
}

output vaultId string = vault.id
