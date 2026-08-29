// modules/web/app-service-plan.bicep
// Reusable App Service Plan, shared by App Services and/or a Function App.

@description('Name of the App Service Plan.')
param planName string

@description('Azure region.')
param location string = resourceGroup().location

@allowed(['Windows', 'Linux'])
param osType string = 'Linux'

@description('SKU name, e.g. P1v3, S1, EP1 (Elastic Premium for Functions).')
param skuName string = 'P1v3'

@description('SKU tier, e.g. PremiumV3, Standard, ElasticPremium.')
param skuTier string = 'PremiumV3'

@description('Number of workers.')
param capacity int = 1

param tags object = {}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  kind: osType == 'Linux' ? 'linux' : 'app'
  sku: {
    name: skuName
    tier: skuTier
    capacity: capacity
  }
  properties: {
    reserved: osType == 'Linux'
  }
}

output planId string = plan.id
output planName string = plan.name
