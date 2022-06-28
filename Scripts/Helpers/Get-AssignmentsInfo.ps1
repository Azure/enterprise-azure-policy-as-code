#Requires -PSEdition Core

function Get-AssignmentsInfo {
    [CmdletBinding()]
    param (
        [array] $assignmentArray,
        [string] $pacEnvironmentSelector,
        [hashtable] $policyInitiativeInfo,
        [hashtable] $cachedAssignmentInfos
    )

    [hashtable] $assignmentsInfo = @{}
    if ($cachedAssignmentInfos.ContainsKey($pacEnvironmentSelector)) {
        $assignmentsInfo = $cachedAssignmentInfos.$pacEnvironmentSelector
    }
    else {
        $null = $cachedAssignmentInfos.Add($pacEnvironmentSelector, $assignmentsInfo)
    }

    foreach ($assignmentEntry in $assignmentArray) {
        $assignmentId = $assignmentEntry.id
        $assignmentShortName = $assignmentEntry.shortName
        Write-Information "$($assignmentId)"
        if (-not $assignmentsInfo.ContainsKey($assignmentId)) {
            $splat = Split-AssignmentIdForAzCli -id $assignmentId
            $assignment = Invoke-AzCli policy assignment show -Splat $splat

            $definitionId = $assignment.policyDefinitionId
            $parameters = ConvertTo-HashTable $assignment.parameters
            $isInitiative = $false
            $initiativeId = "n/a"
            $initiativeName = "n/a"
            $initiativeDisplayName = "n/a"
            $initiativeDescription = "n/a"
            $initiativePolicyType = "n/a"
            $initiativeCategory = "n/a"
            $initiativeParameters = "n/a"
            $policyInfoArray = @()
            if ($definitionId.Contains("policySetDefinition")) {
                # Initiative
                $initiativeInfos = $policyInitiativeInfo.initiativeInfos
                if ($initiativeInfos.ContainsKey($definitionId)) {
                    $isInitiative = $true
                    $initiativeInfo = $initiativeInfos.$definitionId
                    $initiativeId = $initiativeInfo.id
                    $initiativeName = $initiativeInfo.name
                    $initiativeDisplayName = $initiativeInfo.displayName
                    $initiativeDescription = $initiativeInfo.description
                    $initiativePolicyType = $initiativeInfo.policyType
                    $initiativeCategory = $initiativeInfo.category
                    $initiativeParameters = $parameters
                    $policyInfoArray = $initiativeInfo.policyDefinitions
                }
                else {
                    Write-Error "Assignment '$assignmentId' uses an unknown Initiative '$($definitionId)'. This should not be possible!" -ErrorAction Stop
                }
            }
            else {
                $policyInfos = $policyInitiativeInfo.policyInfos
                if ($policyInfos.ContainsKey($definitionId)) {
                    $isInitiative = $false
                    $policyInfo = $policyInfos.$definitionId
                    $policyInfoArray = @( $policyInfo )
                }
                else {
                    Write-Error "Assignment '$assignmentId'buses an unknown Policy '$($definitionId)'. This should not be possible!" -ErrorAction Stop
                }
            }

            [System.Collections.Generic.List[hashtable]] $policyDefinitionsInfoList = [System.Collections.Generic.List[hashtable]]::new()
            foreach ($policyInfo in $policyInfoArray) {

                # Process effect parameters
                $effectParameterName = "n/a"
                $effectValue = $policyInfo.effectValue
                $effectReason = $policyInfo.effectReason
                $effectParameterName = $policyInfo.effectParameterName
                if (($isInitiative -and $policyInfo.effectReason -eq "InitiativeDefault") -or (-not $isInitiative -and $policyInfo.effectReason -eq "PolicyDefault")) {
                    # Effect is parameterized, check if defualt override in Assignment
                    if ($parameters.ContainsKey($effectParameterName)) {
                        $effectParameter = $parameters.$effectParameterName
                        $effectValue = $effectParameter.value
                        $effectReason = "Assignment"
                    }
                }

                # Process parameters
                $policyParameters = $policyInfo.parameters
                $effectiveParameters = @{}
                foreach ($policyParameterName in $policyParameters.Keys) {
                    $policyParameter = $policyParameters.$policyParameterName
                    $policyParameterDisplayName = $policyParameterName
                    $policyParameterDescription = "n/a"
                    $policyParameterValue = $policyParameter.defaultValue
                    if ($policyParameterMetadata) {
                        $policyParameterMetadata = $policyParameter.metadata
                        if ($policyParameterMetadata.displayName) {
                            $policyParameterDisplayName = $policyParameterMetadata.displayName
                        }
                        if ($policyParameterMetadata.description) {
                            $policyParameterDescription = $policyParameterMetadata.description
                        }
                    }
                    if ($parameters.ContainsKey($policyParameterName)) {
                        $parameter = $parameters.$policyParameterName
                        $policyParameterValue = $parameter.value
                    }
                    $effectiveParameter = @{
                        displayName = $policyParameterDisplayName
                        description = $policyParameterDescription
                        value       = $policyParameterValue
                    }
                    $effectiveParameters.Add($policyParameterName, $effectiveParameter)
                }

                # Assemble complete info for policyDefinitions array
                $policyDefinitionInfo = @{
                    id                          = $policyInfo.id
                    name                        = $policyInfo.name
                    displayName                 = $policyInfo.displayName
                    description                 = $policyInfo.description
                    policyType                  = $policyInfo.policyType
                    category                    = $policyInfo.category
                    effectParameterName         = $effectParameterName
                    effectValue                 = $effectValue
                    effectDefault               = $policyInfo.effectDefault
                    effectAllowedValues         = $policyInfo.effectAllowedValues
                    effectReason                = $effectReason
                    parameters                  = $effectiveParameters
                    policyDefinitionReferenceId = $policyInfo.policyDefinitionReferenceId
                    groupNames                  = $policyInfo.groupNames
                }
                $policyDefinitionsInfoList.Add($policyDefinitionInfo)
            }

            # Assemble Assignment info
            $assignmentInfo = @{
                id                     = $assignmentId
                name                   = $assignment.name
                shortName              = $assignmentShortName
                displayName            = $assignment.displayName
                description            = $assignment.description
                isInitiative           = $isInitiative
                initiativeId           = $initiativeId
                initiativeName         = $initiativeName
                initiativeDisplayName  = $initiativeDisplayName
                initiativeDescription  = $initiativeDescription
                initiativePolicyType   = $initiativePolicyType
                initiativeCategory     = $initiativeCategory
                initiativeParameters   = $initiativeParameters
                policyDefinitionsInfos = $policyDefinitionsInfoList.ToArray()
            }
            $null = $assignmentsInfo.Add($assignmentId, $assignmentInfo)
        }
    }
    return $assignmentsInfo
}