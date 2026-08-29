// main.bicep
// Orchestrator: wires together reusable modules under /modules into the full environment
// (VNet, 4 VMs, 2 App Services, 1 Function App, 1 Key Vault, 1 Data Factory, Storage
// Account + Azure Files, and Private Endpoints for all PaaS services).
//
// Scope: resource group. Create the RG first (e.g. az group create) then deploy this.

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Core parameters
// ---------------------------------------------------------------------------

@description('Short name used to prefix/compose resource names, e.g. "contoso".')
@minLength(2)
@maxLength(12)
param namePrefix string

@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

param location string = resourceGroup().location

@description('Common tags applied to every resource. Defaults to {} — set explicitly per environment via the .bicepparam file.')
param tags object = {}

// ---------------------------------------------------------------------------
// Networking parameters
// ---------------------------------------------------------------------------

param vnetAddressPrefix string = '10.10.0.0/16'
param vmSubnetPrefix string = '10.10.1.0/24'
param appSubnetPrefix string = '10.10.2.0/24'
param peSubnetPrefix string = '10.10.3.0/24'

// ---------------------------------------------------------------------------
// Compute (VM) parameters
// ---------------------------------------------------------------------------

@description('Definitions for the 4 VMs to deploy.')
param vmConfigs array = [
  { suffix: 'app1', size: 'Standard_D2s_v5', osType: 'Windows' }
  { suffix: 'app2', size: 'Standard_D2s_v5', osType: 'Windows' }
  { suffix: 'db1', size: 'Standard_D4s_v5', osType: 'Linux' }
  { suffix: 'db2', size: 'Standard_D4s_v5', osType: 'Linux' }
]

param vmAdminUsername string = 'azadmin'

@secure()
param vmAdminPassword string

@description('SSH public key used for Linux VMs (if any vmConfigs entries use osType Linux).')
param vmSshPublicKey string = ''

// ---------------------------------------------------------------------------
// App Service / Function parameters
// ---------------------------------------------------------------------------

@description('Definitions for the 2 App Services to deploy.')
param appServiceConfigs array = [
  { suffix: 'web', linuxFxVersion: 'NODE|20-lts' }
  { suffix: 'api', linuxFxVersion: 'DOTNETCORE|8.0' }
]

param appServicePlanSkuName string = 'P1v3'
param appServicePlanSkuTier string = 'PremiumV3'

param functionPlanSkuName string = 'EP1'
param functionPlanSkuTier string = 'ElasticPremium'

// ---------------------------------------------------------------------------
// Storage / Key Vault / Data Factory parameters
// ---------------------------------------------------------------------------

@minLength(3)
@maxLength(24)
param storageAccountName string

param fileShareName string = 'appdata'
param fileShareQuotaGiB int = 100

@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Leave empty to derive as "<namePrefix>-<environment>-adf".')
param dataFactoryName string = ''

// ---------------------------------------------------------------------------
// Naming
// ---------------------------------------------------------------------------

var vnetName = '${namePrefix}-${environment}-vnet'
var nsgVmName = '${namePrefix}-${environment}-nsg-vm'
var appPlanName = '${namePrefix}-${environment}-plan-web'
var functionPlanName = '${namePrefix}-${environment}-plan-func'
var functionAppName = '${namePrefix}-${environment}-func'
var effectiveDataFactoryName = empty(dataFactoryName) ? '${namePrefix}-${environment}-adf' : dataFactoryName

// ---------------------------------------------------------------------------
// Networking
// ---------------------------------------------------------------------------

module vmNsg 'modules/network/nsg.bicep' = {
  name: 'deploy-nsg-vm'
  params: {
    nsgName: nsgVmName
    location: location
    tags: tags
    securityRules: [
      {
        name: 'Allow-VNet-Inbound'
        priority: 100
        direction: 'Inbound'
        access: 'Allow'
        protocol: '*'
        sourceAddressPrefix: 'VirtualNetwork'
        destinationAddressPrefix: 'VirtualNetwork'
        sourcePortRange: '*'
        destinationPortRange: '*'
      }
      {
        name: 'Deny-Internet-Inbound'
        priority: 4096
        direction: 'Inbound'
        access: 'Deny'
        protocol: '*'
        sourceAddressPrefix: 'Internet'
        destinationAddressPrefix: '*'
        sourcePortRange: '*'
        destinationPortRange: '*'
      }
    ]
  }
}

