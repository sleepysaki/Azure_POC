// modules/web/app-service.bicep
// Reusable Web App (App Service) module. Deployed twice from main.bicep.
// Public network access disabled by default; reach it via Private Endpoint,
// and use regional VNet integration for outbound traffic.

@description('Name of the Web App (must be globally unique).')
param appName string

@description('Azure region.')
param location string = resourceGroup().location

@description('Resource id of the App Service Plan.')
param appServicePlanId string

@allowed(['Linux', 'Windows'])
param osType string = 'Linux'

@description('Linux runtime stack, e.g. \'NODE|20-lts\', \'DOTNETCORE|8.0\', \'PYTHON|3.12\'. Ignored for Windows.')
param linuxFxVersion string = 'NODE|20-lts'

@description('App settings as an array of {name, value}.')
param appSettings array = []

@description('Resource id of the subnet used for regional VNet integration (outbound). Leave empty to skip.')
param vnetIntegrationSubnetId string = ''

@description('Disable public network access (recommended when fronted by Private Endpoint).')
param publicNetworkAccessEnabled bool = false

@description('Enable system-assigned managed identity.')
param systemAssignedIdentity bool = true

param tags object = {}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  tags: tags
  kind: osType == 'Linux' ? 'app,linux' : 'app'
  identity: systemAssignedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
    virtualNetworkSubnetId: empty(vnetIntegrationSubnetId) ? null : vnetIntegrationSubnetId
    siteConfig: {
      linuxFxVersion: osType == 'Linux' ? linuxFxVersion : null
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: true
      appSettings: appSettings
    }
  }
}

output appId string = webApp.id
output appName string = webApp.name
output defaultHostName string = webApp.properties.defaultHostName
output principalId string = systemAssignedIdentity ? webApp.identity.principalId : ''
