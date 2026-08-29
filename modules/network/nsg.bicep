// modules/network/nsg.bicep
// Reusable Network Security Group module.

@description('Name of the NSG.')
param nsgName string

@description('Azure region.')
param location string = resourceGroup().location

@description('Security rules to apply.')
param securityRules array = []
/* Example item:
{
  name: 'Allow-HTTPS-Inbound'
  priority: 100
  direction: 'Inbound'
  access: 'Allow'
  protocol: 'Tcp'
  sourcePortRange: '*'
  destinationPortRange: '443'
  sourceAddressPrefix: 'VirtualNetwork'
  destinationAddressPrefix: '*'
}
*/

param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      for rule in securityRules: {
        name: rule.name
        properties: {
          priority: rule.priority
          direction: rule.direction
          access: rule.access
          protocol: rule.protocol
          sourcePortRange: rule.?sourcePortRange ?? '*'
          destinationPortRange: rule.?destinationPortRange ?? '*'
          sourceAddressPrefix: rule.?sourceAddressPrefix ?? '*'
          destinationAddressPrefix: rule.?destinationAddressPrefix ?? '*'
        }
      }
    ]
  }
}

output nsgId string = nsg.id
output nsgName string = nsg.name
