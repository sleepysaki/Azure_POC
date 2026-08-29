// modules/compute/vm.bicep
// Reusable Windows/Linux VM module (NIC + optional data disks + VM). No public IP by design.

@description('VM name (<=15 chars recommended for Windows NetBIOS).')
param vmName string

@description('Azure region.')
param location string = resourceGroup().location

@description('VM size.')
param vmSize string = 'Standard_D2s_v5'

@allowed(['Windows', 'Linux'])
param osType string = 'Windows'

@description('Resource id of the subnet the NIC is attached to.')
param subnetId string

@description('Admin username.')
param adminUsername string

@description('Admin password (Windows) or SSH-disabled password fallback (Linux). Pass as secure param / from Key Vault reference.')
@secure()
param adminPassword string

@description('SSH public key data, required when osType is Linux and authenticationType is sshPublicKey.')
param sshPublicKey string = ''

@allowed(['password', 'sshPublicKey'])
param linuxAuthenticationType string = 'sshPublicKey'

@description('Image reference. Leave empty ({}) to use the default Windows Server 2022 / Ubuntu 22.04 image for the chosen osType.')
param imageReference object = {}

@description('OS disk size in GB.')
param osDiskSizeGB int = 128

@allowed(['Standard_LRS', 'StandardSSD_LRS', 'Premium_LRS'])
param osDiskType string = 'Premium_LRS'

@description('Number of empty data disks to attach.')
param dataDiskCount int = 0

@description('Size in GB for each data disk.')
param dataDiskSizeGB int = 128

param tags object = {}

var defaultImageReference = osType == 'Windows'
  ? {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
  : {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }

var effectiveImageReference = empty(imageReference) ? defaultImageReference : imageReference

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-${vmName}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: osType == 'Linux' && linuxAuthenticationType == 'sshPublicKey' ? null : adminPassword
      linuxConfiguration: osType == 'Linux' ? {
        disablePasswordAuthentication: linuxAuthenticationType == 'sshPublicKey'
        ssh: linuxAuthenticationType == 'sshPublicKey' ? {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        } : null
      } : null
    }
    storageProfile: {
      imageReference: effectiveImageReference
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGB
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      dataDisks: [
        for i in range(0, dataDiskCount): {
          lun: i
          createOption: 'Empty'
          diskSizeGB: dataDiskSizeGB
          managedDisk: {
            storageAccountType: osDiskType
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        // storageUri omitted -> Azure-managed boot diagnostics storage.
      }
    }
  }
}

output vmId string = vm.id
output vmName string = vm.name
output principalId string = vm.identity.principalId
output privateIPAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
