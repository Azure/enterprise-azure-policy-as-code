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
    $requiredRoleAssignments = @()

    $existingLocation = $Existing.location 
    $definedLocation = "global"
    if ($hasExistingIdentity) { 
        $existingIdentityType = $existingIdentity.type 
        if ($existingIdentityType -eq "UserAssigned") { 
            $existingUserAssignedIdentity = $existingUserAssignedIdentity = $existingIdentity.userAssignedIdentities.Keys[0]
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
        $requiredRoleAssignments = $Assignment.requiredRoleAssignments 
    }

    $replaced = $ReplacedAssignment
    $isNewOrDeleted = $false
    $isUserAssigned = $false
    $changedIdentityStrings = @()
    $addedList = [System.Collections.ArrayList]::new()
    $updatedList = [System.Collections.ArrayList]::new()    
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
                    foreach ($requiredRoleAssignment in $requiredRoleAssignments) {
                        $addedEntry = $null
                        if ($requiredRoleAssignment.crossTenant) {
                            $addedEntry = @{
                                assignmentId          = $Assignment.id
                                assignmentDisplayName = $Assignment.displayName
                                roleDisplayName       = $requiredRoleAssignment.roleDisplayName
                                scope                 = $requiredRoleAssignment.scope
                                properties            = @{
                                    roleDefinitionId = $requiredRoleAssignment.roleDefinitionId
                                    principalId      = $null
                                    principalType    = "ServicePrincipal"
                                    description      = $requiredRoleAssignment.description
                                    crossTenant      = $true
                                }
                            }
                        }
                        else {
                            $addedEntry = @{
                                assignmentId          = $Assignment.id
                                assignmentDisplayName = $Assignment.displayName
                                roleDisplayName       = $requiredRoleAssignment.roleDisplayName
                                scope                 = $requiredRoleAssignment.scope
                                properties            = @{
                                    roleDefinitionId = $requiredRoleAssignment.roleDefinitionId
                                    principalId      = $null
                                    principalType    = "ServicePrincipal"
                                    description      = $requiredRoleAssignment.description
                                }
                            }
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
            # Updating existing Policy assignment
            if ($existingIdentityType -ne "UserAssigned") {

                # calculate addedList role assignments (rare)
                foreach ($requiredRoleAssignment in $requiredRoleAssignments) {
                    $requiredScope = $requiredRoleAssignment.scope
                    $requiredRoleDefinitionId = $requiredRoleAssignment.roleDefinitionId
                    $requiredDescription = $requiredRoleAssignment.description
                    $deployedRoleAssignmentWithUpdatedDescription = $null
                    $matchFound = $false
                    foreach ($deployedRoleAssignment in $existingRoleAssignments) {
                        $deployedScope = $deployedRoleAssignment.scope
                        $deployedRoleDefinitionId = $deployedRoleAssignment.roleDefinitionId
                        if (($deployedScope -eq $requiredScope) -and ($deployedRoleDefinitionId -eq $requiredRoleDefinitionId)) {
                            $deployedDescription = $deployedRoleAssignment.description
                            if ($deployedDescription -ne $requiredDescription) {
                                $deployedRoleAssignmentWithUpdatedDescription = $deployedRoleAssignment
                            }
                            $matchFound = $true
                            break
                        }
                    }
                    $addedEntry = $null
                    if ($requiredRoleAssignment.crossTenant) {
                        $addedEntry = @{
                            assignmentId          = $Assignment.id
                            assignmentDisplayName = $Assignment.displayName
                            roleDisplayName       = $requiredRoleAssignment.roleDisplayName
                            scope                 = $requiredRoleAssignment.scope
                            properties            = @{
                                roleDefinitionId = $requiredRoleAssignment.roleDefinitionId
                                principalId      = $null
                                principalType    = "ServicePrincipal"
                                description      = $requiredRoleAssignment.description
                                crossTenant      = $true
                            }
                        }
                    }
                    else {
                        $addedEntry = @{
                            assignmentId          = $Assignment.id
                            assignmentDisplayName = $Assignment.displayName
                            roleDisplayName       = $requiredRoleAssignment.roleDisplayName
                            scope                 = $requiredRoleAssignment.scope
                            properties            = @{
                                roleDefinitionId = $requiredRoleAssignment.roleDefinitionId
                                principalId      = $null
                                principalType    = "ServicePrincipal"
                                description      = $requiredRoleAssignment.description
                            }
                        }
                    }
                    if ($matchFound) {
                        if ($null -ne $deployedRoleAssignmentWithUpdatedDescription) {
                            $addedEntry.id = $deployedRoleAssignmentWithUpdatedDescription.id
                            $addedEntry.properties.principalId = $deployedRoleAssignmentWithUpdatedDescription.principalId
                            $null = $updatedList.Add($addedEntry)
                        }
                    }
                    else {
                        $null = $addedList.Add($addedEntry)
                    }
                }

                # calculate obsolete role assignments to be removed (rare event)
                foreach ($deployedRoleAssignment in $existingRoleAssignments) {
                    $deployedScope = $deployedRoleAssignment.scope
                    $deployedRoleDefinitionId = $deployedRoleAssignment.roleDefinitionId
                    $matchFound = $false
                    foreach ($requiredRoleAssignment in $requiredRoleAssignments) {
                        $requiredScope = $requiredRoleAssignment.scope
                        $requiredRoleDefinitionId = $requiredRoleAssignment.roleDefinitionId
                        if (($deployedScope -eq $requiredScope) -and ($deployedRoleDefinitionId -eq $requiredRoleDefinitionId)) {
                            $matchFound = $true
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

    $numberOfChanges = 0
    if ($addedList.Count -gt 0) {
        $numberOfChanges += $addedList.Count
        $changedIdentityStrings += "addedRoleAssignments"
    }
    if ($updatedList.Count -gt 0) {
        $numberOfChanges += $updatedList.Count
        $changedIdentityStrings += "updatedRoleAssignments"
    }
    if ($removedList.Count -gt 0) {
        $numberOfChanges += $removedList.Count
        $changedIdentityStrings += "removedRoleAssignments"
    }
    return @{
        replaced               = $replaced
        requiresRoleChanges    = $numberOfChanges -gt 0
        numberOfChanges        = $numberOfChanges
        changedIdentityStrings = $changedIdentityStrings
        isUserAssigned         = $isUserAssigned
        added                  = $addedList
        updated                = $updatedList
        removed                = $removedList
    }
}
