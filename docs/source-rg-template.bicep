param virtualNetworks_vnet_src_app_name string

resource virtualNetworks_vnet_src_app_name_resource 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  location: 'eastus'
  name: virtualNetworks_vnet_src_app_name
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    enableDdosProtection: false
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        id: virtualNetworks_vnet_src_app_name_snet_src_app.id
        name: 'snet-src-app'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: []
  }
}

resource virtualNetworks_vnet_src_app_name_snet_src_app 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' = {
  name: '${virtualNetworks_vnet_src_app_name}/snet-src-app'
  properties: {
    addressPrefix: '10.0.1.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_src_app_name_resource
  ]
}
