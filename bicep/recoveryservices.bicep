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

// Backup policy: retention/schedule is the compliance-critical backup control -
// shrinking the retention window silently shortens how far back you can restore.
// Declared (a custom AzureIaasVM daily policy) so an out-of-band retention or
// schedule change surfaces as critical drift. The built-in DefaultPolicy /
// EnhancedPolicy / HourlyLogBackup that every vault ships are undeclared and so
// filtered as unmanaged - only this policy is compared. Times are fixed literals:
// Azure returns scheduleRunTimes/retentionTimes exactly as declared (verified),
// so they do not false-drift.
resource vmBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-06-01' = {
  parent: vault
  name: 'drift-vm-daily'
  properties: {
    backupManagementType: 'AzureIaasVM'
    policyType: 'V1'
    instantRpRetentionRangeInDays: 2
    timeZone: 'UTC'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '2024-01-01T06:00:00Z'
      ]
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2024-01-01T06:00:00Z'
        ]
        retentionDuration: {
          count: 30
          durationType: 'Days'
        }
      }
    }
  }
}

output vaultId string = vault.id
