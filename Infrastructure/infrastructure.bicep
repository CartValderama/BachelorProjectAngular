@description('The Azure region into which the resources should be deployed.')
param location string = 'Sweden Central'

@description('The type of environment. This must be nonprod or prod.')
@allowed([
  'nonprod'
  'prod'
])
param environmentType string

var appServiceAppName = 'aicee-api'
var appServicePlanName = 'aicee-api-plan'
var reactAppServiceAppName = 'aicee'

// Define the SKUs for each component based on the environment type.
var environmentConfigurationMap = {
  nonprod: {
    appServicePlan: {
      sku: {
        name: 'F1'
        capacity: 1
      }
    }
  }
  prod: {
    appServicePlan: {
      sku: {
        name: 'F1'
        capacity: 1
      }
    }
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: environmentConfigurationMap[environmentType].appServicePlan.sku
}

resource appServiceApp 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        
      ]
    }
  }
}


resource reactAppServiceApp 'Microsoft.Web/sites@2023-01-01' = {
  name: reactAppServiceAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        
      ]
    }
  }
}



// SQL Server and DB resources

@description('The name of the SQL logical server.')
param serverName string = 'aicee-sql-server'

@description('The name of the SQL Database.')
param sqlDBName string = 'aicee-sql-database'

@description('The administrator username of the SQL logical server.')
param administratorLogin string

@description('The administrator password of the SQL logical server.')
@secure()
param administratorLoginPassword string

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: serverName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: sqlDBName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}


// OpenAI Bicep Module

// Parameters
@description('Specifies the name of the Azure OpenAI resource.')
param OpenAIServiceName string = 'aks-${uniqueString(resourceGroup().id)}'

@description('Specifies the resource model definition representing SKU.')
param sku object = {
  name: 'S0'
}

@description('Specifies the identity of the OpenAI resource.')
param identity object = {
  type: 'SystemAssigned'
}

@description('Specifies the resource tags.')
param tags object = {
    environment: 'development'
}

//@description('Specifies an optional subdomain name used for token-based authentication.')
//param customSubDomainName string = ''

@description('Specifies whether or not public endpoint access is allowed for this account.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Specifies the OpenAI deployments to create.')
param deployments array = [
  {
    name: 'text-embedding-ada-002'
    version: '2'
    raiPolicyName: ''
    capacity: 1
    scaleType: 'Standard'
  }
  {
    name: 'gpt-35-turbo'
    version: '1106'
    raiPolicyName: ''
    capacity: 1
    scaleType: 'Standard'
  }
]

// Resources
resource openAi 'Microsoft.CognitiveServices/accounts@2022-12-01' = {
  name: OpenAIServiceName
  location: location 
  sku: sku
  kind: 'OpenAI'
  identity: identity
  tags: tags
  properties: {
    publicNetworkAccess: publicNetworkAccess
  }
}

resource model 'Microsoft.CognitiveServices/accounts/deployments@2022-12-01' =[for deployment in deployments: {
  name: deployment.name
  parent: openAi
  properties: {
    model: {
      format: 'OpenAI'
      name: deployment.name
      version: deployment.version
    }
    raiPolicyName: deployment.raiPolicyName
    scaleSettings: {
      capacity: deployment.capacity
      scaleType: deployment.scaleType
    }
  }
}]

// Outputs
output id string = openAi.id
output name string = openAi.name
