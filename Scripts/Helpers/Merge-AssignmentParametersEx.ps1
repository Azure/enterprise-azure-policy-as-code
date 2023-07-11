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
    $EffectColumn = $ParameterInstructions.effectColumn
    $ParametersColumn = $ParameterInstructions.parametersColumn
    $nonComplianceMessageColumn = $ParameterInstructions.nonComplianceMessageColumn

    #region parameters column

    $Parameters = Get-DeepClone $BaseAssignment.parameters -AsHashtable
    foreach ($row in $csvParameterArray) {
        if ($row.flatPolicyEntryKey) {
            $ParametersColumnCell = $row[$ParametersColumn]
            if ($null -ne $ParametersColumnCell -and $ParametersColumnCell -ne "") {
                $addedParameters = ConvertFrom-Json $ParametersColumnCell -Depth 100 -AsHashtable
                if ($null -ne $addedParameters -and $addedParameters.psbase.Count -gt 0) {
                    foreach ($parameterName in $addedParameters.Keys) {
                        $rawParameterValue = $addedParameters.$parameterName
                        $parameterValue = Get-DeepClone $rawParameterValue -AsHashtable
                        $Parameters[$parameterName] = $parameterValue
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
            $Name = $row.name
            $flatPolicyEntry = $FlatPolicyList.$flatPolicyEntryKey
            if ($null -eq $Name -or $Name -eq "" -or $null -eq $flatPolicyEntry -or $null -eq $flatPolicyEntry.policySetList -or $null -eq $row.policyId) {
                continue
            }
            $PolicySetList = $flatPolicyEntry.policySetList
            if ($PolicySetList.ContainsKey($PolicySetId)) {
                # Policy in this for loop iteration is referenced in the Policy Set currently being processed

                #region effect parameters including overrides
                $perPolicySet = $PolicySetList.$PolicySetId
                $EffectParameterName = $perPolicySet.effectParameterName
                $Effect = $row[$EffectColumn]
                $setEffectAllowedValues = $perPolicySet.effectAllowedValues
                $EffectAllowedOverrides = $flatPolicyEntry.effectAllowedOverrides
                $EffectDefault = $perPolicySet.effectDefault
                $desiredEffect = $Effect.ToLower()
                $useOverrides = $false
                $PolicyDefinitionReferenceId = $perPolicySet.policyDefinitionReferenceId
                if ($perPolicySet.isEffectParameterized) {
                    if ($setEffectAllowedValues -notcontains $desiredEffect) {
                        if ($EffectAllowedOverrides -notcontains $desiredEffect) {
                            Write-Error "    Node $($NodeName):  CSV parameterFile '$parameterFileName' row for Policy name '$Name': the effect ($Effect) must be an allowed parameter or override value [$($EffectAllowedOverrides -join ',')]."
                            $hasErrors = $true
                            continue
                        }
                        else {
                            $useOverrides = $true
                        }
                    }
                }
                else {
                    if ($EffectAllowedOverrides -notcontains $desiredEffect) {
                        Write-Error "    Node $($NodeName):  CSV parameterFile '$parameterFileName' row for Policy name '$Name': the effect ($Effect) must be an allowed override value [$($EffectAllowedOverrides -join ',')]."
                        $hasErrors = $true
                        continue
                    }
                    $useOverrides = $true
                }
                $isProcessed = $EffectProcessedForPolicy.ContainsKey($flatPolicyEntryKey)
                if ($isProcessed) {
                    if ($desiredEffect -eq $EffectProcessedForPolicy.$flatPolicyEntryKey) {
                        # Adjust desiredEffect
                        $modifiedEffect = switch ($desiredEffect) {
                            append {
                                "audit"
                            }
                            modify {
                                "audit"
                            }
                            deny {
                                "audit"
                            }
                            deployIfNotExists {
                                "auditIfNotExists"
                            }
                            manual {
                                "manual"
                            }
                            Default {
                                $_
                            }
                        }
                        if ($setEffectAllowedValues -contains $modifiedEffect) {
                            $desiredEffect = $modifiedEffect
                        }
                        elseif ($EffectAllowedOverrides -contains $modifiedEffect) {
                            $useOverrides = $true
                            $desiredEffect = $modifiedEffect
                        }
                        elseif (@("audit", "auditIfNotExists") -contains $modifiedEffect) {
                            $desiredEffect = "disabled"
                            if ($setEffectAllowedValues -contains "disabled") {
                                $useOverrides = $false
                            }
                            elseif ($EffectAllowedOverrides -contains "disabled") {
                                $useOverrides = $true
                            }
                        }
                    }
                }
                else {
                    $null = $EffectProcessedForPolicy.Add($flatPolicyEntryKey, $desiredEffect)
                }

                $wrongCase = !($setEffectAllowedValues -ccontains $desiredEffect -or $EffectAllowedOverrides -ccontains $desiredEffect)
                if ($wrongCase) {
                    $modifiedEffect = switch ($desiredEffect) {
                        append {
                            "Append"
                        }
                        audit {
                            "Audit"
                        }
                        auditIfNotExists {
                            "AuditIfNotExists"
                        }
                        deny {
                            "Deny"
                        }
                        deployIfNotExists {
                            "DeployIfNotExists"
                        }
                        disabled {
                            "Disabled"
                        }
                        manual {
                            "Manual"
                        }
                        modify {
                            "Modify"
                        }
                    }
                    if ($setEffectAllowedValues -ccontains $modifiedEffect -or $EffectAllowedOverrides -ccontains $modifiedEffect) {
                        $desiredEffect = $modifiedEffect
                    }
                    else {
                        Write-Error "    Node $($NodeName): CSV parameterFile '$parameterFileName' row for Policy name '$Name': the effect ($desiredEffect) must be an allowed value [$($setEffectAllowedValues -join ',')]."
                        $hasErrors = $true
                        continue
                    }
                }
                if ($desiredEffect -ne $EffectDefault) {
                    if ($useOverrides) {
                        $byEffectList = $null
                        if ($overridesByEffect.ContainsKey($desiredEffect)) {
                            $byEffectList = $overridesByEffect[$desiredEffect]
                        }
                        else {
                            $byEffectList = [System.Collections.ArrayList]::new()
                            $overridesByEffect[$desiredEffect] = $byEffectList
                        }
                        $null = $byEffectList.Add($PolicyDefinitionReferenceId)
                    }
                    else {
                        $Parameters[$EffectParameterName] = $desiredEffect
                    }
                }
                #endregion effect parameters including overrides and nonComplianceMessages

                #region nonComplianceMessages
                if ($null -ne $nonComplianceMessageColumn) {
                    $nonComplianceMessage = $row[$nonComplianceMessageColumn]
                    if ($nonComplianceMessage -ne "") {
                        $null = $nonComplianceMessages.Add(
                            @{
                                message                     = $nonComplianceMessage
                                policyDefinitionReferenceId = $PolicyDefinitionReferenceId
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

    $EffectsCount = $overridesByEffect.psbase.Count
    if ($EffectsCount -gt 0) {
        $finalOverrides = [System.Collections.ArrayList]::new()
        foreach ($EffectValue in $overridesByEffect.Keys) {
            [System.Collections.ArrayList] $PolicyDefinitionReferenceIds = $overridesByEffect[$EffectValue]
            $IdsCount = $PolicyDefinitionReferenceIds.Count
            while ($IdsCount -gt 0) {
                $Ids = $null
                if ($IdsCount -gt 50) {
                    $Ids = $PolicyDefinitionReferenceIds.GetRange(0, 50)
                    $PolicyDefinitionReferenceIds.RemoveRange(0, 50)
                    $IdsCount -= 50
                }
                else {
                    $Ids = $PolicyDefinitionReferenceIds
                    $IdsCount = 0
                }
                $override = @{
                    kind      = "policyEffect"
                    value     = $EffectValue
                    selectors = @(
                        @{
                            kind = "policyDefinitionReferenceId"
                            in   = $Ids.ToArray()
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

    $BaseAssignment.parameters = $Parameters

    return $hasErrors
}
