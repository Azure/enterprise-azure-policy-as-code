#Requires -PSEdition Core

function Build-PolicySetPolicyDefinitionIds {
    [CmdletBinding()]
    param(
        $displayName,
        $policyDefinitions,
        $policyDefinitionsScopes,

        [hashtable] $allDefinitions,
        [hashtable] $policyRoleIds
    )

    $validPolicyDefinitions = $true
    $policyDefinitionsFinal = [System.Collections.ArrayList]::new()
    $policyRoleIdsInSet = @{}
    $usedPolicyGroupDefinitions = @{}

    foreach ($policyDefinition in $policyDefinitions) {

        # Validate required fields
        $policyId = $policyDefinition.policyDefinitionId
        $policyName = $policyDefinition.policyDefinitionName
        $policyDefinitionReferenceId = $policyDefinition.policyDefinitionReferenceId
        if ($null -eq $policyDefinitionReferenceId) {
            $validPolicyDefinitions = $false
            $policyDefinitionReferenceId = "** not defined **"
            [string] $policyDefinitionJsonString = $policyDefinition | ConvertTo-Json -Depth 100 -Compress
            if ($policyDefinitionJsonString.Length -gt 120) {
                $policyDefinitionJsonString = $policyDefinitionJsonString.Substring(0, 120)
            }
            Write-Error "$($displayName): policyDefinitions entry is missing policyDefinitionReferenceId: $policyDefinitionJsonString"
        }
        if (!($null -eq $policyId -xor $null -eq $policyName)) {
            $validPolicyDefinitions = $false
            if ("" -eq $policyId -and "" -eq $policyName) {
                Write-Error "$($displayName): policyDefinitions entry ($policyDefinitionReferenceId) does not define a policyDefinitionName or a policyDefinitionId."
            }
            else {
                Write-Error "$($displayName): policyDefinitions entry ($policyDefinitionReferenceId) may only contain a policyDefinitionName '$($policyName)' or a policyDefinitionId '$($policyId)'."
            }
        }


        # Check Policy exist
        if ($validPolicyDefinitions) {
            $policyId = Confirm-PolicyDefinitionUsedExists `
                -id $policyId `
                -name $policyName `
                -policyDefinitionsScopes $policyDefinitionsScopes `
                -allDefinitions $allDefinitions

            if ($null -ne $policyId) {
                # Calculate RoleDefinitionIds
                if ($policyRoleIds.ContainsKey($policyId)) {
                    $addRoleDefinitionIds = $policyRoleIds.$policyId
                    foreach ($roleDefinitionId in $addRoleDefinitionIds) {
                        $policyRoleIdsInSet[$roleDefinitionId] = "added"
                    }
                }

                # calculate union of groupNames
                if ($null -ne $policyDefinition.groupNames) {
                    $groupNames = $policyDefinition.groupNames
                    foreach ($groupName in $groupNames) {
                        if (!$usedPolicyGroupDefinitions.ContainsKey($groupName)) {
                            $null = $usedPolicyGroupDefinitions.Add($groupName, $groupName)
                        }
                    }
                }

                # Create the modified groupDefinition
                $modifiedPolicyDefinition = ConvertTo-HashTable $policyDefinition
                if ($modifiedPolicyDefinition.ContainsKey("policyDefinitionName")) {
                    $modifiedPolicyDefinition.Remove("policyDefinitionName")
                    $modifiedPolicyDefinition.Add("policyDefinitionId", $policyId)
                }
                # TODO: remove
                if ($modifiedPolicyDefinition.ContainsKey("definitionVersion")) {
                    $modifiedPolicyDefinition.Remove("definitionVersion")
                }
                $null = $policyDefinitionsFinal.Add($modifiedPolicyDefinition)
            }
            else {
                $validPolicyDefinitions = $false
            }
        }
    }

    return $validPolicyDefinitions, $policyDefinitionsFinal, $policyRoleIdsInSet, $usedPolicyGroupDefinitions
}