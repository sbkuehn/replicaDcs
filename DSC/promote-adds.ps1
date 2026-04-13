Configuration CreateADReplicaDC {
    param (
        [Parameter(Mandatory)]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SafemodeAdminCreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [int]$RetryCount = 20,

        [int]$RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName `
        xActiveDirectory, `
        xPendingReboot, `
        xStorage, `
        PSDesiredStateConfiguration, `
        xDSCDomainJoin

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
            ActionAfterReboot    = 'ContinueConfiguration'
            ConfigurationMode    = 'ApplyOnly'
            RebootNodeIfNeeded   = $true
        }

        xWaitForDisk Disk1 {
            DiskId           = 1
            RetryIntervalSec = $RetryIntervalSec
            RetryCount       = $RetryCount
        }

        xDisk ADDataDisk {
            DiskId      = 1
            DriveLetter = 'F'
            DependsOn   = '[xWaitForDisk]Disk1'
        }

        xDSCDomainJoin JoinDomain {
            Domain     = $DomainName
            Credential = $DomainCreds
            DependsOn  = '[xDisk]ADDataDisk'
        }

        WindowsFeature ADDSInstall {
            Ensure    = 'Present'
            Name      = 'AD-Domain-Services'
            DependsOn = '[xDSCDomainJoin]JoinDomain'
        }

        WindowsFeature ADManagementTools {
            Ensure               = 'Present'
            Name                 = 'RSAT-AD-Tools'
            IncludeAllSubFeature = $true
            DependsOn            = '[WindowsFeature]ADDSInstall'
        }

        xWaitForADDomain DscForestWait {
            DomainName           = $DomainName
            DomainUserCredential = $DomainCreds
            RetryCount           = $RetryCount
            RetryIntervalSec     = $RetryIntervalSec
            DependsOn            = '[WindowsFeature]ADManagementTools'
        }

        xADDomainController ReplicaDC {
            DomainName                    = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $SafeCreds
            DatabasePath                  = 'F:\NTDS\Database'
            LogPath                       = 'F:\NTDS\Logs'
            SysvolPath                    = 'F:\SYSVOL'
            DependsOn                     = '[xWaitForADDomain]DscForestWait'
        }

        xPendingReboot Reboot1 {
            Name      = 'RebootServer'
            DependsOn = '[xADDomainController]ReplicaDC'
        }
    }
}
