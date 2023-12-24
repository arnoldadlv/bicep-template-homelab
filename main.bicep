@description('Enter a location. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Enter a Windows virtual machine name with a maximum of 12 characters')
@maxLength(12)
param vmName string

@description('Enter the admin user account name with a maximum of 20 characters.')
@maxLength(20)
param adminUsername string

@description('Enter the admin account password with a minimum of 12 characters.')
@minLength(12)
@secure()
param adminPassword string

@description('Enter the  virtual machine size')
@allowed( [
  'Standard_B1ms'
  'Standard_B1s'
])
param vmSize string = 'Standard_B1s'

@description('Select a Windows version')
@allowed( [
  '2019-Datacenter-smalldisk'
  '2019-Datacenter'
  '2016-Datacenter'
  '2022-datacenter'
])
param osVersion string = '2019-Datacenter-smalldisk'

var storageAccountName = 'hlstorageacc01'
var storageAccountSku = 'Standard_LRS'
var bastionHostName = 'bastion'
var bastionSubnet = '10.0.1.0/26'
var bastionSubnetName ='AzureBastionSubnet'
var bastionPublicIpName = 'bastionPublicIP'
var nsgName = 'NSG'
var computerName = '${vmName}-vm'
var nicName = '${vmName}-nic'
var osDiskName = '${vmName}-osdisk'
var vnetName = 'Vnet1'
var vnetPrefix = '10.0.0.0/16'
var subnetName = 'vmSubnet1'
var subnetPrefix = '10.0.0.0/24'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSku
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
   properties: {
    securityRules: [
       {
        name: 'RDP-Allow'
         properties: {
           description: 'Allow inbound RDP connections'
           protocol: 'Tcp'
           sourcePortRange: '*'
           destinationPortRange: '3389'
           sourceAddressPrefix: 'VirtualNetwork'
           destinationAddressPrefix: 'VirtualNetwork'
           access: 'Allow'
           priority: 200
           direction: 'Inbound'
         }
       }
    ]
   }
}

resource bastionPublicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: bastionPublicIpName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
   properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
   }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName 
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    } 
    subnets: [
       {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
       }
       {
         name: bastionSubnetName
         properties: {
          addressPrefix: bastionSubnet
         }
       }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-06-01' = {
  name: nicName
  location: location
  properties: {
    networkSecurityGroup: {
      id:nsg.id
    }
    ipConfigurations: [
     {
      name: 'ipConfig1'
      properties: {
        privateIPAllocationMethod: 'Dynamic'
        subnet: {
          id: '${vnet.id}/subnets/${subnetName}'
        }
      }
     }
    ]
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2023-06-01' = {
  name: bastionHostName
  location: location
  properties: {
     ipConfigurations: [
       {
        name: 'ipConfig'
        properties: {
          publicIPAddress: { 
            id: bastionPublicIP.id
          }
          subnet: {
            id: '${vnet.id}/subnets/${bastionSubnetName}'
          }
        }
       }
     ]
  }
}

resource windowsVM 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: computerName
  location: location
  properties: {
     hardwareProfile: {
      vmSize: vmSize
     }
     networkProfile: {
      networkInterfaces: [
         {
          id: nic.id
          properties: {
            deleteOption: 'Detach'
            primary: true
          }
         }
      ]
     }
     osProfile: {
      adminUsername:adminUsername
      adminPassword:adminPassword
      computerName:computerName
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
     }
     storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: osVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        name: osDiskName
        osType: 'Windows'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
     }
  }
}

output computerName string = windowsVM.properties.osProfile.computerName
output storageAccountKeys string = storageAccount.properties.accessTier
