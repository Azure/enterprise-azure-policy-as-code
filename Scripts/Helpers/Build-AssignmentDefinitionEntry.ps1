function Build-AssignmentDefinitionEntry {
    [CmdletBinding()]
    param(
        $nodeName,
        $policyDefinitionsScopes,
        [hashtable] $definitionEntry,
        [hashtable] $combinedPolicyDetails,
        [switch] $mustDefineAssignment
    )

    $policyName = $definitionEntry.policyName
    $policyId = $definitionEntry.policyId
    $policySetName = $definitionEntry.policySetName
    $policySetId = $definitionEntry.policySetId
    $initiativeName = $definitionEntry.initiativeName
    $initiativeId = $definitionEntry.initiativeId
    $assignment = $definitionEntry.assignment
    $definitionVersion = $definitionEntry.definitionVersion

    $isValid = $true
    $normalizedEntry = $null
    $count = ($null -ne $policyName ? 1 : 0) + ($null -ne $policyId ? 1 : 0) + ($null -ne $policySetName ? 1 : 0) + ($null -ne $policySetId ? 1 : 0) + ($null -ne $initiativeName ? 1 : 0) + ($null -ne $initiativeId ? 1 : 0)
    if ($count -ne 1) {
        Write-Error "   Node $($nodeName): each definitionEntry must contain exactly one field defined from set [policyName, policyId, policySetName, policySetId, initiativeName, initiativeId]."
        $isValid = $false
    }
    else {
        if ($null -ne $policyName -or $null -ne $policyId) {
            $policyId = Confirm-PolicyDefinitionUsedExists `
                -id $policyId `
                -name $policyName `
                -policyDefinitionsScopes $policyDefinitionsScopes `
                -allDefinitions $combinedPolicyDetails.policies
            if ($null -eq $policyId) {
                $isValid = $false
            }
            else {
                $normalizedEntry = @{
                    policyDefinitionId = $policyId
                    isPolicySet        = $false
                }
            }
        }
        elseif ($null -ne $policySetName -or $null -ne $policySetId) {
            $policySetId = Confirm-PolicySetDefinitionUsedExists `
                -id $policySetId `
                -name $policySetName `
                -policyDefinitionsScopes $policyDefinitionsScopes `
                -allPolicySetDefinitions $combinedPolicyDetails.policySets
            if ($null -eq $policySetId) {
                $isValid = $false
            }
            else {
                $normalizedEntry = @{
                    policyDefinitionId = $policySetId
                    isPolicySet        = $true
                }
            }
        }
        elseif ($null -ne $initiativeName -or $null -ne $initiativeId) {
            $policySetId = Confirm-PolicySetDefinitionUsedExists `
                -id $initiativeId `
                -name $initiativeName `
                -policyDefinitionsScopes $policyDefinitionsScopes `
                -allPolicySetDefinitions $combinedPolicyDetails.policySets
            if ($null -eq $policySetId) {
                $isValid = $false
            }
            else {
                $normalizedEntry = @{
                    policyDefinitionId = $policySetId
                    isPolicySet        = $true
                }
            }
        }

        # if ($null -ne $definitionVersion) {
        #     $normalizedEntry.definitionVersion = $definitionVersion
        # }

        if ($null -ne $displayName) {
            $normalizedEntry.displayName = $definitionEntry.displayName
        }
        elseif ($null -ne $definitionEntry.friendlyNameToDocumentIfGuid) {
            $normalizedEntry.displayName = $definitionEntry.friendlyNameToDocumentIfGuid
        }

        if ($null -ne $definitionEntry.nonComplianceMessages) {
            $normalizedEntry.nonComplianceMessages = $definitionEntry.nonComplianceMessages
        }

        # if ($null -ne $shortName) {
        #     $normalizedEntry.displayName = $shortName
        # }
        if ($null -ne $assignment) {
            if ($null -ne $assignment.name -and ($assignment.name).Length -gt 0 -and $null -ne $assignment.displayName -and ($assignment.displayName).Length -gt 0) {
                $normalizedAssignment = ConvertTo-HashTable $assignment
                if (!$normalizedAssignment.ContainsKey("description")) {
                    $normalizedAssignment.description = ""
                }
                if (!$normalizedAssignment.ContainsKey("append")) {
                    $normalizedAssignment.append = $false
                }
                $normalizedEntry.assignment = $normalizedAssignment
            }
            else {
                Write-Error "   Node $($nodeName): each assignment in a definitionEntry must define an assignment name and displayName."
                $isValid = $false
            }
        }
        elseif ($mustDefineAssignment) {
            Write-Error "   Node $($nodeName): each definitionEntry in a definitionEntryList with more than one element must define an assignment field."
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
