// modules/keyvault/key-vault.bicep
// Reusable Key Vault module using RBAC authorization (no access policies).
// Public network access disabled by default; reach it via Private Endpoint.

@description('Key Vault name (3-24 chars, globally unique).')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Azure region.')
param location string = resourceGroup().location

@description('Azure AD tenant id.')
param tenantId string = subscription().tenantId

@allowed(['standard', 'premium'])
param skuName string = 'standard'

@description('Disable public network access (recommended when fronted by Private Endpoint).')
param publicNetworkAccessEnabled bool = false

param enablePurgeProtection bool = true
param softDeleteRetentionInDays int = 90

param tags object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: skuName
    }
    tenantId: tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
