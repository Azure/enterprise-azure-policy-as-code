function Get-AzPolicyAssignments {
    [CmdletBinding()]
    param (
        $DeployedPolicyResources,
        $PacEnvironment,
        $ScopeTable,
        $SkipRoleAssignments
    )

    $thisPacOwnerId = $PacEnvironment.pacOwnerId
    $desiredState = $PacEnvironment.desiredState
    $excludedPolicyResources = $desiredState.excludedPolicyAssignments
    $environmentTenantId = $PacEnvironment.tenantId
    $rootScopeDetails = $ScopeTable.root
    $excludedScopesTable = $rootScopeDetails.excludedScopesTable

    $query = "PolicyResources | where type == 'microsoft.authorization/policyassignments'"
    $ProgressItemName = "Policy Assignments"
    $policyResources = Search-AzGraphAllItems -Query $query -ProgressItemName $ProgressItemName

    $policyResourcesTable = $DeployedPolicyResources.policyassignments
    $uniquePrincipalIds = @{}
    foreach ($policyResource in $policyResources) {
        $resourceTenantId = $policyResource.tenantId
        if ($resourceTenantId -in @($null, "", $environmentTenantId)) {
            $id = $policyResource.id
            $testId = $id
            $properties = Get-PolicyResourceProperties $policyResource
            $included = $true
            $resourceIdParts = $null
            $included, $resourceIdParts = Confirm-PolicyResourceExclusions `
                -TestId $testId `
                -ResourceId $id `
                -ScopeTable $ScopeTable `
                -ExcludedScopesTable $excludedScopesTable `
                -ExcludedIds $excludedPolicyResources `
                -PolicyResourceTable $policyResourcesTable
            if ($included) {
                $scope = $resourceIdParts.scope
                $policyResource.resourceIdParts = $resourceIdParts
                $policyResource.scope = $scope
                $policyResource.scopeType = $resourceIdParts.scopeType
                $policyResource.scopeDisplayName = $ScopeTable.$scope.displayName
                if ($policyResource.scopeDisplayName -eq $policyResource.tenantId) {
                    $policyResource.scopeDisplayName = "Tenant Root Group"
                }
                $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -PolicyResource $policyResource -Scope $scope -ManagedByCounters $policyResourcesTable.counters.managedBy
                if ($policyResource.identity -and $policyResource.identity.type -ne "None") {
                    $principalId = ""
                    if ($policyResource.identity.type -eq "SystemAssigned") {
                        $principalId = $policyResource.identity.principalId
                    }
                    else {
                        $principalId = $policyResource.identity.userAssignedIdentities.Values.principalId
                    }
                    $uniquePrincipalIds[$principalId] = $true
                    $policyResourcesTable.counters.withIdentity += 1
                }
                $null = $policyResourcesTable.managed.Add($id, $policyResource)
            }
            else {
                Write-Verbose "Policy Assignment $id excluded"
            }
        }
    }

    if (-not $skipRoleAssignmentsLocal) {
        $DeployedPolicyResources.numberOfPrincipleIds = $uniquePrincipalIds.Count
        $managedRoleAssignmentsByPrincipalId = $DeployedPolicyResources.roleAssignmentsByPrincipalId
        $roleAssignments = [System.Collections.ArrayList]::new()
        $roleDefinitions = [System.Collections.ArrayList]::new()
        $principalIds = '"' + ($uniquePrincipalIds.Keys -join '", "') + '"'
        $ProgressItemName = "Role Assignments"
        if ($PacEnvironment.Cloud -in @("AzureChinaCloud", "AzureUSGovernment")) {
            # if ($PacEnvironment.Cloud -notin @("AzureChinaCloud", "AzureUSGovernment")) {
            # test normal environment
            $roleAssignmentsCount = 0
            $roleAssignmentsLastCount = 0
            $roleAssignmentsProcessed = @{}
            $roleDefinitionsProcessed = @{}
            foreach ($scopeId in $ScopeTable.Keys) {
                $scopeInformation = $ScopeTable.$scopeId
                if ($scopeInformation.type -ne "microsoft.resources/subscriptions/resourceGroups" -and $scopeId -ne "root") {
                    $roleAssignmentsLocal = Get-AzRoleAssignmentsRestMethod -Scope $scopeId -ApiVersion $PacEnvironment.apiVersions.roleAssignments
                    $roleAssignmentsCount += $roleAssignmentsLocal.Count
                    if (($roleAssignmentsLastCount + 10000) -le $roleAssignmentsCount) {
                        Write-Information "Retrieved $roleAssignmentsCount $($ProgressItemName)"
                        $roleAssignmentsLastCount = $roleAssignmentsCount
                    }
                    foreach ($roleAssignment in $roleAssignmentsLocal) {
                        if ($uniquePrincipalIds.ContainsKey($roleAssignment.properties.principalId)) {
                            $id = $roleAssignment.id
                            if (!$roleAssignmentsProcessed.ContainsKey($id)) {
                                $null = $roleAssignmentsProcessed.Add($id, $true)
                                $null = $roleAssignments.Add($roleAssignment)
                            }
                        }
                    }

                }
            }
            if ($roleAssignmentsCount -gt $roleAssignmentsLastCount) {
                Write-Information "Retrieved $roleAssignmentsCount $($ProgressItemName), collected $($roleAssignmentsProcessed.Count) unique $($ProgressItemName)"
            }
            $scopeInformation = $ScopeTable.root
            $scopeId = $scopeInformation.id
            $roleDefinitionsLocal = Get-AzRoleDefinitionsRestMethod -Scope $scopeId -ApiVersion $PacEnvironment.apiVersions.roleAssignments
            $roleDefinitionsCount += $roleDefinitionsLocal.Count
            foreach ($roleDefinition in $roleDefinitionsLocal) {
                $id = $roleDefinition.id
                if ($id.StartsWith("/subscriptions/")) {
                    $possibleScopeId = ($id -split '/', 5)[1..2] -join '/'
                    $subscriptionLevelRoleDefinition = $false
                    foreach ($assignableScope in $roleDefinition.properties.assignableScopes) {
                        if ($assignableScope.StartsWith("$possibleScopeId")) {
                            if (!$roleDefinitionsProcessed.ContainsKey($id)) {
                                $null = $roleDefinitionsProcessed.Add($id, $true)
                                $null = $roleDefinitions.Add($roleDefinition)
                            }
                            $subscriptionLevelRoleDefinition = $true
                            break
                        }
                    }
                    if (-not $subscriptionLevelRoleDefinition) {
                        $id = $id -replace $possibleScopeId, ""
                        $roleDefinition.id = $id
                        if (!$roleDefinitionsProcessed.ContainsKey($id)) {
                            $null = $roleDefinitionsProcessed.Add($id, $true)
                            $null = $roleDefinitions.Add($roleDefinition)
                        }
                    }
                }
                elseif (!$roleDefinitionsProcessed.ContainsKey($id)) {
                    $null = $roleDefinitionsProcessed.Add($id, $true)
                    $null = $roleDefinitions.Add($roleDefinition)
                }
            }
            Write-Information "Retrieved $($roleDefinitionsProcessed.Count) unique Role Definitions"
        }
        else {
            $roleAssignmentsLocal = Search-AzGraphAllItems `
                -Query "authorizationresources | where type == `"microsoft.authorization/roleassignments`" and properties.principalId in ( $principalIds )" `
                -ProgressItemName "Role Assignments" `
                -ProgressIncrement 1000
            $null = $roleAssignments.AddRange($roleAssignmentsLocal)

            $roleDefinitionsLocal = Search-AzGraphAllItems `
                -Query 'authorizationresources | where type == "microsoft.authorization/roledefinitions"' `
                -ProgressItemName "Role Definitions" `
                -ProgressIncrement 1000
            $null = $roleDefinitions.AddRange($roleDefinitionsLocal)
        }
            
        if ($null -ne $PacEnvironment.managingTenantId) {
            foreach ($subscription in $PacEnvironment.managingTenantRootScope) {
                $remoteAssignments = Get-AzRoleAssignmentsRestMethod -Scope $subscription -ApiVersion $PacEnvironment.apiVersions.roleAssignments -Tenant $PacEnvironment.managingTenantId
                foreach ($assignment in $remoteAssignments) {
                    #if the remote assignment is attached to a principal we are looking at then add to the known role assignments object ($roleAssignments)
                    if ($uniquePrincipalIds.ContainsKey($assignment.properties.principalId)) {
                        #Create object with necessary data to normalize
                        $roleAssignmentObj = @{
                            id          = $assignment.id
                            name        = $assignment.name
                            properties  = @{
                                scope            = $assignment.properties.scope
                                principalType    = $assignment.properties.principalType
                                principalId      = $assignment.properties.principalId
                                description      = $assignment.properties.description
                                roleDefinitionId = "/" + ($assignment.properties.roleDefinitionId -split '/', 4)[3] -join '/'
                            }
                            displayName = ""
                            crossTenant = $true
                        }
                        $null = $roleAssignments.Add($roleAssignmentObj)
                        $DeployedPolicyResources.remoteAssignmentsCount += 1
                    }
                }
            }
            Write-Information "Retrieved $($DeployedPolicyResources.remoteAssignmentsCount) remote Role Assignments"  
        }
           
        $roleDefinitionsHt = $DeployedPolicyResources.roleDefinitions
        foreach ($roleDefinition in $roleDefinitions) {
            $roleDefinitionId = $roleDefinition.id
            $roleDefinitionId = $roleDefinition.id
            $roleDefinitionName = $roleDefinition.name
            $roleDefinitionRoleName = $roleDefinition.properties.roleName
            $null = $roleDefinitionsHt.Add($roleDefinitionId, $roleDefinitionRoleName)
            $null = $roleDefinitionsHt.Add($roleDefinitionName, $roleDefinitionRoleName)
        }
            
        # loop through the collected role assignments to collate by principalId
        foreach ($roleAssignment in $roleAssignments) {
            $properties = $roleAssignment.properties
            $principalId = $roleAssignment.properties.principalId
            $roleDefinitionId = $properties.roleDefinitionId
            $roleDefinitionName = ($roleDefinitionId -split '/')[-1]
            $roleDefinitionRoleName = $roleDefinitionName 
            $crossTenant = $roleAssignment.crossTenant
            if ($roleDefinitionsHt.ContainsKey($roleDefinitionId)) {
                $roleDefinitionRoleName = $roleDefinitionsHt.$roleDefinitionId
            }
            elseif ($roleDefinitionId.StartsWith("/subscriptions/")) {
                $subscriptionId = ($roleDefinitionId -split '/')[0..2] -join '/'
                $roleDefinitionId = $roleDefinitionId -replace $subscriptionId, ""
                if ($roleDefinitionsHt.ContainsKey($roleDefinitionId)) {
                    $roleDefinitionRoleName = $roleDefinitionsHt.$roleDefinitionId
                }
                elseif ($roleDefinitionsHt.ContainsKey($roleDefinitionName)) {
                    $roleDefinitionRoleName = $roleDefinitionsHt.$roleDefinitionId
                }
            }
            elseif ($roleDefinitionsHt.ContainsKey($roleDefinitionName)) {
                $roleDefinitionRoleName = $roleDefinitionsHt.$roleDefinitionId
            }
            $normalizedRoleAssignment = @{
                id               = $roleAssignment.id
                name             = $roleAssignment.name
                scope            = $properties.scope
                displayName      = ""
                description      = $properties.description
                objectType       = $properties.principalType
                principalId      = $principalId
                roleDefinitionId = $roleDefinitionId
                roleDisplayName  = $roleDefinitionRoleName
            }            
            if ($crossTenant -eq $true) {
                $normalizedRoleAssignment["crossTenant"] = $true
            }
            $DeployedPolicyResources.numberOfRoleAssignments += 1
            
            $normalizedRoleAssignments = [System.Collections.ArrayList]::new()
            if ($managedRoleAssignmentsByPrincipalId.ContainsKey($principalId)) {
                $normalizedRoleAssignments = $managedRoleAssignmentsByPrincipalId.$principalId
            }
            else {
                $null = $managedRoleAssignmentsByPrincipalId.Add($principalId, $normalizedRoleAssignments)
            }
            $null = $normalizedRoleAssignments.Add($normalizedRoleAssignment)
        }
    }
}

