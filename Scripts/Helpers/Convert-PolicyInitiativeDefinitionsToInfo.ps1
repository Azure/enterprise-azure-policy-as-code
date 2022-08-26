#Requires -PSEdition Core

function Convert-PolicyInitiativeDefinitionsToInfo {
    [CmdletBinding()]
    param (
        [hashtable] $allAzPolicyInitiativeDefinitions
    )

    $allPolicyDefinitions = $allAzPolicyInitiativeDefinitions.existingCustomPolicyDefinitions + $allAzPolicyInitiativeDefinitions.builtInPolicyDefinitions
    $policyInfos = @{}
    foreach ($policyId in $allPolicyDefinitions.Keys) {
        $policy = $allPolicyDefinitions.$policyId
        $category = "Unknown"
        if ($policy.metadata -and $policy.metadata.category) {
            $category = $policy.metadata.category
        }
        $effectRawValue = $policy.policyRule.then.effect
        $found, $effectParameterName = Get-ParameterNameFromValueString -paramValue $effectRawValue

        $effectValue = $null
        $effectDefault = $null
        $effectAllowedValues = @()
        $effectReason = "Policy No Default"
        $parameters = $policy.parameters | ConvertTo-HashTable
        if ($found) {
            if ($effectParameter.allowedValues) {
                $effectAllowedValues = $effectParameter.allowedValues
            }
            if ($parameters.ContainsKey($effectParameterName)) {
                $effectParameter = $parameters.$effectParameterName
                if ($effectParameter.defaultValue) {
                    $effectValue = $effectParameter.defaultValue
                    $effectDefault = $effectParameter.defaultValue
                    $effectAllowedValues = @( $effectDefault )
                    $effectReason = "Policy Default"
                }
            }
            else {
                Write-Error "Policy uses parameter '$effectParameterName' for the effect not defined in the parameters. This should not be possible!" -ErrorAction Stop
            }
        }
        else {
            # Fixed value
            $effectValue = $effectRawValue
            $effectDefault = $effectRawValue
            $effectAllowedValues = @( $effectRawValue )
            $effectReason = "Policy Fixed"
        }

        $displayName = $policy.displayName
        if (-not $displayName -or $displayName -eq "") {
            $displayName = $policy.name
        }

        $description = $policy.description
        if (-not $description) {
            $description = ""
        }

        $parameterDefinitions = @{}
        foreach ($parameterName in $parameters.Keys) {
            $parameter = $parameters.$parameterName
            $parameterDefinition = @{
                isEffect     = $parameterName -eq $effectParameterName
                value        = $null
                defaultValue = $parameter.defaultValue
                definition   = $parameter
            }
            $null = $parameterDefinitions.Add($parameterName, $parameterDefinition)
        }

        $policyInfo = @{
            id                  = $policyId
            name                = $policy.name
            displayName         = $displayName
            description         = $description
            policyType          = $policy.policyType
            category            = $category
            effectParameterName = $effectParameterName
            effectValue         = $effectValue
            effectDefault       = $effectDefault
            effectAllowedValues = $effectAllowedValues
            effectReason        = $effectReason
            parameters          = $parameterDefinitions
        }
        $null = $policyInfos.Add($policyId, $policyInfo)
    }

    $allInitiativeDefinitions = $allAzPolicyInitiativeDefinitions.existingCustomInitiativeDefinitions + $allAzPolicyInitiativeDefinitions.builtInInitiativeDefinitions
    $initiativeInfos = @{}
    foreach ($initiativeId in $allInitiativeDefinitions.Keys) {
        $initiative = $allInitiativeDefinitions.$initiativeId
        $category = "Unknown"
        if ($initiative.metadata -and $initiative.metadata.category) {
            $category = $initiative.metadata.category
        }

        [System.Collections.ArrayList] $policyInInitiativeInfoList = [System.Collections.ArrayList]::new()
        $initiativeParameters = $initiative.parameters | ConvertTo-HashTable
        $parametersAlreadyCovered = @{}
        foreach ($policyInInitiative in $initiative.policyDefinitions) {
            $policyId = $policyInInitiative.policyDefinitionId
            if ($policyInfos.ContainsKey($policyId)) {
                $policyInfo = $policyInfos.$policyId
                $policyInInitiativeParameters = $policyInInitiative.parameters | ConvertTo-HashTable

                $initiativeLevelEffectParameterName = $null
                $effectParameterName = $policyInfo.effectParameterName
                $effectValue = $policyInfo.effectValue
                $effectDefault = $policyInfo.effectDefault
                $effectAllowedValues = $policyInfo.effectAllowedValues
                $effectReason = $policyInfo.effectReason

                $initiativeLevelEffectParameterFound = $false
                $initiativeLevelEffectParameterName = ""
                if ($effectReason -ne "Policy Fixed") {
                    # Effect is parameterized in Policy
                    if ($policyInInitiativeParameters.ContainsKey($effectParameterName)) {
                        # Effect parameter is used by initiative
                        $initiativeLevelEffectParameter = $policyInInitiativeParameters.$effectParameterName
                        $effectRawValue = $initiativeLevelEffectParameter.value

                        $initiativeLevelEffectParameterFound, $initiativeLevelEffectParameterName = Get-ParameterNameFromValueString -paramValue $effectRawValue
                        if ($initiativeLevelEffectParameterFound) {
                            # Effect parameter is surfaced by Initiative
                            if ($initiativeParameters.ContainsKey($initiativeLevelEffectParameterName)) {
                                $effectParameter = $initiativeParameters.$initiativeLevelEffectParameterName
                                if ($effectParameter.defaultValue) {
                                    $effectValue = $effectParameter.defaultValue
                                    $effectDefault = $effectParameter.defaultValue
                                    $effectReason = "Initiative Default"
                                }
                                else {
                                    $effectReason = "Initiative No Default"
                                }
                                if ($effectParameter.allowedValues) {
                                    $effectAllowedValues = $effectParameter.allowedValues
                                }
                            }
                            else {
                                Write-Error "Policy uses parameter '$effectParameterName' for the effect not defined in the parameters. This should not be possible!" -ErrorAction Stop
                            }
                        }
                        else {
                            # Effect parameter is hard-coded (fixed) by Initiative
                            $initiativeLevelEffectParameterName = $null
                            $effectValue = $effectRawValue
                            $effectDefault = $effectRawValue
                            $effectReason = "Initiative Fixed"
                        }
                    }
                }

                # Process Policy parameters surfaced by Initiative
                $surfacedParameters = @{}
                foreach ($parameterName in $policyInInitiativeParameters.Keys) {
                    $parameter = $policyInInitiativeParameters.$parameterName
                    $rawValue = $parameter.value
                    if ($rawValue -is [string]) {
                        $found, $initiativeParameterName = Get-ParameterNameFromValueString -paramValue $rawValue
                        if ($found) {
                            $initiativeParameter = $initiativeParameters.$initiativeParameterName
                            $multiUse = $false
                            $defaultValue = $initiativeParameter.defaultValue
                            $isEffect = $initiativeParameterName -eq $initiativeLevelEffectParameterName
                            if ($parametersAlreadyCovered.ContainsKey($initiativeParameterName)) {
                                $multiUse = $true
                            }
                            else {
                                $null = $parametersAlreadyCovered.Add($initiativeParameterName, $true)
                            }
                            $null = $surfacedParameters.Add($initiativeParameterName, @{
                                    multiUse     = $multiUse
                                    isEffect     = $isEffect
                                    value        = $defaultValue
                                    defaultValue = $defaultValue
                                    definition   = $initiativeParameter
                                }
                            )
                        }
                    }
                }

                # Assemble the info
                $groupNames = @()
                if ($policyInInitiative.groupNames) {
                    $groupNames = $policyInInitiative.groupNames
                }
                $policyInInitiativeInfo = @{
                    id                          = $policyInfo.id
                    name                        = $policyInfo.name
                    displayName                 = $policyInfo.displayName
                    description                 = $policyInfo.description
                    policyType                  = $policyInfo.policyType
                    category                    = $policyInfo.category
                    effectParameterName         = $initiativeLevelEffectParameterName
                    effectValue                 = $effectValue
                    effectDefault               = $effectDefault
                    effectAllowedValues         = $effectAllowedValues
                    effectReason                = $effectReason
                    parameters                  = $surfacedParameters
                    policyDefinitionReferenceId = $policyInInitiative.policyDefinitionReferenceId
                    groupNames                  = $groupNames
                }
                $null = $policyInInitiativeInfoList.Add($policyInInitiativeInfo)
            }
            else {
                # This is a Policy of policyType static used for compliance purposes and not accessible to this code
                # SKIP
            }
        }

        # Assemble Initiative info
        $displayName = $initiative.displayName
        if (-not $displayName -or $displayName -eq "") {
            $displayName = $initiative.name
        }

        $description = $initiative.description
        if (-not $description) {
            $description = ""
        }

        # Find Policy definitions appearing more than once in Initiative
        $uniquePolicies = @{}
        $policiesWithMultipleReferenceIds = @{}
        foreach ($policyInInitiativeInfo in $policyInInitiativeInfoList) {
            $policyId = $policyInInitiativeInfo.id
            $policyDefinitionReferenceId = $policyInInitiativeInfo.policyDefinitionReferenceId
            # Is this a Poli
            if ($uniquePolicies.ContainsKey($policyId)) {
                if (-not $policiesWithMultipleReferenceIds.ContainsKey($policyId)) {
                    # First time detecting that this Policy has multiple references in the same Initiative
                    $uniquePolicyReferenceIds = $uniquePolicies[$policyId]
                    $null = $policiesWithMultipleReferenceIds.Add($policyId, $uniquePolicyReferenceIds)
                }
                # Add current policyDefinitionReferenceId
                $multipleReferenceIds = $policiesWithMultipleReferenceIds[$policyId]
                $multipleReferenceIds += $policyDefinitionReferenceId
                $policiesWithMultipleReferenceIds[$policyId] = $multipleReferenceIds
            }
            else {
                # First time encounter in this Initiative. Record Policy Id and remember policyDefinitionReferenceId
                $null = $uniquePolicies.Add($policyId, @( $policyDefinitionReferenceId ))
            }
        }

        $initiativeInfo = @{
            id                               = $initiativeId
            name                             = $initiative.name
            displayName                      = $displayName
            description                      = $description
            policyType                       = $initiative.policyType
            category                         = $category
            parameters                       = $initiativeParameters
            policyDefinitions                = $policyInInitiativeInfoList.ToArray()
            policiesWithMultipleReferenceIds = $policiesWithMultipleReferenceIds
        }
        $null = $initiativeInfos.Add($initiativeId, $initiativeInfo)
    }

    # Assemble the policyInitiativeInfo
    $policyInitiativeInfo = @{
        policyInfos     = $policyInfos
        initiativeInfos = $initiativeInfos
    }

    return $policyInitiativeInfo
}