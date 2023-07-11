function Switch-PacEnvironment {
    [CmdletBinding()]
    param (
        [int] $DefinitionStartingLine,
        [int] $DefinitionEndingLine,
        [hashtable] $PacEnvironments,
        [string] $PacEnvironmentSelector,
        [bool] $Interactive
    )


    $PacEnvironment = @{}
    if ($PacEnvironments.ContainsKey($PacEnvironmentSelector)) {
        $PacEnvironment = $PacEnvironments.$PacEnvironmentSelector
    }
    else {
        Write-Error "    pacEnvironment '$PacEnvironmentSelector' in definition on lines $DefinitionStartingLine - $DefinitionEndingLine does not exist" -ErrorAction Stop
    }
    Set-AzCloudTenantSubscription `
        -Cloud $PacEnvironment.cloud `
        -TenantId $PacEnvironment.tenantId `
        -Interactive $Interactive
    # -subscriptionId $PacEnvironment.defaultSubscriptionId `

    return $PacEnvironment
}
