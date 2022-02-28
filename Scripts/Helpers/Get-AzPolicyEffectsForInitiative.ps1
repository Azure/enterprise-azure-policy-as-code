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
        $result = $null
        if ($effect.type -eq "FixedByPolicyDefinition") {
            # parameter is hard-coded into Policy definition
            $result = @{
                paramValue                  = $effect.fixedValue
                allowedValues               = @( $effect.fixedValue )
                defaultValue                = $effect.fixedValue
                definitionType              = $effect.type
                assignmentName              = $assignment.name
                assignmentDisplayName       = $assignment.displayName
                assignmentDescription       = $assignment.description
                initiativeId                = $initiativeDefinition.id
                initiativeDisplayName       = $initiativeDefinition.displayName
                initiativeDescription       = $initiativeDefinition.description
                initiativeParameterName     = "na"
                policyDefinitionReferenceId = $policy.policyDefinitionReferenceId
                policyDefinitionGroupNames  = $policy.groupNames
                policyId                    = $policyDefinition.id
                policyDisplayName           = $policyDefinition.displayName
                policyDescription           = $policyDefinition.description
            }
        }
        else {
            $policyParameters = $policy.parameters | ConvertTo-HashTable
            if ($policyParameters.ContainsKey($effect.parameterName)) {
                # parmeter value is specified in initiative
                $param = $policyParameters[$effect.parameterName]
                $paramValue = $param.value
                # find the translated parameterName, found means it was parmeterized, not found means it is hard coded which would be weird, but legal
                $found, $policyDefinitionParameterName = Get-ParmeterNameFromValueString -paramValue $paramValue
                if ($found) {
                    $initiativeParameter = $initiativeParameters[$policyDefinitionParameterName]
                    $result = @{
                        paramValue                  = $initiativeParameter.paramValue
                        allowedValues               = $effect.allowedValues
                        defaultValue                = $initiativeParameter.defaultValue
                        definitionType              = $initiativeParameter.type
                        assignmentName              = $assignment.name
                        assignmentDisplayName       = $assignment.displayName
                        assignmentDescription       = $assignment.description
                        initiativeId                = $initiativeDefinition.id
                        initiativeDisplayName       = $initiativeDefinition.displayName
                        initiativeDescription       = $initiativeDefinition.description
                        initiativeParameterName     = $policyDefinitionParameterName
                        policyDefinitionReferenceId = $policy.policyDefinitionReferenceId
                        policyDefinitionGroupNames  = $policy.groupNames
                        policyId                    = $policyDefinition.id
                        policyDisplayName           = $policyDefinition.displayName
                        policyDescription           = $policyDefinition.description
                    }
                }
                else {
                    $parameterName = $effect.parameterName
                    $initiativeParameter = $initiativeParameters.$parameterName
                    $result = @{
                        paramValue                  = $paramValue
                        allowedValues               = $effect.allowedValues
                        defaultValue                = $effect.defaultValue
                        definitionType              = "FixedByInitiativeDefinition"
                        assignmentName              = $assignment.name
                        assignmentDisplayName       = $assignment.displayName
                        assignmentDescription       = $assignment.description
                        initiativeId                = $initiativeDefinition.id
                        initiativeDisplayName       = $initiativeDefinition.displayName
                        initiativeDescription       = $initiativeDefinition.description
                        initiativeParameterName     = "na"
                        policyDefinitionReferenceId = $policy.policyDefinitionReferenceId
                        policyDefinitionGroupNames  = $policy.groupNames
                        policyId                    = $policyDefinition.id
                        policyDisplayName           = $policyDefinition.displayName
                        policyDescription           = $policyDefinition.description
                    }
                }
            }
            else {
                # parameter is defined by Policy definition default
                $result = @{
                    paramValue                  = $effect.paramValue
                    allowedValues               = $effect.allowedValues
                    defaultValue                = $effect.defaultValue
                    definitionType              = $effect.type
                    assignmentName              = $assignment.name
                    assignmentDisplayName       = $assignment.displayName
                    assignmentDescription       = $assignment.description
                    initiativeId                = $initiativeDefinition.id
                    initiativeDisplayName       = $initiativeDefinition.displayName
                    initiativeDescription       = $initiativeDefinition.description
                    initiativeParameterName     = "na"
                    policyDefinitionReferenceId = $policy.policyDefinitionReferenceId
                    policyDefinitionGroupNames  = $policy.groupNames
                    policyId                    = $policyDefinition.id
                    policyDisplayName           = $policyDefinition.displayName
                    policyDescription           = $policyDefinition.description
                }
            }
        }
        $effectiveEffectList += $result
    }
    $effectiveEffectList
}