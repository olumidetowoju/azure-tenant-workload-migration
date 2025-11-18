param location string
param vnetName string
param addressPrefix string
param subnetName string
param subnetPrefix string

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ addressPrefix ] }
    subnets: [
      {
        name: subnetName
        properties: { addressPrefix: subnetPrefix }
      }
    ]
  }
}

output vnetId string = vnet.id
