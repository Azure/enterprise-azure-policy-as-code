function Build-AssignmentDefinitionEntry {
    [CmdletBinding()]
    param(
        $NodeName,
        $PolicyDefinitionsScopes,
        [hashtable] $DefinitionEntry,
        [hashtable] $CombinedPolicyDetails,
        [switch] $MustDefineAssignment
    )

    $PolicyName = $DefinitionEntry.policyName
    $PolicyId = $DefinitionEntry.policyId
    $PolicySetName = $DefinitionEntry.policySetName
    $PolicySetId = $DefinitionEntry.policySetId
    $initiativeName = $DefinitionEntry.initiativeName
    $initiativeId = $DefinitionEntry.initiativeId
    $Assignment = $DefinitionEntry.assignment
    $DefinitionVersion = $DefinitionEntry.definitionVersion

    $isValid = $true
    $normalizedEntry = $null
    $count = ($null -ne $PolicyName ? 1 : 0) + ($null -ne $PolicyId ? 1 : 0) + ($null -ne $PolicySetName ? 1 : 0) + ($null -ne $PolicySetId ? 1 : 0) + ($null -ne $initiativeName ? 1 : 0) + ($null -ne $initiativeId ? 1 : 0)
    if ($count -ne 1) {
        Write-Error "   Node $($NodeName): each definitionEntry must contain exactly one field defined from set [policyName, policyId, policySetName, policySetId, initiativeName, initiativeId]."
        $isValid = $false
    }
    else {
        if ($null -ne $PolicyName -or $null -ne $PolicyId) {
            $PolicyId = Confirm-PolicyDefinitionUsedExists `
                -Id $PolicyId `
                -Name $PolicyName `
                -PolicyDefinitionsScopes $PolicyDefinitionsScopes `
                -AllDefinitions $CombinedPolicyDetails.policies
            if ($null -eq $PolicyId) {
                $isValid = $false
            }
            else {
                $normalizedEntry = @{
                    policyDefinitionId = $PolicyId
                    isPolicySet        = $false
                }
            }
        }
        elseif ($null -ne $PolicySetName -or $null -ne $PolicySetId) {
            $PolicySetId = Confirm-PolicySetDefinitionUsedExists `
                -Id $PolicySetId `
                -Name $PolicySetName `
                -PolicyDefinitionsScopes $PolicyDefinitionsScopes `
                -AllPolicySetDefinitions $CombinedPolicyDetails.policySets
            if ($null -eq $PolicySetId) {
                $isValid = $false
            }
            else {
                $normalizedEntry = @{
                    policyDefinitionId = $PolicySetId
                    isPolicySet        = $true
                }
            }
        }
        elseif ($null -ne $initiativeName -or $null -ne $initiativeId) {
            $PolicySetId = Confirm-PolicySetDefinitionUsedExists `
                -Id $initiativeId `
                -Name $initiativeName `
                -PolicyDefinitionsScopes $PolicyDefinitionsScopes `
                -AllPolicySetDefinitions $CombinedPolicyDetails.policySets
            if ($null -eq $PolicySetId) {
                $isValid = $false
            }
            else {
                $normalizedEntry = @{
                    policyDefinitionId = $PolicySetId
                    isPolicySet        = $true
                }
            }
        }

        # if ($null -ne $DefinitionVersion) {
        #     $normalizedEntry.definitionVersion = $DefinitionVersion
        # }

        if ($null -ne $DisplayName) {
            $normalizedEntry.displayName = $DefinitionEntry.displayName
        }
        elseif ($null -ne $DefinitionEntry.friendlyNameToDocumentIfGuid) {
            $normalizedEntry.displayName = $DefinitionEntry.friendlyNameToDocumentIfGuid
        }

        if ($null -ne $DefinitionEntry.nonComplianceMessages) {
            $normalizedEntry.nonComplianceMessages = $DefinitionEntry.nonComplianceMessages
        }

        # if ($null -ne $shortName) {
        #     $normalizedEntry.displayName = $shortName
        # }
        if ($null -ne $Assignment) {
            if ($null -ne $Assignment.name -and ($Assignment.name).Length -gt 0 -and $null -ne $Assignment.displayName -and ($Assignment.displayName).Length -gt 0) {
                $normalizedAssignment = ConvertTo-HashTable $Assignment
                if (!$normalizedAssignment.ContainsKey("description")) {
                    $normalizedAssignment.description = ""
                }
                if (!$normalizedAssignment.ContainsKey("append")) {
                    $normalizedAssignment.append = $false
                }
                $normalizedEntry.assignment = $normalizedAssignment
            }
            else {
                Write-Error "   Node $($NodeName): each assignment in a definitionEntry must define an assignment name and displayName."
                $isValid = $false
            }
        }
        elseif ($MustDefineAssignment) {
            Write-Error "   Node $($NodeName): each definitionEntry in a definitionEntryList with more than one element must define an assignment field."
            $isValid = $false
        }
        else {
            $normalizedEntry.assignment = @{
                append      = $false
                name        = ""
                displayName = ""
                description = ""
            }
        }
    }
    return $isValid, $normalizedEntry
}
