#Requires -PSEdition Core

function Get-AzPolicyEffectsForInitiative {
    [CmdletBinding()]
    param (
        [hashtable] $initiativeParameters,
        $initiativeDefinition,
        $assignment = $null,
        [hashtable] $PolicyDefinitions
    )

    $policyDefinitionsInSet = $initiativeDefinition.policyDefinitions
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
            # parameter is hard-coded into Policy definition
            $paramValue = $effect.fixedValue
            $allowedValues = @( $effect.fixedValue )
            $defaultValue = $effect.fixedValue
            $definitionType = $effect.type
        }
        else {
            $policyParameters = $policy.parameters | ConvertTo-HashTable
            if ($policyParameters.ContainsKey($effect.parameterName)) {
                # parameter value is specified in initiative
                $param = $policyParameters[$effect.parameterName]
                $paramValue = $param.value
                # find the translated parameterName, found means it was parameterized, not found means it is hard coded
                $found, $policyDefinitionParameterName = Get-ParameterNameFromValueString -paramValue $paramValue
                if ($found) {
                    $initiativeParameter = $initiativeParameters[$policyDefinitionParameterName]
                    $paramValue = $initiativeParameter.paramValue
                    $paramName = $policyDefinitionParameterName
                    $allowedValues = $effect.allowedValues
                    $defaultValue = $initiativeParameter.defaultValue
                    $definitionType = $initiativeParameter.type
                }
                else {
                    $allowedValues = $effect.allowedValues
                    $defaultValue = $effect.defaultValue
                    $definitionType = "FixedByInitiativeDefinition"
                }
            }
            else {
                # parameter is defined by Policy definition default
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
            initiativeId                = $initiativeDefinition.id
            initiativeDisplayName       = $initiativeDefinition.displayName
            initiativeDescription       = $initiativeDefinition.description
            initiativeParameterName     = $paramName
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