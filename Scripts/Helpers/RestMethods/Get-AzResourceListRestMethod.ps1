function Get-AzResourceListRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $SubscriptionId,

        [switch]$CheckCustomRoleDefinitions
    )
    
    function Invoke-AzRestMethodCustom {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            $path,
            [Parameter(Mandatory = $true)]
            $method
        )
        
        $response = Invoke-AzRestMethod -Path $path -Method $method

        # Process response
        $statusCode = $response.StatusCode
        if ($statusCode -lt 200 -or $statusCode -ge 300) {
            $content = $response.Content
            Write-Warning "Policy Exemption error for scope '$Scope' $($statusCode) -- $($content)"
            Write-Output @() -NoEnumerate
        }

        $content = $response.Content
        $resources = $content | ConvertFrom-Json -Depth 100 -AsHashtable
        $nextLink = ($response.Content | ConvertFrom-Json -Depth 100 -AsHashtable).nextLink
        while ($null -ne $nextLink) {
            $appendURL = (([uri]$nextlink).Query -split '&')[-1]
            $response = Invoke-AzRestMethod -Path ($path + '&' + $appendURL)  -Method GET
            $resources.value += ($response.Content | ConvertFrom-Json -Depth 100 -AsHashtable).value
            $nextLink = ($response.Content | ConvertFrom-Json -Depth 100 -AsHashtable).nextLink
        }
        return $resources
    }

    # Get the basic resources    
    $ApiVersion = "2021-04-01"
    $path = "/subscriptions/$SubscriptionId/resources?api-version=$ApiVersion"
    $resources = Invoke-AzRestMethodCustom -path $path -method GET

    # Get the Subnets for all the Vnets found in the basic resources
    $snets = $($resources.value | Where-Object { $_.type -eq 'Microsoft.Network/virtualNetworks' })
    foreach ($snet in $snets) {   
        $ApiVersion = "2024-01-01"
        $path = "$($snet.id)/subnets?api-version=$ApiVersion"
        $subnetResources = Invoke-AzRestMethodCustom -path $path -method GET
        $resources.value += $subnetResources.value
    }

    # Get the automation account variables for all the automation accounts found in the basic resources
    $automationAccounts = $($resources.value | Where-Object { $_.type -eq 'Microsoft.Automation/automationAccounts' })
    foreach ($account in $automationAccounts) {   
        $ApiVersion = "2023-11-01"
        $path = "$($account.id)/variables?api-version=$ApiVersion"
        $variableResources = Invoke-AzRestMethodCustom -path $path -method GET
        $resources.value += $variableResources.value
    }

    # Get the custom role definitions if requested
    if ($CheckCustomRoleDefinitions) {
        $ApiVersion = "2022-04-01"
        $path = "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/roleDefinitions?api-version=$ApiVersion&`$filter=type eq 'CustomRole'"
        $customRoleDefinitions = Invoke-AzRestMethodCustom -path $path -method GET
        $resources.value += $customRoleDefinitions.value
    }

    Write-Output $resources.value -NoEnumerate
}
