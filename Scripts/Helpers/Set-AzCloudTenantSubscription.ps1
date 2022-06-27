#Requires -PSEdition Core
function Set-AzCloudTenantSubscription {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string] $cloud,
        [Parameter(Mandatory = $true)] [string] $tenantId,
        [Parameter(Mandatory = $true)] [string] $subscriptionId,
        [Parameter(Mandatory = $true)] [bool] $interactive,
        [Parameter(Mandatory = $false)] [switch] $useAzPowerShell

    )

    if ($useAzPowerShell.IsPresent) {
        $account = Get-AzContext
        if ($null -eq $account -or $account.Environment.Name -ne $cloud -or $account.Tenant.TenantId -ne $tenantId) {
            # Wrong tenant - login to tenant
            if ($interactive) {
                $null = Connect-AzAccount -Environment $cloud -Tenant $tenantId -SubscriptionId $subscriptionId
            }
            else {
                # Cannot interactively login - error
                Write-Error "Wrong cloud or tenant logged in by SPN:`n`tRequired cloud = $($cloud), tenantId = $($tenantId), subscriptionId = $($subscriptionId)`n`tIf you are running this script interactive, specify script parameter -interactive `$true." -ErrorAction Stop
            }
        }
        elseif ($account.Subscription.Id -ne $subscriptionId) {
            $null = Set-AzContext -Subscription $subscriptionId
        }
    }
    else {
        $accountJson = az account show
        $account = $null
        if ($null -ne $accountJson) {
            $account = $accountJson | ConvertFrom-Json
        }
        if (($null -eq $account) -or ($account.environmentName -ne $cloud) -or ($account.tenantId -ne $tenantId)) {
            # Wrong tenant - login to tenant
            if ($interactive) {
                Invoke-AzCli cloud set --name $cloud -SuppressOutput
                Invoke-AzCli login --tenant $tenantId -SuppressOutput
                Invoke-AzCli account set --subscription $subscriptionId -SuppressOutput
            }
            else {
                # Cannot interactively login - error
                Write-Error "Wrong tenant logged in by SPN:`n`tRequired tenantId = $($tenantId), subscription$($subscriptionId)`n`t$(ConvertTo-Json $account)`nIf you are running this script interactive, specify script parameter -interactive `$true" -ErrorAction Stop
            }
        }
        elseif ($account.id -ne $subscriptionId) {
            # wrong subscription - change subscription
            Invoke-AzCli account set --subscription $subscriptionId -SuppressOutput
        }
    }
}
