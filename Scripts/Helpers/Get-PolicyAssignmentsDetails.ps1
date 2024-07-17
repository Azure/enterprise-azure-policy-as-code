function Get-PolicyAssignmentsDetails {
    [CmdletBinding()]
    param (
        [array] $AssignmentArray,
        [string] $PacEnvironmentSelector,
        [hashtable] $PolicyResourceDetails,
        [hashtable] $CachedAssignmentsDetails
    )

    $assignmentsDetailsHt = @{}
    if ($CachedAssignmentsDetails.ContainsKey($PacEnvironmentSelector)) {
        $assignmentsDetailsHt = $CachedAssignmentsDetails.$PacEnvironmentSelector
    }
    else {
        $null = $CachedAssignmentsDetails.Add($PacEnvironmentSelector, $assignmentsDetailsHt)
    }

    [System.Collections.ArrayList] $assignmentPolicySetArray = [System.Collections.ArrayList]::new()
    foreach ($assignmentEntry in $AssignmentArray) {
        $assignmentId = $assignmentEntry.id
        $policySetId = ""
        $shortName = $assignmentEntry.shortName
        # Write-Information "$($assignmentEntry.shortName) - $($assignmentId)"
        if ($assignmentsDetailsHt.ContainsKey($assignmentId)) {
            $combinedDetail = $assignmentsDetailsHt.$assignmentId
            $policySetId = $combinedDetail.id
        }
        else {
            $allAssignments = $PolicyResourceDetails.policyassignments
            $policySetsDetails = $PolicyResourceDetails.policySets
            $policiesDetails = $PolicyResourceDetails.policies
            if (!$allAssignments.ContainsKey($assignmentId)) {
                Write-Error "Assignment '$assignmentId' does not exist or is not managed by EPAC." -ErrorAction Stop
            }
            $assignment = $allAssignments.$assignmentId
            $policySetId = $assignment.properties.policyDefinitionId
            if ($policySetId.Contains("policySetDefinition", [StringComparison]::InvariantCultureIgnoreCase)) {
                # PolicySet
                if ($policySetsDetails.ContainsKey($policySetId)) {
                    $combinedDetail = Get-DeepCloneAsOrderedHashtable $policySetsDetails.$policySetId
                    $combinedDetail.assignmentId = $assignmentId
                    $combinedDetail.assignment = $assignment
                    $combinedDetail.policySetId = $policySetId
                    $null = $assignmentsDetailsHt.Add($assignmentId, $combinedDetail)
                }
                else {
                    Write-Error "Assignment '$assignmentId' uses an unknown Policy Set '$($policySetId)'. This should not be possible!" -ErrorAction Stop
                }
                
                $entry = @{
                    shortName    = $shortName
                    itemId       = $assignmentId
                    assignmentId = $assignmentId
                    policySetId  = $policySetId
                }
            }
            elseif ($policySetId.Contains("policyDefinitions", [StringComparison]::InvariantCultureIgnoreCase)) {
                $combinedDetail = Get-DeepCloneAsOrderedHashtable $policiesDetails.$policySetId
                $combinedDetail.assignmentId = $assignmentId
                $combinedDetail.assignment = $assignment
                $combinedDetail.policyDefinitionId = $policySetId
                $null = $assignmentsDetailsHt.Add($assignmentId, $combinedDetail)
                $entry = @{
                    shortName          = $shortName
                    itemId             = $assignmentId
                    assignmentId       = $assignmentId
                    policyDefinitionId = $policySetId
                    policySetId        = "N/A"
                }
            }
            else {
                Write-Error "Assignment '$assignmentId' is not a Policy Set or Policy Definition. This should not be possible!" -ErrorAction Stop
            }
        }
        $null = $assignmentPolicySetArray.Add($entry)


    }

    return $assignmentPolicySetArray.ToArray(), $assignmentsDetailsHt
}
