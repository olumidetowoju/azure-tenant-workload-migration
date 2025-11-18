param location string
param sqlServerName string
@secure()
param adminPassword string
param adminUser string = 'sqladmin-learner'
param tags object = {}

resource server 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: adminUser
    administratorLoginPassword: adminPassword
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: '1.2'
  }
}

resource db 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  name: '${sqlServerName}/sqldb01'
  location: location
  properties: {
    sku: {
      name: 'Basic'
      tier: 'Basic'
    }
  }
}

output sqlServerId string = server.id
output databaseId string = db.id
