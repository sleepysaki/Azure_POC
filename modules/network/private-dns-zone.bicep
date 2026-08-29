// modules/network/private-dns-zone.bicep
// Reusable Private DNS Zone + VNet link module.

@description('Private DNS zone name, e.g. privatelink.vaultcore.azure.net')
param zoneName string

@description('Resource id of the VNet to link.')
param vnetId string

@description('Name for the vnet link resource. Unique per zone, so a static default is fine.')
param vnetLinkName string = 'vnet-link'

param tags object = {}

// Private DNS zones are global; location must be 'global'.
resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: zoneName
  location: 'global'
  tags: tags
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZone
  name: vnetLinkName
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

output zoneId string = dnsZone.id
output zoneName string = dnsZone.name
