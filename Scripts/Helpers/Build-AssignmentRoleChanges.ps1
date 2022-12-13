#Requires -PSEdition Core

function Build-AssignmentRoleChanges {
    [CmdletBinding()]
    param (
        $principalIdForAddedRoles = $null,
        [array] $requiredRoleDefinitions,
        [array] $deployedRoleAssignments,
        [hashtable] $assignment,
        [hashtable] $roleAssignments
    )

    $changingRoleAssignments = $false
    $addedList = [System.Collections.ArrayList]::new()
    $removedList = [System.Collections.ArrayList]::new()
    $null = $addedList.AddRange($roleAssignments.added)
    $null = $removedList.AddRange($roleAssignments.removed)
    if ($null -eq $principalIdForAddedRoles) {
        Write-Information "DEBUG: principalIdForAddedRoles is null"
        if ($requiredRoleDefinitions.Length -gt 0) {
            Write-Information "DEBUG: requiredRoleDefinitions is populated with $($requiredRoleDefinitions.Length) characters"
            # Add all required role assignments for a new or replaced assignment
            foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
                $requiredRoleDefinitionId = $requiredRoleDefinition.roleDefinitionId.Split('/')[-1]
                $addedEntry = @{
                    assignmentId     = $assignment.id
                    displayName      = $assignment.DisplayName
                    scope            = $requiredRoleDefinition.scope
                    principalId      = $null
                    objectType       = "ServicePrincipal"
                    roleDefinitionId = $requiredRoleDefinitionId
                    roleDisplayName  = $requiredRoleDefinition.roleDisplayName
                }
                $null = $addedList.Add($addedEntry)
                $roleAssignments.numberOfChanges++
            }
            $changingRoleAssignments = $true
        }
        if ($deployedRoleAssignments.Length -gt 0) {
            Write-Information "DEBUG: deployedRoleAssignments is populated with $($deployedRoleAssignments.Length) characters"
            # Deleting or replacing assignment, remove every deployed role assignment
            foreach ($deployedRoleAssignment in $deployedRoleAssignments) {
                $null = $removedList.Add($deployedRoleAssignment)
                $roleAssignments.numberOfChanges++

            }
            $changingRoleAssignments = $true
            write-output "DEBUG: RemovedList has $($removedList.count) items in it"
        }
    }
    else {
        # Updating existing assignment
        Write-Information "DEBUG: Updating an existing assignment, principalIdForAddedRoles is $($principalIdForAddedRoles)"
        # Calculate addedList role assignments (also rare)
        foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
            $requiredRoleDefinitionId = $requiredRoleDefinition.roleDefinitionId.Split('/')[-1]
            foreach ($deployedRoleAssignment in $deployedRoleAssignments) {
                $deployedScope = $deployedRoleAssignment.scope
                $deployedRoleDefinitionId = $deployedRoleAssignment.roleDefinitionId
                $matchFound = $false
                if (($deployedScope -eq $requiredRoleDefinition.scope) -and ($deployedRoleDefinitionId -eq $requiredRoleDefinitionId)) {
                    $matchFound = $true
                    # Nothing to do
                    break
                }
            }
            if (!$matchFound) {
                # add role
                Write-Information "DEBUG: Match Not Found, using requiredRoleDefinition ($($requiredRoleDefinition)), deployedRoleDefinitionId `
                    ($($deployedRoleDefinitionId)), and deployedScope ($($deployedScope)) as matching criteria"
                $addedEntry = @{
                    assignmentId     = $assignment.id
                    displayName      = $assignment.DisplayName
                    principalId      = $principalIdForAddedRoles
                    objectType       = "ServicePrincipal"
                    scope            = $requiredRoleDefinition.scope
                    roleDefinitionId = $requiredRoleDefinitionId
                    roleDisplayName  = $requiredRoleDefinition.roleDisplayName
                }
                $null = $addedList.Add($addedEntry)
                $roleAssignments.numberOfChanges++
                $changingRoleAssignments = $true
            }
        }

        # Calculate obsolete role assignments to be removed if needed (rare event)
        foreach ($deployedRoleAssignment in $deployedRoleAssignments) {
            $deployedScope = $deployedRoleAssignment.scope
            $deployedRoleDefinitionId = $deployedRoleAssignment.roleDefinitionId
            $matchFound = $false
            foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
                $requiredRoleDefinitionId = $requiredRoleDefinition.roleDefinitionId.Split('/')[-1]
                if (($deployedScope -eq $requiredRoleDefinition.scope) -and ($deployedRoleDefinitionId -eq $requiredRoleDefinitionId)) {
                    $matchFound = $true
                    # Nothing to do
                    break
                }
            }
            if (!$matchFound) {
                # Obsolete role assignment
                $null = $removedList.Add($deployedRoleAssignment)
                $roleAssignments.numberOfChanges++
                $changingRoleAssignments = $true
            }
        }
    }

    if ($changingRoleAssignments) {
        if ($addedList.Length -gt 0) {
            $roleAssignments.added = $addedList.ToArray()
        }
        if ($removedList.Length -gt 0) {
            $roleAssignments.removed = $removedList.ToArray()
        }
    }
    return $changingRoleAssignments
}
