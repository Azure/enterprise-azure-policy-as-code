function Confirm-PolicyDefinitionsInPolicySetMatch {
    [CmdletBinding()]
    param (
        $Object1,
        $Object2,
        $Definitions,
        [bool] $GenerateDiff = $false
    )

    $diff = @()
    
    # check for null or empty scenarios
    if ($Object1 -eq $Object2) {
        if ($GenerateDiff) {
            return @{ match = $true; diff = $diff }
        }
        return $true
    }
    if ($Object1 -and $Object1 -isnot [System.Collections.IList]) {
        $Object1 = @($Object1)
    }
    if ($Object2 -and $Object2 -isnot [System.Collections.IList]) {
        $Object2 = @($Object2)
    }
    if (($null -eq $Object1 -and $Object2.Count -eq 0) -or ($null -eq $Object2 -and $Object1.Count -eq 0)) {
        if ($GenerateDiff) {
            return @{ match = $true; diff = $diff }
        }
        return $true
    }
    if ($null -eq $Object1 -or $null -eq $Object2) {
        if ($GenerateDiff) {
            return @{ match = $false; diff = $diff }
        }
        return $false
    }

    # If generating diff, use identity-based comparison
    if ($GenerateDiff) {
        # Build hashtables using policyDefinitionId as key for identity-based comparison
        $policies1 = @{}
        $policies2 = @{}
        
        foreach ($item in $Object1) {
            $policies1[$item.policyDefinitionId] = $item
        }
        foreach ($item in $Object2) {
            $policies2[$item.policyDefinitionId] = $item
        }
        
        # Find removed policies
        foreach ($id in $policies1.Keys) {
            if (!$policies2.ContainsKey($id)) {
                $diff += New-DiffEntry -Operation "remove" -Path "/policyDefinitions[$id]" `
                    -Before $policies1[$id] -Classification "array"
            }
        }
        
        # Find added and modified policies
        foreach ($id in $policies2.Keys) {
            if (!$policies1.ContainsKey($id)) {
                $diff += New-DiffEntry -Operation "add" -Path "/policyDefinitions[$id]" `
                    -After $policies2[$id] -Classification "array"
            }
            else {
                $item1 = $policies1[$id]
                $item2 = $policies2[$id]
                
                # Check for changes in policy definition
                if ($item1.policyDefinitionReferenceId -ne $item2.policyDefinitionReferenceId) {
                    $diff += New-DiffEntry -Operation "replace" -Path "/policyDefinitions[$id]/policyDefinitionReferenceId" `
                        -Before $item1.policyDefinitionReferenceId -After $item2.policyDefinitionReferenceId -Classification "array"
                }
                
                # Check for group name changes
                if (!(Confirm-ObjectValueEqualityDeep $item1.groupNames $item2.groupNames)) {
                    $diff += New-DiffEntry -Operation "replace" -Path "/policyDefinitions[$id]/groupNames" `
                        -Before $item1.groupNames -After $item2.groupNames -Classification "array"
                }
                
                # Check for parameter changes
                $paramResult = Confirm-ParametersUsageMatches `
                    -ExistingParametersObj $item1.parameters `
                    -DefinedParametersObj $item2.parameters `
                    -CompareValueEntryForExistingParametersObj `
                    -CompareValueEntryForDefinedParametersObj `
                    -GenerateDiff $true
                
                if ($paramResult.diff -and $paramResult.diff.Count -gt 0) {
                    foreach ($paramDiff in $paramResult.diff) {
                        $newPath = "/policyDefinitions[$id]$($paramDiff.path)"
                        $diff += New-DiffEntry -Operation $paramDiff.op -Path $newPath `
                            -Before $paramDiff.before -After $paramDiff.after -Classification $paramDiff.classification
                    }
                }
            }
        }
        
        return @{ 
            match = ($diff.Count -eq 0)
            diff  = $diff 
        }
    }

    # Original index-based comparison when not generating diff
    if ($Object1.Count -ne $Object2.Count) {
        return $false
    }
    for ($i = 0; $i -le $Object1.Count; $i++) {
        $item1 = $Object1[$i] # this is the Azure Policy definition set
        $item2 = $Object2[$i] # this is the local policy definition set
        if ($item1 -ne $item2) {
            $policyDefinitionReferenceIdMatches = $item1.policyDefinitionReferenceId -eq $item2.policyDefinitionReferenceId
            if (!$policyDefinitionReferenceIdMatches) {
                return $false
            }
            $policyDefinitionIdMatches = $item1.policyDefinitionId -eq $item2.policyDefinitionId
            if (!$policyDefinitionIdMatches) {
                return $false
            }

            # Validate the Azure definitionVersion with the local definitionVersion, if the local definitionVersion doesn't exist and the Azure definitionVersion is not equal to latest policy version then return false
            # This addresses an error that occurs when there is a null value in the definitionVersion field that cropped up when we removed the variable prior to processing to fix a bug spotted in Build-HydrationDeploymentPlans where the values were retained, and adversely affecting the update information.
            # try {
            #     if ($null -eq $item1.definitionVersion -and $null -eq $item2.definitionVersion) {
            #         # Compare-SemanticVersion -Version1 0 -Version2 0 is always 0, so we forego the calculation and set it
            #         $definitionVersionMatches = 0
            #     }
            #     elseif ($null -eq $item1.definitionVersion) {
            #         # Compare-SemanticVersion -Version1 0 -Version2 (anything not 0) is always -1, so we forego the calculation and set it
            #         # $definitionVersionMatches = Compare-SemanticVersion -Version1 0 -Version2 $item2.definitionVersion
            #         $definitionVersionMatches = -1
            #     }
            #     elseif ($null -eq $item2.definitionVersion) {
            #         # Compare-SemanticVersion -Version1 (anything not 0) -Version2 0 is always 1, so we forego the calculation and set it
            #         # $definitionVersionMatches = Compare-SemanticVersion -Version1 $item1.definitionVersion -Version2 0
            #         $definitionVersionMatches = 1
            #     }               
            #     else {
            #         # If neither of the definitionVersion values are null, then the compare can proceed without error
            #         $definitionVersionMatches = Compare-SemanticVersion -Version1 $($item1.definitionVersion ?? $Definitions[$item1.policyDefinitionId].properties.version ?? '1.*.*') -Version2 $($item2.definitionVersion ?? $Definitions[$item1.policyDefinitionId].properties.version ?? '1.*.*')
            #     }
            # }
            # catch {
            #     Write-Information "Comparison has generated an error."
            #     Write-Information "Item1: $($item1.policyDefinitionId) $($item1.policySetDefinitionId) $($item1.policyDefinitionName) $($item1.policySetDefinitionName)"
            #     Write-Information "Item2: $($item2.policyDefinitionId) $($item2.policySetDefinitionId) $($item2.policyDefinitionName) $($item2.policySetDefinitionName)"
            #     continue
            # }
            # if ($definitionVersionMatches -ne 0) {
            #     Write-Verbose "Definition Id: $($item1.policyDefinitionId)"
            #     Write-Verbose "DefinitionVersion does not match: Azure: $($item1.definitionVersion), Local: $($item2.definitionVersion)"
            #     return $false
            # }

            $groupNames1 = $item1.groupNames
            $groupNames2 = $item2.groupNames
            if ($null -eq $groupNames1 -and $null -eq $groupNames2 -and $i -eq $Object1.Count) {
                return $true
            }
            if ($null -eq $groupNames1 -or $null -eq $groupNames2 -and $i -eq $Object1.Count) {
                if (($null -ne $groupNames1 -and $groupNames1.Count -eq 0) -or ($null -ne $groupNames2 -and $groupNames2.Count -eq 0)) {
                    return $true
                }
                return $false
            }

            if ($groupNames1.Count -ne $groupNames2.Count) {
                return $false
            }

            if ($groupNames1 -and $groupNames2) {
                $groupNamesCompareResults = Compare-Object -ReferenceObject $groupNames1 -DifferenceObject $groupNames2
                if ($groupNamesCompareResults) {
                    return $false
                }
            }

            $parametersUsageMatches = Confirm-ParametersUsageMatches `
                -ExistingParametersObj $item1.parameters `
                -DefinedParametersObj $item2.parameters `
                -CompareValueEntryForExistingParametersObj `
                -CompareValueEntryForDefinedParametersObj
            if (!$parametersUsageMatches) {
                return $false
            }
        }
    }
    return $true
}
