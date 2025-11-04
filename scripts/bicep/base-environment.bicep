param location string = 'eastus'
param rgName string
param vnetName string
param subnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      { name: subnetName
        properties: { addressPrefix: '10.0.1.0/24' } }
    ]
  }
}

output vnetId string = vnet.id
