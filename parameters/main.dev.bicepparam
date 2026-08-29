using '../main.bicep'

param namePrefix = 'contoso'
param environment = 'dev'
param location = 'eastus2'

param storageAccountName = 'contosodevsa001'
param keyVaultName = 'contoso-dev-kv001'
param dataFactoryName = 'contoso-dev-adf'

param vmAdminUsername = 'azadmin'
// Do not commit real secrets. Supply at deploy time, e.g.:
//   az deployment group create ... --parameters vmAdminPassword=$env:VM_ADMIN_PASSWORD
param vmAdminPassword = ''
param vmSshPublicKey = ''

param tags = {
  project: 'contoso'
  environment: 'dev'
  managedBy: 'bicep'
  costCenter: 'it-infra'
}
