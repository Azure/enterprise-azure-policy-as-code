#Requires -PSEdition Core

function Build-AzPolicyAssignmentIdentityAndRoleChanges {
    [CmdletBinding()]
    param (
        [bool] $replacingAssignment,
        [string] $managedIdentityLocation,
        [hashtable] $assignmentConfig,
        [hashtable] $removedIdentities,
        [hashtable] $removedRoleAssignments,
        [hashtable] $addedRoleAssignments
    )

    $existingAssignment = $assignmentConfig.existingAssignment
    $identityRequired = $assignmentConfig.ContainsKey("identityRequired") -and $assignmentConfig.identityRequired
    $hasExistingIdentity = ($null -ne $existingAssignment.identity) -and ($null -ne $existingAssignment.identity.principalId)
    $existingAssignmentlocation = $existingAssignment.location
    $removedIdentity = $false
    $identityLocationChanged = $false
    $addingIdentity = $false
    if ($hasExistingIdentity -or $identityRequired) {
        if (-not $replacingAssignment) {
            $identityLocationChanged = $hasExistingIdentity -and $identityRequired `
                -and ($existingAssignmentlocation) -ne $managedIdentityLocation
            $removedIdentity = (-not $identityRequired) -and $hasExistingIdentity
            $addingIdentity = (-not $hasExistingIdentity) -and $identityRequired
        }

        $key = $assignmentConfig.id
        $existingRoleAssignments = @()
        if ($hasExistingIdentity) {
            $existingRoleAssignments = $existingAssignment.roleAssignments
        }

        if ($replacingAssignment -or $identityLocationChanged -or $removedIdentity) {
            if ($existingRoleAssignments.Count -gt 0) {
                $removedRoleAssignments.Add($key, @{
                        DisplayName     = $assignmentConfig.DisplayName
                        identity        = $existingAssignment.identity
                        roleAssignments = $existingRoleAssignments
                    }
                )
            }
            if ($removedIdentity) {
                # cannot remove if only location change
                $removedIdentities.Add($key, @{
                        DisplayName = $assignmentConfig.DisplayName
                        identity    = $existingAssignment.identity
                    }
                )
            }
        }
        elseif ($hasExistingIdentity -and $identityRequired) {
            # Updating assignment or assignment unchanged
            $identity = $existingAssignment.identity
            $requiredRoleDefinitions = $assignmentConfig.Metadata.roles

            # Check for removed roles
            $removeRoleAssignmentList = @()
            foreach ($existingRoleAssignment in $existingRoleAssignments) {
                $existingScope = $existingRoleAssignment.scope
                $shortRoleDefinitionId = $existingRoleAssignment.roleDefinitionId.Split('/')[-1]
                $matchFound = $false
                foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
                    if (($requiredRoleDefinition.scope -eq $existingScope) -and ($requiredRoleDefinition.roleDefinitionId -eq $shortRoleDefinitionId)) {
                        $matchFound = $true
                        # Nothing to do
                        break
                    }
                }
                if (!$matchFound) {
                    # Obsolete role assignment
                    $removeRoleAssignmentList += $existingRoleAssignment
                }
            }
            $addRoleAssignmentlist = @()
            foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
                foreach ($existingRoleAssignment in $existingRoleAssignments) {
                    $existingScope = $existingRoleAssignment.scope
                    $shortRoleDefinitionId = $existingRoleAssignment.roleDefinitionId.Split('/')[-1]
                    $matchFound = $false
                    if (($requiredRoleDefinition.scope -eq $existingScope) -and ($requiredRoleDefinition.roleDefinitionId -eq $shortRoleDefinitionId)) {
                        $matchFound = $true;
                        # Nothing to do
                        break
                    }
                }
                if (!$matchFound) {
                    # add role
                    $addRoleAssignmentlist += $requiredRoleDefinition                
                }
            }
            if ($addRoleAssignmentlist.Length -gt 0) {
                $addedRoleAssignments.Add($key, @{
                        DisplayName = $assignmentConfig.DisplayName
                        identity    = $identity
                        roles       = $addRoleAssignmentlist
                    }
                )
            }
            if ($removeRoleAssignmentList.Length -gt 0) {
                $removedRoleAssignments.Add($key, @{
                        DisplayName     = $assignmentConfig.DisplayName
                        identity        = $identity
                        roleAssignments = $removeRoleAssignmentList
                    }
                )
            }
        }
        if ($addedRoleAssignments.ContainsKey($key)) {
            $addedRoleAssignment = $addedRoleAssignments[$key]
            $roles = $addedRoleAssignment.roles
            Write-Information "            ADDING $($roles.Length) ROLES"
            foreach ($role in $roles) {
                Write-Information "                RoleId=$($role.roleDefinitionId), Scope=$($role.scope)"
            }

        }
        if ($removedRoleAssignments.ContainsKey($key)) {
            $removedRoleAssignment = $removedRoleAssignments[$key]
            $roleAssignments = $removedRoleAssignment.roleAssignments
            Write-Information "            REMOVING $($roleAssignments.Length) ROLES"
            foreach ($roleAssignment in $roleAssignments) {
                Write-Information "                RolenNme=$($roleAssignment.roleDefinitionName), Scope=$($roleAssignment.scope)"
            }

        }
    }
    $identityLocationChanged, $addingIdentity
}
