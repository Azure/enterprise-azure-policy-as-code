#Requires -PSEdition Core

function Convert-AssignmentsInfoToFlatPolicyList {
    [CmdletBinding()]
    param (
        [array] $assignmentArray,
        [array] $assignmentsInfo
    )

    $flatPolicyList = @{}
    foreach ($assignmentEntry in $assignmentArray) {
        $assignmentId = $assignmentEntry.id
        $shortName = $assignmentEntry.shortName
        if ($assignmentsInfo.ContainsKey($assignmentId)) {
            $assignmentInfo = $assignmentsInfo.$assignmentId
            if ($assignmentInfo.isInitiative) {
                foreach ($policyDefinitionInfo in $assignmentInfo.policyDefinitionsInfos) {
                    $id = $policyDefinitionInfo.id
                    $effect = $policyDefinitionInfo.effectValue
                    $effectAllowedValues = $policyDefinitionInfo.effectAllowedValues
                    $effectReason = $policyDefinitionInfo.effectReason
                    $ordinal = Convert-EffectToOrdinal -effect $effect

                    [hashtable] $currentAssignmentFlatPolicyInfo = @{
                        effect              = $effect
                        effectAllowedValues = $effectAllowedValues
                        effectReason        = $effectReason
                        ordinal             = $ordinal
                        assignmentShortName = $shortName
                        parameters          = $policyDefinitionInfo.parameters
                    }

                    if ($flatPolicyList.ContainsKey($id)) {
                        [hashtable] $flatPolicyInfo = $flatPolicyList.$id
                        [hashtable] $effectiveAssignment = $flatPolicyInfo.effectiveAssignment
                        if ($ordinal -lt $effectiveAssignment.ordinal) {
                            $flatPolicyInfo.effectiveAssignment = $currentAssignmentFlatPolicyInfo
                            $flatPolicyInfo.ordinal = $ordinal
                        }
                        $oldEffectAllowedValues = $flatPolicyInfo.effectAllowedValues
                        if ($effectAllowedValues.Count -gt $oldEffectAllowedValues.Count) {
                            $flatPolicyInfo.effectAllowedValues = $effectAllowedValues
                        }
                        [hashtable] $allAssignments = $flatPolicyInfo.allAssignments
                        if (-not $allAssignments.ContainsKey($shortName)) {
                            $allAssignments.Add($shortName, $currentAssignmentFlatPolicyInfo)
                        }
                        else {
                            Write-Information "    Warning: duplicate Policy $($policyDefinitionInfo.displayName) in Initiative $shortName"
                            # Create an artificila second entry for the duplicate Policy
                            [hashtable] $allAssignments = @{
                                $shortName = $currentAssignmentFlatPolicyInfo
                            }

                            $flatPolicyInfo = @{
                                ordinal             = $ordinal
                                category            = $policyDefinitionInfo.category
                                displayName         = $policyDefinitionInfo.displayName
                                description         = $policyDefinitionInfo.description
                                effectiveAssignment = $currentAssignmentFlatPolicyInfo
                                allAssignments      = $allAssignments
                            }
                            $flatPolicyList.Add($id + $shortName, $flatPolicyInfo)
                        }
                    }
                    else {
                        # First time encountering Policy
                        [hashtable] $allAssignments = @{
                            $shortName = $currentAssignmentFlatPolicyInfo
                        }

                        $flatPolicyInfo = @{
                            ordinal             = $ordinal
                            category            = $policyDefinitionInfo.category
                            displayName         = $policyDefinitionInfo.displayName
                            description         = $policyDefinitionInfo.description
                            effectiveAssignment = $currentAssignmentFlatPolicyInfo
                            allAssignments      = $allAssignments
                        }
                        $flatPolicyList.Add($id, $flatPolicyInfo)
                    }
                }
            }
        }
    }
    return $flatPolicyList
}