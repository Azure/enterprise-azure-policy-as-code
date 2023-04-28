﻿<#
.SYNOPSIS
    Get all tags from all resources in all resource groups in all subscriptions in a tenant.

.PARAMETER PacEnvironmentSelector
    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER OutputFileName
    Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/all-tags.csv or './Outputs/Tags/all-tags.csv'.

.PARAMETER interactive
    Set to false if used non-interactive

.EXAMPLE
    .\Get-AzResourceTags.ps1 -pacEnvironmentSelector "dev" -definitionsRootFolder "C:\Src\Definitions" -outputFolder "C:\Src\Outputs" -interactive $true
    Get all tags from all resources in all resource groups in all subscriptions in a tenant.

.EXAMPLE
    .\Get-AzResourceTags.ps1 -interactive $true
    Get all tags from all resources in all resource groups in all subscriptions in a tenant. The script prompts for the PAC environment and uses the default definitions and output folders.
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/all-tags.csv or './Outputs/Tags/all-tags.csv'.")]
    [string] $OutputFileName,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -interactive $pacEnvironment.interactive

$targetTenant = $pacEnvironment.targetTenant
if ($OutputFileName -eq "") {
    $OutputFileName = "$($pacEnvironment.outputFolder)/Tags/all-tags.csv"
}

$subscriptionList = Get-AzSubscription -TenantId $targetTenant
$subscriptionList | Format-Table | Out-Default

Write-Information "==================================================================================================="
Write-Information "Processing"
Write-Information "==================================================================================================="

foreach ($subscription in $subscriptionList) {

    Try { $null = (Set-AzContext -SubscriptionId $subscription) }
    catch [Exception] { write-host ("Error occurred: " + $($_.Exception.Message)) -ForegroundColor Red; Exit }
    Write-Host "Azure Login Session successful" -ForegroundColor Green -BackgroundColor Black

    # Initialise output array
    $Output = [System.Collections.ArrayList]::new()
    $ResourceGroups = Get-AzResourceGroup
    foreach ($ResourceGroup in $ResourceGroups) {
        Write-Host "Resource Group =$($ResourceGroup.ResourceGroupName)"
        $resourceNames = Get-AzResource -ResourceGroupName $ResourceGroup.ResourceGroupName
        $tags = Get-AzTag -ResourceId $ResourceGroup.ResourceId
        foreach ($key in $tags.Properties.TagsProperty.Keys) {
            $csvObject = New-Object PSObject
            Add-Member -inputObject $csvObject -memberType NoteProperty -name "ResourceID" -value $ResourceGroup.ResourceID
            Add-Member -inputObject $csvObject -memberType NoteProperty -name "ResourceGroup" -value $ResourceGroup.ResourceGroupName
            Add-Member -inputObject $csvObject -memberType NoteProperty -name "ResourceName" -value ''
            Add-Member -inputObject $csvObject -memberType NoteProperty -name "TagKey" -value $key
            Add-Member -inputObject $csvObject -memberType NoteProperty -name "Value" -value $tags.Properties.TagsProperty.Item($($key))
            $null = $Output.Add($csvObject)

            #$Output += "`t ResourceGroup = $($ResourceGroup.ResourceGroupName) `t TagKey= $($key) `t Value = $($tags.Properties.TagsProperty.Item($($key)))"
            Write-Host "`t ResourceGroup = $($ResourceGroup.ResourceGroupName) `t TagKey= $($key) `t Value = $($tags.Properties.TagsProperty.Item($($key)))"
        }
        foreach ($res in $resourceNames) {
            Write-Host "ResourceName = $($res.Name)"
            $tags = Get-AzTag -ResourceId $res.ResourceId
            foreach ($key in $tags.Properties.TagsProperty.Keys) {
                $csvObject = New-Object PSObject
                Add-Member -inputObject $csvObject -memberType NoteProperty -name "ResourceID" -value $ResourceGroup.ResourceID
                Add-Member -inputObject $csvObject -memberType NoteProperty -name "ResourceGroup" -value $ResourceGroup.ResourceGroupName
                Add-Member -inputObject $csvObject -memberType NoteProperty -name "ResourceName" -value $res.Name
                Add-Member -inputObject $csvObject -memberType NoteProperty -name "TagKey" -value $key
                Add-Member -inputObject $csvObject -memberType NoteProperty -name "Value" -value $tags.Properties.TagsProperty.Item($($key))
                $null = $Output.Add($csvObject)

                #$Output += "`t ResourceGroup = $($ResourceGroup.ResourceGroupName) `t TagKey= $($key) `t Value = $($tags.Properties.TagsProperty.Item($($key)))"
                Write-Host "`t `t ResourceID = $($ResourceGroup.ResourceId) `t ResourceGroup = $($ResourceGroup.ResourceGroupName) `t ResourceName = $($res.Name) `t TagKey= $($key) `t Value = $($tags.Properties.TagsProperty.Item($($key)))"
            }
        }
    }

    if (-not (Test-Path $OutputFileName)) {
        New-Item $OutputFileName -Force
    }
    $Output | Export-Csv -Path $OutputFileName -NoClobber -NoTypeInformation -Append -Encoding UTF8 -Force
}
