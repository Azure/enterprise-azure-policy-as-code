
<#
.SYNOPSIS
    Gets all aliases and outputs them to a CSV file.

.PARAMETER PacEnvironmentSelector    
    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER OutputFileName
    Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Storage/StorageNetwork.csv or './Outputs/Storage/StorageNetwork.csv'.

.PARAMETER Interactive
    Set to false if used non-interactive

.EXAMPLE
    .\Get-AzStorageNetworkConfig.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -OutputFolder "C:\Src\Outputs" -Interactive $true
    Gets all aliases and outputs them to a CSV file.

.EXAMPLE
    .\Get-AzStorageNetworkConfig.ps1 -Interactive $true
    Gets all aliases and outputs them to a CSV file. The script prompts for the PAC environment and uses the default definitions and output folders.
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Storage/StorageNetwork.csv or './Outputs/Storage/StorageNetwork.csv'.")]
    [string] $OutputFileName,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $Interactive = $true
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -Interactive $pacEnvironment.interactive

$targetTenant = $pacEnvironment.targetTenant
if ($OutputFileName -eq "") {
    $OutputFileName = "$($pacEnvironment.outputFolder)/Storage/StorageNetwork.csv"
}

Write-Information "==================================================================================================="
Write-Information "Processing"
Write-Information "==================================================================================================="

# Connect to Azure Tenant
$subs = Get-AzSubscription -TenantId $targetTenant | Where-Object { $_.State -eq 'Enabled' }

$output = @()

foreach ($sub in $subs) {
    Select-AzSubscription -Subscription $sub.Name

    $accts = Get-AzStorageAccount

    $privateendpoints = Get-AzPrivateEndpoint

    if ($privateendpoints) {

        $pelist = $privateendpoints.PrivateLinkServiceConnections.PrivateLinkServiceId | ForEach-Object { $_.split('/')[-1] }

    }
    else {

        $pelist = $null

    }

    foreach ($acct in $accts) {

        if ($acct.NetworkRuleSet.IpRules.IPAddressOrRange) {
            $ipRules = [String]::Join("; ", $acct.NetworkRuleSet.IpRules.IPAddressOrRange)


        }
        else {

            $ipRules = $false

        }

        if ($acct.NetworkRuleSet.VirtualNetworkRules) {

            $vnetRules = [String]::Join("; ", ($acct.NetworkRuleSet.VirtualNetworkRules.VirtualNetworkResourceId | ForEach-Object { ($_ -split ("/"))[-1] }))

        }
        else {

            $vnetRules = $false

        }


        $StorageAccountProperties = @{

            StorageAccountName     = $acct.StorageAccountName
            ResourceGroupName      = $acct.ResourceGroupName
            Subscription           = $sub.Name
            Environment            = $acct.Tags.Environment
            Bypass                 = $acct.NetworkRuleSet.Bypass
            DefaultAction          = $acct.NetworkRuleSet.DefaultAction
            IpRules                = $ipRules
            VirtualNetworkRules    = $vnetRules
            PrivateEndpointEnabled = ($pelist -contains $acct.StorageAccountName)
        }

        $output += New-Object PSObject -Property $StorageAccountProperties

    }

}

if (-not (Test-Path $OutputFileName)) {
    New-Item $OutputFileName -Force
}
$output | Export-Csv -Path $OutputFileName -NoTypeInformation
