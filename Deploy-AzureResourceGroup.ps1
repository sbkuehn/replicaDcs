#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources, Az.Storage

<#
.SYNOPSIS
    Deploys the replica domain controller template to a resource group.

.DESCRIPTION
    By default the template pulls the DSC archive from _artifactsLocation in the parameters
    file (the GitHub repo). Use -UploadArtifacts to rebuild DSC\promote-adds.zip from the
    local promote-adds.ps1 and stage it in a private storage container instead, which lets
    you test DSC changes before pushing them.
#>
Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName,
    [switch] $UploadArtifacts,
    [string] $StorageAccountName,
    [string] $StorageContainerName = $ResourceGroupName.ToLowerInvariant() + '-stageartifacts',
    [string] $TemplateFile = 'azuredeploy.json',
    [string] $TemplateParametersFile = 'azuredeploy.parameters.json',
    [switch] $ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

if ($UploadArtifacts) {
    # Rebuild the DSC archive (script plus the DSC modules it imports)
    $DSCArchiveFilePath = Join-Path $PSScriptRoot 'DSC/promote-adds.zip'
    & (Join-Path $PSScriptRoot 'DSC/Build-DscArchive.ps1') -OutputPath $DSCArchiveFilePath

    # Create a storage account name if none was provided
    if (-not $StorageAccountName) {
        $StorageAccountName = 'stage' + ((Get-AzContext).Subscription.SubscriptionId).Replace('-', '').Substring(0, 19)
    }

    $StorageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }

    # Create the storage account if it doesn't already exist
    if ($null -eq $StorageAccount) {
        $StorageResourceGroupName = 'ARM_Deploy_Staging'
        New-AzResourceGroup -Location $ResourceGroupLocation -Name $StorageResourceGroupName -Force | Out-Null
        $StorageAccount = New-AzStorageAccount -StorageAccountName $StorageAccountName -SkuName 'Standard_LRS' `
            -Kind 'StorageV2' -ResourceGroupName $StorageResourceGroupName -Location $ResourceGroupLocation `
            -MinimumTlsVersion 'TLS1_2' -AllowBlobPublicAccess $false
    }

    # Upload only the DSC archive; the container stays private and is read through a SAS token
    New-AzStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1 | Out-Null
    Set-AzStorageBlobContent -File $DSCArchiveFilePath -Blob 'DSC/promote-adds.zip' `
        -Container $StorageContainerName -Context $StorageAccount.Context -Force | Out-Null

    # Point the template at the staged copy, overriding _artifactsLocation from the parameters file
    $OptionalParameters['_artifactsLocation'] = $StorageAccount.Context.BlobEndPoint + $StorageContainerName + '/'
    $OptionalParameters['_artifactsLocationSasToken'] = ConvertTo-SecureString -AsPlainText -Force `
        ('?' + (New-AzStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context `
            -Permission r -ExpiryTime (Get-Date).AddHours(4)).TrimStart('?'))
}

# Create the resource group only when it doesn't already exist
if ($null -eq (Get-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force | Out-Null
}

if ($ValidateOnly) {
    $ErrorMessages = Format-ValidationOutput (Test-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                                                                             -TemplateFile $TemplateFile `
                                                                             -TemplateParameterFile $TemplateParametersFile `
                                                                             @OptionalParameters)
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }
}
else {
    New-AzResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                  -ResourceGroupName $ResourceGroupName `
                                  -TemplateFile $TemplateFile `
                                  -TemplateParameterFile $TemplateParametersFile `
                                  @OptionalParameters `
                                  -Force -Verbose `
                                  -ErrorVariable ErrorMessages
    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}
