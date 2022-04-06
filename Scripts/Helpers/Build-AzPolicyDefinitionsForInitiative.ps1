#Requires -PSEdition Core

function Build-AzPolicyDefinitionsForInitiative {
    [CmdletBinding()]
    param(
        [hashtable] $allPolicyDefinitions,
        [hashtable] $replacedPolicyDefinitions,
        $initiativeObject,
        [string] $definitionScope
    )

    ######## validating each Policy Definition needed in Inititaive exists ###########
    Write-Verbose  "        Check existence of referenced policyDefinitionIDs and build new array"

    $usingUndefinedReference = $false
    $usingReplacedReference = $false
    $policyDefinitions = @()
    $usedPolicyGroupDefinitions = @{}
    if ($null -ne $initiativeObject.properties.PolicyDefinitions) {
        $policyDefinitionsInJson = $initiativeObject.properties.PolicyDefinitions
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
                    $groupNames = $policyDefinition.groupNames
                    $pd.groupNames = $groupNames
                    foreach ($groupName in $groupNames) {
                        if (!$usedPolicyGroupDefinitions.ContainsKey($groupName)) {
                            $usedPolicyGroupDefinitions.Add($groupName, $groupName)
                        }
                    }
                }
                $policyDefinitions += $pd
            }
        }
    }

    if ( -not $usingUndefinedReference) {
        Write-Verbose  "        All referenced policyDefinitionIDs exist"
    }

    $retValue = @{
        usingUndefinedReference    = $usingUndefinedReference
        usingReplacedReference     = $usingReplacedReference
        policyDefinitions          = $policyDefinitions
        usedPolicyGroupDefinitions = $usedPolicyGroupDefinitions
    }
    $retValue
}
