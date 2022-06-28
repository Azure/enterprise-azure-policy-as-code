#Requires -PSEdition Core

function Convert-PolicyInitiativeDefinitionsToInfo {
    [CmdletBinding()]
    param (
        [hashtable] $allAzPolicyInitiativeDefinitions,
        [hashtable] $cachedPolicyInitiativeInfos
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

        $effectValue = "n/a"
        $effectDefault = "n/a"
        $effectAllowedValues = @()
        $effectReason = "Unknown"
        $parameters = $policy.parameters | ConvertTo-HashTable
        if ($found) {
            if ($parameters.ContainsKey($effectParameterName)) {
                $effectParameter = $parameters.$effectParameterName
                if ($effectParameter.defaultValue) {
                    $effectValue = $effectParameter.defaultValue
                    $effectDefault = $effectParameter.defaultValue
                    $effectReason = "PolicyDefault"
                }
                else {
                    $effectValue = "Undefined"
                    $effectDefault = "Undefined"
                }
                if ($effectParameter.allowedValues) {
                    $effectAllowedValues = $effectParameter.allowedValues
                }
                else {
                    $effectAllowedValues = @( "Undefined" )
                }
            }
            else {
                Write-Error "Policy uses parameter '$effectParameterName' for the effect not defined in the parameters. This should not be possible!" -ErrorAction Stop
            }
        }
        else {
            # Fixed value
            $effectParameterName = "n/a"
            $effectValue = $effectRawValue
            $effectDefault = $effectRawValue
            $effectAllowedValues = @( $effectRawValue )
            $effectReason = "PolicyFixed"
        }
        $displayName = $policy.displayName
        if (-not $displayName -or $displayName -eq "") {
            $displayName = $policy.name
        }
        $description = $policy.description
        if (-not $description) {
            $description = ""
        }
        $policyInfo = @{
            id                          = $policyId
            name                        = $policy.name
            displayName                 = $displayName
            description                 = $description
            policyType                  = $policy.policyType
            category                    = $category
            effectParameterName         = $effectParameterName
            effectValue                 = $effectValue
            effectDefault               = $effectDefault
            effectAllowedValues         = $effectAllowedValues
            effectReason                = $effectReason
            parameters                  = $parameters
            policyDefinitionReferenceId = "n/a"
            groupNames                  = @()

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
        foreach ($policyInInitiative in $initiative.policyDefinitions) {
            $policyId = $policyInInitiative.policyDefinitionId
            if ($policyInfos.ContainsKey($policyId)) {
                $policyInfo = $policyInfos.$policyId
                $policyInInitiativeParameters = $policyInInitiative.parameters | ConvertTo-HashTable

                $initiativeLevelEffectParameterName = "n/a"
                $effectParameterName = $policyInfo.effectParameterName
                $effectValue = $policyInfo.effectValue
                $effectDefault = $policyInfo.effectDefault
                $effectAllowedValues = $policyInfo.effectAllowedValues
                $effectReason = $policyInfo.effectReason

                if ($effectReason -ne "PolicyFixed") {
                    # Effect is parameterized in Policy
                    if ($policyInInitiativeParameters.ContainsKey($effectParameterName)) {
                        # Effect parameter is used by initiative
                        $initiativeLevelEffectParameter = $policyInInitiativeParameters.$effectParameterName
                        $effectRawValue = $initiativeLevelEffectParameter.value

                        $found, $initiativeLevelEffectParameterName = Get-ParameterNameFromValueString -paramValue $effectRawValue
                        if ($found) {
                            # Effect parameter is surfaced by Initiative
                            if ($initiativeParameters.ContainsKey($initiativeLevelEffectParameterName)) {
                                $effectParameter = $initiativeParameters.$initiativeLevelEffectParameterName
                                if ($effectParameter.defaultValue) {
                                    $effectValue = $effectParameter.defaultValue
                                    $effectDefault = $effectParameter.defaultValue
                                    $effectReason = "InitiativeDefault"
                                }
                                else {
                                    $effectValue = "Undefined"
                                    $effectDefault = "Undefined"
                                }
                                if ($effectParameter.allowedValues) {
                                    $effectAllowedValues = $effectParameter.allowedValues
                                }
                                else {
                                    $effectAllowedValues = @( "Undefined" )
                                }
                            }
                            else {
                                Write-Error "Policy uses parameter '$effectParameterName' for the effect not defined in the parameters. This should not be possible!" -ErrorAction Stop
                            }
                        }
                        else {
                            # Effect parameter is hard-coded (fixed) by Initiative
                            $initiativeLevelEffectParameterName = "n/a"
                            $effectValue = $effectRawValue
                            $effectDefault = $effectRawValue
                            $effectReason = "InitiativeFixed"
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
                            $null = $surfacedParameters.Add($initiativeParameterName, $initiativeParameter)
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
        $initiativeInfo = @{
            id                = $initiativeId
            name              = $initiative.name
            displayName       = $displayName
            description       = $description
            policyType        = $initiative.policyType
            category          = $category
            policyDefinitions = $policyInInitiativeInfoList.ToArray()
            parameters        = $initiativeParameters
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