module network 'modules/network/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    vnetName: vnetName
    location: location
    tags: tags
    addressPrefixes: [vnetAddressPrefix]
    subnets: [
      {
        name: 'snet-vm'
        addressPrefix: vmSubnetPrefix
        networkSecurityGroupId: vmNsg.outputs.nsgId
      }
      {
        name: 'snet-appsvc'
        addressPrefix: appSubnetPrefix
        delegation: 'Microsoft.Web/serverFarms'
        privateEndpointNetworkPolicies: 'Disabled'
      }
      {
        name: 'snet-pe'
        addressPrefix: peSubnetPrefix
        privateEndpointNetworkPolicies: 'Disabled'
      }
    ]
  }
}

var subnetIds = network.outputs.subnetIds

// Private DNS zones for each PaaS service reached via Private Endpoint.
module dnsZoneKeyVault 'modules/network/private-dns-zone.bicep' = {
  name: 'deploy-dns-kv'
  params: {
    zoneName: 'privatelink.vaultcore.azure.net'
    vnetId: network.outputs.vnetId
    tags: tags
  }
}

module dnsZoneBlob 'modules/network/private-dns-zone.bicep' = {
  name: 'deploy-dns-blob'
  params: {
    zoneName: 'privatelink.blob.${environment().suffixes.storage}'
    vnetId: network.outputs.vnetId
    tags: tags
  }
}

module dnsZoneFile 'modules/network/private-dns-zone.bicep' = {
  name: 'deploy-dns-file'
  params: {
    zoneName: 'privatelink.file.${environment().suffixes.storage}'
    vnetId: network.outputs.vnetId
    tags: tags
  }
}

module dnsZoneAdf 'modules/network/private-dns-zone.bicep' = {
  name: 'deploy-dns-adf'
  params: {
    zoneName: 'privatelink.datafactory.azure.net'
    vnetId: network.outputs.vnetId
    tags: tags
  }
}

// ---------------------------------------------------------------------------
// Compute: 4 VMs
// ---------------------------------------------------------------------------

module virtualMachines 'modules/compute/vm.bicep' = [
  for vmConfig in vmConfigs: {
    name: 'deploy-vm-${vmConfig.suffix}'
    params: {
      vmName: '${namePrefix}${environment}${vmConfig.suffix}'
      location: location
      tags: tags
      vmSize: vmConfig.size
      osType: vmConfig.osType
      subnetId: subnetIds['snet-vm']
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      sshPublicKey: vmSshPublicKey
    }
  }
]

// ---------------------------------------------------------------------------
// App Services: 2 web apps on a shared Premium v3 plan
// ---------------------------------------------------------------------------

module appServicePlan 'modules/web/app-service-plan.bicep' = {
  name: 'deploy-plan-web'
  params: {
    planName: appPlanName
    location: location
    tags: tags
    osType: 'Linux'
    skuName: appServicePlanSkuName
    skuTier: appServicePlanSkuTier
  }
}

module appServices 'modules/web/app-service.bicep' = [
  for appServiceConfig in appServiceConfigs: {
    name: 'deploy-app-${appServiceConfig.suffix}'
    params: {
      appName: '${namePrefix}-${environment}-${appServiceConfig.suffix}'
      location: location
      tags: tags
      appServicePlanId: appServicePlan.outputs.planId
      osType: 'Linux'
      linuxFxVersion: appServiceConfig.linuxFxVersion
      vnetIntegrationSubnetId: subnetIds['snet-appsvc']
      publicNetworkAccessEnabled: false
    }
  }
]

// ---------------------------------------------------------------------------
// Storage Account + Azure Files
// ---------------------------------------------------------------------------

module storage 'modules/storage/storage-account.bicep' = {
  name: 'deploy-storage'
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: tags
    publicNetworkAccessEnabled: false
  }
}

