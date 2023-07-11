function Build-PolicySetPolicyDefinitionIds {
    [CmdletBinding()]
    param(
        $DisplayName,
        $PolicyDefinitions,
        $PolicyDefinitionsScopes,

        [hashtable] $AllDefinitions,
        [hashtable] $PolicyRoleIds
    )

    $validPolicyDefinitions = $true
    $PolicyDefinitionsFinal = [System.Collections.ArrayList]::new()
    $PolicyRoleIdsInSet = @{}
    $usedPolicyGroupDefinitions = @{}

    foreach ($PolicyDefinition in $PolicyDefinitions) {

        # Validate required fields
        $PolicyId = $PolicyDefinition.policyDefinitionId
        $PolicyName = $PolicyDefinition.policyDefinitionName
        $PolicyDefinitionReferenceId = $PolicyDefinition.policyDefinitionReferenceId
        if ($null -eq $PolicyDefinitionReferenceId) {
            $validPolicyDefinitions = $false
            $PolicyDefinitionReferenceId = "** not defined **"
            [string] $PolicyDefinitionJsonString = $PolicyDefinition | ConvertTo-Json -Depth 100 -Compress
            if ($PolicyDefinitionJsonString.Length -gt 120) {
                $PolicyDefinitionJsonString = $PolicyDefinitionJsonString.Substring(0, 120)
            }
            Write-Error "$($DisplayName): policyDefinitions entry is missing policyDefinitionReferenceId: $PolicyDefinitionJsonString"
        }
        if (!($null -eq $PolicyId -xor $null -eq $PolicyName)) {
            $validPolicyDefinitions = $false
            if ("" -eq $PolicyId -and "" -eq $PolicyName) {
                Write-Error "$($DisplayName): policyDefinitions entry ($PolicyDefinitionReferenceId) does not define a policyDefinitionName or a policyDefinitionId."
            }
            else {
                Write-Error "$($DisplayName): policyDefinitions entry ($PolicyDefinitionReferenceId) may only contain a policyDefinitionName '$($PolicyName)' or a policyDefinitionId '$($PolicyId)'."
            }
        }


        # Check Policy exist
        if ($validPolicyDefinitions) {
            $PolicyId = Confirm-PolicyDefinitionUsedExists `
                -Id $PolicyId `
                -Name $PolicyName `
                -PolicyDefinitionsScopes $PolicyDefinitionsScopes `
                -AllDefinitions $AllDefinitions

            if ($null -ne $PolicyId) {
                # Calculate RoleDefinitionIds
                if ($PolicyRoleIds.ContainsKey($PolicyId)) {
                    $addRoleDefinitionIds = $PolicyRoleIds.$PolicyId
                    foreach ($roleDefinitionId in $addRoleDefinitionIds) {
                        $PolicyRoleIdsInSet[$roleDefinitionId] = "added"
                    }
                }

                # calculate union of groupNames
                if ($null -ne $PolicyDefinition.groupNames) {
                    $groupNames = $PolicyDefinition.groupNames
                    foreach ($groupName in $groupNames) {
                        if (!$usedPolicyGroupDefinitions.ContainsKey($groupName)) {
                            $null = $usedPolicyGroupDefinitions.Add($groupName, $groupName)
                        }
                    }
                }

                # Create the modified groupDefinition
                $modifiedPolicyDefinition = @{
                    policyDefinitionReferenceId = $PolicyDefinitionReferenceId
                    policyDefinitionId          = $PolicyId
                    # definitionVersion           = $PolicyDefinition.definitionVersion
                }
                if ($null -ne $PolicyDefinition.parameters) {
                    $modifiedPolicyDefinition.Add("parameters", $PolicyDefinition.parameters)
                }
                if ($null -ne $PolicyDefinition.groupNames) {
                    $modifiedPolicyDefinition.Add("groupNames", $PolicyDefinition.groupNames)
                }
                $null = $PolicyDefinitionsFinal.Add($modifiedPolicyDefinition)
            }
            else {
                $validPolicyDefinitions = $false
            }
        }
    }

    return $validPolicyDefinitions, $PolicyDefinitionsFinal, $PolicyRoleIdsInSet, $usedPolicyGroupDefinitions
}
