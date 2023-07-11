function Build-AssignmentIdentityChanges {
    [CmdletBinding()]
    param (
        $Existing,
        $Assignment,
        $ReplacedAssignment,
        $DeployedRoleAssignmentsByPrincipalId
    )

    $ExistingIdentity = $Existing.identity
    $hasExistingIdentity = $null -ne $Existing -and $null -ne $ExistingIdentity -and $ExistingIdentity.type -ne "None"
    $IdentityRequired = $null -ne $Assignment -and $Assignment.identityRequired

    $ExistingIdentityType = "None"
    $ExistingPrincipalId = $null
    $ExistingUserAssignedIdentity = $null
    $ExistingLocation = $null
    $ExistingRoleAssignments = @()

    $definedIdentity = $null
    $definedIdentityType = "None"
    $definedUserAssignedIdentity = $null
    $definedLocation = $null
    $requiredRoleDefinitions = @()

    if ($hasExistingIdentity) { 
        $ExistingIdentityType = $ExistingIdentity.type 
        if ($ExistingIdentityType -eq "UserAssigned") { 
            $ExistingUserAssignedIdentity = ($ExistingIdentity.userAssignedIdentities | get-member)[-1].Name 
        } 
        if ($ExistingIdentityType -eq "UserAssigned") { 
            $ExistingPrincipalId = $ExistingIdentity.userAssignedIdentities.$ExistingUserAssignedIdentity.principalId 
        }
        else { 
            $ExistingPrincipalId = $ExistingIdentity.principalId 
        } $ExistingLocation = $Existing.location 
        if ($DeployedRoleAssignmentsByPrincipalId.ContainsKey($ExistingPrincipalId)) { 
            $ExistingRoleAssignments = $DeployedRoleAssignmentsByPrincipalId.$ExistingPrincipalId 
        } 
    } 
    if ($IdentityRequired ) { 
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
    $RemovedList = [System.Collections.ArrayList]::new()
    if ($hasExistingIdentity -or $IdentityRequired) {
        # need to check if either an existing identity or a newly added identity or existing and required identity
        if ($null -ne $Existing -and $null -ne $Assignment) {
            # this is an update, not a delete or new Assignment
            if ($hasExistingIdentity -xor $IdentityRequired) {
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
                if ($ExistingLocation -ne $definedLocation) {
                    $changedIdentityStrings += "identityLocation $ExistingLocation->$definedLocation"
                    $replaced = $true
                }
                if ($ExistingIdentityType -ne $definedIdentityType) {
                    $changedIdentityStrings += "identityType $ExistingIdentityType->$definedIdentityType"
                    $replaced = $true
                }
                elseif ($ExistingIdentityType -eq "UserAssigned" -and $ExistingUserAssignedIdentity -ne $definedUserAssignedIdentity) {
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
            if ($hasExistingIdentity -and $ExistingRoleAssignments.Count -gt 0) {
                if ($ExistingIdentityType -ne "UserAssigned") {
                    foreach ($deployedRoleAssignment in $ExistingRoleAssignments) {
                        $null = $RemovedList.Add($deployedRoleAssignment)
                    }
                }
                else {
                    # note: do not manage role assignments if user-assigned MI
                    $isUserAssigned = $true
                }
            }
            if ($IdentityRequired) {
                if ($definedIdentityType -ne "UserAssigned") {
                    foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
                        $requiredRoleDefinitionId = $requiredRoleDefinition.roleDefinitionId.Split('/')[-1]
                        $addedEntry = @{
                            assignmentId     = $Assignment.id
                            displayName      = $Assignment.DisplayName
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
            if ($ExistingIdentityType -ne "UserAssigned") {

                # calculate addedList role assignments (rare)
                foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
                    $requiredRoleDefinitionId = $requiredRoleDefinition.roleDefinitionId.Split('/')[-1]
                    $matchFound = $false
                    foreach ($deployedRoleAssignment in $ExistingRoleAssignments) {
                        $deployedScope = $deployedRoleAssignment.scope
                        $deployedRoleDefinitionId = $deployedRoleAssignment.roleDefinitionId
                        if (($deployedScope -eq $requiredRoleDefinition.scope) -and ($deployedRoleDefinitionId -eq $requiredRoleDefinitionId)) {
                            $matchFound = $true
                            # nNothing to do
                            break
                        }
                    }
                    if (!$matchFound) {
                        # add role
                        $addedEntry = @{
                            assignmentId     = $Assignment.id
                            displayName      = $Assignment.DisplayName
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
                foreach ($deployedRoleAssignment in $ExistingRoleAssignments) {
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
                        $null = $RemovedList.Add($deployedRoleAssignment)
                    }
                }
            }
            else {
                # note: do not manage role assignments if user-assigned MI
                $isUserAssigned = $true
            }
        }
    }

    $numberOfChanges = $addedList.Count + $RemovedList.Count
    return @{
        replaced               = $replaced
        requiresRoleChanges    = $numberOfChanges -gt 0
        numberOfChanges        = $numberOfChanges
        changedIdentityStrings = $changedIdentityStrings
        isUserAssigned         = $isUserAssigned
        added                  = $addedList.ToArray()
        removed                = $RemovedList.ToArray()
    }
}
