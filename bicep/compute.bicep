param location string = 'australiaeast'
param environment string = 'test'

// Compute tranche: VM Scale Set, standalone managed disk, availability set,
// and zone placement. Deployed ALWAYS rather than gated, because none of it
// carries meaningful cost:
//   * a scale set at capacity 0 runs no VM instances - the scale set object
//     itself is free, and every property worth drifting (capacity, upgrade
//     policy, repairs, instance public IPs) lives on the model, not on a
//     running instance. Same "free object" trick as the unattached WAF and
//     firewall policies.
//   * an availability set is pure metadata - always free.
//   * a 4 GiB Standard HDD is about 20 cents a month.
// Quota note: B-series has no quota in australiaeast on this subscription
// (see vm.bicep), so the scale set model uses the same D2s_v3 size. At
// capacity 0 no quota is actually consumed.

var vmssName = 'vmss-drift-test'
var adminUsername = 'azureuser'

// Reference the estate VNet/subnet created by the messaging-dns module.
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: 'vnet-drift-test'
}
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: 'default'
}

// Availability set: fault/update domain counts are the whole point - shrinking
// platformFaultDomainCount is a silent resiliency downgrade the agent must
// rate critical. 'Aligned' = managed-disk aware.
resource availabilitySet 'Microsoft.Compute/availabilitySets@2023-03-01' = {
  name: 'avset-drift-test'
  location: location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Standalone managed data disk - NOT attached to a VM, so it is independent of
// the gated vm.bicep and exercises the "declared disk" path that the live-state
// filter used to drop wholesale. networkAccessPolicy/publicNetworkAccess are
// declared explicitly so opening them out-of-band is unambiguous drift rather
// than a first-contact default.
resource dataDisk 'Microsoft.Compute/disks@2023-04-02' = {
  name: 'disk-drift-data'
  location: location
  zones: [
    '1'
  ]
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    diskSizeGB: 4
    creationData: {
      createOption: 'Empty'
    }
    networkAccessPolicy: 'DenyAll'
    publicNetworkAccess: 'Disabled'
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Zone-redundant scale set at capacity 0. zoneBalance + the explicit zone list
// give the exact-set zone comparison an anchor; automaticRepairsPolicy and
// upgradePolicy are the mutable security/availability properties to drift.
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2023-09-01' = {
  name: vmssName
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  sku: {
    name: 'Standard_D2s_v3'
    tier: 'Standard'
    capacity: 0
  }
  properties: {
    orchestrationMode: 'Uniform'
    overprovision: false
    singlePlacementGroup: false
    zoneBalance: true
    upgradePolicy: {
      mode: 'Automatic'
    }
    automaticRepairsPolicy: {
      enabled: true
      gracePeriod: 'PT10M'
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: 'vmssdrift'
        adminUsername: adminUsername
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                // Throwaway public key whose private half was generated and
                // destroyed without ever being stored. A public key is not a
                // secret, and the scale set runs no instances to log into.
                // NOTE: this must be a REAL key - Azure parses keyData and
                // rejects a made-up string with InvalidParameter, which is
                // exactly how the first deployment of this file failed.
                keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4hrBSZeP1njoYi5bXoivf3ppUa4d3wSuCY9mSbgLRY/dSqVo/ka9OWqwLIpHcXVuuwWm4wXpc/Dmj7dj8S1K4csrSuClKtODRU3nDHhMiWDYp21X9ROlZaleiaP9uBvhF8T8xXPUA7sjb7afYIG7oh2hQ3AEjhBQlYaXXabxmvD0vtgPg+y4aBZ4EAMVOJT0thsqOAp6Uf6eizVTsASaAaLDAxpYLBLpQXy1S/qD4z8AGIAzaA/8Zi91ZfVVkHxFRUSJi9woA/VTLNMAmLevF8xRy0C1zuFQVc3NZwA5ylcUkg70rxJZjNTPkyxbh+giSXBSHg7+Q9EJ25dTxTRBn drift-test-throwaway'
              }
            ]
          }
        }
      }
      // NO securityProfile block. `encryptionAtHost` requires the
      // Microsoft.Compute/EncryptionAtHost subscription feature, and Azure
      // rejects the property for merely BEING PRESENT - declaring it false is
      // still InvalidParameter. Enabling the feature is a subscription-wide
      // change this estate should not make on its own. The agent still rates
      // encryptionAtHost critical wherever a template does declare it; it just
      // is not exercised live here.
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      }
      // Application Health extension. Not decoration: automaticRepairsPolicy
      // above CANNOT be enabled without health monitoring - Azure rejects the
      // scale set otherwise - and it would have been the next deployment
      // failure after encryptionAtHost. Costs nothing at capacity 0 (the model
      // carries the extension; no instance ever runs it) and adds an
      // extensionProfile surface to drift against.
      extensionProfile: {
        extensions: [
          {
            name: 'HealthExtension'
            properties: {
              publisher: 'Microsoft.ManagedServices'
              type: 'ApplicationHealthLinux'
              typeHandlerVersion: '1.0'
              autoUpgradeMinorVersion: true
              settings: {
                protocol: 'tcp'
                port: 80
              }
            }
          }
        ]
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${vmssName}-nic'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    subnet: {
                      id: subnet.id
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

output availabilitySetId string = availabilitySet.id
output dataDiskId string = dataDisk.id
output vmssId string = vmss.id
