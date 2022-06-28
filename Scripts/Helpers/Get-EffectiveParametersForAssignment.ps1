#Requires -PSEdition Core

function Get-EffectiveParametersForAssignment {
    [CmdletBinding()]
    param (
        [string] $AssignmentId = $null,
        [hashtable] $PolicyDefinitions,
        [hashtable] $InitiativeDefinitions
    )

    # Write-Information "    $($assignmentId)"
    $splat = Split-AssignmentIdForAzCli -id $assignmentId
    $assignment = Invoke-AzCli policy assignment show -Splat $splat -AsHashTable

    $assignmentParameters = $assignment.parameters
    [hashtable[]] $effectiveEffectList = @()

    # This code could be broken up and optimized; however, the author believes that this long form is more readable
    if ($assignment.policyDefinitionId.Contains("policySetDefinition")) {
        # Initiative
        $initiativeDefinition = $initiativeDefinitions[$assignment.policyDefinitionId]
        $initiativeDefinitionParameters = $initiativeDefinition.parameters | ConvertTo-HashTable
        $initiativeParameters = Get-AzInitiativeParameters -parametersIn $assignmentParameters -definedParameters $initiativeDefinitionParameters

        $result = Get-AzPolicyEffectsForInitiative `
            -initiativeParameters $initiativeParameters `
            -initiativeDefinition $initiativeDefinition `
            -assignment $assignment `
            -PolicyDefinitions $PolicyDefinitions
        $effectiveEffectList = $result
    }
    else {
        # Policy
        $policyDefinition = $PolicyDefinitions[$assignment.policyDefinitionId]
        $effect = Get-PolicyEffectDetails -policy $PolicyDefinition
        $result = $null
        $paramValue = ""
        $allowedValues = ""
        $defaultValue = ""
        $defaultValue = ""
        $definitionType = ""
        if ($effect.type -eq "FixedByPolicyDefinition") {
            # parameter is hard-coded into Policy definition
            $paramValue = $effect.fixedValue
            $allowedValues = @( $effect.fixedValue )
            $defaultValue = $effect.fixedValue
            $definitionType = $effect.type
        }
        elseif ($assignmentParameters.ContainsKey($effect.parameterName)) {
            # parameter value is specified in assignment
            $param = $policy.parameters[$effect.parameterName]
            $paramValue = $param.value
            $allowedValues = $effect.allowedValues
            $defaultValue = $effect.defaultValue
            $definitionType = "SetInAssignment"
        }
        else {
            # parameter is defined by Policy definition default
            $paramValue = $effect.paramValue
            $allowedValues = $effect.allowedValues
            $defaultValue = $effect.defaultValue
            $definitionType = $effect.type
        }
        $result = @{
            paramValue                  = $paramValue
            allowedValues               = $allowedValues
            defaultValue                = $defaultValue
            definitionType              = $definitionType
            assignmentName              = $assignment.name
            assignmentDisplayName       = $assignment.displayName
            assignmentDescription       = $assignment.description
            initiativeId                = "na"
            initiativeDisplayName       = "na"
            initiativeDescription       = "na"
            initiativeParameterName     = "na"
            policyDefinitionReferenceId = "na"
            policyDefinitionGroupNames  = @( "na" )
            policyId                    = $policyDefinition.id
            policyDisplayName           = $policyDefinition.displayName
            policyDescription           = $policyDefinition.description
        }
        $effectiveEffectList += $result
    }
    return $effectiveEffectList
}
