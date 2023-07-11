function Convert-PolicySetsToDetails {
    [CmdletBinding()]
    param (
        [hashtable] $AllPolicyDefinitions,
        [hashtable] $AllPolicySetDefinitions
    )

    $PolicyDetails = @{}
    Write-Information "Calculating effect parameters for $($AllPolicyDefinitions.psbase.Count) Policies."
    foreach ($PolicyId in $AllPolicyDefinitions.Keys) {
        $Policy = $AllPolicyDefinitions.$PolicyId
        $properties = Get-PolicyResourceProperties -PolicyResource $Policy
        $category = "Unknown"
        if ($properties.metadata -and $properties.metadata.category) {
            $category = $properties.metadata.category
        }
        $EffectRawValue = $properties.policyRule.then.effect
        $found, $EffectParameterName = Get-ParameterNameFromValueString -ParamValue $EffectRawValue

        $EffectValue = $null
        $EffectDefault = $null
        $EffectAllowedValues = @()
        $EffectAllowedOverrides = @()
        $EffectReason = "Policy No Default"
        $Parameters = $properties.parameters | ConvertTo-HashTable
        if ($found) {
            if ($Parameters.Keys -contains $EffectParameterName) {
                $EffectParameter = $Parameters.$EffectParameterName
                if ($EffectParameter.defaultValue) {
                    $EffectValue = $EffectParameter.defaultValue
                    $EffectDefault = $EffectParameter.defaultValue
                    $EffectReason = "Policy Default"
                }
            }
            else {
                Write-Error "Policy uses parameter '$EffectParameterName' for the effect not defined in the parameters. This should not be possible!" -ErrorAction Stop
            }
            if ($EffectParameter.allowedValues) {
                $EffectAllowedValues = $EffectParameter.allowedValues
                $EffectAllowedOverrides = $EffectParameter.allowedValues
            }
        }
        else {
            # Fixed value
            $EffectValue = $EffectRawValue
            $EffectDefault = $EffectRawValue
            $EffectAllowedValues = @( $EffectDefault )
            $EffectReason = "Policy Fixed"
        }
        if ($EffectAllowedOverrides.Count -eq 0) {
            # Analyze Policy
            $then = $properties.policyRule.then
            $Details = $then.details
            $denyAction = $Details -and $Details.actionNames
            $auditIfNotExists = $Details -and $Details.existenceCondition
            $deployIfNotExists = $auditIfNotExists -and $Details.deployment
            $modify = $Details -and $Details.operations
            $manual = $Details -and $Details.defaultState
            $append = $Details -and $Details -is [array]

            if ($denyAction) {
                $EffectAllowedOverrides = @("Disabled", "DenyAction")
            }
            elseif ($manual) {
                $EffectAllowedOverrides = @("Disabled", "Manual")
            }
            elseif ($deployIfNotExists) {
                $EffectAllowedOverrides = @("Disabled", "AuditIfNotExists", "DeployIfNotExists")
            }
            elseif ($auditIfNotExists) {
                $EffectAllowedOverrides = @("Disabled", "AuditIfNotExists")
            }
            elseif ($modify) {
                $EffectAllowedOverrides = @("Disabled", "Audit", "Modify")
            }
            elseif ($append) {
                $EffectAllowedOverrides = @("Disabled", "Audit", "Deny", "Append")
            }
            else {
                if ($EffectReason -eq "Policy Fixed") {
                    if ($EffectValue -eq "deny") {
                        $EffectAllowedOverrides = @("Disabled", "Audit", "Deny")
                    }
                    elseif ($EffectValue -eq "audit") {
                        $EffectAllowedOverrides = @("Disabled", "Audit", "Deny") # Safe assumption if Audit or Disabled - deny is a valid case as well - see ALZ deny-unmanageddisk
                    }
                    else {
                        # Disabled: very weird for hard coded
                        $EffectAllowedOverrides = @("Disabled", "Audit") # Safe assumption
                    }
                }
                else {
                    if ($EffectDefault -eq "deny") {
                        $EffectAllowedOverrides = @("Disabled", "Audit", "Deny")
                    }
                    else {
                        $EffectAllowedOverrides = @("Disabled", "Audit", "Deny") # Guess, could be @("Disabled", "Audit")
                    }
                }
            }
        }

        $DisplayName = $properties.displayName
        if (-not $DisplayName -or $DisplayName -eq "") {
            $DisplayName = $Policy.name
        }

        $description = $properties.description
        if (-not $description) {
            $description = ""
        }

        $parameterDefinitions = @{}
        foreach ($parameterName in $Parameters.Keys) {
            $parameter = $Parameters.$parameterName
            $parameterDefinition = @{
                isEffect     = $parameterName -eq $EffectParameterName
                value        = $null
                defaultValue = $parameter.defaultValue
                definition   = $parameter
            }
            $null = $parameterDefinitions.Add($parameterName, $parameterDefinition)
        }

        $PolicyDetail = @{
            id                     = $PolicyId
            name                   = $Policy.name
            displayName            = $DisplayName
            description            = $description
            policyType             = $properties.policyType
            category               = $category
            effectParameterName    = $EffectParameterName
            effectValue            = $EffectValue
            effectDefault          = $EffectDefault
            effectAllowedValues    = $EffectAllowedValues
            effectAllowedOverrides = $EffectAllowedOverrides
            effectReason           = $EffectReason
            parameters             = $parameterDefinitions
        }
        $null = $PolicyDetails.Add($PolicyId, $PolicyDetail)
    }

    Write-Information "Calculating effect parameters for $($AllPolicySetDefinitions.psbase.Count) Policy Sets."
    $PolicySetDetails = @{}
    foreach ($PolicySetId in $AllPolicySetDefinitions.Keys) {
        $PolicySet = $AllPolicySetDefinitions.$PolicySetId
        $properties = Get-PolicyResourceProperties -PolicyResource $PolicySet
        $category = "Unknown"
        if ($properties.metadata -and $properties.metadata.category) {
            $category = $properties.metadata.category
        }

        [System.Collections.ArrayList] $PolicyInPolicySetDetailList = [System.Collections.ArrayList]::new()
        $PolicySetParameters = Get-DeepClone $properties.parameters -AsHashtable
        $ParametersAlreadyCovered = @{}
        foreach ($PolicyInPolicySet in $properties.policyDefinitions) {
            $PolicyId = $PolicyInPolicySet.policyDefinitionId
            if ($PolicyDetails.ContainsKey($PolicyId)) {
                $PolicyDetail = $PolicyDetails.$PolicyId
                $PolicyInPolicySetParameters = $PolicyInPolicySet.parameters | ConvertTo-HashTable

                $PolicySetLevelEffectParameterName = $null
                $EffectParameterName = $PolicyDetail.effectParameterName
                $EffectValue = $PolicyDetail.effectValue
                $EffectDefault = $PolicyDetail.effectDefault
                $EffectAllowedValues = $PolicyDetail.effectAllowedValues
                $EffectAllowedOverrides = $PolicyDetail.effectAllowedOverrides
                $EffectReason = $PolicyDetail.effectReason

                $PolicySetLevelEffectParameterFound = $false
                $PolicySetLevelEffectParameterName = ""
                if ($EffectReason -ne "Policy Fixed") {
                    # Effect is parameterized in Policy
                    if ($PolicyInPolicySetParameters.Keys -contains $EffectParameterName) {
                        # Effect parameter is used by policySet
                        $PolicySetLevelEffectParameter = $PolicyInPolicySetParameters.$EffectParameterName
                        $EffectRawValue = $PolicySetLevelEffectParameter.value

                        $PolicySetLevelEffectParameterFound, $PolicySetLevelEffectParameterName = Get-ParameterNameFromValueString -ParamValue $EffectRawValue
                        if ($PolicySetLevelEffectParameterFound) {
                            # Effect parameter is surfaced by PolicySet
                            if ($PolicySetParameters.Keys -contains $PolicySetLevelEffectParameterName) {
                                $EffectParameter = $PolicySetParameters.$PolicySetLevelEffectParameterName
                                if ($EffectParameter.defaultValue) {
                                    $EffectValue = $EffectParameter.defaultValue
                                    $EffectDefault = $EffectParameter.defaultValue
                                    $EffectReason = "PolicySet Default"
                                }
                                else {
                                    $EffectReason = "PolicySet No Default"

                                }
                                if ($EffectParameter.allowedValues) {
                                    $EffectAllowedValues = $EffectParameter.allowedValues
                                }
                            }
                            else {
                                Write-Error "Policy '$($PolicyId)', referenceId '$($PolicyInPolicySet.policyDefinitionReferenceId)' tries to pass an unknown Policy Set parameter '$PolicySetLevelEffectParameterName' to the Policy parameter '$EffectParameterName'. Check the spelling of the parameters occurrences in the Policy Set." -ErrorAction Stop
                            }
                        }
                        else {
                            # Effect parameter is hard-coded (fixed) by PolicySet
                            $PolicySetLevelEffectParameterName = $null
                            $EffectValue = $EffectRawValue
                            $EffectDefault = $EffectRawValue
                            $EffectReason = "PolicySet Fixed"
                        }
                    }
                }

                # Process Policy parameters surfaced by PolicySet
                $surfacedParameters = @{}
                foreach ($parameterName in $PolicyInPolicySetParameters.Keys) {
                    $parameter = $PolicyInPolicySetParameters.$parameterName
                    $rawValue = $parameter.value
                    if ($rawValue -is [string]) {
                        $found, $PolicySetParameterName = Get-ParameterNameFromValueString -ParamValue $rawValue
                        if ($found) {
                            $PolicySetParameter = $PolicySetParameters.$PolicySetParameterName
                            $multiUse = $false
                            $defaultValue = $PolicySetParameter.defaultValue
                            $isEffect = $PolicySetParameterName -eq $PolicySetLevelEffectParameterName
                            if ($ParametersAlreadyCovered.ContainsKey($PolicySetParameterName)) {
                                $multiUse = $true
                            }
                            else {
                                $null = $ParametersAlreadyCovered.Add($PolicySetParameterName, $true)
                            }
                            $null = $surfacedParameters.Add($PolicySetParameterName, @{
                                    multiUse     = $multiUse
                                    isEffect     = $isEffect
                                    value        = $defaultValue
                                    defaultValue = $defaultValue
                                    definition   = $PolicySetParameter
                                }
                            )
                        }
                    }
                }

                # Assemble the info
                $groupNames = @()
                if ($PolicyInPolicySet.groupNames) {
                    $groupNames = $PolicyInPolicySet.groupNames
                }
                $PolicyInPolicySetDetail = @{
                    id                          = $PolicyDetail.id
                    name                        = $PolicyDetail.name
                    displayName                 = $PolicyDetail.displayName
                    description                 = $PolicyDetail.description
                    policyType                  = $PolicyDetail.policyType
                    category                    = $PolicyDetail.category
                    effectParameterName         = $PolicySetLevelEffectParameterName
                    effectValue                 = $EffectValue
                    effectDefault               = $EffectDefault
                    effectAllowedValues         = $EffectAllowedValues
                    effectAllowedOverrides      = $EffectAllowedOverrides
                    effectReason                = $EffectReason
                    parameters                  = $surfacedParameters
                    policyDefinitionReferenceId = $PolicyInPolicySet.policyDefinitionReferenceId
                    groupNames                  = $groupNames
                }
                $null = $PolicyInPolicySetDetailList.Add($PolicyInPolicySetDetail)
            }
            else {
                # This is a Policy of policyType static used for compliance purposes and not accessible to this code
                # SKIP
            }
        }

        # Assemble Policy Set info
        $DisplayName = $properties.displayName
        if (-not $DisplayName -or $DisplayName -eq "") {
            $DisplayName = $PolicySet.name
        }

        $description = $properties.description
        if (-not $description) {
            $description = ""
        }

        # Find Policies appearing more than once in PolicySet
        $uniquePolicies = @{}
        $policiesWithMultipleReferenceIds = @{}
        foreach ($PolicyInPolicySetDetail in $PolicyInPolicySetDetailList) {
            $PolicyId = $PolicyInPolicySetDetail.id
            $PolicyDefinitionReferenceId = $PolicyInPolicySetDetail.policyDefinitionReferenceId
            if ($uniquePolicies.ContainsKey($PolicyId)) {
                if (-not $policiesWithMultipleReferenceIds.ContainsKey($PolicyId)) {
                    # First time detecting that this Policy has multiple references in the same PolicySet
                    $uniquePolicyReferenceIds = $uniquePolicies[$PolicyId]
                    $null = $policiesWithMultipleReferenceIds.Add($PolicyId, $uniquePolicyReferenceIds)
                }
                # Add current policyDefinitionReferenceId
                $multipleReferenceIds = $policiesWithMultipleReferenceIds[$PolicyId]
                $multipleReferenceIds += $PolicyDefinitionReferenceId
                $policiesWithMultipleReferenceIds[$PolicyId] = $multipleReferenceIds
            }
            else {
                # First time encounter in this PolicySet. Record Policy Id and remember policyDefinitionReferenceId
                $null = $uniquePolicies.Add($PolicyId, @( $PolicyDefinitionReferenceId ))
            }
        }

        $PolicySetDetail = @{
            id                               = $PolicySetId
            name                             = $PolicySet.name
            displayName                      = $DisplayName
            description                      = $description
            policyType                       = $properties.policyType
            category                         = $category
            parameters                       = $PolicySetParameters
            policyDefinitions                = $PolicyInPolicySetDetailList.ToArray()
            policiesWithMultipleReferenceIds = $policiesWithMultipleReferenceIds
        }
        $null = $PolicySetDetails.Add($PolicySetId, $PolicySetDetail)
    }

    # Assemble result
    $CombinedPolicyDetails = @{
        policies   = $PolicyDetails
        policySets = $PolicySetDetails
    }

    return $CombinedPolicyDetails
}
