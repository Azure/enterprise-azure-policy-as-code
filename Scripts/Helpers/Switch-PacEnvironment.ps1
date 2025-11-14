function Switch-PacEnvironment {
    [CmdletBinding()]
    param (
        [hashtable] $PacEnvironments,
        [string] $PacEnvironmentSelector,
        [bool] $Interactive
    )


    $pacEnvironment = @{}
    if ($PacEnvironments.ContainsKey($PacEnvironmentSelector)) {
        $pacEnvironment = $PacEnvironments.$PacEnvironmentSelector
    }
    else {
        Write-Error "    pacEnvironment '$PacEnvironmentSelector' does not exist" -ErrorAction Stop
    }
    $null = Set-AzCloudTenantSubscription `
        -Cloud $pacEnvironment.cloud `
        -TenantId $pacEnvironment.tenantId `
        -Interactive $Interactive
    # -subscriptionId $pacEnvironment.defaultSubscriptionId `

    return $pacEnvironment
}
