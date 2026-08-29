// modules/network/vnet.bicep
// Reusable Virtual Network + subnets module.

@description('Name of the virtual network.')
param vnetName string

@description('Azure region.')
param location string = resourceGroup().location

@description('Address space for the VNet, e.g. [\'10.10.0.0/16\'].')
param addressPrefixes array

@description('Subnets to create.')
param subnets array = []
/* Example item:
{
  name: 'snet-vm'
  addressPrefix: '10.10.1.0/24'
  delegation: ''                         // e.g. 'Microsoft.Web/serverFarms'
  privateEndpointNetworkPolicies: 'Disabled'
  networkSecurityGroupId: ''             // optional NSG resource id
  serviceEndpoints: []                   // optional array of service endpoint objects
}
*/

param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
          privateEndpointNetworkPolicies: subnet.?privateEndpointNetworkPolicies ?? 'Disabled'
          delegations: empty(subnet.?delegation ?? '') ? [] : [
            {
              name: '${subnet.name}-delegation'
              properties: {
                serviceName: subnet.delegation
              }
            }
          ]
          networkSecurityGroup: empty(subnet.?networkSecurityGroupId ?? '') ? null : {
            id: subnet.networkSecurityGroupId
          }
          serviceEndpoints: subnet.?serviceEndpoints ?? []
        }
      }
    ]
  }
}

@description('Resource id of the VNet.')
output vnetId string = vnet.id

@description('Name of the VNet.')
output vnetName string = vnet.name

@description('Map of subnet name to subnet resource id.')
output subnetIds object = toObject(vnet.properties.subnets, s => s.name, s => s.id)
