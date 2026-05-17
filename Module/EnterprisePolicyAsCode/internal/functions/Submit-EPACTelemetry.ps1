function Submit-EPACTelemetry {
    [CmdletBinding()]
    param(
        [string]$Cuapid,
        [string]$DeploymentRootScope
    )
    $method = "PUT"

    # Note - all these calls are meant to fail - we can track the pid in the logs
    if ($DeploymentRootScope -match "Microsoft.Management/managementgroups") {
        $managementGroupId = $DeploymentRootScope.Split("/")[-1]
        Invoke-AzRestMethod -Uri "https://management.azure.com/providers/Microsoft.Management/managementGroups/$($managementGroupId)/providers/Microsoft.Resources/deployments/$($Cuapid)?api-version=2021-04-01" -Method $method -ErrorAction SilentlyContinue -AsJob | Out-Null
    }
    elseif ($DeploymentRootScope -match "subscriptions") {
        $subscriptionId = $DeploymentRootScope.Split("/")[-1]
        Invoke-AzRestMethod -Uri "https://management.azure.com/subscriptions/$($subscriptionId)/providers/Microsoft.Resources/deployments/$($Cuapid)?api-version=2021-04-01" -Method $method -ErrorAction SilentlyContinue -AsJob | Out-Null
    }
    else {
        $subscriptionId = (Get-AzContext).Subscription.Id
        Invoke-AzRestMethod -Uri "https://management.azure.com/subscriptions/$($subscriptionId)/providers/Microsoft.Resources/deployments/$($Cuapid)?api-version=2021-04-01" -Method $method -ErrorAction SilentlyContinue -AsJob | Out-Null
    }
}