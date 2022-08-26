#Requires -PSEdition Core

function Get-AssignmentsInfo {
    [CmdletBinding()]
    param (
        [array] $assignmentArray,
        [string] $pacEnvironmentSelector,
        [hashtable] $initiativeInfos,
        [hashtable] $cachedAssignmentInfos
    )

    $assignmentInfosHt = @{}
    if ($cachedAssignmentInfos.ContainsKey($pacEnvironmentSelector)) {
        $assignmentInfosHt = $cachedAssignmentInfos.$pacEnvironmentSelector
    }
    else {
        $null = $cachedAssignmentInfos.Add($pacEnvironmentSelector, $assignmentInfosHt)
    }

    [System.Collections.ArrayList] $assignmentInitiativeArray = [System.Collections.ArrayList]::new()
    foreach ($assignmentEntry in $assignmentArray) {
        $assignmentId = $assignmentEntry.id
        $initiativeId = ""
        $shortName = $assignmentEntry.shortName
        Write-Information "$($assignmentEntry.shortName) - $($assignmentId)"
        if ($assignmentInfosHt.ContainsKey($assignmentId)) {
            $combinedInfo = $assignmentInfosHt.$assignmentId
            $initiativeId = $combinedInfo.id
        }
        else {
            $splat = Split-AssignmentIdForAzCli -id $assignmentId
            $assignment = Invoke-AzCli policy assignment show -Splat $splat -AsHashTable

            $initiativeId = $assignment.policyDefinitionId
            if ($initiativeId.Contains("policySetDefinition")) {
                # Initiative
                if ($initiativeInfos.ContainsKey($initiativeId)) {
                    $initiativeInfo = $initiativeInfos.$initiativeId
                    $combinedInfo = Get-DeepClone -InputObject $initiativeInfo -AsHashTable
                    $combinedInfo.assignmentId = $assignmentId
                    $combinedInfo.assignment = $assignment

                    $initiativeId = $initiativeId
                    $null = $assignmentInfosHt.Add($assignmentId, $combinedInfo)
                }
                else {
                    Write-Error "Assignment '$assignmentId' uses an unknown Initiative '$($initiativeId)'. This should not be possible!" -ErrorAction Stop
                }
            }
            else {
                Write-Error "Assignment '$assignmentId' must be an Initiative assignment (not a Policy assignment)." -ErrorAction Stop
            }
        }

        $assignmentEntry = @{
            shortName    = $shortName
            itemId       = $assignmentId
            assignmentId = $assignmentId
            initiativeId = $initiativeId
        }
        $null = $assignmentInitiativeArray.Add($assignmentEntry)
    }

    return $assignmentInitiativeArray.ToArray(), $assignmentInfosHt
}