#Requires -PSEdition Core
function Set-AzCloudTenantSubscription {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string] $cloud,
        [Parameter(Mandatory = $true)] [string] $tenantId,
        [Parameter(Mandatory = $true)] [bool] $interactive
    )

    if (!(Get-Module Az.ResourceGraph -ListAvailable)) {
        Write-Information "Installing Az.ResourceGraph module"
        Install-Module Az.ResourceGraph -Force -Repository PSGallery
    }

    $account = Get-AzContext
    if ($null -eq $account -or $account.Environment.Name -ne $cloud -or $account.Tenant.TenantId -ne $tenantId) {
        # Wrong tenant - login to tenant
        if ($interactive) {
            $null = Connect-AzAccount -Environment $cloud -Tenant $tenantId
        }
        else {
            # Cannot interactively login - error
            Write-Error "Wrong cloud or tenant logged in by SPN:`n`tRequired cloud = $($cloud), tenantId = $($tenantId)`n`tIf you are running this script interactive, specify script parameter -interactive `$true." -ErrorAction Stop
        }
    }
}
