// modules/storage/storage-account.bicep
// Reusable Storage Account module (blob + file services). Public access disabled by
// default; reach it via Private Endpoint(s) for blob and file.

@description('Storage account name (3-24 lowercase alphanumeric, globally unique).')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Azure region.')
param location string = resourceGroup().location

@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS', 'Standard_RAGRS', 'Premium_LRS', 'Premium_ZRS'])
param skuName string = 'Standard_ZRS'

@allowed(['StorageV2', 'FileStorage', 'BlockBlobStorage'])
param kind string = 'StorageV2'

@description('Disable public network access (recommended when fronted by Private Endpoint).')
param publicNetworkAccessEnabled bool = false

@description('Enable hierarchical namespace (Data Lake Gen2).')
param isHnsEnabled bool = false

@description('Minimum TLS version.')
param minimumTlsVersion string = 'TLS1_2'

param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: kind
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    isHnsEnabled: isHnsEnabled
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output primaryFileEndpoint string = storageAccount.properties.primaryEndpoints.file
@secure()
output primaryKey string = storageAccount.listKeys().keys[0].value
