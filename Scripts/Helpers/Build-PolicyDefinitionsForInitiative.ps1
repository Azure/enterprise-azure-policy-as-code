#Requires -PSEdition Core

function Build-PolicyDefinitionsForInitiative {
    [CmdletBinding()]
    param(
        [hashtable] $allPolicyDefinitions,
        [hashtable] $replacedPolicyDefinitions,
        [array] $policyDefinitionsInJson,
        [string] $definitionScope
    )

    ######## validating each Policy Definition needed in Inititaive exists ###########
    Write-Verbose  "        Check existence of referenced policyDefinitionIDs and build new array"

    $usingUndefinedReference = $false
    $usingReplacedReference = $false
    $policyDefinitions = @()
    foreach ($policyDefinition in $policyDefinitionsInJson) {
        # check desired state defined in JSON
        $result = Confirm-PolicyDefinitionUsedExists -allPolicyDefinitions  $allPolicyDefinitions `
            -replacedPolicyDefinitions $replacedPolicyDefinitions -policyNameRequired $policyDefinition.policyDefinitionName
        if ($result.usingUndefinedReference) {
            $usingUndefinedReference = $true
        }
        else {
            if ($result.usingReplacedReference) {
                $usingReplacedReference = $true
            }
            $policy = $result.policy
            $id = $policy.id
            if ($null -eq $id) {
                $id = $definitionScope + "/providers/Microsoft.Authorization/policyDefinitions/" + $policyDefinition.policyDefinitionName
            }
            $pd = @{
                policyDefinitionId          = $id
                policyDefinitionReferenceId = $policyDefinition.policyDefinitionReferenceId
            }
            if ($null -ne $policyDefinition.parameters) {
                $pd.parameters = $policyDefinition.parameters
            }
            else {
                $pd.parameters = @{}
            }
            if ($null -ne $policyDefinition.groupNames) {
                $pd.groupNames = $policyDefinition.groupNames
            }
            $policyDefinitions += $pd
        }
    }

    if ( -not $usingUndefinedReference) {
        Write-Verbose  "        All referenced policyDefinitionIDs exist"
    }

    $retValue = @{
        usingUndefinedReference = $usingUndefinedReference
        usingReplacedReference  = $usingReplacedReference
        policyDefinitions       = $policyDefinitions
    }
    $retValue
}
