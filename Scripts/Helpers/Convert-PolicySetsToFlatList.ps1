function Convert-PolicySetsToFlatList {
    [CmdletBinding()]
    param (
        [array] $ItemList,
        $Details
    )

    #region Find Policies which are listed more than once in at least one of the PolicySets

    $policiesWithMultipleReferenceIds = @{}
    foreach ($item in $ItemList) {
        $shortName = $item.shortName
        $itemId = $item.itemId
        $AssignmentId = $item.assignmentId
        $itemKind = "PolicySet"
        if ($null -ne $AssignmentId) {
            $itemKind = "Assignment"
        }
        if (-not $shortName) {
            Write-Error "'$Title' $($itemKind)s array entry does not specify an $($itemKind) shortName." -ErrorAction Stop
        }
        if (-not $itemId) {
            Write-Error "'$Title' $($itemKind)s array entry does not specify an $($itemKind) id." -ErrorAction Stop
        }
        if (-not $Details.ContainsKey($itemId)) {
            Write-Error "'$Title' $($itemKind) does not exist: $itemId." -ErrorAction Stop
        }

        $detail = $Details.$itemId
        $policiesWithMultipleReferenceIdsInThisPolicySet = $detail.policiesWithMultipleReferenceIds
        if ($policiesWithMultipleReferenceIdsInThisPolicySet.psbase.Count -gt 0) {
            foreach ($PolicyId in $policiesWithMultipleReferenceIdsInThisPolicySet.Keys) {
                if (-not $policiesWithMultipleReferenceIds.ContainsKey($PolicyId)) {
                    $null = $policiesWithMultipleReferenceIds.Add($PolicyId, $PolicyId)
                }
            }
        }
    }

    #endregion

    #region Collate and pivot to flat list

    $FlatPolicyList = @{}
    $ParametersAlreadyCovered = @{}
    foreach ($item in $ItemList) {
        $shortName = $item.shortName
        $itemId = $item.itemId
        $PolicySetId = $item.policySetId
        $AssignmentId = $item.assignmentId

        # Collate
        $detail = $Details.$itemId
        $AssignmentParameters = @{}
        $AssignmentOverrides = @()
        if ($null -ne $detail.assignmentId) {
            $Assignment = $detail.assignment
            $properties = Get-PolicyResourceProperties -PolicyResource $Assignment
            $AssignmentOverrides = $properties.overrides
            $AssignmentParameters = Get-DeepClone $properties.parameters -AsHashtable
        }

        foreach ($PolicyInPolicySetInfo in $detail.policyDefinitions) {
            $PolicyId = $PolicyInPolicySetInfo.id
            $PolicyDefinitionReferenceId = $PolicyInPolicySetInfo.policyDefinitionReferenceId
            $EffectParameterName = $PolicyInPolicySetInfo.effectParameterName
            $EffectReason = $PolicyInPolicySetInfo.effectReason
            $EffectAllowedValues = $PolicyInPolicySetInfo.effectAllowedValues
            $EffectAllowedOverrides = $PolicyInPolicySetInfo.effectAllowedOverrides
            $EffectValue = $PolicyInPolicySetInfo.effectValue
            $EffectDefault = $PolicyInPolicySetInfo.effectDefault
            $Parameters = $PolicyInPolicySetInfo.parameters
            $isEffectParameterized = $EffectReason -eq "PolicySet Default" -or $EffectReason -eq "PolicySet No Default" -or $EffectReason -eq "Assignment"
            $flatPolicyEntryKey = $PolicyId
            $flatPolicyReferencePath = ""
            if ($policiesWithMultipleReferenceIds.ContainsKey($PolicyId)) {
                $flatPolicyReferencePath = "$($detail.name)\\$($PolicyDefinitionReferenceId)"
                $flatPolicyEntryKey = "$PolicyId\\$flatPolicyReferencePath"
            }

            $flatPolicyEntry = @{}
            if ($FlatPolicyList.ContainsKey($flatPolicyEntryKey)) {
                $flatPolicyEntry = $FlatPolicyList.$flatPolicyEntryKey
                if ($isEffectParameterized) {
                    $flatPolicyEntry.isEffectParameterized = $true
                }
            }
            else {
                $flatPolicyEntry = @{
                    id                     = $PolicyId
                    name                   = $PolicyInPolicySetInfo.name
                    referencePath          = $flatPolicyReferencePath
                    displayName            = $PolicyInPolicySetInfo.displayName
                    description            = $PolicyInPolicySetInfo.description
                    policyType             = $PolicyInPolicySetInfo.policyType
                    category               = $PolicyInPolicySetInfo.category
                    effectDefault          = $EffectDefault
                    effectValue            = $EffectValue
                    ordinal                = 99
                    isEffectParameterized  = $isEffectParameterized
                    effectAllowedValues    = @{}
                    effectAllowedOverrides = $EffectAllowedOverrides
                    parameters             = @{}
                    policySetList          = @{}
                    groupNames             = @{}
                    groupNamesList         = @()
                    policySetEffectStrings = @()
                }
                $null = $FlatPolicyList.Add($flatPolicyEntryKey, $flatPolicyEntry)
            }

            $perPolicySet = @{
                id                          = $PolicySetId
                name                        = $detail.name
                shortName                   = $shortName
                displayName                 = $detail.displayName
                description                 = $detail.description
                policyType                  = $detail.policyType
                effectParameterName         = $EffectParameterName
                effectValue                 = $PolicyInPolicySetInfo.effectValue
                effectDefault               = $EffectDefault
                effectAllowedValues         = $EffectAllowedValues
                effectAllowedOverrides      = $EffectAllowedOverrides
                effectReason                = $EffectReason
                isEffectParameterized       = $isEffectParameterized
                effectString                = ""
                parameters                  = $Parameters
                policyDefinitionReferenceId = $PolicyDefinitionReferenceId
                groupNames                  = $PolicyInPolicySetInfo.groupNames
                assignmentId                = $AssignmentId
                assignment                  = $detail.assignment
            }

            $groupNames = $PolicyInPolicySetInfo.groupNames
            $ExistingGroupNames = $flatPolicyEntry.groupNames
            $ExistingGroupNamesList = $flatPolicyEntry.groupNamesList
            if ($null -ne $groupNames -and $groupNames.Count -gt 0) {
                $modifiedGroupNamesList = @()
                foreach ($groupName in $ExistingGroupNamesList) {
                    $modifiedGroupNamesList += $groupName
                }
                foreach ($groupName in $groupNames) {
                    if (!$ExistingGroupNames.ContainsKey($groupName)) {
                        $null = $ExistingGroupNames.Add($groupName, $groupName)
                        $modifiedGroupNamesList += $groupName
                    }
                }
                $flatPolicyEntry.groupNamesList = $modifiedGroupNamesList
            }


            # Allowed Effects
            $ExistingEffectAllowedValues = $flatPolicyEntry.effectAllowedValues
            foreach ($Effect in $EffectAllowedValues) {
                if (-not $ExistingEffectAllowedValues.ContainsKey($Effect)) {
                    $null = $ExistingEffectAllowedValues.Add($Effect, $Effect)
                }
            }

            $EffectString = ""
            if ($null -ne $detail.assignmentId) {
                $isOverridden = $false
                if ($null -ne $AssignmentOverrides -and $AssignmentOverrides.Count -gt 0) {
                    # Check if we have an override
                    foreach ($override in $AssignmentOverrides) {
                        if ($override.kind -eq "policyEffect") {
                            $tempEffect = $override.value
                            foreach ($selector in $override.selectors) {
                                if ($selector.kind -eq "policyDefinitionReferenceId") {
                                    if ($selector.in -contains $PolicyDefinitionReferenceId) {
                                        $EffectValue = $tempEffect
                                        $perPolicySet.effectReason = "Override"
                                        $EffectString = "$($EffectValue) (override))"
                                        $isOverridden = $true
                                    }
                                }
                            }
                        }
                    }
                }
                if (!$isOverridden) {
                    if ($isEffectParameterized) {
                        $ExistingOrdinal = $flatPolicyEntry.ordinal
                        $EffectString = "$($EffectDefault) (default: $($EffectParameterName))"
                        # Best actual value if processing an Assignment
                        $EffectValue = $EffectDefault
                        if ($null -ne $AssignmentParameters) {
                            # Assignment has parameters
                            if ($AssignmentParameters.Keys -contains $EffectParameterName) {
                                # Effect default is replaced by assignment parameter
                                $AssignmentLevelEffectParameter = $AssignmentParameters.$EffectParameterName
                                $EffectValue = $AssignmentLevelEffectParameter.value
                                $perPolicySet.effectReason = "Assignment"
                                $EffectString = "$($EffectValue) (assignment: $($EffectParameterName))"
                            }
                        }
                    }
                    else {
                        $EffectString = "$($EffectDefault) ($($EffectReason))"
                    }
                }
                $Ordinal = Convert-EffectToOrdinal -Effect $EffectValue
                if ($Ordinal -lt $ExistingOrdinal) {
                    $flatPolicyEntry.ordinal = $Ordinal
                    $flatPolicyEntry.effectValue = $EffectValue
                    $flatPolicyEntry.effectDefault = $EffectDefault
                }
            }
            else {
                # Best default to fill effect columns for an PolicySet
                $Ordinal = Convert-EffectToOrdinal -Effect $EffectDefault
                if ($Ordinal -lt $ExistingOrdinal) {
                    $flatPolicyEntry.ordinal = $Ordinal
                    $flatPolicyEntry.effectValue = $EffectDefault
                    $flatPolicyEntry.effectDefault = $EffectDefault
                }
                $EffectString = "$($EffectDefault) ($($EffectReason))"
            }

            $perPolicySet.effectString = $EffectString
            $PolicySetEffectString = "$($shortName): $($EffectString)"

            $PolicySetEffectStrings = $flatPolicyEntry.policySetEffectStrings + $PolicySetEffectString
            $flatPolicyEntry.policySetEffectStrings = $PolicySetEffectStrings

            $PolicySetList = $flatPolicyEntry.policySetList
            if ($PolicySetList.ContainsKey($shortName)) {
                Write-Error "'$Title' item array entry contains duplicate shortName ($shortName)." -ErrorAction Stop
            }
            $null = $PolicySetList.Add($shortName, $perPolicySet)

            # Collate union of parameters
            $ParametersForThisPolicy = $flatPolicyEntry.parameters
            foreach ($parameterName in $Parameters.Keys) {
                $parameter = $Parameters.$parameterName
                if ($ParametersForThisPolicy.ContainsKey($parameterName)) {
                    $parameterPolicySets = $parameter.policySets
                    $parameterPolicySets += $detail.displayName
                    $parameter.policySets = $parameterPolicySets
                }
                else {
                    if ($ParametersAlreadyCovered.ContainsKey($parameterName)) {
                        $parameter.multiUse = $true
                    }
                    else {
                        $null = $ParametersAlreadyCovered.Add($parameterName, $true)
                        $parameter.multiUse = $false # Redo multi-use based on sorted liist of Policies

                        $parameterValue = $null
                        if ($null -ne $AssignmentId) {
                            if ($null -ne $parameter.defaultValue) {
                                $parameterValue = $parameter.defaultValue
                            }
                            $AssignmentParameters = $AssignmentParameters
                            if ($null -ne $AssignmentParameters) {
                                # Assignment has parameters
                                if ($AssignmentParameters.ContainsKey($parameterName)) {
                                    # Effect default is replaced by assignment parameter
                                    $AssignmentLevelEffectParameter = $AssignmentParameters.$parameterName
                                    $parameterValue = $AssignmentLevelEffectParameter.value
                                }
                            }
                        }
                        $parameter.value = $parameterValue
                        $parameter.policySets = @( $detail.displayName )
                        $null = $ParametersForThisPolicy.Add($parameterName, $parameter)
                    }
                }
            }
            # Write-Information "Test"
        }
    }

    #endregion

    return $FlatPolicyList
}
