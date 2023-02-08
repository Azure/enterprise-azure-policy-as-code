#Requires -PSEdition Core

function Get-AzPolicyEffectsForPolicySet {
    [CmdletBinding()]
    param (
        [hashtable] $policySetParameters,
        $policySetDefinition,
        $assignment = $null,
        [hashtable] $PolicyDefinitions
    )

    $policyDefinitionsInSet = $policySetDefinition.policyDefinitions
    [array] $effectiveEffectList = @()
    if ($null -eq $assignment) {
        $assignment = @{
            name        = ""
            displayName = ""
            description = ""

        }
    }
    foreach ($policy in $policyDefinitionsInSet) {
        $policyDefinition = $PolicyDefinitions[$policy.policyDefinitionId]
        $effect = Get-PolicyEffectDetails -policy $policyDefinition
        $paramValue = ""
        $allowedValues = ""
        $defaultValue = ""
        $defaultValue = ""
        $definitionType = ""
        $paramName = "na"
        if ($effect.type -eq "FixedByPolicyDefinition") {
            # parameter is hard-coded into Policy
            $paramValue = $effect.fixedValue
            $allowedValues = @( $effect.fixedValue )
            $defaultValue = $effect.fixedValue
            $definitionType = $effect.type
        }
        else {
            $policyParameters = $policy.parameters | ConvertTo-HashTable
            if ($policyParameters.ContainsKey($effect.parameterName)) {
                # parameter value is specified in policySet
                $param = $policyParameters[$effect.parameterName]
                $paramValue = $param.value
                # find the translated parameterName, found means it was parameterized, not found means it is hard coded
                $found, $policyDefinitionParameterName = Get-ParameterNameFromValueString -paramValue $paramValue
                if ($found) {
                    $policySetParameter = $policySetParameters[$policyDefinitionParameterName]
                    $paramValue = $policySetParameter.paramValue
                    $paramName = $policyDefinitionParameterName
                    $allowedValues = $effect.allowedValues
                    $defaultValue = $policySetParameter.defaultValue
                    $definitionType = $policySetParameter.type
                }
                else {
                    $allowedValues = $effect.allowedValues
                    $defaultValue = $effect.defaultValue
                    $definitionType = "FixedByPolicySetDefinition"
                }
            }
            else {
                # parameter is defined by Policy default
                $paramValue = $effect.paramValue
                $allowedValues = $effect.allowedValues
                $defaultValue = $effect.defaultValue
                $definitionType = $effect.type
            }
        }
        $result = @{
            paramValue                  = $paramValue
            allowedValues               = $allowedValues
            defaultValue                = $defaultValue
            definitionType              = $definitionType
            assignmentName              = $assignment.name
            assignmentDisplayName       = $assignment.displayName
            assignmentDescription       = $assignment.description
            policySetId                = $policySetDefinition.id
            policySetDisplayName       = $policySetDefinition.displayName
            policySetDescription       = $policySetDefinition.description
            policySetParameterName     = $paramName
            policyDefinitionReferenceId = $policy.policyDefinitionReferenceId
            policyDefinitionGroupNames  = $policy.groupNames
            policyId                    = $policyDefinition.id
            policyDisplayName           = $policyDefinition.displayName
            policyDescription           = $policyDefinition.description
        }
        $effectiveEffectList += $result
    }
    $effectiveEffectList
}