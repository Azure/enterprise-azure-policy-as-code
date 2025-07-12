function Convert-PolicySetToDetails {
    [CmdletBinding()]
    param (
        $PolicySetId,
        $PolicySetDefinition,
        $PolicySetDetails,
        $PolicyDetails
    )

    $properties = Get-PolicyResourceProperties -PolicyResource $PolicySetDefinition
    $category = "Unknown"
    if ($properties.metadata -and $properties.metadata.category) {
        $category = $properties.metadata.category
    }

    [System.Collections.ArrayList] $policyInPolicySetDetailList = [System.Collections.ArrayList]::new()
    $policySetParameters = $properties.parameters | ConvertTo-HashTable
    $parametersAlreadyCovered = @{}
    foreach ($policyInPolicySet in $properties.policyDefinitions) {
        $policyId = $policyInPolicySet.policyDefinitionId
        if ($PolicyDetails.ContainsKey($policyId)) {
            $policyDetail = $PolicyDetails.$policyId
            $policyInPolicySetParameters = $policyInPolicySet.parameters | ConvertTo-HashTable

            $policySetLevelEffectParameterName = $null
            $effectParameterName = $policyDetail.effectParameterName
            $effectValue = $policyDetail.effectValue
            $effectDefault = $policyDetail.effectDefault
            $effectAllowedValues = $policyDetail.effectAllowedValues
            $effectAllowedOverrides = $policyDetail.effectAllowedOverrides
            $effectReason = $policyDetail.effectReason

            $policySetLevelEffectParameterFound = $false
            $policySetLevelEffectParameterName = ""
            if ($effectReason -ne "Policy Fixed") {
                # Effect is parameterized in Policy
                if ($policyInPolicySetParameters.Keys -contains $effectParameterName) {
                    # Effect parameter is used by policySet
                    $policyInPolicySetParameter = $policyInPolicySetParameters.$effectParameterName
                    if ($null -eq $policyInPolicySetParameter) {
                        $key1 = $policyInPolicySetParameters.Keys | Where-Object { $_.ToLower() -eq $effectParameterName.ToLower() }
                        Write-Debug "key '$effectParameterName' exists with a different case '$key1' in '$($policyInPolicySetParameters | ConvertTo-Json -Depth 100 -Compress)'"
                        if ($null -ne $key1) {
                            $policyInPolicySetParameter = $policyInPolicySetParameters.$key1
                        }
                        # else keep $policyInPolicySetParameter as $null
                    }
                    $policySetLevelEffectParameterFound = $false
                    $policySetLevelEffectParameterName = $null
                    if ($policyInPolicySetParameter) {
                        $effectRawValue = $policyInPolicySetParameter.value
                        $policySetLevelEffectParameterFound, $policySetLevelEffectParameterName = Get-ParameterNameFromValueString -ParamValue $effectRawValue
                    }

                    if ($policySetLevelEffectParameterFound) {
                        # Effect parameter is surfaced by PolicySet
                        if ($policySetParameters.Keys -contains $policySetLevelEffectParameterName) {
                            $effectParameter = $policySetParameters.$policySetLevelEffectParameterName
                            if ($effectParameter.defaultValue) {
                                $effectValue = $effectParameter.defaultValue
                                $effectDefault = $effectParameter.defaultValue
                                $effectReason = "PolicySet Default"
                            }
                            else {
                                $effectReason = "PolicySet No Default"

                            }
                            if ($effectParameter.allowedValues) {
                                $effectAllowedValues = $effectParameter.allowedValues
                            }
                        }
                        else {
                            Write-Error "Policy '$($policyId)', referenceId '$($policyInPolicySet.policyDefinitionReferenceId)' tries to pass an unknown Policy Set parameter '$policySetLevelEffectParameterName' to the Policy parameter '$effectParameterName'. Check the spelling of the parameters occurrences in the Policy Set." -ErrorAction Stop
                        }
                    }
                    else {
                        # Effect parameter is hard-coded (fixed) by PolicySet
                        $policySetLevelEffectParameterName = $null
                        $effectValue = $effectRawValue
                        $effectDefault = $effectRawValue
                        $effectReason = "PolicySet Fixed"
                    }
                }
            }

            # Process Policy parameters surfaced by PolicySet
            $surfacedParameters = @{}
            foreach ($parameterName in $policyInPolicySetParameters.Keys) {
                $parameter = $policyInPolicySetParameters.$parameterName
                $rawValue = $parameter.value
                if ($rawValue -is [string]) {
                    $found, $policySetParameterName = Get-ParameterNameFromValueString -ParamValue $rawValue
                    if ($found) {
                        $policySetParameter = $policySetParameters.$policySetParameterName
                        $multiUse = $false
                        $defaultValue = $policySetParameter.defaultValue
                        $isEffect = $policySetParameterName -eq $policySetLevelEffectParameterName
                        if ($parametersAlreadyCovered.ContainsKey($policySetParameterName)) {
                            $multiUse = $true
                        }
                        else {
                            $null = $parametersAlreadyCovered.Add($policySetParameterName, $true)
                        }
                        if (!($surfacedParameters.ContainsKey($policySetParameterName))){
                            $null = $surfacedParameters.Add($policySetParameterName, @{
                                multiUse     = $multiUse
                                isEffect     = $isEffect
                                value        = $defaultValue
                                defaultValue = $defaultValue
                                definition   = $policySetParameter
                            }
                        )
                        }
                        
                    }
                }
            }

            # Assemble the info
            $groupNames = @()
            if ($policyInPolicySet.groupNames) {
                $groupNames = $policyInPolicySet.groupNames
            }
            $policyDefinitionReferenceId = $policyInPolicySet.policyDefinitionReferenceId
            $policyDetailId = $policyDetail.id
            $policyInPolicySetDetail = @{
                id                          = $policyDetailId
                name                        = $policyDetail.name
                displayName                 = $policyDetail.displayName
                description                 = $policyDetail.description
                policyType                  = $policyDetail.policyType
                category                    = $policyDetail.category
                effectParameterName         = $policySetLevelEffectParameterName
                effectValue                 = $effectValue
                effectDefault               = $effectDefault
                effectAllowedValues         = $effectAllowedValues
                effectAllowedOverrides      = $effectAllowedOverrides
                effectReason                = $effectReason
                parameters                  = $surfacedParameters
                policyDefinitionReferenceId = $policyDefinitionReferenceId
                groupNames                  = $groupNames
            }
            $null = $policyInPolicySetDetailList.Add($policyInPolicySetDetail)
        }
        else {
            # This is a Policy of policyType static used for compliance purposes and not accessible to this code
            # SKIP
        }
    }

    # Assemble Policy Set info
    $displayName = $properties.displayName
    if (-not $displayName -or $displayName -eq "") {
        $displayName = $PolicySetDefinition.name
    }

    $description = $properties.description
    if (-not $description) {
        $description = ""
    }

    # Find Policies appearing more than once in PolicySet
    $uniquePolicies = @{}
    $policiesWithMultipleReferenceIds = @{}
    foreach ($policyInPolicySetDetail in $policyInPolicySetDetailList) {
        $policyId = $policyInPolicySetDetail.id
        $policyDefinitionReferenceId = $policyInPolicySetDetail.policyDefinitionReferenceId
        if ($uniquePolicies.ContainsKey($policyId)) {
            if (-not $policiesWithMultipleReferenceIds.ContainsKey($policyId)) {
                # First time detecting that this Policy has multiple references in the same PolicySet
                $uniquePolicyReferenceIds = $uniquePolicies[$policyId]
                $null = $policiesWithMultipleReferenceIds.Add($policyId, $uniquePolicyReferenceIds)
            }
            # Add current policyDefinitionReferenceId
            $multipleReferenceIds = $policiesWithMultipleReferenceIds[$policyId]
            $multipleReferenceIds += $policyDefinitionReferenceId
            $policiesWithMultipleReferenceIds[$policyId] = $multipleReferenceIds
        }
        else {
            # First time encounter in this PolicySet. Record Policy Id and remember policyDefinitionReferenceId
            $null = $uniquePolicies.Add($policyId, @( $policyDefinitionReferenceId ))
        }
    }

    # collect the PolicySet details
    $policySetDetail = @{
        id                               = $PolicySetId
        name                             = $PolicySetDefinition.name
        displayName                      = $displayName
        description                      = $description
        policyType                       = $properties.policyType
        category                         = $category
        parameters                       = $policySetParameters
        policyDefinitions                = $policyInPolicySetDetailList.ToArray()
        policiesWithMultipleReferenceIds = $policiesWithMultipleReferenceIds
    }
    $null = $PolicySetDetails.Add($PolicySetId, $policySetDetail)

}
