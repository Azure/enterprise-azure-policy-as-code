function Split-ScopeId {
    [CmdletBinding()]
    param (
        [string] $scopeId,
        [switch] $asSplat,
        [string] $parameterNameForManagementGroup = "ManagementGroupName",
        [string] $parameterNameForSubscription = "SubscriptionId"
    )

    $argName = ""
    $argValue = $null
    if ($scopeId.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
        $argName = $parameterNameForManagementGroup
        $argValue = $scopeId -replace "/providers/Microsoft.Management/managementGroups/"
    }
    elseif ($scopeId.StartsWith("/subscriptions/")) {
        $argName = $parameterNameForSubscription
        $argValue = $scopeId -replace "/subscriptions/"
    }
    else {
        Write-Error "'$scopeId' is not a valid scope." -ErrorAction Stop
    }
    if ($asSplat) {
        return @{
            $argName = $argValue
        }
    }
    else {
        return $argName, $argValue
    }
}
