function Merge-AssignmentParametersEx {
    # Recursive Function
    param(
        $NodeName,
        $PolicySetId,
        [hashtable] $BaseAssignment,
        [hashtable] $ParameterInstructions,
        [hashtable] $FlatPolicyList,
        [hashtable] $CombinedPolicyDetails,
        [hashtable] $EffectProcessedForPolicy
    )

    $csvParameterArray = $ParameterInstructions.csvParameterArray
    $effectColumn = $ParameterInstructions.effectColumn
    $parametersColumn = $ParameterInstructions.parametersColumn
    $nonComplianceMessageColumn = $ParameterInstructions.nonComplianceMessageColumn

    #region parameters column

    $parameters = Get-DeepClone $BaseAssignment.parameters -AsHashTable
    foreach ($row in $csvParameterArray) {
        if ($row.flatPolicyEntryKey) {
            $parametersColumnCell = $row[$parametersColumn]
            if ($null -ne $parametersColumnCell -and $parametersColumnCell -ne "") {
                $addedParameters = ConvertFrom-Json $parametersColumnCell -Depth 100 -AsHashTable
                if ($null -ne $addedParameters -and $addedParameters.psbase.Count -gt 0) {
                    foreach ($parameterName in $addedParameters.Keys) {
                        $rawParameterValue = $addedParameters.$parameterName
                        $parameterValue = Get-DeepClone $rawParameterValue -AsHashTable
                        $parameters[$parameterName] = $parameterValue
                    }
                }
            }
        }
    }

    #endregion parameters column

    #region parameters column = mutual exclusion handled

    $overridesByEffect = @{}
    $nonComplianceMessages = $BaseAssignment.nonComplianceMessages
    $hasErrors = $false
    foreach ($row in $csvParameterArray) {
        $flatPolicyEntryKey = $row.flatPolicyEntryKey
        if ($flatPolicyEntryKey) {
            $name = $row.name
            $flatPolicyEntry = $FlatPolicyList.$flatPolicyEntryKey
            if ($null -eq $name -or $name -eq "" -or $null -eq $flatPolicyEntry -or $null -eq $flatPolicyEntry.policySetList -or $null -eq $row.policyId) {
                continue
            }
            $policySetList = $flatPolicyEntry.policySetList
            if ($policySetList.ContainsKey($PolicySetId)) {
                # Policy in this for loop iteration is referenced in the Policy Set currently being processed

                #region effect parameters including overrides
                $perPolicySet = $policySetList.$PolicySetId
                $effectParameterName = $perPolicySet.effectParameterName
                $effect = $row[$effectColumn]
                $setEffectAllowedValues = $perPolicySet.effectAllowedValues
                $effectAllowedOverrides = $flatPolicyEntry.effectAllowedOverrides
                $effectDefault = $perPolicySet.effectDefault
                $desiredEffect = $effect.ToLower()
                $useOverrides = $false
                $policyDefinitionReferenceId = $perPolicySet.policyDefinitionReferenceId
                $isProcessed = $EffectProcessedForPolicy.ContainsKey($flatPolicyEntryKey)
                $modifiedEffect = $desiredEffect
                if ($isProcessed) {
                    # the second and subsequent time this Policy is processed, the effect must be adjusted to audit
                    if ($desiredEffect -eq $EffectProcessedForPolicy.$flatPolicyEntryKey) {
                        # Adjust desiredEffect
                        $modifiedEffect = switch ($desiredEffect) {
                            append {
                                "Audit"
                            }
                            modify {
                                "Audit"
                            }
                            deny {
                                "Audit"
                            }
                            deployIfNotExists {
                                "AuditIfNotExists"
                            }
                            manual {
                                "Manual"
                            }
                            Default {
                                $_
                            }
                        }
                    }
                }
                else {
                    # first encounter of this Policy, use desired value (previously set) and enter in list of processed Policies
                    $null = $EffectProcessedForPolicy.Add($flatPolicyEntryKey, $desiredEffect)
                }

                $isAllowed = $false
                if ($perPolicySet.isEffectParameterized) {
                    if ($desiredEffect -ne $modifiedEffect) {
                        # check if the modified effect is an allowed parameter value or an allowed override value
                        if ($setEffectAllowedValues -contains $modifiedEffect) {
                            # the modified effect is an allowed parameter value
                            $isAllowed = $true
                            $desiredEffect = $modifiedEffect
                        }
                        elseif ($effectAllowedOverrides -contains $modifiedEffect) {
                            # the modified effect is an allowed override value
                            $desiredEffect = $modifiedEffect
                            $isAllowed = $true
                            $useOverrides = $true
                        }
                    }
                    if (!$isAllowed) {
                        # check if the original desired effect is an allowed parameter value or an allowed override value
                        if ($setEffectAllowedValues -contains $desiredEffect) {
                            # the original desired effect is an allowed parameter value
                            $isAllowed = $true
                        }
                        elseif ($effectAllowedOverrides -contains $desiredEffect) {
                            # the original desired effect is an allowed override value
                            $isAllowed = $true
                            $useOverrides = $true
                        }
                    }
                }
                else {
                    # the effect is not parameterized
                    if ($desiredEffect -ne $modifiedEffect) {
                        # check if the modified effect is an allowed override value
                        if ($effectAllowedOverrides -contains $modifiedEffect) {
                            # the modified effect is an allowed override value
                            $desiredEffect = $modifiedEffect
                            $isAllowed = $true
                            $useOverrides = $true
                        }
                    }
                    if (!$isAllowed) {
                        # check if the original desired effect is an allowed override value
                        if ($effectAllowedOverrides -contains $desiredEffect) {
                            # the original desired effect is an allowed override value
                            $isAllowed = $true
                            $useOverrides = $true
                        }
                    }
                }

                if (!$isAllowed) {
                    # the effect is not an allowed value
                    Write-Error "    Node $($NodeName):  CSV parameterFile '$parameterFileName' row for Policy name '$name': the effect ($effect) must be an allowed value."
                    $hasErrors = $true
                    continue
                }
                else {
                    if ($desiredEffect -ne $effectDefault) {
                        # the effect is not the default value
                        if ($useOverrides) {
                            # find the correct case for the allowed override value
                            foreach ($effectAllowedOverride in $effectAllowedOverrides) {
                                if ($effectAllowedOverride -eq $desiredEffect) {
                                    $desiredEffect = $effectAllowedOverride # fixes potentially wrong case, or keeps the original case
                                    break
                                }
                            }
                            # collate the overrides by effect
                            $byEffectList = $null
                            if ($overridesByEffect.ContainsKey($desiredEffect)) {
                                $byEffectList = $overridesByEffect[$desiredEffect]
                            }
                            else {
                                $byEffectList = [System.Collections.ArrayList]::new()
                                $overridesByEffect[$desiredEffect] = $byEffectList
                            }
                            $null = $byEffectList.Add($policyDefinitionReferenceId)
                        }
                        else {
                            # find the correct case for the allowed parameter value
                            foreach ($setEffectAllowedValue in $setEffectAllowedValues) {
                                if ($setEffectAllowedValue -eq $desiredEffect) {
                                    $desiredEffect = $setEffectAllowedValue # fixes potentially wrong case, or keeps the original case
                                    break
                                }
                            }
                            # set the effect parameter
                            $parameters[$effectParameterName] = $desiredEffect
                        }
                    }
                }
                #endregion effect parameters including overrides

                #region nonComplianceMessages
                if ($null -ne $nonComplianceMessageColumn) {
                    $nonComplianceMessage = $row[$nonComplianceMessageColumn]
                    if ($nonComplianceMessage -ne "") {
                        $null = $nonComplianceMessages.Add(
                            @{
                                message                     = $nonComplianceMessage
                                policyDefinitionReferenceId = $policyDefinitionReferenceId
                            }
                        )
                    }
                }
                #endregion nonComplianceMessages
            }
        }
    }

    #endregion parameters column = mutual exclusion handled

    #region optimize overrides

    $effectsCount = $overridesByEffect.psbase.Count
    if ($effectsCount -gt 0) {
        $finalOverrides = [System.Collections.ArrayList]::new()
        foreach ($effectValue in $overridesByEffect.Keys) {
            [System.Collections.ArrayList] $policyDefinitionReferenceIds = $overridesByEffect[$effectValue]
            $idsCount = $policyDefinitionReferenceIds.Count
            $startIndex = 0
            while ($idsCount -gt 0) {
                $ids = $null
                if ($idsCount -gt 50) {
                    # each override can have up to 50 selectors
                    $ids = ($policyDefinitionReferenceIds.GetRange($startIndex, 50)).ToArray()
                    $startIndex += 50
                    $idsCount -= 50
                }
                else {
                    $ids = ($policyDefinitionReferenceIds.GetRange($startIndex, $idsCount)).ToArray()
                    $idsCount = 0
                }
                $override = @{
                    kind      = "policyEffect"
                    value     = $effectValue
                    selectors = @(
                        @{
                            kind = "policyDefinitionReferenceId"
                            in   = $ids
                        }
                    )
                }
                $null = $finalOverrides.Add($override)
            }
        }
        if ($finalOverrides.Count -gt 10) {
            Write-Error "    Node $($NodeName): CSV parameterFile '$parameterFileName' causes too many overrides ($($finalOverrides.Count)) for Policies without parameterized effect." -ErrorAction Continue
            $hasErrors = $true
        }
        else {
            $BaseAssignment.overrides = $finalOverrides.ToArray()
        }
    }
    #endregion optimize overrides

    $BaseAssignment.parameters = $parameters

    return $hasErrors
}
