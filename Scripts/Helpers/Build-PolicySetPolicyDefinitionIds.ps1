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
    $policyDefinitionsFinal = [System.Collections.ArrayList]::new()
    $policyRoleIdsInSet = @{}
    $usedPolicyGroupDefinitions = @{}

    foreach ($policyDefinition in $PolicyDefinitions) {

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
            Write-Error "$($DisplayName): policyDefinitions entry is missing policyDefinitionReferenceId: $policyDefinitionJsonString"
        }
        if (!($null -eq $policyId -xor $null -eq $policyName)) {
            $validPolicyDefinitions = $false
            if ("" -eq $policyId -and "" -eq $policyName) {
                Write-Error "$($DisplayName): policyDefinitions entry ($policyDefinitionReferenceId) does not define a policyDefinitionName or a policyDefinitionId."
            }
            else {
                Write-Error "$($DisplayName): policyDefinitions entry ($policyDefinitionReferenceId) may only contain a policyDefinitionName '$($policyName)' or a policyDefinitionId '$($policyId)'."
            }
        }


        # Check Policy exist
        if ($validPolicyDefinitions) {
            $policyId = Confirm-PolicyDefinitionUsedExists `
                -Id $policyId `
                -Name $policyName `
                -PolicyDefinitionsScopes $PolicyDefinitionsScopes `
                -AllDefinitions $AllDefinitions

            if ($null -ne $policyId) {
                # Calculate RoleDefinitionIds
                if ($PolicyRoleIds.ContainsKey($policyId)) {
                    $addRoleDefinitionIds = $PolicyRoleIds.$policyId
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
                $modifiedPolicyDefinition = @{
                    policyDefinitionReferenceId = $policyDefinitionReferenceId
                    policyDefinitionId          = $policyId
                    # definitionVersion           = $policyDefinition.definitionVersion
                }
                if ($null -ne $policyDefinition.parameters) {
                    $modifiedPolicyDefinition.Add("parameters", $policyDefinition.parameters)
                }
                if ($null -ne $policyDefinition.groupNames) {
                    $modifiedPolicyDefinition.Add("groupNames", $policyDefinition.groupNames)
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
