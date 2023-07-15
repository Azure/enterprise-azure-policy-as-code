function Split-ScopeId {
    [CmdletBinding()]
    param (
        [string] $ScopeId,
        [switch] $AsSplat,
        [string] $ParameterNameForManagementGroup = "ManagementGroupName",
        [string] $ParameterNameForSubscription = "SubscriptionId"
    )

    $argName = ""
    $argValue = $null
    if ($ScopeId.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
        $argName = $ParameterNameForManagementGroup
        $argValue = $ScopeId -replace "/providers/Microsoft.Management/managementGroups/"
    }
    elseif ($ScopeId.StartsWith("/subscriptions/")) {
        $argName = $ParameterNameForSubscription
        $argValue = $ScopeId -replace "/subscriptions/"
    }
    else {
        Write-Error "'$ScopeId' is not a valid scope." -ErrorAction Stop
    }
    if ($AsSplat) {
        return @{
            $argName = $argValue
        }
    }
    else {
        return $argName, $argValue
    }
}
