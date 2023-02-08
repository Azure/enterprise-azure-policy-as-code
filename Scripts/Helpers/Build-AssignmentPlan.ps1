#Requires -PSEdition Core

function Write-AssignmentDetails {
    [CmdletBinding()]
    param (
        $displayName,
        $scope,
        $prefix
    )

    $shortScope = $scope -replace "/providers/Microsoft.Management", ""
    Write-Information "$($prefix) '$($displayName)' at $($shortScope)"
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
        Write-Information "There aren't any Policy Assignment files in the folder provided!"
    }

    # Cache role definitions
    $roleDefinitionList = Get-AzRoleDefinition
    [hashtable] $roleDefinitions = @{}
    foreach ($roleDefinition in $roleDefinitionList) {
        if (!$roleDefinitions.ContainsKey($roleDefinition.Id)) {
            $null = $roleDefinitions.Add($roleDefinition.Id, $roleDefinition.Name)
        }
    }

    # Convert Policy and PolicySetDefinition to detailed Info
    $combinedPolicyDetails = Convert-PolicySetsToDetails `
        -allPolicyDefinitions $allDefinitions.policydefinitions `
        -allPolicySetDefinitions $allDefinitions.policysetdefinitions

    # Process files
    $deployedPolicyAssignments = $deployedPolicyResources.policyassignments.managed
    $deployedRoleAssignmentsByPrincipalId = $deployedPolicyResources.roleAssignmentsByPrincipalId
    $deleteCandidates = Get-HashtableShallowClone $deployedPolicyAssignments
    foreach ($id  in $deployedPolicyAssignments.Keys) {
        $allAssignments[$id] = $deployedPolicyAssignments.$id
    }

    foreach ($assignmentFile in $assignmentFiles) {
        $Json = Get-Content -Path $assignmentFile.FullName -Raw -ErrorAction Stop
        if ((Test-Json $Json)) {
            Write-Information "Processing file '$($assignmentFile.FullName)'"
        }
        else {
            Write-Error "Assignment JSON file '$($assignmentFile.FullName)' is not valid." -ErrorAction Stop
        }
        $assignmentObject = $Json | ConvertFrom-Json -AsHashtable

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
            parameterSuppressDefaultValues = $false
            hasErrors                      = $false
            hasOnlyNotSelectedEnvironments = $false
            ignoreBranch                   = $false
            managedIdentityLocation        = $pacEnvironment.managedIdentityLocation
            notScope                       = $pacEnvironment.globalNotScopes
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

        foreach ($assignment in $assignmentsList) {

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
                    -existingObj $deployedPolicyAssignmentProperties.notScopes `
                    -definedObj $notScopes
                $parametersMatch = Confirm-AssignmentParametersMatch `
                    -existingParametersObj $deployedPolicyAssignmentProperties.parameters `
                    -definedParametersObj $parameters
                $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                    -existingMetadataObj $deployedPolicyAssignmentProperties.metadata `
                    -definedMetadataObj $metadata
                $enforcementModeMatches = $enforcementMode -eq $deployedPolicyAssignmentProperties.EnforcementMode
                $nonComplianceMessagesMatches = Confirm-ObjectValueEqualityDeep `
                    -existingObj $deployedPolicyAssignmentProperties.nonComplianceMessages `
                    -definedObj $nonComplianceMessages 

                $replace = $replacedDefinition -or $changedPolicyDefinitionId

                $changingRoleAssignments = $false
                $hasExistingIdentity = ($null -ne $deployedPolicyAssignment.identity) -and ($null -ne $deployedPolicyAssignment.identity.principalId)
                $identityRequired = $assignment.ContainsKey("identityRequired") -and $assignment.identityRequired
                $changedIdentityLocation = $false
                $changedIdentity = $false
                if ($hasExistingIdentity -or $identityRequired) {
                    $principalId = $null
                    $deployedRoleAssignments = @()
                    $requiredRoleDefinitions = @()
                    if ($identityRequired) {
                        $requiredRoleDefinitions = $assignment.metadata.roles
                    }
                    if ($hasExistingIdentity) {
                        $principalId = $deployedPolicyAssignment.identity.principalId
                        if ($deployedRoleAssignmentsByPrincipalId.ContainsKey($principalId)) {
                            $deployedRoleAssignments = $deployedRoleAssignmentsByPrincipalId.$principalId
                        }
                    }
                    if (!$replace) {
                        if ($hasExistingIdentity -and $identityRequired) {
                            $changedIdentityLocation = $deployedAssignment.location -ne $managedIdentityLocation
                            $replace = $changedIdentityLocation
                        }
                        else {
                            # adding or removing identity
                            $replace = $true
                            $changedIdentity = $true
                        }
                    }
                    $changingRoleAssignments = Build-AssignmentRoleChanges `
                        -principalIdForAddedRoles ($replace ? $null : $principalId) `
                        -requiredRoleDefinitions $requiredRoleDefinitions `
                        -deployedRoleAssignments $deployedRoleAssignments `
                        -assignment $assignment `
                        -roleAssignments $roleAssignments
                }

                # Check if Policy assignment in Azure is the same as in the JSON file

                $changesStrings = @()
                $match = $displayNameMatches -and $descriptionMatches -and $parametersMatch -and $metadataMatches -and !$changePacOwnerId -and $enforcementModeMatches -and $notScopesMatch -and $nonComplianceMessagesMatches -and !$replace
                if ($match) {
                    # no Assignment properties changed
                    $assignments.numberUnchanged++
                    if ($changingRoleAssignments) {
                        # role assignments for Managed Identity changed - caused by a mangedIdentityLocation changed or a previously failed role assignment failure
                        Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "Update(roles)"
                    }
                    else {
                        # Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "Unchanged"
                    }
                }
                else {
                    # One or more properties have changed
                    if ($replace) {
                        # Assignment must be deleted and recreated (new)
                        if ($changedPolicyDefinitionId) {
                            $changesStrings += "definitionId"
                        }
                        if ($replacedDefinition) {
                            $changesStrings += "replacedDefinition"
                        }
                        if ($changedIdentity) {
                            if ($hasExistingIdentity) {
                                $changesStrings += "removedIdentity"
                            }
                            else {
                                $changesStrings += "addedIdentity"
                            }
                        }
                        if ($changedIdentityLocation) {
                            $changesStrings += "identityLocation"
                        }
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
                    if ($changingRoleAssignments) {
                        $changesStrings += "roles"
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

                    if ($replace) {
                        # Assignment must be deleted and recreated (new)
                        Remove-EmptyFields $assignment
                        $null = $assignments.replace.Add($id, $assignment)
                        $assignments.numberOfChanges++
                        $changesString = $changesStrings -join ","
                        Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "Replace($changesString)"
                    }
                    else {
                        $changesString = $changesStrings -join ","
                        $splatTransformString = $splatTransformStrings -join " "
                        $assignment.splatTransform = $splatTransformString
                        $null = $assignments.update.Add($id, $assignment)
                        $assignments.numberOfChanges++
                        Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "Update($changesString)"
                    }
                }
            }
            else {
                # New Assignment
                # Remove-EmptyFields $assignment
                $null = $assignments.new.Add($id, $assignment)
                $assignments.numberOfChanges++
                $requiredRoleDefinitions = $assignment.metadata.roles
                if ($requiredRoleDefinitions.Length -gt 0) {
                    $null = Build-AssignmentRoleChanges `
                        -requiredRoleDefinitions $requiredRoleDefinitions `
                        -deployedRoleAssignments @() `
                        -assignment $assignment `
                        -roleAssignments $roleAssignments
                }
                Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "New"
            }
        }
    }

    $strategy = $pacEnvironment.desiredState.strategy
    foreach ($id in $deleteCandidates.Keys) {
        $deleteCandidate = $deleteCandidates.$id
        $deleteCandidateProperties = Get-PolicyResourceProperties $deleteCandidate
        $displayName = $deleteCandidateProperties.displayName
        $scope = $deleteCandidateProperties.scope
        $pacOwner = $deleteCandidate.pacOwner
        $shallDelete = Confirm-DeleteForStrategy -pacOwner $pacOwner -strategy $strategy
        if ($shallDelete) {
            # always delete if owned by this Policy as Code solution
            # never delete if owned by another Policy as Code solution
            # if strategy is "full", delete with unknown owner (missing pacOwnerId)
            Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "Delete"
            $splat = @{
                id          = $id
                name        = $deleteCandidate.name
                scopeId     = $scope
                displayName = $deleteCandidateProperties.displayName
            }

            $allAssignments.Remove($id)
            $assignments.delete.Add($id, $splat)
            $assignments.numberOfChanges++
            $hasExistingIdentity = ($null -ne $deleteCandidate.identity) -and ($null -ne $deleteCandidate.identity.principalId)
            if ($hasExistingIdentity) {
                $principalId = $deleteCandidate.identity.principalId
                if ($deployedRoleAssignmentsByPrincipalId.ContainsKey($principalId)) {
                    $deployedRoleAssignments = $deployedRoleAssignmentsByPrincipalId.$principalId
                    $null = Build-AssignmentRoleChanges `
                        -requiredRoleDefinitions @() `
                        -deployedRoleAssignments $deployedRoleAssignments `
                        -assignment $assignment `
                        -roleAssignments $roleAssignments
                }
            }
        }
        else {
            # Write-AssignmentDetails -displayName $displayName -scope $scope -prefix "No delete($pacOwner,$strategy)"
        }
    }

    Write-Information "Number of unchanged Policy Assignments = $($assignments.numberUnchanged)"
    Write-Information ""
}