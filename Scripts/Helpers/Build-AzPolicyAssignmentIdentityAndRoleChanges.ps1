#Requires -PSEdition Core

function Build-RemovedRoleAssignment {
    [CmdletBinding()]
    param (
        [string] $assignmentId,
        [string] $displayName,
        $identity,
        [array] $removedRoleAssignmentList,
        [hashtable] $removedRoleAssignments
    )

    [System.Collections.ArrayList] $simplifiedRoleAssignmentList = [System.Collections.ArrayList]::new()
    foreach ($removedRoleAssignment in $removedRoleAssignmentList) {
        $shortRoleDefinitionId = $removedRoleAssignment.roleDefinitionId.Split('/')[-1]
        [void] $simplifiedRoleAssignmentList.Add(@{
                id                 = $removedRoleAssignment.id
                scope              = $removedRoleAssignment.scope
                roleDefinitionId   = $shortRoleDefinitionId
                roleDefinitionName = $removedRoleAssignment.roleDefinitionName
            }
        )
    }
    if ($simplifiedRoleAssignmentList.Count -gt 0) {
        [void] $removedRoleAssignments.Add($assignmentId, @{
                DisplayName     = $displayName
                identity        = $identity
                roleAssignments = $simplifiedRoleAssignmentList.ToArray()
            }
        )
    }
}

function Build-AzPolicyAssignmentIdentityAndRoleChanges {
    [CmdletBinding()]
    param (
        [bool] $replacingAssignment,
        [string] $managedIdentityLocation,
        [hashtable] $assignmentConfig,
        [hashtable] $removedRoleAssignments,
        [hashtable] $addedRoleAssignments
    )

    $existingAssignment = $assignmentConfig.existingAssignment
    $identity = $existingAssignment.identity
    $identityRequired = $assignmentConfig.ContainsKey("identityRequired") -and $assignmentConfig.identityRequired
    $hasExistingIdentity = ($null -ne $existingAssignment.identity) -and ($null -ne $existingAssignment.identity.principalId)
    if ($hasExistingIdentity -or $identityRequired) {
        # Identity and Role assignments are require or it has an existing identity

        if (-not $replacingAssignment) {
            # Check if we have changes which must or are at best handled by replacing
            $existingAssignmentlocation = $existingAssignment.location
            $identityLocationChanged = $hasExistingIdentity -and $identityRequired `
                -and ($existingAssignmentlocation) -ne $managedIdentityLocation
            $removedIdentity = (-not $identityRequired) -and $hasExistingIdentity
            $addingIdentity = (-not $hasExistingIdentity) -and $identityRequired
            $replacingAssignment = $identityLocationChanged -or $removedIdentity -or $addingIdentity
        }

        # Collect existing role assignments (if any)
        $assignmentId = $assignmentConfig.id
        $existingRoleAssignments = @()
        if ($hasExistingIdentity) {
            $existingRoleAssignments = $existingAssignment.roleAssignments
        }
        $requiredRoleDefinitions = $assignmentConfig.Metadata.roles

        if ($replacingAssignment) {
            # Replacing assignment

            # Remove all existing role assignments in old identity
            if ($existingRoleAssignments.Length -gt 0) {
                Build-RemovedRoleAssignment -assignmentId $assignmentId `
                    -identity $identity `
                    -displayName $displayName `
                    -removedRoleAssignmentList $existingRoleAssignments `
                    -removedRoleAssignments $removedRoleAssignments
            }
            
            # Add all required role assignments in new assignment
            if ($requiredRoleDefinitions.Length -gt 0) {
                [void] $addedRoleAssignments.Add($assignmentId, @{
                        DisplayName = $assignmentConfig.DisplayName
                        identity    = $identity
                        roles       = $existingRoleAssignments
                    }
                )
            }
        }
        else {
            # Updating role assignment

            # Calculate obsolete role assignments to be removed if needed (rare event) 
            $removedRoleAssignmentList = @()
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
                    $removedRoleAssignmentList += $existingRoleAssignment
                }
            }
            if ($removedRoleAssignmentList.Length -gt 0) {
                Build-RemovedRoleAssignment -assignmentId $assignmentId `
                    -identity $identity `
                    -displayName $displayName `
                    -removedRoleAssignmentList $removedRoleAssignmentList `
                    -removedRoleAssignments $removedRoleAssignments
            }

            # Calculate added role assignments (also rare)
            $addedRoleAssignmentList = @()
            foreach ($requiredRoleDefinition in $requiredRoleDefinitions) {
                foreach ($existingRoleAssignment in $existingRoleAssignments) {
                    $existingScope = $existingRoleAssignment.scope
                    $shortRoleDefinitionId = $existingRoleAssignment.roleDefinitionId.Split('/')[-1]
                    $matchFound = $false
                    if (($requiredRoleDefinition.scope -eq $existingScope) -and ($requiredRoleDefinition.roleDefinitionId -eq $shortRoleDefinitionId)) {
                        $matchFound = $true
                        # Nothing to do
                        break
                    }
                }
                if (!$matchFound) {
                    # add role
                    $addedRoleAssignmentList += $requiredRoleDefinition                
                }
            }
            if ($addedRoleAssignmentList.Length -gt 0) {
                [void] $addedRoleAssignments.Add($assignmentId, @{
                        DisplayName = $assignmentConfig.DisplayName
                        identity    = $identity
                        roles       = $addedRoleAssignmentList
                    }
                )
            }
        }
    }
    $replacingAssignment
}
