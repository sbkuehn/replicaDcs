<#
.SYNOPSIS
    Rebuilds promote-adds.zip for the Azure DSC extension.

.DESCRIPTION
    The DSC extension does not download modules from the PowerShell Gallery, so the
    archive must contain the configuration script plus every DSC module it imports,
    each in its own folder at the root of the zip. Run this whenever promote-adds.ps1
    or the module versions below change, then commit the resulting zip.
#>
[CmdletBinding()]
param (
    [string]$OutputPath = (Join-Path $PSScriptRoot 'promote-adds.zip')
)

$ErrorActionPreference = 'Stop'

$modules = @(
    @{ Name = 'ActiveDirectoryDsc';    RequiredVersion = '6.7.1' }
    @{ Name = 'ComputerManagementDsc'; RequiredVersion = '10.0.0' }
    @{ Name = 'StorageDsc';            RequiredVersion = '6.0.1' }
)

$staging = Join-Path ([System.IO.Path]::GetTempPath()) "promote-adds-$([guid]::NewGuid())"
$download = Join-Path $staging 'download'
$archive = Join-Path $staging 'archive'
New-Item -ItemType Directory -Path $download, $archive | Out-Null

try {
    foreach ($module in $modules) {
        Save-Module -Name $module.Name -RequiredVersion $module.RequiredVersion -Repository PSGallery -Path $download
        # Flatten <Name>\<Version>\ to <Name>\, matching the layout Publish-AzVMDscConfiguration produces.
        Copy-Item -Path (Join-Path $download "$($module.Name)/$($module.RequiredVersion)") `
            -Destination (Join-Path $archive $module.Name) -Recurse
    }

    Copy-Item -Path (Join-Path $PSScriptRoot 'promote-adds.ps1') -Destination $archive

    Compress-Archive -Path (Join-Path $archive '*') -DestinationPath $OutputPath -Force
    Write-Host "Wrote $OutputPath"
}
finally {
    Remove-Item -Path $staging -Recurse -Force
}
