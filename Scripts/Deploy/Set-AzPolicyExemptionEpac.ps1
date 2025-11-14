[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    $Scope,

    [Parameter(Mandatory = $true)]
    $Name,

    [Parameter(Mandatory = $true)]
    $DisplayName,

    [Parameter(Mandatory = $false)]
    $Description = "description",

    [Parameter(Mandatory = $false)]
    $ExemptionCategory = "Waiver",

    [Parameter(Mandatory = $false)]
    $ExpiresOn = $null,

    [Parameter(Mandatory = $true)]
    $PolicyAssignmentId,

    [Parameter(Mandatory = $false)]
    $PolicyDefinitionReferenceIds = $null,

    [Parameter(Mandatory = $false)]
    $AssignmentScopeValidation = "Default",

    [Parameter(Mandatory = $false)]
    $ResourceSelectors = $null,

    [Parameter(Mandatory = $false)]
    $Metadata = $null,

    [Parameter(Mandatory = $false)]
    $ApiVersion = "2022-07-01-preview"
)

. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$id = "$Scope/providers/Microsoft.Authorization/policyExemptions/$Name"

$exemptionObject = [ordered]@{
    id                           = $id
    policyAssignmentId           = $PolicyAssignmentId
    exemptionCategory            = $ExemptionCategory
    assignmentScopeValidation    = $AssignmentScopeValidation
    displayName                  = $DisplayName
    description                  = $Description
    expiresOn                    = $ExpiresOn
    metadata                     = $Metadata
    policyDefinitionReferenceIds = $PolicyDefinitionReferenceIds
    resourceSelectors            = $ResourceSelectors
}

Set-AzPolicyExemptionRestMethod -ExemptionObj $exemptionObject -ApiVersion $ApiVersion