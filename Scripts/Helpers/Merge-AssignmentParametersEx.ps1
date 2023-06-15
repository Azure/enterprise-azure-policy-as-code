function Merge-AssignmentParametersEx {
    # Recursive Function
    param(
        $nodeName,
        $policySetId,
        [hashtable] $baseAssignment,
        [hashtable] $parameterInstructions,
        [hashtable] $flatPolicyList,
        [hashtable] $combinedPolicyDetails,
        [hashtable] $effectProcessedForPolicy
    )

    $csvParameterArray = $parameterInstructions.csvParameterArray
    $effectColumn = $parameterInstructions.effectColumn
    $parametersColumn = $parameterInstructions.parametersColumn
    $nonComplianceMessageColumn = $parameterInstructions.nonComplianceMessageColumn

    #region parameters column

    $parameters = Get-DeepClone $baseAssignment.parameters -AsHashTable
    foreach ($row in $csvParameterArray) {
        if ($row.flatPolicyEntryKey) {
            $parametersColumnCell = $row[$parametersColumn]
            if ($null -ne $parametersColumnCell -and $parametersColumnCell -ne "") {
                $addedParameters = ConvertFrom-Json $parametersColumnCell -Depth 100 -AsHashtable
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
    $nonComplianceMessages = $baseAssignment.nonComplianceMessages
    $hasErrors = $false
    foreach ($row in $csvParameterArray) {
        $flatPolicyEntryKey = $row.flatPolicyEntryKey
        if ($flatPolicyEntryKey) {
            $name = $row.name
            $flatPolicyEntry = $flatPolicyList.$flatPolicyEntryKey
            if ($null -eq $name -or $name -eq "" -or $null -eq $flatPolicyEntry -or $null -eq $flatPolicyEntry.policySetList -or $null -eq $row.policyId) {
                continue
            }
            $policySetList = $flatPolicyEntry.policySetList
            if ($policySetList.ContainsKey($policySetId)) {
                # Policy in this for loop iteration is referenced in the Policy Set currently being processed

                #region effect parameters including overrides
                $perPolicySet = $policySetList.$policySetId
                $effectParameterName = $perPolicySet.effectParameterName
                $effect = $row[$effectColumn]
                $setEffectAllowedValues = $perPolicySet.effectAllowedValues
                $effectAllowedOverrides = $flatPolicyEntry.effectAllowedOverrides
                $effectDefault = $perPolicySet.effectDefault
                $desiredEffect = $effect.ToLower()
                $useOverrides = $false
                $policyDefinitionReferenceId = $perPolicySet.policyDefinitionReferenceId
                if ($perPolicySet.isEffectParameterized) {
                    if ($setEffectAllowedValues -notcontains $desiredEffect) {
                        if ($effectAllowedOverrides -notcontains $desiredEffect) {
                            Write-Error "    Node $($nodeName):  CSV parameterFile '$parameterFileName' row for Policy name '$name': the effect ($effect) must be an allowed parameter or override value [$($effectAllowedOverrides -join ',')]."
                            $hasErrors = $true
                            continue
                        }
                        else {
                            $useOverrides = $true
                        }
                    }
                }
                else {
                    if ($effectAllowedOverrides -notcontains $desiredEffect) {
                        Write-Error "    Node $($nodeName):  CSV parameterFile '$parameterFileName' row for Policy name '$name': the effect ($effect) must be an allowed override value [$($effectAllowedOverrides -join ',')]."
                        $hasErrors = $true
                        continue
                    }
                    $useOverrides = $true
                }
                $isProcessed = $effectProcessedForPolicy.ContainsKey($flatPolicyEntryKey)
                if ($isProcessed) {
                    if ($desiredEffect -eq $effectProcessedForPolicy.$flatPolicyEntryKey) {
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
                        elseif ($effectAllowedOverrides -contains $modifiedEffect) {
                            $useOverrides = $true
                            $desiredEffect = $modifiedEffect
                        }
                        elseif (@("audit", "auditIfNotExists") -contains $modifiedEffect) {
                            $desiredEffect = "disabled"
                            if ($setEffectAllowedValues -contains "disabled") {
                                $useOverrides = $false
                            }
                            elseif ($effectAllowedOverrides -contains "disabled") {
                                $useOverrides = $true
                            }
                        }
                    }
                }
                else {
                    $null = $effectProcessedForPolicy.Add($flatPolicyEntryKey, $desiredEffect)
                }

                $wrongCase = !($setEffectAllowedValues -ccontains $desiredEffect -or $effectAllowedOverrides -ccontains $desiredEffect)
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
                    if ($setEffectAllowedValues -ccontains $modifiedEffect -or $effectAllowedOverrides -ccontains $modifiedEffect) {
                        $desiredEffect = $modifiedEffect
                    }
                    else {
                        Write-Error "    Node $($nodeName): CSV parameterFile '$parameterFileName' row for Policy name '$name': the effect ($desiredEffect) must be an allowed value [$($setEffectAllowedValues -join ',')]."
                        $hasErrors = $true
                        continue
                    }
                }
                if ($desiredEffect -ne $effectDefault) {
                    if ($useOverrides) {
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
                        $parameters[$effectParameterName] = $desiredEffect
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
            while ($idsCount -gt 0) {
                $ids = $null
                if ($idsCount -gt 50) {
                    $ids = $policyDefinitionReferenceIds.GetRange(0, 50)
                    $policyDefinitionReferenceIds.RemoveRange(0, 50)
                    $idsCount -= 50
                }
                else {
                    $ids = $policyDefinitionReferenceIds
                    $idsCount = 0
                }
                $override = @{
                    kind      = "policyEffect"
                    value     = $effectValue
                    selectors = @(
                        @{
                            kind = "policyDefinitionReferenceId"
                            in   = $ids.ToArray()
                        }
                    )
                }
                $null = $finalOverrides.Add($override)
            }
        }
        if ($finalOverrides.Count -gt 10) {
            Write-Error "    Node $($nodeName): CSV parameterFile '$parameterFileName' causes too many overrides ($($finalOverrides.Count)) for Policies without parameterized effect." -ErrorAction Continue
            $hasErrors = $true
        }
        else {
            $baseAssignment.overrides = $finalOverrides.ToArray()
        }
    }
    #endregion optimize overrides

    $baseAssignment.parameters = $parameters

    return $hasErrors
}