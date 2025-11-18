// ==========================
// Azure Tenant Workload Migration – Day 5
// main.bicep (complete file)
// ==========================

// -------- Parameters --------
param location string = 'eastus'        // default region for most resources
param sqlLocation string = 'eastus2'    // SQL in a different region (fixes East US restriction)

param tags object = {
  Owner: 'olumidetowoju'
  Scenario: 'acquisition'
  Lab: 'day05'
}

// Network & names
param vnetAddress string = '10.1.0.0/16'
param subnetAddress string = '10.1.1.0/24'
param vnetName string = 'vnet-tgt-app'
param subnetName string = 'snet-tgt-app'

// Resource names (supply storage/sql names via params or params/dev.eastus.json)
param storageName string
param sqlServerName string

// Secrets (supply at deploy time – do NOT commit to Git)
@secure()
param sqlAdminPassword string

param vmName string = 'vm-app-01'
@secure()
param vmAdminPassword string

// VM SKU (adjust if region capacity limits)
param vmSize string = 'Standard_B1ls'

// -------- Modules --------
// Network
module net './modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: vnetName
    addressPrefix: vnetAddress
    subnetName: subnetName
    subnetPrefix: subnetAddress
  }
}

// Storage
module sa './modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    storageName: storageName
    tags: tags
  }
}

// SQL (note: deployed to sqlLocation)
module sql './modules/sql.bicep' = {
  name: 'sql'
  params: {
    location: sqlLocation
    sqlServerName: sqlServerName
    adminPassword: sqlAdminPassword
    tags: tags
  }
}

// VM
module vm './modules/vm.bicep' = {
  name: 'vm'
  params: {
    location: location
    vmName: vmName
    subnetId: '${net.outputs.vnetId}/subnets/${subnetName}'
    adminPassword: vmAdminPassword
    vmSize: vmSize
    tags: tags
  }
}

// -------- Outputs --------
output vnetId string        = net.outputs.vnetId
output storageId string     = sa.outputs.storageId
output sqlServerId string   = sql.outputs.sqlServerId
output databaseId string    = sql.outputs.databaseId
output vmId string          = vm.outputs.vmId
