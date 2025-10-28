function Remove-AzPolicyExemptionEpac {
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    $Scope,

    [Parameter(Mandatory = $true)]
    $Name,

    [Parameter(Mandatory = $false)]
    $ApiVersion = "2022-07-01-preview"
)


$id = "$Scope/providers/Microsoft.Authorization/policyExemptions/$Name"

Remove-AzResourceByIdRestMethod -Id $id -ApiVersion $ApiVersion
}
