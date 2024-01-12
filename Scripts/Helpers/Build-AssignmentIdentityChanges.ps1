function Build-AssignmentIdentityChanges {
    [CmdletBinding()]
    param (
        $Existing,
        $Assignment,
        $ReplacedAssignment,
        $DeployedRoleAssignmentsByPrincipalId
    )

    $existingIdentity = $Existing.identity
    $hasExistingIdentity = $null -ne $Existing -and $null -ne $existingIdentity -and $existingIdentity.type -ne "None"
    $identityRequired = $null -ne $Assignment -and $Assignment.identityRequired

    $existingIdentityType = "None"
    $existingPrincipalId = $null
    $existingUserAssignedIdentity = $null
    $existingLocation = $null
    $existingRoleAssignments = @()

    $definedIdentity = $null
    $definedIdentityType = "None"
    $definedUserAssignedIdentity = $null
    $requiredRoleDefinitions = @()

    $existingLocation = $Existing.location 
    $definedLocation = "global"
    if ($hasExistingIdentity) { 
        $existingIdentityType = $existingIdentity.type 
        if ($existingIdentityType -eq "UserAssigned") { 
            $existingUserAssignedIdentity = ($existingIdentity.userAssignedIdentities | get-member)[-1].Name 
        } 
        if ($existingIdentityType -eq "UserAssigned") { 
            $existingPrincipalId = $existingIdentity.userAssignedIdentities.$existingUserAssignedIdentity.principalId 
        }
        else { 
            $existingPrincipalId = $existingIdentity.principalId 
        } 
        if ($DeployedRoleAssignmentsByPrincipalId.ContainsKey($existingPrincipalId)) { 
            $existingRoleAssignments = $DeployedRoleAssignmentsByPrincipalId.$existingPrincipalId 
        } 
    } 
    if ($identityRequired ) { 
        $definedIdentity = $Assignment.identity 
        $definedIdentityType = $definedIdentity.type 
        if ($definedIdentityType -eq "UserAssigned") { 
            $definedUserAssignedIdentity = $definedIdentity.userAssignedIdentities.GetEnumerator().Name
        } 
        $definedLocation = $Assignment.managedIdentityLocation
        $requiredRoleDefinitions = $Assignment.metadata.roles 
    }

    $replaced = $ReplacedAssignment
    $isNewOrDeleted = $false
    $isUserAssigned = $false
    $changedIdentityStrings = @()
    $addedList = [System.Collections.ArrayList]::new()
    $removedList = [System.Collections.ArrayList]::new()
    if ($hasExistingIdentity -or $identityRequired) {
        # need to check if either an existing identity or a newly added identity or existing and required identity
        if ($null -ne $Existing -and $null -ne $Assignment) {
            # this is an update, not a delete or new Assignment
            if ($hasExistingIdentity -xor $identityRequired) {
                # change (xor) in need for an identity, determine which one
                if ($hasExistingIdentity) {
                    $changedIdentityStrings += "removedIdentity"
                }
                else {
                    $changedIdentityStrings += "addedIdentity"
                }
                $replaced = $true
            }
            else {
                # existing identity and still requires an entity
                if ($existingLocation -ne $definedLocation) {
                    $changedIdentityStrings += "identityLocation $existingLocation->$definedLocation"
                    $replaced = $true
                }
                if ($existingIdentityType -ne $definedIdentityType) {
                    $changedIdentityStrings += "identityType $existingIdentityType->$definedIdentityType"
                    $replaced = $true
                }
                elseif ($existingIdentityType -eq "UserAssigned" -and $existingUserAssignedIdentity -ne $definedUserAssignedIdentity) {
                    $changedIdentityStrings += "changed userAssignedIdentity"
                    $replaced = $true
                }
            }
        }
        else {
            # deleted or new Assignment
            $isNewOrDeleted = $true
        }

        if ($replaced -or $isNewOrDeleted) {
            # replaced, new or deleted Assignment
            if ($hasExistingIdentity -and $existingRoleAssignments.Count -gt 0) {
                if ($existingIdentityType -ne "UserAssigned") {
                    foreach ($deployedRoleAssignment in $existingRoleAssignments) {
                        $null = $removedList.Add($deployedRoleAssignment)
                    }
                }
                else {
                    # note: do not manage role assignments if user-assigned MI
                    $isUserAssigned = $true
                }
            }
            if ($identityRequired) {
                if ($definedIdentityType -ne "UserAssigned") {
                    foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
                        $requiredRoleDefinitionId = $requiredRoleDefinition.roleDefinitionId
                        $addedEntry = @{
                            assignmentId     = $Assignment.id
                            displayName      = $Assignment.displayName
                            scope            = $requiredRoleDefinition.scope
                            principalId      = $null
                            objectType       = "ServicePrincipal"
                            roleDefinitionId = $requiredRoleDefinitionId
                            roleDisplayName  = $requiredRoleDefinition.roleDisplayName
                        }
                        $null = $addedList.Add($addedEntry)
                    }
                }
                else {
                    # note: do not manage role assignments if user-assigned MI
                    $isUserAssigned = $true
                }
            }
        }
        else {
            # Updating existing assignment
            if ($existingIdentityType -ne "UserAssigned") {

                # calculate addedList role assignments (rare)
                foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
                    $requiredRoleDefinitionId = $requiredRoleDefinition.roleDefinitionId
                    $matchFound = $false
                    foreach ($deployedRoleAssignment in $existingRoleAssignments) {
                        $deployedScope = $deployedRoleAssignment.scope
                        $deployedRoleDefinitionId = $deployedRoleAssignment.roleDefinitionId
                        if (($deployedScope -eq $requiredRoleDefinition.scope) -and ($deployedRoleDefinitionId -eq $requiredRoleDefinitionId)) {
                            $matchFound = $true
                            # nothing to do
                            break
                        }
                    }
                    if (!$matchFound) {
                        # add role
                        $addedEntry = @{
                            assignmentId     = $Assignment.id
                            displayName      = $Assignment.displayName
                            principalId      = $principalIdForAddedRoles
                            objectType       = "ServicePrincipal"
                            scope            = $requiredRoleDefinition.scope
                            roleDefinitionId = $requiredRoleDefinitionId
                            roleDisplayName  = $requiredRoleDefinition.roleDisplayName
                        }
                        $null = $addedList.Add($addedEntry)
                    }
                }

                # calculate obsolete role assignments to be removed (rare event)
                foreach ($deployedRoleAssignment in $existingRoleAssignments) {
                    $deployedScope = $deployedRoleAssignment.scope
                    $deployedRoleDefinitionId = $deployedRoleAssignment.roleDefinitionId
                    $matchFound = $false
                    foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
                        $requiredRoleDefinitionId = $requiredRoleDefinition.roleDefinitionId
                        if (($deployedScope -eq $requiredRoleDefinition.scope) -and ($deployedRoleDefinitionId -eq $requiredRoleDefinitionId)) {
                            $matchFound = $true
                            # Nothing to do
                            break
                        }
                    }
                    if (!$matchFound) {
                        # Obsolete role assignment
                        $null = $removedList.Add($deployedRoleAssignment)
                    }
                }
            }
            else {
                # note: do not manage role assignments if user-assigned MI
                $isUserAssigned = $true
            }
        }
    }
    elseif ($existingLocation -ne $definedLocation) {
        # location change
        if ($null -eq $definedLocation) {
            $definedLocation = "."
        }
        $changedIdentityStrings += "identityLocation $existingLocation->$definedLocation"
        $replaced = $true
    }

    if ($addedList.Count -gt 0) {
        $changedIdentityStrings += "addedRoleAssignments"
    }
    if ($removedList.Count -gt 0) {
        $changedIdentityStrings += "removedRoleAssignments"
    }
    $numberOfChanges = $addedList.Count + $removedList.Count
    return @{
        replaced               = $replaced
        requiresRoleChanges    = $numberOfChanges -gt 0
        numberOfChanges        = $numberOfChanges
        changedIdentityStrings = $changedIdentityStrings
        isUserAssigned         = $isUserAssigned
        added                  = $addedList.ToArray()
        removed                = $removedList.ToArray()
    }
}
