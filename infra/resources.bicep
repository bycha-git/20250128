param name string = 'azurechat-demo'
param resourceToken string

param location string = resourceGroup().location

@secure()
param nextAuthHash string = uniqueString(newGuid())

param tags object = {}

var webapp_name = toLower('${name}-webapp-${resourceToken}')
var appservice_name = toLower('${name}-app-${resourceToken}')
var kv_prefix = take(name, 7)
var keyVaultName = toLower('${kv_prefix}-kv-${resourceToken}')
var la_workspace_name = toLower('${name}-la-${resourceToken}')
var diagnostic_setting_name = 'AppServiceConsoleLogs'

var keyVaultSecretsOfficerRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')

resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appservice_name
  location: location
  tags: tags
  properties: {
    reserved: true
  }
  sku: {
    name: 'P0v3'
    tier: 'Premium0V3'
    size: 'P0v3'
    family: 'Pv3'
    capacity: 1
  }
  kind: 'linux'
}

resource webApp 'Microsoft.Web/sites@2020-06-01' = {
  name: webapp_name
  location: location
  tags: union(tags, { 'azd-service-name': 'frontend' })
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'node|20-lts'
      alwaysOn: true
      appCommandLine: 'node .next/standalone/server.js'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'CUSTOM_BUILD_COMMAND'
          value: 'bash build.sh'
        }
        {
          name: 'NEXTAUTH_SECRET'
          value: '@Microsoft.KeyVault(VaultName=${kv.name};SecretName=${kv::NEXTAUTH_SECRET.name})'
        }
        {
          name: 'NEXTAUTH_URL'
          value: 'https://${webapp_name}.azurewebsites.net'
        }
        {
          name: 'AZURE_COSMOSDB_URI'
          value: ''
        }
        {
          name: 'AZURE_COSMOSDB_KEY'
          value: ''
        }
        {
          name: 'AZURE_COSMOSDB_DB_NAME'
          value: 'chat'
        }
        {
          name: 'AZURE_COSMOSDB_CONTAINER_NAME'
          value: 'history'
        }
        {
          name: 'AZURE_COSMOSDB_CONFIG_CONTAINER_NAME'
          value: 'config'
        }
        {
          name: 'AZURE_COSMOSDB_EMPLOYEE_CONTAINER_NAME'
          value: 'employee'
        }
        {
          name: 'AZURE_COSMOSDB_DEPARTMENT_CONTAINER_NAME'
          value: 'department'
        }
        {
          name: 'AZURE_COSMOSDB_APPROVAL_CONTAINER_NAME'
          value: 'approval'
        }
        {
          name: 'AZURE_AD_CLIENT_ID'
          value: ''
        }
        {
          name: 'AZURE_AD_CLIENT_SECRET'
          value: ''
        }
        {
          name: 'AZURE_AD_TENANT_ID'
          value: ''
        }
        {
          name: 'AZURE_SPEECH_REGION'
          value: ''
        }
        {
          name: 'AZURE_SPEECH_KEY'
          value: ''
        }
        {
          name: 'AZURE_STORAGE_ACCOUNT_NAME'
          value: ''
        }
        {
          name: 'AZURE_STORAGE_ACCOUNT_KEY'
          value: ''
        }
        {
          name: 'AZURE_STORAGE_ATTACHMENT_CONTAINER_NAME'
          value: 'attachment'
        }
        {
          name: 'REACT_APP_APPROVAL_MESSAGE'
          value: ''
        }
      ]
    }
  }
  identity: { type: 'SystemAssigned'}

  resource configLogs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: { fileSystem: { level: 'Verbose' } }
      detailedErrorMessages: { enabled: true }
      failedRequestsTracing: { enabled: true }
      httpLogs: { fileSystem: { enabled: true, retentionInDays: 1, retentionInMb: 35 } }
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: la_workspace_name
  location: location
}

resource webDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnostic_setting_name
  scope: webApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
    ]
    metrics: []
  }
}

resource kvFunctionAppPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(kv.id, webApp.name, keyVaultSecretsOfficerRole)
  scope: kv
  properties: {
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: keyVaultSecretsOfficerRole
  }
}

resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: false
  }

  resource NEXTAUTH_SECRET 'secrets' = {
    name: 'NEXTAUTH-SECRET'
    properties: {
      contentType: 'text/plain'
      value: nextAuthHash
    }
  }
}

output url string = 'https://${webApp.properties.defaultHostName}'
