// modules/web/function-app.bicep
// Reusable Azure Function App module, backed by the shared storage account.

@description('Name of the Function App (must be globally unique).')
param functionAppName string

@description('Azure region.')
param location string = resourceGroup().location

@description('Resource id of the App Service Plan (use an Elastic Premium or dedicated plan for VNet integration + private endpoints).')
param appServicePlanId string

@allowed(['Linux', 'Windows'])
param osType string = 'Linux'

@allowed(['dotnet-isolated', 'node', 'python', 'java', 'powershell'])
param functionRuntime string = 'node'

param functionRuntimeVersion string = '20'

@description('Storage account name backing the function app.')
param storageAccountName string

@secure()
param storageAccountKey string

@description('Resource id of the subnet used for regional VNet integration (outbound).')
param vnetIntegrationSubnetId string = ''

@description('Disable public network access (recommended when fronted by Private Endpoint).')
param publicNetworkAccessEnabled bool = false

param appSettings array = []

param tags object = {}

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccountKey}'

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: osType == 'Linux' ? 'functionapp,linux' : 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
    virtualNetworkSubnetId: empty(vnetIntegrationSubnetId) ? null : vnetIntegrationSubnetId
    siteConfig: {
      linuxFxVersion: osType == 'Linux' ? '${toUpper(functionRuntime)}|${functionRuntimeVersion}' : null
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: union([
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionRuntime
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
      ], appSettings)
    }
  }
}

output functionAppId string = functionApp.id
output functionAppName string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName
output principalId string = functionApp.identity.principalId
