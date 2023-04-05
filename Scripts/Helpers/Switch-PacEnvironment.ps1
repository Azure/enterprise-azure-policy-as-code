function Switch-PacEnvironment {
    [CmdletBinding()]
    param (
        [int] $definitionStartingLine,
        [int] $definitionEndingLine,
        [hashtable] $pacEnvironments,
        [string] $pacEnvironmentSelector,
        [bool] $interactive
    )


    $pacEnvironment = @{}
    if ($pacEnvironments.ContainsKey($pacEnvironmentSelector)) {
        $pacEnvironment = $pacEnvironments.$pacEnvironmentSelector
    }
    else {
        Write-Error "    pacEnvironment '$pacEnvironmentSelector' in definition on lines $definitionStartingLine - $definitionEndingLine does not exist" -ErrorAction Stop
    }
    Set-AzCloudTenantSubscription `
        -cloud $pacEnvironment.cloud `
        -tenantId $pacEnvironment.tenantId `
        -interactive $interactive
    # -subscriptionId $pacEnvironment.defaultSubscriptionId `

    return $pacEnvironment
}