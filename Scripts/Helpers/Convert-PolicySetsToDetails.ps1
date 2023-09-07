function Convert-PolicySetsToDetails {
    [CmdletBinding()]
    param (
        [hashtable] $AllPolicyDefinitions,
        [hashtable] $AllPolicySetDefinitions
    )

    $policyDetails = @{}
    Write-Information "Calculating effect parameters for $($AllPolicyDefinitions.psbase.Count) Policies."
    foreach ($policyId in $AllPolicyDefinitions.Keys) {
        $policy = $AllPolicyDefinitions.$policyId
        $properties = Get-PolicyResourceProperties -PolicyResource $policy
        $category = "Unknown"
        if ($properties.metadata -and $properties.metadata.category) {
            $category = $properties.metadata.category
        }
        $effectRawValue = $properties.policyRule.then.effect
        $found, $effectParameterName = Get-ParameterNameFromValueString -ParamValue $effectRawValue

        $effectValue = $null
        $effectDefault = $null
        $effectAllowedValues = @()
        $effectAllowedOverrides = @()
        $effectReason = "Policy No Default"
        $parameters = $properties.parameters | ConvertTo-HashTable
        if ($found) {
            if ($parameters.Keys -contains $effectParameterName) {
                $effectParameter = $parameters.$effectParameterName
                if ($effectParameter.defaultValue) {
                    $effectValue = $effectParameter.defaultValue
                    $effectDefault = $effectParameter.defaultValue
                    $effectReason = "Policy Default"
                }
            }
            else {
                Write-Error "Policy uses parameter '$effectParameterName' for the effect not defined in the parameters. This should not be possible!" -ErrorAction Stop
            }
            if ($effectParameter.allowedValues) {
                $effectAllowedValues = $effectParameter.allowedValues
                $effectAllowedOverrides = $effectParameter.allowedValues
            }
        }
        else {
            # Fixed value
            $effectValue = $effectRawValue
            $effectDefault = $effectRawValue
            $effectAllowedValues = @( $effectDefault )
            $effectReason = "Policy Fixed"
        }
        if ($effectAllowedOverrides.Count -eq 0) {
            # Analyze Policy
            $then = $properties.policyRule.then
            $details = $then.details
            $denyAction = $details -and $details.actionNames
            $auditIfNotExists = $details -and $details.existenceCondition
            $deployIfNotExists = $auditIfNotExists -and $details.deployment
            $modify = $details -and $details.operations
            $manual = $details -and $details.defaultState
            $append = $details -and $details -is [array]

            if ($denyAction) {
                $effectAllowedOverrides = @("Disabled", "DenyAction")
            }
            elseif ($manual) {
                $effectAllowedOverrides = @("Disabled", "Manual")
            }
            elseif ($deployIfNotExists) {
                $effectAllowedOverrides = @("Disabled", "AuditIfNotExists", "DeployIfNotExists")
            }
            elseif ($auditIfNotExists) {
                $effectAllowedOverrides = @("Disabled", "AuditIfNotExists")
            }
            elseif ($modify) {
                $effectAllowedOverrides = @("Disabled", "Audit", "Modify")
            }
            elseif ($append) {
                $effectAllowedOverrides = @("Disabled", "Audit", "Deny", "Append")
            }
            else {
                if ($effectReason -eq "Policy Fixed") {
                    if ($effectValue -eq "deny") {
                        $effectAllowedOverrides = @("Disabled", "Audit", "Deny")
                    }
                    elseif ($effectValue -eq "audit") {
                        $effectAllowedOverrides = @("Disabled", "Audit", "Deny") # Safe assumption if Audit or Disabled - deny is a valid case as well - see ALZ deny-unmanageddisk
                    }
                    else {
                        # Disabled: very weird for hard coded
                        $effectAllowedOverrides = @("Disabled", "Audit") # Safe assumption
                    }
                }
                else {
                    if ($effectDefault -eq "deny") {
                        $effectAllowedOverrides = @("Disabled", "Audit", "Deny")
                    }
                    else {
                        $effectAllowedOverrides = @("Disabled", "Audit", "Deny") # Guess, could be @("Disabled", "Audit")
                    }
                }
            }
        }

        $displayName = $properties.displayName
        if (-not $displayName -or $displayName -eq "") {
            $displayName = $policy.name
        }

        $description = $properties.description
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

        $policyDetail = @{
            id                     = $policyId
            name                   = $policy.name
            displayName            = $displayName
            description            = $description
            policyType             = $properties.policyType
            category               = $category
            effectParameterName    = $effectParameterName
            effectValue            = $effectValue
            effectDefault          = $effectDefault
            effectAllowedValues    = $effectAllowedValues
            effectAllowedOverrides = $effectAllowedOverrides
            effectReason           = $effectReason
            parameters             = $parameterDefinitions
        }
        $null = $policyDetails.Add($policyId, $policyDetail)
    }

    Write-Information "Calculating effect parameters for $($AllPolicySetDefinitions.psbase.Count) Policy Sets."
    $policySetDetails = @{}
    foreach ($policySetId in $AllPolicySetDefinitions.Keys) {
        $policySet = $AllPolicySetDefinitions.$policySetId
        $properties = Get-PolicyResourceProperties -PolicyResource $policySet
        $category = "Unknown"
        if ($properties.metadata -and $properties.metadata.category) {
            $category = $properties.metadata.category
        }

        [System.Collections.ArrayList] $policyInPolicySetDetailList = [System.Collections.ArrayList]::new()
        $policySetParameters = Get-DeepClone $properties.parameters -AsHashTable
        $parametersAlreadyCovered = @{}
        foreach ($policyInPolicySet in $properties.policyDefinitions) {
            $policyId = $policyInPolicySet.policyDefinitionId
            if ($policyDetails.ContainsKey($policyId)) {
                $policyDetail = $policyDetails.$policyId
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

                # Assemble the info
                $groupNames = @()
                if ($policyInPolicySet.groupNames) {
                    $groupNames = $policyInPolicySet.groupNames
                }
                $policyInPolicySetDetail = @{
                    id                          = $policyDetail.id
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
                    policyDefinitionReferenceId = $policyInPolicySet.policyDefinitionReferenceId
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
            $displayName = $policySet.name
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

        $policySetDetail = @{
            id                               = $policySetId
            name                             = $policySet.name
            displayName                      = $displayName
            description                      = $description
            policyType                       = $properties.policyType
            category                         = $category
            parameters                       = $policySetParameters
            policyDefinitions                = $policyInPolicySetDetailList.ToArray()
            policiesWithMultipleReferenceIds = $policiesWithMultipleReferenceIds
        }
        $null = $policySetDetails.Add($policySetId, $policySetDetail)
    }

    # Assemble result
    $combinedPolicyDetails = @{
        policies   = $policyDetails
        policySets = $policySetDetails
    }

    return $combinedPolicyDetails
}
