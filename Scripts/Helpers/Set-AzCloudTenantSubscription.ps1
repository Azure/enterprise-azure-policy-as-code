#Requires -PSEdition Core
function Set-AzCloudTenantSubscription {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string] $Cloud,
        [Parameter(Mandatory = $true)] [string] $TenantId,
        [Parameter(Mandatory = $true)] [bool] $Interactive
    )

    if ($null -eq (Get-Module Az.ResourceGraph -ListAvailable)) {
        Write-Information "Installing Az.ResourceGraph module"
        Install-Module Az.ResourceGraph -Force -Repository PSGallery
    }

    $account = Get-AzContext
    if ($null -eq $account -or $account.Environment.Name -ne $Cloud -or $account.Tenant.TenantId -ne $TenantId) {
        # Wrong tenant - login to tenant
        if ($Interactive) {
            $null = Connect-AzAccount -Environment $Cloud -Tenant $TenantId
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
