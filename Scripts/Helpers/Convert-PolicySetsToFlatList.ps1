function Convert-PolicySetsToFlatList {
    [CmdletBinding()]
    param (
        $ItemList,
        $Details
    )

    #region Find Policies which are listed more than once in at least one of the PolicySets

    $policiesWithMultipleReferenceIds = @{}
    foreach ($item in $ItemList) {
        $shortName = $item.shortName
        $itemId = $item.itemId
        $assignmentId = $item.assignmentId
        $itemKind = "PolicySet"
        if ($null -ne $assignmentId) {
            $itemKind = "Assignment"
        }
        if (-not $shortName) {
            Write-Error "'$title' $($itemKind)s array entry does not specify an $($itemKind) shortName." -ErrorAction Stop
        }
        if (-not $itemId) {
            Write-Error "'$title' $($itemKind)s array entry does not specify an $($itemKind) id." -ErrorAction Stop
        }
        if (-not $Details.ContainsKey($itemId)) {
            Write-Error "'$title' $($itemKind) does not exist: $itemId." -ErrorAction Stop
        }

        $detail = $Details.$itemId
        $policiesWithMultipleReferenceIdsInThisPolicySet = $detail.policiesWithMultipleReferenceIds
        if ($policiesWithMultipleReferenceIdsInThisPolicySet.psbase.Count -gt 0) {
            foreach ($policyId in $policiesWithMultipleReferenceIdsInThisPolicySet.Keys) {
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
    foreach ($item in $ItemList) {
        $shortName = $item.shortName
        $itemId = $item.itemId
        $policySetId = $item.policySetId
        $assignmentId = $item.assignmentId

        # Collate
        $detail = $Details.$itemId
        $assignmentParameters = @{}
        $assignmentOverrides = @()
        if ($null -ne $detail.assignmentId) {
            $assignment = $detail.assignment
            $properties = Get-PolicyResourceProperties -PolicyResource $assignment
            $assignmentOverrides = $properties.overrides
            $assignmentParameters = Get-DeepClone $properties.parameters -AsHashTable
        }

        foreach ($policyInPolicySetInfo in $detail.policyDefinitions) {
            $policyId = $policyInPolicySetInfo.id
            $policyDefinitionReferenceId = $policyInPolicySetInfo.policyDefinitionReferenceId
            $effectParameterName = $policyInPolicySetInfo.effectParameterName
            $effectReason = $policyInPolicySetInfo.effectReason
            $effectAllowedValues = $policyInPolicySetInfo.effectAllowedValues
            $effectAllowedOverrides = $policyInPolicySetInfo.effectAllowedOverrides
            $effectValue = $policyInPolicySetInfo.effectValue
            $effectDefault = $policyInPolicySetInfo.effectDefault
            $parameters = $policyInPolicySetInfo.parameters
            $isEffectParameterized = $effectReason -eq "PolicySet Default" -or $effectReason -eq "PolicySet No Default" -or $effectReason -eq "Assignment"
            $flatPolicyEntryKey = $policyId
            $flatPolicyReferencePath = ""
            if ($policiesWithMultipleReferenceIds.ContainsKey($policyId)) {
                $flatPolicyReferencePath = "$($detail.name)\\$($policyDefinitionReferenceId)"
                $flatPolicyEntryKey = "$policyId\\$flatPolicyReferencePath"
            }

            $flatPolicyEntry = @{}
            if ($flatPolicyList.ContainsKey($flatPolicyEntryKey)) {
                $flatPolicyEntry = $flatPolicyList.$flatPolicyEntryKey
                if ($isEffectParameterized) {
                    $flatPolicyEntry.isEffectParameterized = $true
                }
            }
            else {
                $flatPolicyEntry = @{
                    id                     = $policyId
                    name                   = $policyInPolicySetInfo.name
                    referencePath          = $flatPolicyReferencePath
                    displayName            = $policyInPolicySetInfo.displayName
                    description            = $policyInPolicySetInfo.description
                    policyType             = $policyInPolicySetInfo.policyType
                    category               = $policyInPolicySetInfo.category
                    effectDefault          = $effectDefault
                    effectValue            = $effectValue
                    ordinal                = 99
                    isEffectParameterized  = $isEffectParameterized
                    effectAllowedValues    = @{}
                    effectAllowedOverrides = $effectAllowedOverrides
                    parameters             = @{}
                    policySetList          = @{}
                    groupNames             = @{}
                    groupNamesList         = @()
                    policySetEffectStrings = @()
                }
                $null = $flatPolicyList.Add($flatPolicyEntryKey, $flatPolicyEntry)
            }

            $perPolicySet = @{
                id                          = $policySetId
                name                        = $detail.name
                shortName                   = $shortName
                displayName                 = $detail.displayName
                description                 = $detail.description
                policyType                  = $detail.policyType
                effectParameterName         = $effectParameterName
                effectValue                 = $policyInPolicySetInfo.effectValue
                effectDefault               = $effectDefault
                effectAllowedValues         = $effectAllowedValues
                effectAllowedOverrides      = $effectAllowedOverrides
                effectReason                = $effectReason
                isEffectParameterized       = $isEffectParameterized
                effectString                = ""
                parameters                  = $parameters
                policyDefinitionReferenceId = $policyDefinitionReferenceId
                groupNames                  = $policyInPolicySetInfo.groupNames
                assignmentId                = $assignmentId
                assignment                  = $detail.assignment
            }

            $groupNames = $policyInPolicySetInfo.groupNames
            $existingGroupNames = $flatPolicyEntry.groupNames
            $existingGroupNamesList = $flatPolicyEntry.groupNamesList
            if ($null -ne $groupNames -and $groupNames.Count -gt 0) {
                $modifiedGroupNamesList = @()
                foreach ($groupName in $existingGroupNamesList) {
                    $modifiedGroupNamesList += $groupName
                }
                foreach ($groupName in $groupNames) {
                    if (!$existingGroupNames.ContainsKey($groupName)) {
                        $null = $existingGroupNames.Add($groupName, $groupName)
                        $modifiedGroupNamesList += $groupName
                    }
                }
                $flatPolicyEntry.groupNamesList = $modifiedGroupNamesList
            }


            # Allowed Effects
            $existingEffectAllowedValues = $flatPolicyEntry.effectAllowedValues
            foreach ($effect in $effectAllowedValues) {
                if (-not $existingEffectAllowedValues.ContainsKey($effect)) {
                    $null = $existingEffectAllowedValues.Add($effect, $effect)
                }
            }

            $effectString = ""
            if ($null -ne $detail.assignmentId) {
                $isOverridden = $false
                if ($null -ne $assignmentOverrides -and $assignmentOverrides.Count -gt 0) {
                    # Check if we have an override
                    foreach ($override in $assignmentOverrides) {
                        if ($override.kind -eq "policyEffect") {
                            $tempEffect = $override.value
                            foreach ($selector in $override.selectors) {
                                if ($selector.kind -eq "policyDefinitionReferenceId") {
                                    if ($selector.in -contains $policyDefinitionReferenceId) {
                                        $effectValue = $tempEffect
                                        $perPolicySet.effectReason = "Override"
                                        $effectString = "$($effectValue) (override))"
                                        $isOverridden = $true
                                    }
                                }
                            }
                        }
                    }
                }
                if (!$isOverridden) {
                    if ($isEffectParameterized) {
                        $existingOrdinal = $flatPolicyEntry.ordinal
                        $effectString = "$($effectDefault) (default: $($effectParameterName))"
                        # Best actual value if processing an Assignment
                        $effectValue = $effectDefault
                        if ($null -ne $assignmentParameters) {
                            # Assignment has parameters
                            if ($assignmentParameters.Keys -contains $effectParameterName) {
                                # Effect default is replaced by assignment parameter
                                $assignmentLevelEffectParameter = $assignmentParameters.$effectParameterName
                                $effectValue = $assignmentLevelEffectParameter.value
                                $perPolicySet.effectReason = "Assignment"
                                $effectString = "$($effectValue) (assignment: $($effectParameterName))"
                            }
                        }
                    }
                    else {
                        $effectString = "$($effectDefault) ($($effectReason))"
                    }
                }
                $ordinal = Convert-EffectToOrdinal -Effect $effectValue
                if ($ordinal -lt $existingOrdinal) {
                    $flatPolicyEntry.ordinal = $ordinal
                    $flatPolicyEntry.effectValue = $effectValue
                    $flatPolicyEntry.effectDefault = $effectDefault
                }
            }
            else {
                # Best default to fill effect columns for an PolicySet
                $ordinal = Convert-EffectToOrdinal -Effect $effectDefault
                if ($ordinal -lt $existingOrdinal) {
                    $flatPolicyEntry.ordinal = $ordinal
                    $flatPolicyEntry.effectValue = $effectDefault
                    $flatPolicyEntry.effectDefault = $effectDefault
                }
                $effectString = switch ($effectReason) {
                    "PolicySet Default" {
                        "$($effectDefault) (default: $($effectParameterName))"
                        break
                    }
                    "PolicySet No Default" {
                        # Very unnusul to have a policy set effect parameter with no default
                        "$($effectReason) ($($effectParameterName))"
                        break
                    }
                    default {
                        "$($effectDefault) ($($effectReason))"
                        break
                    }
                }
            }

            $perPolicySet.effectString = $effectString
            $policySetEffectString = "$($shortName): $($effectString)"

            $policySetEffectStrings = $flatPolicyEntry.policySetEffectStrings + $policySetEffectString
            $flatPolicyEntry.policySetEffectStrings = $policySetEffectStrings

            $policySetList = $flatPolicyEntry.policySetList
            if ($policySetList.ContainsKey($shortName)) {
                Write-Error "'$title' item array entry contains duplicate shortName ($shortName)." -ErrorAction Stop
            }
            $null = $policySetList.Add($shortName, $perPolicySet)

            # Collate union of parameters
            $parametersForThisPolicy = $flatPolicyEntry.parameters
            foreach ($parameterName in $parameters.Keys) {
                $parameter = $parameters.$parameterName
                if ($parametersForThisPolicy.ContainsKey($parameterName)) {
                    $parameterPolicySets = $parameter.policySets
                    $parameterPolicySets += $detail.displayName
                    $parameter.policySets = $parameterPolicySets
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
                            $assignmentParameters = $assignmentParameters
                            if ($null -ne $assignmentParameters) {
                                # Assignment has parameters
                                if ($assignmentParameters.ContainsKey($parameterName)) {
                                    # Effect default is replaced by assignment parameter
                                    $assignmentLevelEffectParameter = $assignmentParameters.$parameterName
                                    $parameterValue = $assignmentLevelEffectParameter.value
                                }
                            }
                        }
                        $parameter.value = $parameterValue
                        $parameter.policySets = @( $detail.displayName )
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
