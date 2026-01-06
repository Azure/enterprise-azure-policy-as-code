function Build-AssignmentPlan {
    [CmdletBinding()]
    param (
        [string] $AssignmentsRootFolder,
        [hashtable] $PacEnvironment,
        [hashtable] $ScopeTable,
        [hashtable] $DeployedPolicyResources,
        [hashtable] $Assignments,
        [hashtable] $RoleAssignments,
        [hashtable] $AllAssignments,
        [hashtable] $ReplaceDefinitions,
        [hashtable] $PolicyRoleIds,
        [hashtable] $CombinedPolicyDetails,
        [hashtable] $DeprecatedHash,
        [string] $DiffGranularity = "summary"
    )

    $generateDiff = ($DiffGranularity -ne "standard")

    Write-ModernSection -Title "Processing Policy Assignments" -Color Blue
    $normalizedFolder = $AssignmentsRootFolder -replace '[\\/]+', [System.IO.Path]::DirectorySeparatorChar
    Write-ModernStatus -Message "Source folder: $normalizedFolder" -Status "info" -Indent 2

    $assignmentFiles = @()
    $assignmentFiles += Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.json"
    $assignmentFiles += Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.jsonc"
    $csvFiles = Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.csv"
    $parameterFilesCsv = @{}
    if ($assignmentFiles.Length -gt 0) {
        Write-ModernStatus -Message "Found $($assignmentFiles.Length) assignment files" -Status "success" -Indent 2
        foreach ($csvFile in $csvFiles) {
            $parameterFilesCsv.Add($csvFile.Name, $csvFile.FullName)
        }
    }
    else {
        Write-Warning "No Policy Assignment files found! Deleting any Policy Assignments."
    }

    # Cache role assignments and definitions
    $deployedPolicyAssignments = $deployedPolicyResources.policyassignments.managed
    $deployedRoleAssignmentsByPrincipalId = $DeployedPolicyResources.roleAssignmentsByPrincipalId
    $deleteCandidates = $deployedPolicyAssignments.Clone()
    $roleDefinitions = $DeployedPolicyResources.roleDefinitions

    # Process each assignment file
    foreach ($assignmentFile in $assignmentFiles) {
        $Json = Get-Content -Path $assignmentFile.FullName -Raw -ErrorAction Stop

        $includedCloudEnvironments = ($Json | ConvertFrom-Json).epacCloudEnvironments
        if ($includedCloudEnvironments) {
            if ($pacEnvironment.cloud -notIn $includedCloudEnvironments) {
                continue
            }
        }

        $assignmentObject = $null
        try {
            $assignmentObject = $Json | ConvertFrom-Json -Depth 100 -AsHashtable
        }
        catch {
            Write-Error "Assignment JSON file '$($assignmentFile.FullName)' is not valid." -ErrorAction Stop
        }
        # Remove-NullFields $assignmentObject

        # Collect all assignment definitions (values)
        $rootAssignmentDefinition = @{
            nodeName                       = "/"
            metadata                       = @{
                assignedBy = $PacEnvironment.deployedBy
            }
            assignment                     = @{
                append      = $false
                name        = ""
                displayName = ""
                description = ""
            }
            enforcementMode                = "Default"
            parameters                     = @{}
            additionalRoleAssignments      = [System.Collections.ArrayList]::new()
            requiredRoleAssignments        = $null
            nonComplianceMessages          = [System.Collections.ArrayList]::new()
            overrides                      = [System.Collections.ArrayList]::new()
            resourceSelectors              = [System.Collections.ArrayList]::new()
            hasErrors                      = $false
            hasOnlyNotSelectedEnvironments = $false
            ignoreBranch                   = $false
            managedIdentityLocation        = $PacEnvironment.managedIdentityLocation
            notScopesList                  = [System.Collections.ArrayList]::new()
            csvRowsValidated               = $false
        }

        $hasErrors, $assignmentsList = Build-AssignmentDefinitionNode `
            -PacEnvironment $PacEnvironment `
            -ScopeTable $ScopeTable `
            -ParameterFilesCsv $parameterFilesCsv `
            -DefinitionNode $assignmentObject `
            -AssignmentDefinition $rootAssignmentDefinition `
            -CombinedPolicyDetails $CombinedPolicyDetails `
            -PolicyRoleIds $PolicyRoleIds `
            -RoleDefinitions $roleDefinitions `
            -DeprecatedHash $DeprecatedHash

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
            $definitionVersion = $assignment.definitionVersion
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
                $definitionVersionMatches = $true
                if ($definitionVersion) {
                    $definitionVersionMatches = $definitionVersion -eq $deployedPolicyAssignmentProperties.definitionVersion
                }
                $displayNameMatches = $displayName -eq $deployedPolicyAssignmentProperties.displayName
                $descriptionMatches = $description -eq $deployedPolicyAssignmentProperties.description
                $notScopesMatch = Confirm-ObjectValueEqualityDeep `
                    $deployedPolicyAssignmentProperties.notScopes `
                    $notScopes
                $paramResult = Confirm-ParametersUsageMatches `
                    -ExistingParametersObj $deployedPolicyAssignmentProperties.parameters `
                    -DefinedParametersObj $parameters `
                    -CompareValueEntryForExistingParametersObj `
                    -GenerateDiff:$generateDiff
                $parametersMatch = $paramResult.match
                $metadataResult = Confirm-MetadataMatches `
                    -ExistingMetadataObj $deployedPolicyAssignmentProperties.metadata `
                    -DefinedMetadataObj $metadata `
                    -GenerateDiff:$generateDiff
                $metadataMatches = $metadataResult.match
                $changePacOwnerId = $metadataResult.changePacOwnerId
                $enforcementModeMatches = $enforcementMode -eq $deployedPolicyAssignmentProperties.enforcementMode
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
                    -Existing $deployedPolicyAssignment `
                    -Assignment $assignment `
                    -ReplacedAssignment ($replacedDefinition -or $changedPolicyDefinitionId) `
                    -DeployedRoleAssignmentsByPrincipalId $deployedRoleAssignmentsByPrincipalId
                if ($identityStatus.requiresRoleChanges) {
                    $null = $RoleAssignments.added.AddRange($identityStatus.added)
                    $null = $RoleAssignments.updated.AddRange($identityStatus.updated)
                    $null = $RoleAssignments.removed.AddRange($identityStatus.removed)
                    $RoleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                }
                if ($identityStatus.isUserAssigned) {
                    $isUserAssignedAny = $true
                }

                # Generate detailed diffs if requested
                if ($generateDiff -and !$match) {
                    $diffArray = @()
                    if (!$displayNameMatches) {
                        $diffArray += New-DiffEntry -Operation "replace" -Path "/displayName" `
                            -Before $deployedPolicyAssignmentProperties.displayName -After $displayName -Classification "core"
                    }
                    if (!$descriptionMatches) {
                        $diffArray += New-DiffEntry -Operation "replace" -Path "/description" `
                            -Before $deployedPolicyAssignmentProperties.description -After $description -Classification "core"
                    }
                    if ($metadataResult.diff) {
                        $diffArray += $metadataResult.diff
                    }
                    if ($paramResult.diff) {
                        $diffArray += $paramResult.diff
                    }
                    if (!$definitionVersionMatches) {
                        $diffArray += New-DiffEntry -Operation "replace" -Path "/definitionVersion" `
                            -Before $deployedPolicyAssignmentProperties.definitionVersion -After $definitionVersion -Classification "core"
                    }
                    if (!$enforcementModeMatches) {
                        $diffArray += New-DiffEntry -Operation "replace" -Path "/enforcementMode" `
                            -Before $deployedPolicyAssignmentProperties.enforcementMode -After $enforcementMode -Classification "core"
                    }
                    if (!$notScopesMatch) {
                        $diffArray += New-DiffEntry -Operation "replace" -Path "/notScopes" `
                            -Before $deployedPolicyAssignmentProperties.notScopes -After $notScopes -Classification "array"
                    }
                    if (!$nonComplianceMessagesMatches) {
                        $diffArray += New-DiffEntry -Operation "replace" -Path "/nonComplianceMessages" `
                            -Before $deployedPolicyAssignmentProperties.nonComplianceMessages -After $nonComplianceMessages -Classification "array"
                    }
                    if (!$overridesMatch) {
                        $diffArray += New-DiffEntry -Operation "replace" -Path "/overrides" `
                            -Before $deployedPolicyAssignmentProperties.overrides -After $overrides -Classification "array"
                    }
                    if (!$resourceSelectorsMatch) {
                        $diffArray += New-DiffEntry -Operation "replace" -Path "/resourceSelectors" `
                            -Before $deployedPolicyAssignmentProperties.resourceSelectors -After $resourceSelectors -Classification "array"
                    }
                    if ($diffArray.Count -gt 0) {
                        $assignment.diff = $diffArray
                    }
                }

                # Check if Policy assignment in Azure is the same as in the JSON file
                $changesStrings = @()
                $match = $displayNameMatches -and $descriptionMatches -and $parametersMatch -and $metadataMatches -and $definitionVersionMatches -and !$changePacOwnerId `
                    -and $enforcementModeMatches -and $notScopesMatch -and $nonComplianceMessagesMatches -and $overridesMatch -and $resourceSelectorsMatch -and !$identityStatus.replaced
                if ($match) {
                    # no Assignment properties changed
                    $Assignments.numberUnchanged++
                    if ($identityStatus.requiresRoleChanges) {
                        # role assignments for Managed Identity changed - caused by a mangedIdentityLocation changed or a previously failed role assignment failure
                        Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "Update($($identityStatus.changedIdentityStrings -join ','))" -IdentityStatus $identityStatus -ScopeTable $ScopeTable
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
                    elseif ($identityStatus.requiresRoleChanges) {
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
                    if (!$definitionVersionMatches) {
                        $changesStrings += "definitionVersion"
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
                    $updateCollection = $Assignments.update
                    $prefixText = "Update($changesString)"
                    if ($identityStatus.replaced) {
                        $prefixText = "Replace($changesString)"
                        $updateCollection = $Assignments.replace
                        # Store replacement reason on assignment for display
                        $assignment | Add-Member -MemberType NoteProperty -Name "replacementReason" -Value $changesStrings -Force
                    }
                    else {
                        # Store change list for updates too
                        $assignment | Add-Member -MemberType NoteProperty -Name "changeList" -Value $changesStrings -Force
                    }
                    if ($Assignments.update.ContainsKey($id) -or $Assignments.replace.ContainsKey($id)) {
                        Write-Error "Duplicate Policy Assignment ID '$id' found in the JSON files." -ErrorAction Stop
                    }
                    $null = $updateCollection.Add($id, $assignment)
                    Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix $prefixText -IdentityStatus $identityStatus -ScopeTable $ScopeTable
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
                    $null = $RoleAssignments.added.AddRange($identityStatus.added)
                    $RoleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                }
                if ($identityStatus.isUserAssigned) {
                    $isUserAssignedAny = $true
                }
                Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "New" -IdentityStatus $identityStatus -ScopeTable $ScopeTable
            }
        }
    }

    $strategy = $PacEnvironment.desiredState.strategy
    $keepDfcSecurityAssignments = $PacEnvironment.desiredState.keepDfcSecurityAssignments
    $keepDfcPlanAssignments = $PacEnvironment.desiredState.keepDfcPlanAssignments
    if ($deleteCandidates.psbase.Count -gt 0) {
        foreach ($id in $deleteCandidates.Keys) {
            $deleteCandidate = $deleteCandidates.$id
            $deleteCandidateProperties = Get-PolicyResourceProperties $deleteCandidate
            $name = $deleteCandidate.name
            $displayName = $deleteCandidateProperties.displayName
            $scope = $deleteCandidateProperties.scope
            $pacOwner = $deleteCandidate.pacOwner
            $shallDelete = Confirm-DeleteForStrategy `
                -PacOwner $pacOwner `
                -Strategy $strategy `
                -KeepDfcSecurityAssignments $keepDfcSecurityAssignments `
                -KeepDfcPlanAssignments $keepDfcPlanAssignments
            # Check if this Policy Assignment type is "SystemHidden" and skip deletion - this seems to be only the case from Microsoft Managed Policies
            if ( $deleteCandidateProperties.assignmentType -eq "SystemHidden") {
                $shallDelete = $false
                # Commented out for now - Check if these are the 2 required MFA Policies and ignore them
                # if ( ($id.split("/"))[-1] -in @("sys.mfa-write", "sys.mfa-delete")) {
                #     $shallDelete = $false
                # }
            }
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
                    $null = $RoleAssignments.removed.AddRange($identityStatus.removed)
                    $RoleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                }
                if ($identityStatus.isUserAssigned) {
                    $isUserAssignedAny = $true
                }
                Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "Delete" -IdentityStatus $identityStatus -ScopeTable $ScopeTable
                $splat = @{
                    id                 = $id
                    name               = $name
                    scope              = $scope
                    scopeId            = $scope
                    displayName        = $displayName
                    policyDefinitionId = $deleteCandidateProperties.policyDefinitionId
                    enforcementMode    = $deleteCandidateProperties.enforcementMode
                    description        = $deleteCandidateProperties.description
                    metadata           = $deleteCandidateProperties.metadata
                    identity           = $deleteCandidateProperties.identity
                    pacOwner           = $pacOwner
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
                            Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete (owned by other PaC):" -IdentityStatus $identityStatus -ScopeTable $ScopeTable
                        }
                    }
                    unknownOwner {
                        if ($VerbosePreference -eq "Continue") {
                            Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete owned by unknown (strategy $strategy):" -IdentityStatus $identityStatus -ScopeTable $ScopeTable
                        }
                    }
                    managedByDfcSecurityPolicies {
                        if ($VerbosePreference -eq "Continue") {
                            Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete (DfC Security Policies):" -IdentityStatus $identityStatus -ScopeTable $ScopeTable
                        }
                    }
                    managedByDfcDefenderPlans {
                        if ($VerbosePreference -eq "Continue") {
                            Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete (DfC Defender Plans):" -IdentityStatus $identityStatus -ScopeTable $ScopeTable
                        }
                    }
                }
            } 
        }
    }

    if ($isUserAssignedAny) {
        Write-ModernStatus -Message "User-assigned Managed Identities detected - EPAC does not manage their role assignments" -Status "warning" -Indent 2
    }
    Write-ModernStatus -Message "Unchanged assignments: $($Assignments.numberUnchanged)" -Status "info" -Indent 2
}
