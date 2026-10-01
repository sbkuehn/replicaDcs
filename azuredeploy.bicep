@description('Name prefix for domain controllers')
param dcPrefix string

@description('Domain that the VM is joining')
param domainToJoin string

@description('Domain Administrator username')
param domainAdminUsername string

@description('Domain Administrator password')
@secure()
param domainAdminPassword string

@description('Directory Services Restore Mode (DSRM) password. Defaults to the domain administrator password when left empty.')
@secure()
param safeModeAdminPassword string = ''

@description('Local administrator username for the domain controller VMs')
param locAdminUserName string

@description('Local administrator password for the domain controller VMs')
@secure()
param locAdminPswrd string

@description('Static private IP address for each domain controller. One domain controller is deployed per address.')
@minLength(1)
param ipAddresses array

@description('Active Directory site to place the domain controllers in. Leave empty to let AD choose the site from the subnet.')
param adSiteName string = ''

@description('OS versions for VMs deployed (Generation 2 images, required for Trusted Launch)')
@allowed([
  '2019-datacenter-gensecond'
  '2022-datacenter-g2'
  '2022-datacenter-azure-edition'
  '2025-datacenter-g2'
  '2025-datacenter-azure-edition'
])
param winOSVer string = '2022-datacenter-azure-edition'

@description('VM size for the domain controllers. If you choose a size with a local temp disk (e.g. Ddsv5), set dataDiskNumber to 2.')
param vmSize string = 'Standard_D2s_v5'

@description('Windows disk number of the NTDS/SYSVOL data disk: 1 for VM sizes without a local temp disk, 2 for sizes with one.')
@allowed([
  1
  2
])
param dataDiskNumber int = 1

@description('Size in GB of the NTDS/SYSVOL data disk')
param dataDiskSizeGB int = 64

@description('Type of storage deployed with the VMs')
@allowed([
  'Premium_LRS'
  'StandardSSD_LRS'
  'Standard_LRS'
])
param storAcctType string = 'Premium_LRS'

@description('Spread domain controllers across Availability Zones (recommended where the region supports them) or place them in an Availability Set.')
@allowed([
  'AvailabilityZones'
  'AvailabilitySet'
])
param availabilityOption string = 'AvailabilitySet'

@description('Availability Set name (used only when availabilityOption is AvailabilitySet)')
param availSetName string = '${dcPrefix}-avset'

@description('Existing vNet name')
param existingVnetName string

@description('Existing vNet Resource Group')
param existingVnetResourceGroup string

@description('Existing subnet for deployment')
param existingSubnetName string

@description('Location of deployed resources')
param location string = resourceGroup().location

@description('Base URI where the DSC folder is located, including a trailing slash')
param _artifactsLocation string = deployment().properties.templateLink.uri

@description('SAS token to access _artifactsLocation, if required')
@secure()
param _artifactsLocationSasToken string = ''

var useZones = availabilityOption == 'AvailabilityZones'
var extensionName = 'promote-adds'
var dscArchiveUri = uri(_artifactsLocation, 'DSC/promote-adds.zip${_artifactsLocationSasToken}')

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: existingVnetName
  scope: resourceGroup(existingVnetResourceGroup)

  resource subnet 'subnets' existing = {
    name: existingSubnetName
  }
}

resource dcNics 'Microsoft.Network/networkInterfaces@2024-05-01' = [for (ip, i) in ipAddresses: {
  name: '${dcPrefix}-nic${padLeft(i + 1, 2, '0')}'
  location: location
  tags: {
    displayName: 'dcVmNic'
  }
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ip
          subnet: {
            id: vnet::subnet.id
          }
        }
      }
    ]
  }
}]

resource availSet 'Microsoft.Compute/availabilitySets@2024-07-01' = if (!useZones) {
  name: availSetName
  location: location
  tags: {
    displayName: 'availSet'
  }
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformUpdateDomainCount: 5
    platformFaultDomainCount: 2
  }
}

resource dcVms 'Microsoft.Compute/virtualMachines@2024-07-01' = [for (ip, i) in ipAddresses: {
  name: '${dcPrefix}${padLeft(i + 1, 2, '0')}'
  location: location
  zones: useZones ? [string((i % 3) + 1)] : null
  tags: {
    displayName: 'dc'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    availabilitySet: useZones ? null : {
      id: availSet.id
    }
    osProfile: {
      computerName: '${dcPrefix}${padLeft(i + 1, 2, '0')}'
      adminUsername: locAdminUserName
      adminPassword: locAdminPswrd
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: winOSVer
        version: 'latest'
      }
      osDisk: {
        name: '${dcPrefix}${padLeft(i + 1, 2, '0')}-osDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: storAcctType
        }
      }
      dataDisks: [
        {
          // Host caching must be None for the disk holding NTDS/SYSVOL.
          name: '${dcPrefix}${padLeft(i + 1, 2, '0')}-dataDisk'
          caching: 'None'
          diskSizeGB: dataDiskSizeGB
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
          id: dcNics[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}]

resource dcDsc 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = [for (ip, i) in ipAddresses: {
  parent: dcVms[i]
  name: '${extensionName}${padLeft(i + 1, 2, '0')}'
  location: location
  tags: {
    displayName: 'promote-adds'
  }
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: dscArchiveUri
        script: 'promote-adds.ps1'
        function: 'CreateADReplicaDC'
      }
      configurationArguments: {
        DomainName: domainToJoin
        SiteName: adSiteName
        DataDiskNumber: string(dataDiskNumber)
      }
    }
    protectedSettings: {
      configurationArguments: {
        SafemodeAdminCreds: {
          UserName: domainAdminUsername
          Password: empty(safeModeAdminPassword) ? domainAdminPassword : safeModeAdminPassword
        }
        AdminCreds: {
          UserName: domainAdminUsername
          Password: domainAdminPassword
        }
      }
    }
  }
}]

output domainControllers array = [for (ip, i) in ipAddresses: {
  name: dcVms[i].name
  privateIPAddress: ip
}]
