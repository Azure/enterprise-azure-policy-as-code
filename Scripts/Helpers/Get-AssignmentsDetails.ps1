function Get-AssignmentsDetails {
    [CmdletBinding()]
    param (
        [array] $AssignmentArray,
        [string] $PacEnvironmentSelector,
        [hashtable] $PolicyResourceDetails,
        [hashtable] $CachedAssignmentsDetails
    )

    $AssignmentsDetailsHt = @{}
    if ($CachedAssignmentsDetails.ContainsKey($PacEnvironmentSelector)) {
        $AssignmentsDetailsHt = $CachedAssignmentsDetails.$PacEnvironmentSelector
    }
    else {
        $null = $CachedAssignmentsDetails.Add($PacEnvironmentSelector, $AssignmentsDetailsHt)
    }

    [System.Collections.ArrayList] $AssignmentPolicySetArray = [System.Collections.ArrayList]::new()
    foreach ($AssignmentEntry in $AssignmentArray) {
        $AssignmentId = $AssignmentEntry.id
        $PolicySetId = ""
        $shortName = $AssignmentEntry.shortName
        # Write-Information "$($AssignmentEntry.shortName) - $($AssignmentId)"
        if ($AssignmentsDetailsHt.ContainsKey($AssignmentId)) {
            $combinedDetail = $AssignmentsDetailsHt.$AssignmentId
            $PolicySetId = $combinedDetail.id
        }
        else {
            $AllAssignments = $PolicyResourceDetails.policyassignments
            $PolicySetsDetails = $PolicyResourceDetails.policySets
            if (!$AllAssignments.ContainsKey($AssignmentId)) {
                Write-Error "Assignment '$AssignmentId' does not exist or is not managed by EPAC." -ErrorAction Stop
            }
            $Assignment = $AllAssignments.$AssignmentId
            $PolicySetId = $Assignment.properties.policyDefinitionId
            if ($PolicySetId.Contains("policySetDefinition")) {
                # PolicySet
                if ($PolicySetsDetails.ContainsKey($PolicySetId)) {
                    $combinedDetail = Get-DeepClone $PolicySetsDetails.$PolicySetId -AsHashtable
                    $combinedDetail.assignmentId = $AssignmentId
                    $combinedDetail.assignment = $Assignment
                    $combinedDetail.policySetId = $PolicySetId
                    $null = $AssignmentsDetailsHt.Add($AssignmentId, $combinedDetail)
                }
                else {
                    Write-Error "Assignment '$AssignmentId' uses an unknown Policy Set '$($PolicySetId)'. This should not be possible!" -ErrorAction Stop
                }
            }
            else {
                Write-Error "Assignment '$AssignmentId' must be an Policy Set assignment (not a Policy assignment)." -ErrorAction Stop
            }
        }
        $entry = @{
            shortName    = $shortName
            itemId       = $AssignmentId
            assignmentId = $AssignmentId
            policySetId  = $PolicySetId
        }
        $null = $AssignmentPolicySetArray.Add($entry)


    }

    return $AssignmentPolicySetArray.ToArray(), $AssignmentsDetailsHt
}
