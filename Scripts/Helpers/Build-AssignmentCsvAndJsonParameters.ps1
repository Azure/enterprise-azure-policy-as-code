#Requires -PSEdition Core

function Build-AssignmentCsvAndJsonParameters {
    # Recursive Function
    param(
        $nodeName,
        $policySetId,
        $policyDefinitionsScopes,
        [hashtable] $assignmentDefinition,
        [hashtable] $flatPolicyList,
        [hashtable] $combinedPolicyDetails,
        [hashtable] $effectProcessedForPolicy
    )

    # Explicitly defined parameters in tree
    $parameters = Get-DeepClone $assignmentDefinition.parameters -AsHashTable

    # Processing nnnn_ParametersColumn collection
    $parametersColumn = $assignmentDefinition.parametersColumn
    foreach ($row in $assignmentDefinition.csvParameterArray) {
        if ($row.flatPolicyEntryKey) {
            $parametersColumnCell = $row[$parametersColumn]
            if ($null -ne $parametersColumnCell -and $parametersColumnCell -ne "") {
                $addedParameters = ConvertFrom-Json $parametersColumnCell -Depth 100 -AsHashtable
                if ($null -ne $addedParameters -and $addedParameters.Count -gt 0) {
                    foreach ($parameterName in $addedParameters.Keys) {
                        $rawParameterValue = $addedParameters.$parameterName
                        $parameterValue = Get-DeepClone $rawParameterValue -AsHashTable
                        $parameters[$parameterName] = $parameterValue
                    }
                }
            }
        }
    }

    # Processing effect parameters
    $hasErrors = $false
    $effectColumn = $assignmentDefinition.effectColumn
    foreach ($row in $assignmentDefinition.csvParameterArray) {
        $flatPolicyEntryKey = $row.flatPolicyEntryKey
        if ($flatPolicyEntryKey) {
            $name = $row.name
            $flatPolicyEntry = $flatPolicyList.$flatPolicyEntryKey
            if ($null -eq $name -or $name -eq "" -or $null -eq $flatPolicyEntry -or $null -eq $flatPolicyEntry.policySetList -or $null -eq $row.policyId) {
                continue
            }
            $policySetList = $flatPolicyEntry.policySetList
            if ($policySetList.ContainsKey($policySetId)) {
                # Policy in this for loop iteration is referenced in the Policy Set currently being assigned
                $perPolicySet = $policySetList.$policySetId
                if ($perPolicySet.isEffectParameterized) {
                    $effectParameterName = $perPolicySet.effectParameterName
                    $effect = $row[$effectColumn]
                    $allEffectAllowedValues = $flatPolicyEntry.effectAllowedValues.Keys
                    $setEffectAllowedValues = $perPolicySet.effectAllowedValues
                    $desiredEffect = $effect.ToLower()
                    if ($allEffectAllowedValues -notcontains $desiredEffect) {
                        Write-Error "    Node $($nodeName):  CSV parameterFile '$parameterFileName' row for Policy name '$name': the effect ($effect) must be an allowed value [$($effectAllowedValues -join ',')]."
                        $hasErrors = $true
                        continue
                    }
                    elseif ($setEffectAllowedValues -notcontains $desiredEffect) {
                        $desiredEffect = $perPolicySet.effectDefault.ToLower()
                    }
                    $isProcessed = $effectProcessedForPolicy.ContainsKey($flatPolicyEntryKey)
                    if ($isProcessed) {
                        if ($desiredEffect -eq $effectProcessedForPolicy.$flatPolicyEntryKey) {
                            # Adjust desiredEffect
                            $modifiedEffect = switch ($desiredEffect) {
                                append { "audit" }
                                modify { "audit" }
                                deny { "deny" }
                                deployIfNotExists { "auditIfNotExists" }
                                manual { "manual" }
                                Default { $_ }
                            }
                            if ($setEffectAllowedValues -contains $modifiedEffect) {
                                $desiredEffect = $modifiedEffect
                            }
                        }
                    }
                    elseif ($desiredEffect -eq $effect) {
                        $null = $effectProcessedForPolicy.Add($flatPolicyEntryKey, $desiredEffect)
                    }

                    $wrongCase = !$setEffectAllowedValues.Contains($desiredEffect)
                    if ($wrongCase) {
                        $modifiedEffect = switch ($desiredEffect) {
                            append { "Append" }
                            audit { "Audit" }
                            auditIfNotExists { "AuditIfNotExists" }
                            deny { "Deny" }
                            deployIfNotExists { "DeployIfNotExists" }
                            disabled { "Disabled" }
                            manual { "Manual" }
                            modify { "Modify" }
                        }
                        if ($setEffectAllowedValues.Contains($modifiedEffect)) {
                            $desiredEffect = $modifiedEffect
                        }
                        else {
                            Write-Error "    Node $($nodeName): **Code bug** CSV parameterFile '$parameterFileName' row for Policy name '$name': the effect ($desiredEffect) must be an allowed value [$($setEffectAllowedValues -join ',')]."
                            $hasErrors = $true
                            continue
                        }
                    }
                    $parameters[$effectParameterName] = $desiredEffect
                }
            }
        }
    }
    return $parameters, $hasErrors
}