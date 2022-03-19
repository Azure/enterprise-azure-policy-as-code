#Requires -PSEdition Core

function Merge-Initiatives {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [string] $initiativeDisplayName,
        [Parameter(Mandatory = $true)] [hashtable] $merge,
        [Parameter(Mandatory = $true)] [hashtable] $builtInInitiativeDefinitions,
        [Parameter(Mandatory = $true)] [hashtable] $allPolicyDefinitions,
        [Parameter(Mandatory = $true)] [hashtable] $mergedParameters,
        [Parameter(Mandatory = $true)] $mergedPolicyDefinitions,
        [Parameter(Mandatory = $true)] [hashtable] $mergedGroupDefinitions
    )

    Write-Information "Initiative '$($initiativeDisplayName)' processing merge"
    if ($merge.initiatives) {
        $over16Count = 0
        $limitNotReachedPolicyDefinitionGroups = $true
        foreach ($initiative in $merge.initiatives) {
            if ($initiative.initiativeNameOrId) {
                $initiativeNameOrId = $initiative.initiativeNameOrId
                if ($builtInInitiativeDefinitions.ContainsKey($initiativeNameOrId)) {
                    $mergeInitiative = $builtInInitiativeDefinitions.$initiativeNameOrId
                    Write-Information "    Merging '$($mergeInitiative.displayName)'"
                    if ($limitNotReachedPolicyDefinitionGroups) {
                        if ($mergeInitiative.policyDefinitionGroups) {
                            # Unique Groups are always imported
                            [hashtable] $addedPolicyDefinitionGroups = @{}
                            foreach ($policyDefinitionGroup in $mergeInitiative.policyDefinitionGroups) {
                                if (!$mergedGroupDefinitions.ContainsKey($policyDefinitionGroup.name)) {
                                    # Ignore duplicates
                                    $null = $addedPolicyDefinitionGroups.Add($policyDefinitionGroup.name, $policyDefinitionGroup)
                                }
                            }
                            if ($addedPolicyDefinitionGroups.Count -gt 0) {
                                $totalNumberOfPolicyDefinitionGroups = $mergedGroupDefinitions.Count + $addedPolicyDefinitionGroups.Count
                                if ($totalNumberOfPolicyDefinitionGroups -gt 1000) {
                                    # Azure limits the number of PolicyDefinitionGroups in a Initiative to 1000
                                    Write-Information "        Too many DefinitionGroups - $($mergedGroupDefinitions.Count)+$($addedPolicyDefinitionGroups.Count)"
                                    $limitNotReachedPolicyDefinitionGroups = $false
                                }
                                else {
                                    foreach ($key in $addedPolicyDefinitionGroups.Keys) {
                                        $addedValue = $addedPolicyDefinitionGroups.$key
                                        $mergedGroupDefinitions.Add($key, $addedValue)
                                    }
                                }
                            }
                        }
                    }

                    if ($mergeInitiative.policyDefinitions) {
                        # Every Initiative should have Policy Definitions
                        foreach ($mergePolicyDefinition in $mergeInitiative.policyDefinitions) {
                            # Loop through the Policy Definition being merged in
                            $mergePolicyDefinitionId = $mergePolicyDefinition.policyDefinitionId
                            $mergedPolicyDefinition = $null
                            foreach ($merged in $mergedPolicyDefinitions) {
                                if ($merged.policyDefinitionId -eq $mergePolicyDefinitionId) {
                                    $mergedPolicyDefinition = $merged
                                    break
                                }
                            }
                            if ($null -ne $mergedPolicyDefinition) {
                                # Policy definition already covered, apply any additional groups
                                if ($limitNotReachedPolicyDefinitionGroups) {
                                    if ($mergePolicyDefinition.groupNames) {
                                        # Entry being merged in has group Names, Merge into existing entry
                                        [array] $newGroupNames = $mergePolicyDefinition.groupNames
                                        if ($mergedPolicyDefinition.groupNames) {
                                            # Already merged Policy definition has groupNames, merge groupNames as the union of groupNames
                                            [array] $existingGroupNames = $mergedPolicyDefinition.groupNames
                                            $newNumberOfGroupNames = $existingGroupNames.Count + $newGroupNames.Count
                                            if ($newNumberOfGroupNames -le 16) {
                                                # Azure limits the number of groupNames per PolicyDefinition to 16
                                                $mergedPolicyDefinition.groupNames = ($newGroupNames + $mergedPolicyDefinition.groupNames) | Sort-Object -Unique
                                            }
                                            else {
                                                # Truncate
                                                ++$over16Count
                                                Write-Information "        Too many GroupNames - $($existingGroupNames.Length)+$($newGroupNames.Length) for '$($mergedPolicyDefinition.policyDefinitionReferenceId)'"
                                            }
                                        }
                                        else {
                                            $mergedPolicyDefinition.groupNames = $newGroupNames
                                        }
                                    }
                                }
                            }
                            else {
                                # Policy definition is being merged

                                # Process any parameters
                                if ($mergePolicyDefinition.parameters) {
                                    $mergeParameters = ConvertTo-HashTable $mergePolicyDefinition.parameters
                                    foreach ($parameterName in $mergeParameters.Keys) {
                                        $parameter = $mergeParameters.$parameterName
                                        $value = $parameter.value
                                        # Analyze value
                                        $parameterPattern = "\[parameters\('(.+)'\)]"
                                        $initiativeParameterName = [regex]::match($value, $parameterPattern).Groups[1].Value
                                        if (!$mergedParameters.ContainsKey($initiativeParameterName)) {
                                            $mergeParameter = $mergeInitiative.parameters.$initiativeParameterName
                                            $null = $mergedParameters.Add($initiativeParameterName, $mergeParameter)
                                        }
                                    }
                                }

                                # Add to merged initiative
                                $null = $mergedPolicyDefinitions.Add($mergePolicyDefinition)
                            }
                        }
                    }
                }
                else {
                    Write-Error "    Built-In Initiative '$($mergeInitiative.initiativeNameOrId) not found" -ErrorAction Stop
                }
            }
            else {
                Write-Error "    Missing initiativeNameOrId" -ErrorAction Stop
            }
        }
        if ($over16Count -gt 0) {
            Write-Information "    $over16Count of $($mergedPolicyDefinitions.Count) Policy Definition have over 16 GroupNames defined"
        }
        if ($mergedParameters.Count -gt 300) {
            Write-Information "    Too many paramters defined - $($mergedParameters.Count)"
        }
    }
    else {
        Write-Error "    Missing initiatives array" -ErrorAction Stop
    }
}