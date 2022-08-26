#Requires -PSEdition Core

function Merge-MultipleInitiativeInfos {
    [CmdletBinding()]
    param (
        [array] $itemList,
        $combinedInfos
    )

    #region Find Policies which are listed more than once in at least one of the Initiatives

    $policiesWithMultipleReferenceIds = @{}
    foreach ($item in $itemList) {
        $shortName = $item.shortName
        $itemId = $item.itemId
        $assignmentId = $item.assignmentId
        $itemKind = "Initiative"
        if ($null -ne $assignmentId) {
            $itemKind = "Assignment"
        }
        if (-not $shortName) {
            Write-Error "'$title' $($itemKind)s array entry does not specify an $($itemKind) shortName." -ErrorAction Stop
        }
        if (-not $itemId) {
            Write-Error "'$title' $($itemKind)s array entry does not specify an $($itemKind) id." -ErrorAction Stop
        }
        if (-not $combinedInfos.ContainsKey($itemId)) {
            Write-Error "'$title' $($itemKind) does not exist: $itemId." -ErrorAction Stop
        }

        $combinedInfo = $combinedInfos.$itemId
        $policiesWithMultipleReferenceIdsInThisInitiative = $combinedInfo.policiesWithMultipleReferenceIds
        if ($policiesWithMultipleReferenceIdsInThisInitiative.Count -gt 0) {
            foreach ($policyId in $policiesWithMultipleReferenceIdsInThisInitiative.Keys) {
                if (-not $policiesWithMultipleReferenceIds.ContainsKey($policyId)) {
                    $null = $policiesWithMultipleReferenceIds.Add($policyId, $policyId)
                }
            }
        }
    }

    #endregion

    #region Collate and pivot to flat list

    $flatPolicyList = @{}
    $parametersAlreadyCovered = @{}
    foreach ($item in $itemList) {
        $shortName = $item.shortName
        $itemId = $item.itemId
        $initiativeId = $item.initiativeId
        $assignmentId = $item.assignmentId

        # Collate
        $combinedInfo = $combinedInfos.$itemId
        foreach ($policyInInitiativeInfo in $combinedInfo.policyDefinitions) {
            $policyId = $policyInInitiativeInfo.id
            $effectParameterName = $policyInInitiativeInfo.effectParameterName
            $effectReason = $policyInInitiativeInfo.effectReason
            $effectAllowedValues = $policyInInitiativeInfo.effectAllowedValues
            $effectValue = $policyInInitiativeInfo.effectValue
            $effectDefault = $policyInInitiativeInfo.effectDefault
            $parameters = $policyInInitiativeInfo.parameters
            $isEffectParameterized = $effectReason -eq "Initiative Default" -or $effectReason -eq "Initiative No Default" -or $effectReason -eq "Assignment"
            $flatPolicyEntryKey = $policyId
            $flatPolicyReferencePath = ""
            if ($policiesWithMultipleReferenceIds.ContainsKey($policyId)) {
                $flatPolicyReferencePath = "$($combinedInfo.name)\\$($policyInInitiativeInfo.policyDefinitionReferenceId)"
                $flatPolicyEntryKey = "$policyId\\$flatPolicyReferencePath"
            }

            $flatPolicyEntry = @{}
            if ($flatPolicyList.ContainsKey($flatPolicyEntryKey)) {
                $flatPolicyEntry = $flatPolicyList.$flatPolicyEntryKey
            }
            else {
                $flatPolicyEntry = @{
                    id                    = $policyId
                    name                  = $policyInInitiativeInfo.name
                    referencePath         = $flatPolicyReferencePath
                    displayName           = $policyInInitiativeInfo.displayName
                    description           = $policyInInitiativeInfo.description
                    policyType            = $policyInInitiativeInfo.policyType
                    category              = $policyInInitiativeInfo.category
                    effectDefault         = $effectDefault
                    effectValue           = "Unknown"
                    effectAllowedValues   = @{}
                    isEffectParameterized = $false
                    ordinal               = 99
                    parameters            = @{}
                    initiativeList        = @{}
                    groupNames            = @{}
                }
                $null = $flatPolicyList.Add($flatPolicyEntryKey, $flatPolicyEntry)
            }

            $perInitiative = @{
                id                          = $initiativeId
                name                        = $combinedInfo.name
                shortName                   = $shortName
                displayName                 = $combinedInfo.displayName
                description                 = $combinedInfo.description
                policyType                  = $combinedInfo.policyType
                effectParameterName         = $effectParameterName
                effectValue                 = $policyInInitiativeInfo.effectValue
                effectDefault               = $effectDefault
                effectAllowedValues         = $effectAllowedValues
                effectReason                = $effectReason
                isEffectParameterized       = $isEffectParameterized
                effectDefaultString         = ""
                effectValueString           = ""
                parameters                  = $parameters
                policyDefinitionReferenceId = $policyInInitiativeInfo.policyDefinitionReferenceId
                groupNames                  = $policyInInitiativeInfo.groupNames
                assignmentId                = $assignmentId
                assignment                  = $combinedInfo.assignment
            }

            $groupNames = $policyInInitiativeInfo.groupNames
            $existingGroupNames = $flatPolicyEntry.groupNames
            if ($null -ne $groupNames -and $groupNames.Count -gt 0) {
                foreach ($groupName in $groupNames) {
                    if (-not $existingGroupNames.ContainsKey($groupName)) {
                        $null = $existingGroupNames.Add($groupName, $groupName)
                    }
                }
            }

            $effectDefaultString = ""
            $effectValueString = ""

            # Allowed Effects
            $existingEffectAllowedValues = $flatPolicyEntry.effectAllowedValues
            foreach ($effect in $effectAllowedValues) {
                if (-not $existingEffectAllowedValues.ContainsKey($effect)) {
                    $null = $existingEffectAllowedValues.Add($effect, $effect)
                }
            }

            if ($isEffectParameterized) {
                # Temporary

                $existingOrdinal = $flatPolicyEntry.ordinal

                $effectValueString = "$($effectDefault) (default: $($effectParameterName))"
                if ($null -ne $combinedInfo.assignmentId) {
                    # Best actual value if processing an Assignment
                    $effectValue = $effectDefault
                    $assignmentParameters = $combinedInfo.assignment.parameters
                    $effectValue = $effectDefault
                    $effectValueString = "$($effectDefault) (default: $($effectParameterName))"
                    if ($null -ne $assignmentParameters) {
                        # Assignment has parameters
                        if ($assignmentParameters.ContainsKey($effectParameterName)) {
                            # Effect default is repaced by assignment parameter
                            $assignmentLevelEffectParameter = $assignmentParameters.$effectParameterName
                            $effectValue = $assignmentLevelEffectParameter.value
                            $perInitiative.effectReason = "Assignment"
                            $effectValueString = "$($effectValue) (assignment: $($effectParameterName))"
                        }
                    }
                    $ordinal = Convert-EffectToOrdinal -effect $effectValue
                    if ($ordinal -lt $existingOrdinal) {
                        $flatPolicyEntry.ordinal = $ordinal
                        $flatPolicyEntry.effectValue = $effectValue
                        $flatPolicyEntry.effectDefault = $effectDefault
                    }
                }
                else {
                    # Best default to fill effect columns for an Initiative
                    $ordinal = Convert-EffectToOrdinal -effect $effectDefault
                    if ($ordinal -lt $existingOrdinal) {
                        $flatPolicyEntry.ordinal = $ordinal
                        $flatPolicyEntry.effectValue = $null
                        $flatPolicyEntry.effectDefault = $effectDefault
                    }
                }
                $effectDefaultString = "$($effectDefault) ($($effectParameterName))"
            }
            else {
                $effectDefaultString = "$($effectDefault) ($($effectReason))"
                $effectValueString = $effectDefaultString
                $flatPolicyEntry.effectValue = $null
                $flatPolicyEntry.effectDefault = $effectDefault
            }

            $perInitiative.effectDefaultString = $effectDefaultString
            $perInitiative.effectValueString = $effectValueString

            $initiativeList = $flatPolicyEntry.initiativeList
            if ($initiativeList.ContainsKey($shortName)) {
                Write-Error "'$title' item array entry contains duplicate shortName ($shortName)." -ErrorAction Stop
            }
            $null = $initiativeList.Add($shortName, $perInitiative)

            # Collate union of parameters
            $parametersForThisPolicy = $flatPolicyEntry.parameters
            foreach ($parameterName in $parameters.Keys) {
                $parameter = $parameters.$parameterName
                if ($parametersForThisPolicy.ContainsKey($parameterName)) {
                    $parameterInitiatives = $parameter.initiatives
                    $parameterInitiatives += $combinedInfo.displayName
                    $parameter.initiatives = $parameterInitiatives
                }
                else {
                    if ($parametersAlreadyCovered.ContainsKey($parameterName)) {
                        $parameter.multiUse = $true
                    }
                    else {
                        $null = $parametersAlreadyCovered.Add($parameterName, $true)
                        $parameter.multiUse = $false # Redo multi-use based on sorted liist of Policies

                        $parameterValue = $null
                        if ($null -ne $assignmentId) {
                            if ($null -ne $parameter.defaultValue) {
                                $parameterValue = $parameter.defaultValue
                            }
                            $assignmentParameters = $combinedInfo.assignment.parameters
                            if ($null -ne $assignmentParameters) {
                                # Assignment has parameters
                                if ($assignmentParameters.ContainsKey($parameterName)) {
                                    # Effect default is repaced by assignment parameter
                                    $assignmentLevelEffectParameter = $assignmentParameters.$parameterName
                                    $parameterValue = $assignmentLevelEffectParameter.value
                                }
                            }
                        }
                        $parameter.value = $parameterValue
                        $parameter.initiatives = @( $combinedInfo.displayName )
                        $null = $parametersForThisPolicy.Add($parameterName, $parameter)
                    }
                }
            }
            # Write-Information "Test"
        }
    }

    #endregion

    return $flatPolicyList
}