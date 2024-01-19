function Build-AssignmentPlan {
    [CmdletBinding()]
    param (
        [string] $AssignmentsRootFolder,
        [hashtable] $PacEnvironment,
        [hashtable] $ScopeTable,
        [hashtable] $DeployedPolicyResources,
        [hashtable] $Assignments,
        [hashtable] $RoleAssignments,
        [hashtable] $AllDefinitions,
        [hashtable] $AllAssignments,
        [hashtable] $ReplaceDefinitions,
        [hashtable] $PolicyRoleIds
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy Assignments JSON files in folder '$AssignmentsRootFolder'"
    Write-Information "==================================================================================================="

    # Cache role definitions
    [hashtable] $roleDefinitions = $DeployedPolicyResources.roleDefinitions

    # Populate allAssignments
    $deployedPolicyAssignments = $DeployedPolicyResources.policyassignments.managed
    $deployedRoleAssignmentsByPrincipalId = $DeployedPolicyResources.roleAssignmentsByPrincipalId
    $deleteCandidates = Get-HashtableShallowClone $deployedPolicyAssignments
    foreach ($id  in $deployedPolicyAssignments.Keys) {
        $AllAssignments[$id] = $deployedPolicyAssignments.$id
    }

    if (!(Test-Path $AssignmentsRootFolder -PathType Container)) {
        Write-Warning "Policy Assignments folder 'policyAssignments' not found. Assignments not managed by this EPAC instance."
    }
    else {

        # Convert Policy and PolicySetDefinition to detailed Info
        $combinedPolicyDetails = Convert-PolicySetsToDetails `
            -AllPolicyDefinitions $AllDefinitions.policydefinitions `
            -AllPolicySetDefinitions $AllDefinitions.policysetdefinitions

        $assignmentFiles = @()
        $assignmentFiles += Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.json"
        $assignmentFiles += Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.jsonc"
        $csvFiles = Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.csv"
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

            $includedCloudEnvironments = ($Json | ConvertFrom-Json).epacCloudEnvironments
            if ($includedCloudEnvironments) {
                if ($pacEnvironment.cloud -notIn $includedCloudEnvironments) {
                    continue
                }
            }

            # Write-Information ""
            try {
                $assignmentObject = $Json | ConvertFrom-Json -AsHashtable
            }
            catch {
                Write-Error "Assignment JSON file '$($assignmentFile.FullName)' is not valid." -ErrorAction Stop
            }
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
                managedIdentityLocation        = $PacEnvironment.managedIdentityLocation
                notScope                       = $PacEnvironment.globalNotScopes
                csvRowsValidated               = $false
            }

            $hasErrors, $assignmentsList = Build-AssignmentDefinitionNode `
                -PacEnvironment $PacEnvironment `
                -ScopeTable $ScopeTable `
                -ParameterFilesCsv $parameterFilesCsv `
                -DefinitionNode $assignmentObject `
                -AssignmentDefinition $rootAssignmentDefinition `
                -CombinedPolicyDetails $combinedPolicyDetails `
                -PolicyRoleIds $PolicyRoleIds `
                -RoleDefinitions $roleDefinitions

            if ($hasErrors) {
                Write-Error "Assignment definitions content errors" -ErrorAction Stop
            }

            $isUserAssignedAny = $false
            foreach ($assignment in $assignmentsList) {

                # Remove-NullFields $assignment
                $id = $assignment.id
                $AllAssignments[$id] = $assignment
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

                    $replacedDefinition = $ReplaceDefinitions.ContainsKey($policyDefinitionId)
                    $changedPolicyDefinitionId = $policyDefinitionId -ne $deployedPolicyAssignmentProperties.policyDefinitionId
                    $displayNameMatches = $displayName -eq $deployedPolicyAssignmentProperties.displayName
                    $descriptionMatches = $description -eq $deployedPolicyAssignmentProperties.description
                    $notScopesMatch = Confirm-ObjectValueEqualityDeep `
                        $deployedPolicyAssignmentProperties.notScopes `
                        $notScopes
                    $parametersMatch = Confirm-ParametersUsageMatches `
                        -ExistingParametersObj $deployedPolicyAssignmentProperties.parameters `
                        -DefinedParametersObj $parameters `
                        -CompareValueEntryForExistingParametersObj
                    $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                        -ExistingMetadataObj $deployedPolicyAssignmentProperties.metadata `
                        -DefinedMetadataObj $metadata
                    $enforcementModeMatches = $enforcementMode -eq $deployedPolicyAssignmentProperties.EnforcementMode
                    $nonComplianceMessagesMatches = Confirm-ObjectValueEqualityDeep `
                        $deployedPolicyAssignmentProperties.nonComplianceMessages `
                        $nonComplianceMessages `
                        -HandleRandomOrderArray
                    $overridesMatch = Confirm-ObjectValueEqualityDeep `
                        $deployedPolicyAssignmentProperties.overrides `
                        $overrides `
                        -HandleRandomOrderArray
                    $resourceSelectorsMatch = Confirm-ObjectValueEqualityDeep `
                        $deployedPolicyAssignmentProperties.resourceSelectors `
                        $resourceSelectors `
                        -HandleRandomOrderArray

                    $identityStatus = Build-AssignmentIdentityChanges `
                        -Existing $deployedPolicyAssignment `
                        -Assignment $assignment `
                        -ReplacedAssignment ($replacedDefinition -or $changedPolicyDefinitionId) `
                        -DeployedRoleAssignmentsByPrincipalId $deployedRoleAssignmentsByPrincipalId
                    if ($identityStatus.requiresRoleChanges) {
                        $RoleAssignments.added += ($identityStatus.added)
                        $RoleAssignments.removed += ($identityStatus.removed)
                        $RoleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
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
                        $Assignments.numberUnchanged++
                        if ($identityStatus.requiresRoleChanges) {
                            # role assignments for Managed Identity changed - caused by a mangedIdentityLocation changed or a previously failed role assignment failure
                            Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "Update($($identityStatus.changedIdentityStrings -join ','))" -IdentityStatus $identityStatus
                        }
                        else {
                            # Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "Unchanged" -IdentityStatus $identityStatus
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
                            $null = $Assignments.replace.Add($id, $assignment)
                            Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "Replace($changesString)" -IdentityStatus $identityStatus
                        }
                        else {
                            $null = $Assignments.update.Add($id, $assignment)
                            Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "Update($changesString)" -IdentityStatus $identityStatus
                        }
                        $Assignments.numberOfChanges++
                    }
                }
                else {
                    # New Assignment
                    $null = $Assignments.new.Add($id, $assignment)
                    $Assignments.numberOfChanges++
                    $identityStatus = Build-AssignmentIdentityChanges `
                        -Existing $null `
                        -Assignment $assignment `
                        -ReplacedAssignment $false `
                        -DeployedRoleAssignmentsByPrincipalId $deployedRoleAssignmentsByPrincipalId
                    if ($identityStatus.requiresRoleChanges) {
                        $RoleAssignments.added += ($identityStatus.added)
                        $RoleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                    }
                    if ($identityStatus.isUserAssigned) {
                        $isUserAssignedAny = $true
                    }
                    Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "New" -IdentityStatus $identityStatus
                }
            }
        }

        $strategy = $PacEnvironment.desiredState.strategy
        $keepDfcSecurityAssignments = $PacEnvironment.desiredState.keepDfcSecurityAssignments
        if ($deleteCandidates.psbase.Count -gt 0) {
            foreach ($id in $deleteCandidates.Keys) {
                $deleteCandidate = $deleteCandidates.$id
                $deleteCandidateProperties = Get-PolicyResourceProperties $deleteCandidate
                $name = $deleteCandidate.name
                $displayName = $deleteCandidateProperties.displayName
                $scope = $deleteCandidateProperties.scope
                $pacOwner = $deleteCandidate.pacOwner
                $shallDelete = Confirm-DeleteForStrategy -PacOwner $pacOwner -Strategy $strategy -KeepDfcSecurityAssignments $keepDfcSecurityAssignments
                if ($shallDelete) {
                    # always delete if owned by this Policy as Code solution
                    # never delete if owned by another Policy as Code solution
                    # if strategy is "full", delete with unknown owner (missing pacOwnerId)
                    $identityStatus = Build-AssignmentIdentityChanges `
                        -Existing $deleteCandidate `
                        -Assignment $null `
                        -ReplacedAssignment $false `
                        -DeployedRoleAssignmentsByPrincipalId $deployedRoleAssignmentsByPrincipalId
                    if ($identityStatus.requiresRoleChanges) {
                        $RoleAssignments.removed += ($identityStatus.removed)
                        $RoleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                    }
                    if ($identityStatus.isUserAssigned) {
                        $isUserAssignedAny = $true
                    }
                    Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "Delete" -IdentityStatus $identityStatus
                    $splat = @{
                        id          = $id
                        name        = $name
                        scopeId     = $scope
                        displayName = $displayName
                    }

                    $AllAssignments.Remove($id)
                    $Assignments.delete.Add($id, $splat)
                    $Assignments.numberOfChanges++

                }
                else {
                    $identityStatus = @{
                        requiresRoleChanges    = $false
                        numberOfChanges        = 0
                        added                  = @()
                        removed                = @()
                        changedIdentityStrings = @()
                        replaced               = $false
                        isUserAssigned         = $false
                    }
                    $shortScope = $scope -replace "/providers/Microsoft.Management", ""
                    switch ($pacOwner) {
                        thisPaC { 
                            Write-Error "Policy Assignment '$displayName' at $shortScope owned by this Policy as Code solution should have been deleted." -ErrorAction Stop
                        }
                        otherPaC {
                            if ($VerbosePreference -eq "Continue") {
                                Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete (owened by other PaC):" -IdentityStatus $identityStatus
                            }
                        }
                        unknownOwner {
                            if ($VerbosePreference -eq "Continue") {
                                Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete (strategy $strategy):" -IdentityStatus $identityStatus
                            }
                        }
                        managedByDfcSecurityPolicies {
                            Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete (DfC Security Policies):" -IdentityStatus $identityStatus
                        }
                        managedByDfcDefenderPlans {
                            Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete (DfC Defender Plans):" -IdentityStatus $identityStatus
                        }
                    }
                } 
            }
        }

        if ($isUserAssignedAny) {
            Write-Warning "EPAC does not manage role assignments for Policy Assignments with user-assigned Managed Identities."
        }
        Write-Information "Number of unchanged Policy Assignments = $($Assignments.numberUnchanged)"
    }
    Write-Information ""
}
