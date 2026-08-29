// modules/data/data-factory.bicep
// Reusable Azure Data Factory module.
// Public network access disabled by default; reach it via Private Endpoint (groupId 'dataFactory').

@description('Data Factory name (globally unique).')
param dataFactoryName string

@description('Azure region.')
param location string = resourceGroup().location

@description('Disable public network access (recommended when fronted by Private Endpoint).')
param publicNetworkAccessEnabled bool = false

@description('Enable a managed virtual network for the factory (required for managed private endpoints to SaaS-only sources).')
param managedVirtualNetworkEnabled bool = true

param tags object = {}

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
  }
}

resource managedVnet 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = if (managedVirtualNetworkEnabled) {
  parent: dataFactory
  name: 'default'
  properties: {}
}

output dataFactoryId string = dataFactory.id
output dataFactoryName string = dataFactory.name
output principalId string = dataFactory.identity.principalId
