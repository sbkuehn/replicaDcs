Configuration CreateADReplicaDC {
    param (
        [Parameter(Mandatory)]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SafemodeAdminCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        # AD site to place the DC in. Leave empty to let AD pick the site from the DC's subnet.
        [string]$SiteName = '',

        # Disk number of the NTDS/SYSVOL data disk (LUN 0). This is 1 on VM sizes without a
        # local temp disk (e.g. Dsv5) and 2 on sizes that have one (e.g. DSv2, Ddsv5).
        [string]$DataDiskNumber = '1',

        [int]$RetryCount = 20,

        [int]$RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ActiveDirectoryDsc
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName StorageDsc

    [System.Management.Automation.PSCredential]$DomainCreds =
        New-Object System.Management.Automation.PSCredential (
            "${DomainName}\$($AdminCreds.UserName)",
            $AdminCreds.Password
        )

    [System.Management.Automation.PSCredential]$SafeCreds =
        New-Object System.Management.Automation.PSCredential (
            $SafemodeAdminCreds.UserName,
            $SafemodeAdminCreds.Password
        )

    Node localhost {

        LocalConfigurationManager {
            ActionAfterReboot  = 'ContinueConfiguration'
            ConfigurationMode  = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        WaitForDisk Disk1 {
            DiskId           = $DataDiskNumber
            RetryIntervalSec = $RetryIntervalSec
            RetryCount       = $RetryCount
        }

        Disk ADDataDisk {
            DiskId      = $DataDiskNumber
            DriveLetter = 'F'
            FSLabel     = 'ADDS'
            DependsOn   = '[WaitForDisk]Disk1'
        }

        WindowsFeature ADDSInstall {
            Ensure    = 'Present'
            Name      = 'AD-Domain-Services'
            DependsOn = '[Disk]ADDataDisk'
        }

        WindowsFeature ADManagementTools {
            Ensure               = 'Present'
            Name                 = 'RSAT-AD-Tools'
            IncludeAllSubFeature = $true
            DependsOn            = '[WindowsFeature]ADDSInstall'
        }

        Computer JoinDomain {
            Name       = 'localhost'
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn  = '[WindowsFeature]ADManagementTools'
        }

        WaitForADDomain DscForestWait {
            DomainName  = $DomainName
            Credential  = $DomainCreds
            WaitTimeout = $RetryCount * $RetryIntervalSec
            DependsOn   = '[Computer]JoinDomain'
        }

        if ($SiteName) {
            ADDomainController ReplicaDC {
                DomainName                    = $DomainName
                Credential                    = $DomainCreds
                SafemodeAdministratorPassword = $SafeCreds
                SiteName                      = $SiteName
                DatabasePath                  = 'F:\NTDS\Database'
                LogPath                       = 'F:\NTDS\Logs'
                SysvolPath                    = 'F:\SYSVOL'
                IsGlobalCatalog               = $true
                InstallDns                    = $true
                DependsOn                     = '[WaitForADDomain]DscForestWait'
            }
        }
        else {
            ADDomainController ReplicaDC {
                DomainName                    = $DomainName
                Credential                    = $DomainCreds
                SafemodeAdministratorPassword = $SafeCreds
                DatabasePath                  = 'F:\NTDS\Database'
                LogPath                       = 'F:\NTDS\Logs'
                SysvolPath                    = 'F:\SYSVOL'
                IsGlobalCatalog               = $true
                InstallDns                    = $true
                DependsOn                     = '[WaitForADDomain]DscForestWait'
            }
        }

        PendingReboot Reboot1 {
            Name      = 'RebootServer'
            DependsOn = '[ADDomainController]ReplicaDC'
        }
    }
}
