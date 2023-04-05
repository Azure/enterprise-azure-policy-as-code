function Get-AssignmentsDetails {
    [CmdletBinding()]
    param (
        [array] $assignmentArray,
        [string] $pacEnvironmentSelector,
        [hashtable] $policyResourceDetails,
        [hashtable] $cachedAssignmentsDetails
    )

    $assignmentsDetailsHt = @{}
    if ($cachedAssignmentsDetails.ContainsKey($pacEnvironmentSelector)) {
        $assignmentsDetailsHt = $cachedAssignmentsDetails.$pacEnvironmentSelector
    }
    else {
        $null = $cachedAssignmentsDetails.Add($pacEnvironmentSelector, $assignmentsDetailsHt)
    }

    [System.Collections.ArrayList] $assignmentPolicySetArray = [System.Collections.ArrayList]::new()
    foreach ($assignmentEntry in $assignmentArray) {
        $assignmentId = $assignmentEntry.id
        $policySetId = ""
        $shortName = $assignmentEntry.shortName
        # Write-Information "$($assignmentEntry.shortName) - $($assignmentId)"
        if ($assignmentsDetailsHt.ContainsKey($assignmentId)) {
            $combinedDetail = $assignmentsDetailsHt.$assignmentId
            $policySetId = $combinedDetail.id
        }
        else {
            $allAssignments = $policyResourceDetails.policyassignments
            $policySetsDetails = $policyResourceDetails.policySets
            if (!$allAssignments.ContainsKey($assignmentId)) {
                Write-Error "Assignment '$assignmentId' does not exist or is not managed by EPAC." -ErrorAction Stop
            }
            $assignment = $allAssignments.$assignmentId
            $policySetId = $assignment.properties.policyDefinitionId
            if ($policySetId.Contains("policySetDefinition")) {
                # PolicySet
                if ($policySetsDetails.ContainsKey($policySetId)) {
                    $combinedDetail = Get-DeepClone $policySetsDetails.$policySetId -AsHashTable
                    $combinedDetail.assignmentId = $assignmentId
                    $combinedDetail.assignment = $assignment
                    $combinedDetail.policySetId = $policySetId
                    $null = $assignmentsDetailsHt.Add($assignmentId, $combinedDetail)
                }
                else {
                    Write-Error "Assignment '$assignmentId' uses an unknown Policy Set '$($policySetId)'. This should not be possible!" -ErrorAction Stop
                }
            }
            else {
                Write-Error "Assignment '$assignmentId' must be an Policy Set assignment (not a Policy assignment)." -ErrorAction Stop
            }
        }
        $entry = @{
            shortName    = $shortName
            itemId       = $assignmentId
            assignmentId = $assignmentId
            policySetId  = $policySetId
        }
        $null = $assignmentPolicySetArray.Add($entry)


    }

    return $assignmentPolicySetArray.ToArray(), $assignmentsDetailsHt
}