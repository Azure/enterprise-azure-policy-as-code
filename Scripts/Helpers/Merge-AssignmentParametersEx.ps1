function Merge-AssignmentParametersEx {
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
    $parameters = Get-DeepCloneAsOrderedHashtable $BaseAssignment.parameters
    foreach ($row in $csvParameterArray) {
        if ($row.flatPolicyEntryKey) {
            $parametersColumnCell = $row[$parametersColumn]
            if ($null -ne $parametersColumnCell -and $parametersColumnCell -ne "") {
                $addedParameters = ConvertFrom-Json $parametersColumnCell -Depth 100 -AsHashTable
                if ($null -ne $addedParameters) {
                    foreach ($parameterName in $addedParameters.Keys) {
                        if (!$parameters.ContainsKey($parameterName)) {
                            $parameterValue = $addedParameters.$parameterName
                            $parameters[$parameterName] = $parameterValue
                        }
                    }
                }
            }
        }
    }
    #endregion parameters column

    #region effects column = mutual exclusion handled
    $overridesByEffect = @{}
    $nonComplianceMessages = $BaseAssignment.nonComplianceMessages
    $hasErrors = $false
    $rowNumber = 1
    foreach ($row in $csvParameterArray) {
        ++$rowNumber
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

                $requestedEffect = $row[$effectColumn]
                $planedEffect = $requestedEffect
                $isProcessed = $EffectProcessedForPolicy.ContainsKey($flatPolicyEntryKey)
                $perPolicySet = $policySetList.$PolicySetId
                $effectParameterName = $perPolicySet.effectParameterName
                $effectAllowedValues = $perPolicySet.effectAllowedValues
                $effectAllowedOverrides = $perPolicySet.effectAllowedOverrides
                $effectDefault = $perPolicySet.effectDefault
                $policyDefinitionReferenceId = $perPolicySet.policyDefinitionReferenceId
                if ($isProcessed) {
                    #region the second and subsequent time this Policy is processed, the effect must be adjusted to audit
                    $planedEffect = switch ($requestedEffect) {
                        "Append" {
                            "Audit"
                            break
                        }
                        "Modify" {
                            "Audit"
                            break
                        }
                        "Deny" {
                            "Audit"
                            break
                        }
                        "DeployIfNotExists" {
                            "AuditIfNotExists"
                            break
                        }
                        "DenyAction" {
                            "Disabled"
                            break
                        }
                        default {
                            $_
                        }
                    }
                    #endregion the second and subsequent time this Policy is processed, the effect must be adjusted to audit
                }
                else {
                    $EffectProcessedForPolicy[$flatPolicyEntryKey] = $true
                }

                if ($planedEffect -ne $effectDefault) {

                    #region effect parameters including overrides
                    $useOverrides = $false
                    $confirmedEffect = $null
                    if ($perPolicySet.isEffectParameterized) {
                        # test parameter
                        $useOverrides = $false
                        $confirmedEffect = Confirm-EffectIsAllowed -Effect $planedEffect -AllowedEffects $effectAllowedValues
                        if ($null -eq $confirmedEffect) {
                            # fallback 1: test override
                            $useOverrides = $true
                            $confirmedEffect = Confirm-EffectIsAllowed -Effect $planedEffect -AllowedEffects $effectAllowedOverrides
                            if ($null -eq $confirmedEffect -and $requestedEffect -ne $planedEffect) {
                                # fallback 2: if this is the second processed Policy Set, try parameter with original requested effect
                                $useOverrides = $false
                                $confirmedEffect = Confirm-EffectIsAllowed -Effect $requestedEffect -AllowedEffects $effectAllowedValues
                                if ($null -eq $confirmedEffect) {
                                    # fallback 3: try overrides with the original requested effect
                                    $useOverrides = $true
                                    $confirmedEffect = Confirm-EffectIsAllowed -Effect $requestedEffect -AllowedEffects $effectAllowedOverrides
                                }
                            }
                        }
                    }
                    else {
                        # the effect is not parameterized
                        $useOverrides = $true
                        $confirmedEffect = Confirm-EffectIsAllowed -Effect $planedEffect -AllowedEffects $effectAllowedOverrides
                        if ($null -eq $confirmedEffect) {
                            # fallback: try overrides with the original requested effect
                            $confirmedEffect = Confirm-EffectIsAllowed -Effect $requestedEffect -AllowedEffects $effectAllowedOverrides
                        }
                    }

                    if ($null -eq $confirmedEffect) {
                        # the effect is not an allowed value
                        Write-Error "    Node $($NodeName):  CSV parameterFile '$parameterFileName' row $rowNumber for Policy name '$name': the effect ($effect) must be an allowed value." -ErrorAction Continue
                        $hasErrors = $true
                        continue
                    }
                    elseif ($confirmedEffect -ne $effectDefault) {
                        if ($useOverrides) {
                            # collate the overrides by effect
                            $byEffectList = $null
                            if ($overridesByEffect.ContainsKey($confirmedEffect)) {
                                $byEffectList = $overridesByEffect[$confirmedEffect]
                            }
                            else {
                                $byEffectList = [System.Collections.ArrayList]::new()
                                $overridesByEffect[$confirmedEffect] = $byEffectList
                            }
                            $null = $byEffectList.Add($policyDefinitionReferenceId)
                        }
                        else {
                            # set the effect parameter
                            $parameters[$effectParameterName] = $confirmedEffect
                        }
                    }
                    #endregion effect parameters including overrides
                }

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

    #endregion effects column = mutual exclusion handled

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