module fileShare 'modules/storage/file-share.bicep' = {
  name: 'deploy-file-share'
  params: {
    storageAccountName: storage.outputs.storageAccountName
    shareName: fileShareName
    shareQuotaGiB: fileShareQuotaGiB
  }
}

// ---------------------------------------------------------------------------
// Azure Function (on its own Elastic Premium plan, backed by the storage account)
// ---------------------------------------------------------------------------

module functionPlan 'modules/web/app-service-plan.bicep' = {
  name: 'deploy-plan-func'
  params: {
    planName: functionPlanName
    location: location
    tags: tags
    osType: 'Linux'
    skuName: functionPlanSkuName
    skuTier: functionPlanSkuTier
  }
}

module functionApp 'modules/web/function-app.bicep' = {
  name: 'deploy-function'
  params: {
    functionAppName: functionAppName
    location: location
    tags: tags
    appServicePlanId: functionPlan.outputs.planId
    osType: 'Linux'
    functionRuntime: 'node'
    functionRuntimeVersion: '20'
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.primaryKey
    vnetIntegrationSubnetId: subnetIds['snet-appsvc']
    publicNetworkAccessEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Key Vault
// ---------------------------------------------------------------------------

module keyVault 'modules/keyvault/key-vault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    keyVaultName: keyVaultName
    location: location
    tags: tags
    publicNetworkAccessEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Data Factory
// ---------------------------------------------------------------------------

module dataFactory 'modules/data/data-factory.bicep' = {
  name: 'deploy-adf'
  params: {
    dataFactoryName: effectiveDataFactoryName
    location: location
    tags: tags
    publicNetworkAccessEnabled: false
  }
}

// ---------------------------------------------------------------------------
// Private Endpoints (Key Vault, Blob, File, Data Factory)
// ---------------------------------------------------------------------------

module peKeyVault 'modules/network/private-endpoint.bicep' = {
  name: 'deploy-pe-kv'
  params: {
    privateEndpointName: '${namePrefix}-${environment}-pe-kv'
    location: location
    tags: tags
    subnetId: subnetIds['snet-pe']
    targetResourceId: keyVault.outputs.keyVaultId
    groupIds: ['vault']
    privateDnsZoneId: dnsZoneKeyVault.outputs.zoneId
  }
}

module peBlob 'modules/network/private-endpoint.bicep' = {
  name: 'deploy-pe-blob'
  params: {
    privateEndpointName: '${namePrefix}-${environment}-pe-blob'
    location: location
    tags: tags
    subnetId: subnetIds['snet-pe']
    targetResourceId: storage.outputs.storageAccountId
    groupIds: ['blob']
    privateDnsZoneId: dnsZoneBlob.outputs.zoneId
  }
}

module peFile 'modules/network/private-endpoint.bicep' = {
  name: 'deploy-pe-file'
  params: {
    privateEndpointName: '${namePrefix}-${environment}-pe-file'
    location: location
    tags: tags
    subnetId: subnetIds['snet-pe']
    targetResourceId: storage.outputs.storageAccountId
    groupIds: ['file']
    privateDnsZoneId: dnsZoneFile.outputs.zoneId
  }
}

module peDataFactory 'modules/network/private-endpoint.bicep' = {
  name: 'deploy-pe-adf'
  params: {
    privateEndpointName: '${namePrefix}-${environment}-pe-adf'
    location: location
    tags: tags
    subnetId: subnetIds['snet-pe']
    targetResourceId: dataFactory.outputs.dataFactoryId
    groupIds: ['dataFactory']
    privateDnsZoneId: dnsZoneAdf.outputs.zoneId
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output vnetId string = network.outputs.vnetId
output vmNames array = [for i in range(0, length(vmConfigs)): virtualMachines[i].outputs.vmName]
output appServiceNames array = [for i in range(0, length(appServiceConfigs)): appServices[i].outputs.appName]
output functionAppName string = functionApp.outputs.functionAppName
output storageAccountName string = storage.outputs.storageAccountName
output fileShareName string = fileShare.outputs.shareName
output keyVaultUri string = keyVault.outputs.keyVaultUri
output dataFactoryName string = dataFactory.outputs.dataFactoryName
