function Find-AzNonCompliantResources {
    [CmdletBinding()]
    param (
        [switch] $RemmediationOnly,
        $PacEnvironment,
        [switch] $OnlyCheckManagedAssignments,
        [string[]] $PolicyDefinitionFilter,
        [string[]] $PolicySetDefinitionFilter,
        [string[]] $PolicyAssignmentFilter,
        [string[]] $PolicyExemptionFilter,
        [string[]] $PolicyEffectFilter
    )
    
    Write-Information "==================================================================================================="
    Write-Information "Retrieve Policy Commpliance List"
    Write-Information "==================================================================================================="
    $query = 'policyresources | where type == "microsoft.policyinsights/policystates" and properties.complianceState <> "Compliant"'
    if ($RemmediationOnly) {
        $query = 'policyresources | where type == "microsoft.policyinsights/policystates" | where properties.complianceState == "NonCompliant" and (properties.policyDefinitionAction == "deployifnotexists" or properties.policyDefinitionAction == "modify")'
    }
    $result = @() + (Search-AzGraphAllItems -Query $query -Scope @{ UseTenantScope = $true } -ProgressItemName "Policy compliance records")
    Write-Information ""

    $rawNonCompliantList = [System.Collections.ArrayList]::new()
    $deployedPolicyResources = $null
    $scopeTable = $null
    if ($result.Count -ne 0) {
        # Get all Policy Assignments, Policy Definitions and Policy Set Definitions
        $scopeTable = Get-AzScopeTree -PacEnvironment $PacEnvironment
        $deployedPolicyResources = Get-AzPolicyResources -PacEnvironment $PacEnvironment -ScopeTable $scopeTable -SkipExemptions -SkipRoleAssignments
        $allAssignments = $deployedPolicyResources.policyassignments.all
        $strategy = $pacEnvironment.desiredState.strategy
        # Filter result
        if (-not $OnlyCheckManagedAssignments -and -not $PolicyDefinitionFilter -and -not $PolicySetDefinitionFilter -and -not $PolicyAssignmentFilter) {
            $null = $rawNonCompliantList.AddRange($result)
        }
        else {
            foreach ($entry in $result) {
                $entryProperties = $entry.properties
                $policyAssignmentId = $entryProperties.policyAssignmentId
                if ($allAssignments.ContainsKey($policyAssignmentId)) {
                    $entryToAdd = $null
                    $assignment = $allAssignments.$policyAssignmentId
                    $assignmentPacOwner = $assignment.pacOwner
                    if (-not $OnlyCheckManagedAssignments -or ($assignmentPacOwner -eq "thisPaC" -or ($assignmentPacOwner -eq "unknownOwner" -and $strategy -eq "full"))) {
                        if ($PolicyDefinitionFilter -or $PolicySetDefinitionFilter -or $PolicyAssignmentFilter) {
                            if ($PolicyDefinitionFilter) {
                                foreach ($filterValue in $PolicyDefinitionFilter) {
                                    if ($entryProperties.policyDefinitionName -eq $filterValue -or $entryProperties.policyDefinitionId -eq $filterValue) {
                                        $entryToAdd = $entry
                                        break
                                    }
                                }
                            }
                            if (!$entryToAdd -and $PolicySetDefinitionFilter) {
                                foreach ($filterValue in $PolicySetDefinitionFilter) {
                                    if ($entryProperties.policySetDefinitionName -eq $filterValue -or $entryProperties.policySetDefinitionId -eq $filterValue) {
                                        $entryToAdd = $entry
                                        break
                                    }
                                }
                            }
                            if (!$entryToAdd -and $PolicyAssignmentFilter) {
                                foreach ($filterValue in $PolicyAssignmentFilter) {
                                    if ($entryProperties.policyAssignmentName -eq $filterValue -or $entryProperties.policyAssignmentId -eq $filterValue) {
                                        $entryToAdd = $entry
                                        break
                                    }
                                }
                            }
                        }
                        else {
                            $entryToAdd = $entry
                        }
                    }
                    if ($entryToAdd) {
                        if ($PolicyEffectFilter) {
                            foreach ($filterValue in $PolicyEffectFilter) {
                                if ($entryProperties.policyDefinitionAction -eq $filterValue) {
                                    $null = $rawNonCompliantList.Add($entryToAdd)
                                    break
                                }
                            }
                        }
                        else {
                            $null = $rawNonCompliantList.Add($entryToAdd)
                        }
                    }
                }
            }
        }
    }
    Write-Information "Found $($rawNonCompliantList.Count) non-compliant resources"
    Write-Information ""

    return $rawNonCompliantList, $deployedPolicyResources, $scopeTable
}