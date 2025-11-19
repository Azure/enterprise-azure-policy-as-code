#Requires -PSEdition Core
function Set-AzCloudTenantSubscription {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string] $Cloud,
        [Parameter(Mandatory = $true)] [string] $TenantId,
        [Parameter(Mandatory = $true)] [bool] $Interactive,
        [Parameter(Mandatory = $false)] [string] $DeploymentDefaultContext
    )

    if ([string]::IsNullOrWhitespace($DeploymentDefaultContext)) {
        Get-AzSubscription | Where-Object HomeTenantId -eq (Get-AzContext).Tenant | Select-Object -First 1 | Set-AzContext
    }
    else {
        Set-AzContext -Subscription $DeploymentDefaultContext
    }

    $account = Get-AzContext
    if ($null -eq $account -or $account.Environment.Name -ne $Cloud -or $account.Tenant.TenantId -ne $TenantId) {
        # Wrong tenant - login to tenant
        if ($Interactive) {
            $null = Connect-AzAccount -Environment $Cloud -Tenant $TenantId
            if ([string]::IsNullOrWhitespace($DeploymentDefaultContext)) {
                Get-AzSubscription | Where-Object HomeTenantId -eq (Get-AzContext).Tenant | Select-Object -First 1 | set-AzContext
            }
            else {
                Set-AzContext -Subscription $DeploymentDefaultContext
            }
            $account = Get-AzContext
        }
        else {
            # Cannot interactively login - error
            Write-Error "Wrong cloud or tenant logged in by SPN:`n`tRequired cloud = $($Cloud), tenantId = $($TenantId)`n`tIf you are running this script interactive, specify script parameter -Interactive `$true." -ErrorAction Stop
        }
    }
    Update-AzConfig -DisplayBreakingChangeWarning $false
    return $account
}
