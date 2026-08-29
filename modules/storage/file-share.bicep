// modules/storage/file-share.bicep
// Reusable Azure Files share, child of an existing storage account.

@description('Name of the parent storage account.')
param storageAccountName string

@description('Name of the file share.')
param shareName string

@description('Quota in GiB.')
param shareQuotaGiB int = 100

@allowed(['TransactionOptimized', 'Hot', 'Cool', 'Premium'])
param accessTier string = 'TransactionOptimized'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' existing = {
  parent: storageAccount
  name: 'default'
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: shareName
  properties: {
    shareQuota: shareQuotaGiB
    accessTier: accessTier
    enabledProtocols: 'SMB'
  }
}

output shareId string = share.id
output shareName string = share.name
