function Write-AssignmentDetails {
    [CmdletBinding()]
    param (
        $displayName,
        $scope,
        $prefix,
        $identityStatus
    )

    $shortScope = $scope -replace "/providers/Microsoft.Management", ""
    if ($prefix -ne "") {
        Write-Information "  $($prefix) '$($displayName)' at $($shortScope)"
    }
    else {
        Write-Information "  '$($displayName)' at $($shortScope)"
    }
    if ($identityStatus.requiresRoleChanges) {
        foreach ($role in $identityStatus.added) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            Write-Information "    add role $($role.roleDisplayName) at $($roleShortScope)"
        }
        foreach ($role in $identityStatus.removed) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            Write-Information "    remove role $($role.roleDisplayName) at $($roleShortScope)"
        }
    }
}

function Build-AssignmentPlan {
    [CmdletBinding()]
    param (
        [string] $assignmentsRootFolder,
        [hashtable] $pacEnvironment,
        [hashtable] $scopeTable,
        [hashtable] $deployedPolicyResources,
        [hashtable] $assignments,
        [hashtable] $roleAssignments,
        [hashtable] $allDefinitions,
        [hashtable] $allAssignments,
        [hashtable] $replaceDefinitions,
        [hashtable] $policyRoleIds
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy Assignments JSON files in folder '$assignmentsRootFolder'"
    Write-Information "==================================================================================================="
    # Cache role definitions
    $roleDefinitionList = Get-AzRoleDefinition
    [hashtable] $roleDefinitions = @{}
    foreach ($roleDefinition in $roleDefinitionList) {
        if (!$roleDefinitions.ContainsKey($roleDefinition.Id)) {
            $null = $roleDefinitions.Add($roleDefinition.Id, $roleDefinition.Name)
        }
    }

    # Populate allAssignments
    $deployedPolicyAssignments = $deployedPolicyResources.policyassignments.managed
    $deployedRoleAssignmentsByPrincipalId = $deployedPolicyResources.roleAssignmentsByPrincipalId
    $deleteCandidates = Get-HashtableShallowClone $deployedPolicyAssignments
    foreach ($id  in $deployedPolicyAssignments.Keys) {
        $allAssignments[$id] = $deployedPolicyAssignments.$id
    }

    if (!(Test-Path $assignmentsRootFolder -PathType Container)) {
        Write-Warning "Policy Assignments folder 'policyAssignments' not found. Assignments not managed by this EPAC instance."
    }
    else {

        # Convert Policy and PolicySetDefinition to detailed Info
        $combinedPolicyDetails = Convert-PolicySetsToDetails `
            -allPolicyDefinitions $allDefinitions.policydefinitions `
            -allPolicySetDefinitions $allDefinitions.policysetdefinitions

        $assignmentFiles = @()
        $assignmentFiles += Get-ChildItem -Path $assignmentsRootFolder -Recurse -File -Filter "*.json"
        $assignmentFiles += Get-ChildItem -Path $assignmentsRootFolder -Recurse -File -Filter "*.jsonc"
        $csvFiles = Get-ChildItem -Path $assignmentsRootFolder -Recurse -File -Filter "*.csv"
        $parameterFilesCsv = @{}
        if ($assignmentFiles.Length -gt 0) {
            Write-Information "Number of Policy Assignment files = $($assignmentFiles.Length)"
            foreach ($csvFile in $csvFiles) {
                $parameterFilesCsv.Add($csvFile.Name, $csvFile.FullName)
            }
        }
        else {
            Write-Warning "No Policy Assignment files found! Deleting any Policy Assignments."
        }

        # Process each assignment file
        foreach ($assignmentFile in $assignmentFiles) {
            $Json = Get-Content -Path $assignmentFile.FullName -Raw -ErrorAction Stop
            Write-Information ""
            if ((Test-Json $Json)) {
                Write-Information "Processing file '$($assignmentFile.FullName)'"
            }
            else {
                Write-Error "Assignment JSON file '$($assignmentFile.FullName)' is not valid." -ErrorAction Stop
            }
            $assignmentObject = $Json | ConvertFrom-Json -AsHashtable
            # Remove-NullFields $assignmentObject

            # Collect all assignment definitions (values)
            $rootAssignmentDefinition = @{
                nodeName                       = "/"
                assignment                     = @{
                    append      = $false
                    name        = ""
                    displayName = ""
                    description = ""
                }
                enforcementMode                = "Default"
                parameters                     = @{}
                additionalRoleAssignments      = @()
                nonComplianceMessages          = @()
                overrides                      = @()
                resourceSelectors              = @()
                hasErrors                      = $false
                hasOnlyNotSelectedEnvironments = $false
                ignoreBranch                   = $false
                managedIdentityLocation        = $pacEnvironment.managedIdentityLocation
                notScope                       = $pacEnvironment.globalNotScopes
                csvRowsValidated               = $false
            }

            $hasErrors, $assignmentsList = Build-AssignmentDefinitionNode `
                -pacEnvironment $pacEnvironment `
                -scopeTable $scopeTable `
                -parameterFilesCsv $parameterFilesCsv `
                -definitionNode $assignmentObject `
                -assignmentDefinition $rootAssignmentDefinition `
                -combinedPolicyDetails $combinedPolicyDetails `
                -policyRoleIds $policyRoleIds

            if ($hasErrors) {
                Write-Error "Assignment definitions content errors" -ErrorAction Stop
            }

            $isUserAssignedAny = $false
            foreach ($assignment in $assignmentsList) {

                # Remove-NullFields $assignment
                $id = $assignment.id
                $allAssignments[$id] = $assignment
                $displayName = $assignment.displayName
                $description = $assignment.description
                $metadata = $assignment.metadata
                $parameters = $assignment.parameters
                $policyDefinitionId = $assignment.policyDefinitionId
                $scope = $assignment.scope
                $notScopes = $assignment.notScopes
                $enforcementMode = $assignment.enforcementMode
                $nonComplianceMessages = $assignment.nonComplianceMessages
                $overrides = $assignment.overrides
                $resourceSelectors = $assignment.resourceSelectors
                if ($deployedPolicyAssignments.ContainsKey($id)) {
                    # Update and replace scenarios
                    $deployedPolicyAssignment = $deployedPolicyAssignments[$id]
                    $deployedPolicyAssignmentProperties = Get-PolicyResourceProperties $deployedPolicyAssignment
                    $deleteCandidates.Remove($id) # do not delete

                    $replacedDefinition = $replaceDefinitions.ContainsKey($policyDefinitionId)
                    $changedPolicyDefinitionId = $policyDefinitionId -ne $deployedPolicyAssignmentProperties.policyDefinitionId
                    $displayNameMatches = $displayName -eq $deployedPolicyAssignmentProperties.displayName
                    $descriptionMatches = $description -eq $deployedPolicyAssignmentProperties.description
                    $notScopesMatch = Confirm-ObjectValueEqualityDeep `
                        $deployedPolicyAssignmentProperties.notScopes `
                        $notScopes
                    $parametersMatch = Confirm-AssignmentParametersMatch `
                        -existingParametersObj $deployedPolicyAssignmentProperties.parameters `
                        -definedParametersObj $parameters
                    $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                        -existingMetadataObj $deployedPolicyAssignmentProperties.metadata `
                        -definedMetadataObj $metadata
                    $enforcementModeMatches = $enforcementMode -eq $deployedPolicyAssignmentProperties.EnforcementMode
                    $nonComplianceMessagesMatches = Confirm-ObjectValueEqualityDeep `
                        $deployedPolicyAssignmentProperties.nonComplianceMessages `
                        $nonComplianceMessages
                    $overridesMatch = Confirm-ObjectValueEqualityDeep `
                        $deployedPolicyAssignmentProperties.overrides `
                        $overrides
                    $resourceSelectorsMatch = Confirm-ObjectValueEqualityDeep `
                        $deployedPolicyAssignmentProperties.resourceSelectors `
                        $resourceSelectors

                    $identityStatus = Build-AssignmentIdentityChanges `
                        -existing $deployedPolicyAssignment `
                        -assignment $assignment `
                        -replacedAssignment ($replacedDefinition -or $changedPolicyDefinitionId) `
                        -deployedRoleAssignmentsByPrincipalId $deployedRoleAssignmentsByPrincipalId
                    if ($identityStatus.requiresRoleChanges) {
                        $roleAssignments.added += ($identityStatus.added)
                        $roleAssignments.removed += ($identityStatus.removed)
                        $roleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                    }
                    if ($identityStatus.isUserAssigned) {
                        $isUserAssignedAny = $true
                    }

                    # Check if Policy assignment in Azure is the same as in the JSON file

                    $changesStrings = @()
                    $match = $displayNameMatches -and $descriptionMatches -and $parametersMatch -and $metadataMatches -and !$changePacOwnerId `
                        -and $enforcementModeMatches -and $notScopesMatch -and $nonComplianceMessagesMatches -and $overridesMatch -and $resourceSelectorsMatch -and !$identityStatus.replaced
                    if ($match) {
                        # no Assignment properties changed
                        $assignments.numberUnchanged++
                        if ($identityStatus.requiresRoleChanges) {
                            # role assignments for Managed Identity changed - caused by a mangedIdentityLocation changed or a previously failed role assignment failure
                            Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "Update($($identityStatus.changedIdentityStrings))" -identityStatus $identityStatus
                        }
                        else {
                            Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "Unchanged" -identityStatus $identityStatus
                        }
                    }
                    else {
                        # One or more properties have changed
                        if ($identityStatus.replaced) {
                            # Assignment must be deleted and recreated (new)
                            if ($changedPolicyDefinitionId) {
                                $changesStrings += "definitionId"
                            }
                            if ($replacedDefinition) {
                                $changesStrings += "replacedDefinition"
                            }
                            $changesStrings += ($identityStatus.changedIdentityStrings)
                        }

                        if (!$displayNameMatches) {
                            $changesStrings += "displayName"
                        }
                        if (!$descriptionMatches) {
                            $changesStrings += "description"
                        }
                        if ($changePacOwnerId) {
                            $changesStrings += "owner"
                        }
                        if (!$metadataMatches) {
                            $changesStrings += "metadata"
                        }
                        if (!$parametersMatch) {
                            $changesStrings += "parameters"
                        }
                        if (!$enforcementModeMatches) {
                            $changesStrings += "enforcementMode"
                        }
                        if (!$notScopesMatch) {
                            $changesStrings += "notScopes"
                        }
                        if (!$nonComplianceMessagesMatches) {
                            $changesStrings += "nonComplianceMessages"
                        }
                        if (!$overridesMatch) {
                            $changesStrings += "overrides"
                        }
                        if (!$resourceSelectorsMatch) {
                            $changesStrings += "resourceSelectors"
                        }

                        $changesString = $changesStrings -join ","
                        if ($identityStatus.replaced) {
                            # Assignment must be deleted and recreated (new)
                            $null = $assignments.replace.Add($id, $assignment)
                            Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "Replace($changesString)" -identityStatus $identityStatus
                        }
                        else {
                            $null = $assignments.update.Add($id, $assignment)
                            Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "Update($changesString)" -identityStatus $identityStatus
                        }
                        $assignments.numberOfChanges++
                    }
                }
                else {
                    # New Assignment
                    $null = $assignments.new.Add($id, $assignment)
                    $assignments.numberOfChanges++
                    $identityStatus = Build-AssignmentIdentityChanges `
                        -existing $null `
                        -assignment $assignment `
                        -replacedAssignment $false `
                        -deployedRoleAssignmentsByPrincipalId $deployedRoleAssignmentsByPrincipalId
                    if ($identityStatus.requiresRoleChanges) {
                        $roleAssignments.added += ($identityStatus.added)
                        $roleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                    }
                    if ($identityStatus.isUserAssigned) {
                        $isUserAssignedAny = $true
                    }
                    Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "New" -identityStatus $identityStatus
                }
            }
        }

        $strategy = $pacEnvironment.desiredState.strategy
        if ($deleteCandidates.psbase.Count -gt 0) {
            Write-Information "Cleanup removed Policy Assignments (delete)"
            foreach ($id in $deleteCandidates.Keys) {
                $deleteCandidate = $deleteCandidates.$id
                $deleteCandidateProperties = Get-PolicyResourceProperties $deleteCandidate
                $name = $deleteCandidate.name
                $displayName = $deleteCandidateProperties.displayName
                $scope = $deleteCandidateProperties.scope
                $pacOwner = $deleteCandidate.pacOwner
                $shallDelete = Confirm-DeleteForStrategy -pacOwner $pacOwner -strategy $strategy
                if ($shallDelete) {
                    # always delete if owned by this Policy as Code solution
                    # never delete if owned by another Policy as Code solution
                    # if strategy is "full", delete with unknown owner (missing pacOwnerId)
                    $identityStatus = Build-AssignmentIdentityChanges `
                        -existing $deleteCandidate `
                        -assignment $null `
                        -replacedAssignment $false `
                        -deployedRoleAssignmentsByPrincipalId $deployedRoleAssignmentsByPrincipalId
                    if ($identityStatus.requiresRoleChanges) {
                        $roleAssignments.removed += ($identityStatus.removed)
                        $roleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                    }
                    if ($identityStatus.isUserAssigned) {
                        $isUserAssignedAny = $true
                    }
                    Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "" -identityStatus $identityStatus
                    $splat = @{
                        id          = $id
                        name        = $name
                        scopeId     = $scope
                        displayName = $displayName
                    }

                    $allAssignments.Remove($id)
                    $assignments.delete.Add($id, $splat)
                    $assignments.numberOfChanges++

                }
                else {
                    Write-AssignmentDetails -displayName $name -scope $scope -prefix "Desired State($pacOwner,$strategy) - no delete" -identityStatus $identityStatus
                }
            }
        }

        Write-Information ""
        if ($isUserAssignedAny) {
            Write-Warning "EPAC does not manage role assignments for Policy Assignments with user-assigned Managed Identities."
        }
        Write-Information "Number of unchanged Policy Assignments = $($assignments.numberUnchanged)"
    }
    Write-Information ""
}
