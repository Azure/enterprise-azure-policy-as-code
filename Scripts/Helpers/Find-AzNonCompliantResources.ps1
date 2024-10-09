function Find-AzNonCompliantResources {
    [CmdletBinding()]
    param (
        [switch] $RemediationOnly,
        $PacEnvironment,
        [string[]] $PolicyDefinitionFilter,
        [string[]] $PolicySetDefinitionFilter,
        [string[]] $PolicyAssignmentFilter,
        [string[]] $PolicyExemptionFilter,
        [string[]] $PolicyEffectFilter,
        [switch] $OnlyCheckManagedAssignments,
        [switch] $ExcludeManualPolicyEffect
    )
    
    Write-Information "==================================================================================================="
    Write-Information "Retrieve Policy Compliance List"
    Write-Information "==================================================================================================="
    $effectFilter = ""
    if ($PolicyEffectFilter -and $ExcludeManualPolicyEffect) {
        Write-Error "Parameter PolicyEffectFilter cannot be used with parameter ExcludeManualPolicyEffect" -ErrorAction Stop
    }
    elseif ($ExcludeManualPolicyEffect -and $RemediationOnly) {
        Write-Error "Parameter ExcludeManualPolicyEffect cannot be used with parameter RemediationOnly" -ErrorAction Stop
    }
    elseif ($ExcludeManualPolicyEffect) {
        $effectFilter = " and properties.policyDefinitionAction <> `"manual`""
    }
    else {
        if ($PolicyEffectFilter -and $PolicyEffectFilter.Count -ne 0) {
            $effectFilter = " and ("
            foreach ($filterValue in $PolicyEffectFilter) {
                if ($RemediationOnly) {
                    if ($filterValue -in @("deployifnotexists", "modify")) {
                        $effectFilter += "properties.policyDefinitionAction == `"$filterValue`" or "
                    }
                    else {
                        Write-Error "Invalid value(s) for parameter PolicyEffectFilter $($PolicyEffectFilter | ConvertTo-Json -Compress). Valid values are: deployifnotexists, modify" -ErrorAction Stop
                    }
                }
                else {
                    if ($filterValue -in @("audit", "deny", "append", "modify", "auditifnotexists", "deployifnotexists", "denyaction", "manual")) {
                        $effectFilter += "properties.policyDefinitionAction == `"$filterValue`" or "
                    }
                    else {
                        Write-Error "Invalid value(s) for parameter PolicyEffectFilter $($PolicyEffectFilter | ConvertTo-Json -Compress). Valid values are: audit, deny, append, modify, auditifnotexists, deployifnotexists, denyaction, manual" -ErrorAction Stop
                    }
                }
            }
            $effectFilter = $effectFilter.Substring(0, $effectFilter.Length - 4) + ")"
        }
        elseif ($RemediationOnly) {
            $effectFilter = " and (properties.policyDefinitionAction == `"deployifnotexists`" or properties.policyDefinitionAction == `"modify`")"
        }
    }
    $query = ""
    if ($RemediationOnly) {
        $query = "policyresources | where type == `"microsoft.policyinsights/policystates`" and properties.complianceState == `"NonCompliant`"$($effectFilter)"
    }
    else {
        $query = "policyresources | where type == `"microsoft.policyinsights/policystates`""
    }
    Write-Information "Az Graph Query: '$query'"
    $result = @() + (Search-AzGraphAllItems -Query $query -ProgressItemName "Policy compliance records")
    Write-Information ""

    $rawNonCompliantList = [System.Collections.ArrayList]::new()
    $deployedPolicyResources = $null
    $scopeTable = $null
    if ($result.Count -ne 0) {
        # Get all Policy Assignments, Policy Definitions and Policy Set Definitions
        $scopeTable = Build-ScopeTableForDeploymentRootScope -PacEnvironment $PacEnvironment
        $deployedPolicyResources = Get-AzPolicyResources -PacEnvironment $PacEnvironment -ScopeTable $scopeTable -SkipExemptions -SkipRoleAssignments
        $allAssignments = $deployedPolicyResources.policyassignments.managed
        # Filter result
        foreach ($entry in $result) {
            $entryProperties = $entry.properties
            $policyAssignmentId = $entryProperties.policyAssignmentId
            if ($allAssignments.ContainsKey($policyAssignmentId)) {
                $entryToAdd = $null
                $assignment = $allAssignments.$policyAssignmentId
                $assignmentPacOwner = $assignment.pacOwner
                $process = $false
                if ($OnlyCheckManagedAssignments -and $assignmentPacOwner -ne "otherPaC" -and $assignmentPacOwner -ne "unknownOwner") {
                    # owned by the PaC solution or auto-created by Defender for Cloud (DfC)
                    $process = $true
                }
                elseif (!$OnlyCheckManagedAssignments) {
                    $process = $true
                }
                if ($process) {
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
                if ($null -ne $entryToAdd) {
                    $null = $rawNonCompliantList.Add($entryToAdd)
                }
            }
        }
        
    }
    Write-Information "Found $($rawNonCompliantList.Count) non-compliant resources"
    Write-Information ""

    return $rawNonCompliantList, $deployedPolicyResources, $scopeTable
}