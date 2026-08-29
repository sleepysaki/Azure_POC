// modules/network/private-endpoint.bicep
// Generic, reusable Private Endpoint (+ optional Private DNS Zone Group) module.
// Works for Key Vault, Storage (blob/file), Data Factory, or any resource that supports PE.

@description('Name of the private endpoint.')
param privateEndpointName string

@description('Azure region.')
param location string = resourceGroup().location

@description('Resource id of the subnet the private endpoint NIC will be placed in.')
param subnetId string

@description('Resource id of the target PaaS resource (storage account, key vault, ADF, etc).')
param targetResourceId string

@description('groupIds for the service connection, e.g. [\'vault\'], [\'blob\'], [\'file\'], [\'dataFactory\'].')
param groupIds array

@description('Optional: resource id of an existing Private DNS Zone to link for auto-registration. Leave empty to skip DNS zone group creation.')
param privateDnsZoneId string = ''

param tags object = {}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: groupIds
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = if (!empty(privateDnsZoneId)) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output privateEndpointId string = privateEndpoint.id
output privateEndpointName string = privateEndpoint.name
output nicId string = privateEndpoint.properties.networkInterfaces[0].id
