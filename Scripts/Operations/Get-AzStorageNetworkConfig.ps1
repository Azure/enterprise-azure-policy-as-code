#Requires -PSEdition Core

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, Position = 0)] [string] $environmentSelector = $null,
    [Parameter(Mandatory = $false)] [string] $OutputFileName = ".Output\tags\all-tags.csv"
)

. "$PSScriptRoot/../Config/Initialize-Environment.ps1"
. "$PSScriptRoot/../Config/Get-AzEnvironmentDefinitions.ps1"

$InformationPreference = "Continue"
$environment, $defaultSubscriptionId = Initialize-Environment $environmentSelector
$targetTenant = $environment.targetTenant

# Connect to Azure Tenant
Connect-AzAccount -Tenant $targetTenant
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

$output | Export-Csv -Path $OutputFileName -NoTypeInformation
