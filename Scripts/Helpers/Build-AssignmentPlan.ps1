function Write-AssignmentDetails {
    [CmdletBinding()]
    param (
        $DisplayName,
        $Scope,
        $Prefix,
        $IdentityStatus
    )

    $shortScope = $Scope -replace "/providers/Microsoft.Management", ""
    if ($Prefix -ne "") {
        Write-Information "  $($Prefix) '$($DisplayName)' at $($shortScope)"
    }
    else {
        Write-Information "  '$($DisplayName)' at $($shortScope)"
    }
    if ($IdentityStatus.requiresRoleChanges) {
        foreach ($role in $IdentityStatus.added) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            Write-Information "    add role $($role.roleDisplayName) at $($roleShortScope)"
        }
        foreach ($role in $IdentityStatus.removed) {
            $roleScope = $role.scope
            $roleShortScope = $roleScope -replace "/providers/Microsoft.Management", ""
            Write-Information "    remove role $($role.roleDisplayName) at $($roleShortScope)"
        }
    }
}

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
    $roleDefinitionList = Get-AzRoleDefinition
    [hashtable] $roleDefinitions = @{}
    foreach ($roleDefinition in $roleDefinitionList) {
        if (!$roleDefinitions.ContainsKey($roleDefinition.Id)) {
            $null = $roleDefinitions.Add($roleDefinition.Id, $roleDefinition.Name)
        }
    }

    # Populate allAssignments
    $deployedPolicyAssignments = $DeployedPolicyResources.policyassignments.managed
    $DeployedRoleAssignmentsByPrincipalId = $DeployedPolicyResources.roleAssignmentsByPrincipalId
    $deleteCandidates = Get-HashtableShallowClone $deployedPolicyAssignments
    foreach ($Id  in $deployedPolicyAssignments.Keys) {
        $AllAssignments[$Id] = $deployedPolicyAssignments.$Id
    }

    if (!(Test-Path $AssignmentsRootFolder -PathType Container)) {
        Write-Warning "Policy Assignments folder 'policyAssignments' not found. Assignments not managed by this EPAC instance."
    }
    else {

        # Convert Policy and PolicySetDefinition to detailed Info
        $CombinedPolicyDetails = Convert-PolicySetsToDetails `
            -AllPolicyDefinitions $AllDefinitions.policydefinitions `
            -AllPolicySetDefinitions $AllDefinitions.policysetdefinitions

        $AssignmentFiles = @()
        $AssignmentFiles += Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.json"
        $AssignmentFiles += Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.jsonc"
        $csvFiles = Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.csv"
        $ParameterFilesCsv = @{}
        if ($AssignmentFiles.Length -gt 0) {
            Write-Information "Number of Policy Assignment files = $($AssignmentFiles.Length)"
            foreach ($csvFile in $csvFiles) {
                $ParameterFilesCsv.Add($csvFile.Name, $csvFile.FullName)
            }
        }
        else {
            Write-Warning "No Policy Assignment files found! Deleting any Policy Assignments."
        }

        # Process each assignment file
        foreach ($AssignmentFile in $AssignmentFiles) {
            $Json = Get-Content -Path $AssignmentFile.FullName -Raw -ErrorAction Stop
            Write-Information ""
            if ((Test-Json $Json)) {
                Write-Information "Processing file '$($AssignmentFile.FullName)'"
            }
            else {
                Write-Error "Assignment JSON file '$($AssignmentFile.FullName)' is not valid." -ErrorAction Stop
            }
            $AssignmentObject = $Json | ConvertFrom-Json -AsHashtable
            # Remove-NullFields $AssignmentObject

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

            $hasErrors, $AssignmentsList = Build-AssignmentDefinitionNode `
                -PacEnvironment $PacEnvironment `
                -ScopeTable $ScopeTable `
                -ParameterFilesCsv $ParameterFilesCsv `
                -DefinitionNode $AssignmentObject `
                -AssignmentDefinition $rootAssignmentDefinition `
                -CombinedPolicyDetails $CombinedPolicyDetails `
                -PolicyRoleIds $PolicyRoleIds

            if ($hasErrors) {
                Write-Error "Assignment definitions content errors" -ErrorAction Stop
            }

            $isUserAssignedAny = $false
            foreach ($Assignment in $AssignmentsList) {

                # Remove-NullFields $Assignment
                $Id = $Assignment.id
                $AllAssignments[$Id] = $Assignment
                $DisplayName = $Assignment.displayName
                $description = $Assignment.description
                $Metadata = $Assignment.metadata
                $Parameters = $Assignment.parameters
                $PolicyDefinitionId = $Assignment.policyDefinitionId
                $Scope = $Assignment.scope
                $NotScopes = $Assignment.notScopes
                $enforcementMode = $Assignment.enforcementMode
                $nonComplianceMessages = $Assignment.nonComplianceMessages
                $overrides = $Assignment.overrides
                $resourceSelectors = $Assignment.resourceSelectors
                if ($deployedPolicyAssignments.ContainsKey($Id)) {
                    # Update and replace scenarios
                    $deployedPolicyAssignment = $deployedPolicyAssignments[$Id]
                    $deployedPolicyAssignmentProperties = Get-PolicyResourceProperties $deployedPolicyAssignment
                    $deleteCandidates.Remove($Id) # do not delete

                    $replacedDefinition = $ReplaceDefinitions.ContainsKey($PolicyDefinitionId)
                    $changedPolicyDefinitionId = $PolicyDefinitionId -ne $deployedPolicyAssignmentProperties.policyDefinitionId
                    $DisplayNameMatches = $DisplayName -eq $deployedPolicyAssignmentProperties.displayName
                    $descriptionMatches = $description -eq $deployedPolicyAssignmentProperties.description
                    $NotScopesMatch = Confirm-ObjectValueEqualityDeep `
                        $deployedPolicyAssignmentProperties.notScopes `
                        $NotScopes
                    $ParametersMatch = Confirm-AssignmentParametersMatch `
                        -ExistingParametersObj $deployedPolicyAssignmentProperties.parameters `
                        -DefinedParametersObj $Parameters
                    $MetadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                        -ExistingMetadataObj $deployedPolicyAssignmentProperties.metadata `
                        -DefinedMetadataObj $Metadata
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

                    $IdentityStatus = Build-AssignmentIdentityChanges `
                        -Existing $deployedPolicyAssignment `
                        -Assignment $Assignment `
                        -ReplacedAssignment ($replacedDefinition -or $changedPolicyDefinitionId) `
                        -DeployedRoleAssignmentsByPrincipalId $DeployedRoleAssignmentsByPrincipalId
                    if ($IdentityStatus.requiresRoleChanges) {
                        $RoleAssignments.added += ($IdentityStatus.added)
                        $RoleAssignments.removed += ($IdentityStatus.removed)
                        $RoleAssignments.numberOfChanges += ($IdentityStatus.numberOfChanges)
                    }
                    if ($IdentityStatus.isUserAssigned) {
                        $isUserAssignedAny = $true
                    }

                    # Check if Policy assignment in Azure is the same as in the JSON file

                    $changesStrings = @()
                    $match = $DisplayNameMatches -and $descriptionMatches -and $ParametersMatch -and $MetadataMatches -and !$changePacOwnerId `
                        -and $enforcementModeMatches -and $NotScopesMatch -and $nonComplianceMessagesMatches -and $overridesMatch -and $resourceSelectorsMatch -and !$IdentityStatus.replaced
                    if ($match) {
                        # no Assignment properties changed
                        $Assignments.numberUnchanged++
                        if ($IdentityStatus.requiresRoleChanges) {
                            # role assignments for Managed Identity changed - caused by a mangedIdentityLocation changed or a previously failed role assignment failure
                            Write-AssignmentDetails -DisplayName $DisplayName -Scope $Scope -Prefix "Update($($IdentityStatus.changedIdentityStrings))" -IdentityStatus $IdentityStatus
                        }
                        else {
                            Write-AssignmentDetails -DisplayName $DisplayName -Scope $Scope -Prefix "Unchanged" -IdentityStatus $IdentityStatus
                        }
                    }
                    else {
                        # One or more properties have changed
                        if ($IdentityStatus.replaced) {
                            # Assignment must be deleted and recreated (new)
                            if ($changedPolicyDefinitionId) {
                                $changesStrings += "definitionId"
                            }
                            if ($replacedDefinition) {
                                $changesStrings += "replacedDefinition"
                            }
                            $changesStrings += ($IdentityStatus.changedIdentityStrings)
                        }

                        if (!$DisplayNameMatches) {
                            $changesStrings += "displayName"
                        }
                        if (!$descriptionMatches) {
                            $changesStrings += "description"
                        }
                        if ($changePacOwnerId) {
                            $changesStrings += "owner"
                        }
                        if (!$MetadataMatches) {
                            $changesStrings += "metadata"
                        }
                        if (!$ParametersMatch) {
                            $changesStrings += "parameters"
                        }
                        if (!$enforcementModeMatches) {
                            $changesStrings += "enforcementMode"
                        }
                        if (!$NotScopesMatch) {
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
                        if ($IdentityStatus.replaced) {
                            # Assignment must be deleted and recreated (new)
                            $null = $Assignments.replace.Add($Id, $Assignment)
                            Write-AssignmentDetails -DisplayName $DisplayName -Scope $Scope -Prefix "Replace($changesString)" -IdentityStatus $IdentityStatus
                        }
                        else {
                            $null = $Assignments.update.Add($Id, $Assignment)
                            Write-AssignmentDetails -DisplayName $DisplayName -Scope $Scope -Prefix "Update($changesString)" -IdentityStatus $IdentityStatus
                        }
                        $Assignments.numberOfChanges++
                    }
                }
                else {
                    # New Assignment
                    $null = $Assignments.new.Add($Id, $Assignment)
                    $Assignments.numberOfChanges++
                    $IdentityStatus = Build-AssignmentIdentityChanges `
                        -Existing $null `
                        -Assignment $Assignment `
                        -ReplacedAssignment $false `
                        -DeployedRoleAssignmentsByPrincipalId $DeployedRoleAssignmentsByPrincipalId
                    if ($IdentityStatus.requiresRoleChanges) {
                        $RoleAssignments.added += ($IdentityStatus.added)
                        $RoleAssignments.numberOfChanges += ($IdentityStatus.numberOfChanges)
                    }
                    if ($IdentityStatus.isUserAssigned) {
                        $isUserAssignedAny = $true
                    }
                    Write-AssignmentDetails -DisplayName $DisplayName -Scope $Scope -Prefix "New" -IdentityStatus $IdentityStatus
                }
            }
        }

        $Strategy = $PacEnvironment.desiredState.strategy
        if ($deleteCandidates.psbase.Count -gt 0) {
            Write-Information "Cleanup removed Policy Assignments (delete)"
            foreach ($Id in $deleteCandidates.Keys) {
                $deleteCandidate = $deleteCandidates.$Id
                $deleteCandidateProperties = Get-PolicyResourceProperties $deleteCandidate
                $Name = $deleteCandidate.name
                $DisplayName = $deleteCandidateProperties.displayName
                $Scope = $deleteCandidateProperties.scope
                $PacOwner = $deleteCandidate.pacOwner
                $shallDelete = Confirm-DeleteForStrategy -PacOwner $PacOwner -Strategy $Strategy
                if ($shallDelete) {
                    # always delete if owned by this Policy as Code solution
                    # never delete if owned by another Policy as Code solution
                    # if strategy is "full", delete with unknown owner (missing pacOwnerId)
                    $IdentityStatus = Build-AssignmentIdentityChanges `
                        -Existing $deleteCandidate `
                        -Assignment $null `
                        -ReplacedAssignment $false `
                        -DeployedRoleAssignmentsByPrincipalId $DeployedRoleAssignmentsByPrincipalId
                    if ($IdentityStatus.requiresRoleChanges) {
                        $RoleAssignments.removed += ($IdentityStatus.removed)
                        $RoleAssignments.numberOfChanges += ($IdentityStatus.numberOfChanges)
                    }
                    if ($IdentityStatus.isUserAssigned) {
                        $isUserAssignedAny = $true
                    }
                    Write-AssignmentDetails -DisplayName $DisplayName -Scope $Scope -Prefix "" -IdentityStatus $IdentityStatus
                    $Splat = @{
                        id          = $Id
                        name        = $Name
                        scopeId     = $Scope
                        displayName = $DisplayName
                    }

                    $AllAssignments.Remove($Id)
                    $Assignments.delete.Add($Id, $Splat)
                    $Assignments.numberOfChanges++

                }
                else {
                    Write-AssignmentDetails -DisplayName $Name -Scope $Scope -Prefix "Desired State($PacOwner,$Strategy) - no delete" -IdentityStatus $IdentityStatus
                }
            }
        }

        Write-Information ""
        if ($isUserAssignedAny) {
            Write-Warning "EPAC does not manage role assignments for Policy Assignments with user-assigned Managed Identities."
        }
        Write-Information "Number of unchanged Policy Assignments = $($Assignments.numberUnchanged)"
    }
    Write-Information ""
}
