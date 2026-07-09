param location string = 'australiaeast'
param environment string = 'test'

@description('Admin password for the VM (test estate only).')
@secure()
param adminPassword string

var vmName = 'vm-drift-test'
var adminUsername = 'azureuser'

// Reference the estate VNet/subnet created by the messaging-dns module.
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: 'vnet-drift-test'
}
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnet
  name: 'default'
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
  }
  tags: {
    environment: environment
    managed: 'true'
  }
}

// Small burstable VM — cheapest option that exercises the agent's VM property
// comparison, osProfile write-only redaction, and disk/NIC validators.
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3' // B-series has no/zero quota in australiaeast on this sub; DSv3 has quota
    }
    osProfile: {
      computerName: 'vmdrifttest'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
  tags: {
    environment: environment
    managed: 'true'
    purpose: 'drift-detection-test'
  }
}

// Azure Monitor Agent — declared in IaC (not policy-deployed for this pass).
// Exercises the agent's VM extension child coverage (Microsoft.Compute/
// virtualMachines/extensions).
resource ama 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: vm
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.29'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

output vmId string = vm.id
output vmName string = vm.name
