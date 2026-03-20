param location string = resourceGroup().location
param adminUsername string = 'azureuser'
param adminPublicKey string
param runnerToken string
param githubRepo string
param runnerVersion string

// ── Application Security Groups ──────────────────────────────────────────────

resource asgBastion 'Microsoft.Network/applicationSecurityGroups@2024-07-01' = {
  name: 'asg-bastion'
  location: location
}

resource asgProxy 'Microsoft.Network/applicationSecurityGroups@2024-07-01' = {
  name: 'asg-proxy'
  location: location
}

resource asgApp 'Microsoft.Network/applicationSecurityGroups@2024-07-01' = {
  name: 'asg-app'
  location: location
}

// ── Network Security Group ───────────────────────────────────────────────────

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: 'nsg-cloudsoft'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Internet-Bastion'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          destinationApplicationSecurityGroups: [{ id: asgBastion.id }]
        }
      }
      {
        name: 'Allow-HTTP-Internet-Proxy'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          destinationApplicationSecurityGroups: [{ id: asgProxy.id }]
        }
      }
      {
        name: 'Allow-HTTPS-Internet-Proxy'
        properties: {
          priority: 210
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          destinationApplicationSecurityGroups: [{ id: asgProxy.id }]
        }
      }
      {
        name: 'Allow-App-Proxy-To-App'
        properties: {
          priority: 300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '5000'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourceApplicationSecurityGroups: [{ id: asgProxy.id }]
          destinationApplicationSecurityGroups: [{ id: asgApp.id }]
        }
      }
      {
        name: 'Allow-SSH-Bastion-Internal'
        properties: {
          priority: 310
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourceApplicationSecurityGroups: [{ id: asgBastion.id }]
          destinationApplicationSecurityGroups: [{ id: asgProxy.id }]
        }
      }
      {
        name: 'Allow-SSH-Bastion-To-App'
        properties: {
          priority: 320
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourceApplicationSecurityGroups: [{ id: asgBastion.id }]
          destinationApplicationSecurityGroups: [{ id: asgApp.id }]
        }
      }
    ]
  }
}

// ── Virtual Network ──────────────────────────────────────────────────────────

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: 'vnet-cloudsoft'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

// ── Public IP Addresses ──────────────────────────────────────────────────────

resource pipBastion 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: 'pip-bastion'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource pipProxy 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: 'pip-proxy'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// ── Network Interfaces ───────────────────────────────────────────────────────

resource nicBastion 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: 'nic-bastion'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          publicIPAddress: { id: pipBastion.id }
          privateIPAllocationMethod: 'Dynamic'
          applicationSecurityGroups: [{ id: asgBastion.id }]
        }
      }
    ]
  }
}

resource nicProxy 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: 'nic-proxy'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          publicIPAddress: { id: pipProxy.id }
          privateIPAllocationMethod: 'Dynamic'
          applicationSecurityGroups: [{ id: asgProxy.id }]
        }
      }
    ]
  }
}

resource nicApp 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: 'nic-app'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: vnet.properties.subnets[0].id }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.10'
          applicationSecurityGroups: [{ id: asgApp.id }]
        }
      }
    ]
  }
}

// ── CosmosDB (MongoDB API) ───────────────────────────────────────────────────

var cosmosName = 'cosmos-cloudsoft-${uniqueString(resourceGroup().id)}'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: cosmosName
  location: location
  kind: 'MongoDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [{ locationName: location, failoverPriority: 0 }]
    capabilities: [{ name: 'EnableMongo' }]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
  }
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2024-11-15' = {
  parent: cosmosAccount
  name: 'cloudsoft'
  properties: {
    resource: { id: 'cloudsoft' }
  }
}

resource cosmosCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2024-11-15' = {
  parent: cosmosDb
  name: 'subscribers'
  properties: {
    resource: {
      id: 'subscribers'
      shardKey: { email: 'Hash' }
    }
  }
}

// ── Storage Account ──────────────────────────────────────────────────────────

var storageName = 'stcloudsoft${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource imageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'images'
}

// ── Cloud-Init ───────────────────────────────────────────────────────────────

var cloudInitBastion = loadTextContent('cloud-init-bastion.yaml')

var cloudInitProxy = replace(
  replace(
    loadTextContent('cloud-init-proxy.yaml'),
    '__PROXY_PUBLIC_IP__',
    pipProxy.properties.ipAddress
  ),
  '__APP_PRIVATE_IP__',
  '10.0.1.10'
)

var cloudInitApp = replace(
  replace(
    replace(
      replace(
        replace(
          replace(
            loadTextContent('cloud-init-app.yaml'),
            '__COSMOS_CONNECTION_STRING__',
            cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
          ),
          '__STORAGE_ACCOUNT_NAME__',
          storageAccount.name
        ),
        '__STORAGE_ACCOUNT_KEY__',
        storageAccount.listKeys().keys[0].value
      ),
      '__RUNNER_TOKEN__',
      runnerToken
    ),
    '__GITHUB_REPO__',
    githubRepo
  ),
  '__RUNNER_VERSION__',
  runnerVersion
)

// ── Virtual Machines ─────────────────────────────────────────────────────────

resource vmBastion 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: 'vm-bastion'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    osProfile: {
      computerName: 'vm-bastion'
      adminUsername: adminUsername
      customData: base64(cloudInitBastion)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    networkProfile: { networkInterfaces: [{ id: nicBastion.id }] }
  }
}

resource vmProxy 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: 'vm-proxy'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    osProfile: {
      computerName: 'vm-proxy'
      adminUsername: adminUsername
      customData: base64(cloudInitProxy)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    networkProfile: { networkInterfaces: [{ id: nicProxy.id }] }
  }
}

resource vmApp 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: 'vm-app'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    osProfile: {
      computerName: 'vm-app'
      adminUsername: adminUsername
      customData: base64(cloudInitApp)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    networkProfile: { networkInterfaces: [{ id: nicApp.id }] }
  }
}

// ── Outputs ──────────────────────────────────────────────────────────────────

output proxyPublicIp string = pipProxy.properties.ipAddress
output bastionPublicIp string = pipBastion.properties.ipAddress
output storageAccountName string = storageAccount.name
