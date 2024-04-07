@description('Name prefix for domain controllers')
param dcPrefix string

@description('Availability Set name')
param availSetName string

@description('Domain that the VM is joining')
param domainToJoin string

@description('Domain Administrator username')
param domainAdminUsername string

@description('Domain Administrator password')
@secure()
param domainAdminPassword string

@description('First domain controller local admin name')
param locAdminUserName string

@description('First domain controller local admin password')
@secure()
param locAdminPswrd string
param ipAddresses array

@description('OS versions for VMs deployed')
@allowed([
  '2008-R2-SP1'
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2016-Datacenter'
  '2019-Datacenter'
])
param winOSVer string

@description('Number of resources in template - 2 will be default for this template')
param resourceCount int = 2

@description('Type of storage deployed with the VMs')
@allowed([
  'Premium_LRS'
  'Standard_LRS'
])
param storAcctType string

@description('Existing vNet name')
param existing_vNetName string

@description('Existing vNet Resource Group')
param existing_vNet_rg string

@description('Existing subnet for deployment')
param existing_vNet_subnet string

@description('Location of deployed resources')
param location string

@description('Auto-generated container in staging storage account to receive post-build staging folder upload')
param _artifactsLocation string

@description('Auto-generated token to access _artifactsLocation')
@secure()
param _artifactsLocationSasToken string

var imagePublisher = 'MicrosoftWindowsServer'
var imageOffer = 'WindowsServer'
var extensionName = 'promote-adds'
var osDiskName = 'osDisk'
var dataDiskName = 'dataDisk'
var dataDiskSize = '100'
var vmSize = 'Standard_DS2_v2'
var promote_addsArchiveFolder = 'DSC'
var promote_addsArchiveFileName = 'promote-adds.zip'
var vNetID = resourceId(existing_vNet_rg, 'Microsoft.Network/virtualNetworks', existing_vNetName)
var subRef = '${vNetID}/subnets/${existing_vNet_subnet}'
var dcNicName = '${dcPrefix}-nic'

resource dcNicName_1_2_0 'Microsoft.Network/networkInterfaces@2016-10-01' = [for i in range(0, resourceCount): {
  name: concat(dcNicName, padLeft((i + 1), 2, '0'))
  location: location
  tags: {
    displayName: 'dcVmNic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ipAddresses[i]
          subnet: {
            id: subRef
          }
        }
      }
    ]
  }
  dependsOn: []
}]

resource availSet 'Microsoft.Compute/availabilitySets@2017-03-30' = {
  location: location
  name: availSetName
  properties: {
    platformUpdateDomainCount: 20
    platformFaultDomainCount: 2
  }
  tags: {
    displayName: 'availSet'
  }
  sku: {
    name: 'Aligned'
  }
  dependsOn: [
    dcNicName_1_2_0
  ]
}

resource dcPrefix_1_2_0 'Microsoft.Compute/virtualMachines@2017-03-30' = [for i in range(0, resourceCount): {
  name: concat(dcPrefix, padLeft((i + 1), 2, '0'))
  location: location
  tags: {
    displayName: 'dc'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    availabilitySet: {
      id: availSet.id
    }
    osProfile: {
      computerName: concat(dcPrefix, padLeft((i + 1), 2, '0'))
      adminUsername: locAdminUserName
      adminPassword: locAdminPswrd
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: winOSVer
        version: 'latest'
      }
      osDisk: {
        name: '${dcPrefix}${padLeft((i + 1), 2, '0')}-${osDiskName}'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storAcctType
        }
      }
      dataDisks: [
        {
          name: '${dcPrefix}${padLeft((i + 1), 2, '0')}-${dataDiskName}'
          caching: 'None'
          diskSizeGB: dataDiskSize
          lun: 0
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: storAcctType
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', concat(dcNicName, padLeft((i + 1), 2, '0')))
        }
      ]
    }
  }
  dependsOn: [
    dcNicName_1_2_0
  ]
}]

resource dcPrefix_1_2_0_extensionName_1_2_0 'Microsoft.Compute/virtualMachines/extensions@2018-06-01' = [for i in range(0, resourceCount): {
  name: '${dcPrefix}${padLeft((i + 1), 2, '0')}/${extensionName}${padLeft((i + 1), 2, '0')}'
  location: location
  tags: {
    displayName: 'promote-adds'
  }
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.19'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        WMFVersion: 'latest'
        url: '${_artifactsLocation}/${promote_addsArchiveFolder}/${promote_addsArchiveFileName}'
        script: 'promote-adds.ps1'
        function: 'CreateADReplicaDC'
      }
      configurationArguments: {
        DomainName: domainToJoin
      }
    }
    protectedSettings: {
      configurationArguments: {
        safemodeAdminCreds: {
          UserName: domainAdminUsername
          Password: domainAdminPassword
        }
        adminCreds: {
          UserName: domainAdminUsername
          Password: domainAdminPassword
        }
      }
    }
  }
  dependsOn: [
    dcPrefix_1_2_0
  ]
}]