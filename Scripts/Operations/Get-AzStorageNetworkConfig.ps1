Param (
    [Parameter(Mandatory = $false)]
    [String] $tenantId = "e898ff4a-4b69-45ee-a3ae-1cd6f239feb2",

    [Parameter(Mandatory = $false)]
    [String] $outputFilePath,

    [Parameter(Mandatory = $false)]
    [String] $outputFileName = "AzStorageAccountNetworkConfig.csv"

)

$subs = Get-AzSubscription -TenantId $tenant | Where-Object { $_.State -eq 'Enabled' }

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

$output

if ($outputFilePath) {

    $output | Export-Csv -Path "$outputFilePath\$outputFileName" -NoTypeInformation

}

#Example output 
#$output | ? {$_.PrivateEndpointEnabled -eq $false -and $_.DefaultAction -eq "allow"}