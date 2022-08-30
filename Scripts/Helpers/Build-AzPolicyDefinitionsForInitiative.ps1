#Requires -PSEdition Core

function Build-AzPolicyDefinitionsForInitiative {
    [CmdletBinding()]
    param(
        [hashtable] $allPolicyDefinitions,
        [hashtable] $replacedPolicyDefinitions,
        $initiativeObject,
        [string] $definitionScope,
        [hashtable] $policyNeededRoleDefinitionIds,
        [hashtable] $initiativeNeededRoleDefinitionIds

    )

    ######## validating each Policy Definition needed in Inititaive exists ###########
    Write-Verbose  "        Check existence of referenced policyDefinitionIDs and build new array"

    $usingUndefinedReference = $false
    $usingReplacedReference = $false
    $policyDefinitions = @()

    $usedPolicyGroupDefinitions = @{}
    if ($null -ne $initiativeObject.properties.PolicyDefinitions) {
        $policyDefinitionsInJson = $initiativeObject.properties.PolicyDefinitions
        $roleDefinitionIdsInInitiative = @{}
        $initiativeName = $initiativeObject.name
        foreach ($policyDefinition in $policyDefinitionsInJson) {
            # check desired state defined in JSON
            $policyName = $policyDefinition.policyDefinitionName
            $result = Confirm-PolicyDefinitionUsedExists `
                -allPolicyDefinitions  $allPolicyDefinitions `
                -replacedPolicyDefinitions $replacedPolicyDefinitions `
                -policyNameRequired $policyName

            # Calculate RoleDefinitionIds
            if ($policyNeededRoleDefinitionIds.ContainsKey($policyName)) {
                $addRoleDefinitionIds = $policyNeededRoleDefinitionIds.$policyName
                foreach ($roleDefinitionId in $addRoleDefinitionIds) {
                    if (-not ($roleDefinitionIdsInInitiative.ContainsKey($roleDefinitionId))) {
                        $roleDefinitionIdsInInitiative.Add($roleDefinitionId, "added")
                    }
                }
            }


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
                    # Custom Policy
                    $id = $definitionScope + "/providers/Microsoft.Authorization/policyDefinitions/" + $policyName
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
        if ($roleDefinitionIdsInInitiative.Count -gt 0) {
            $initiativeNeededRoleDefinitionIds.Add($initiativeName, $roleDefinitionIdsInInitiative.Keys)
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
