function Get-AzPolicyResources {
    [CmdletBinding()]
    param (
        [hashtable] $PacEnvironment,
        [hashtable] $ScopeTable,

        [switch] $SkipRoleAssignments,
        [switch] $SkipExemptions,
        [switch] $CollectRemediations,
        [switch] $CollectAllPolicies
    )

    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    $tenantId = $PacEnvironment.tenantId
    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Get Policy Resources for EPAC environment '$($PacEnvironment.pacSelector)' at root scope $($deploymentRootScope -replace '/providers/Microsoft.Management','')"
    Write-Information "==================================================================================================="
    $prefBackup = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    $policyResources = Search-AzGraphAllItems `
        -Query 'PolicyResources | where (type == "microsoft.authorization/policyassignments") or (type == "microsoft.authorization/policysetdefinitions") or (type == "microsoft.authorization/policydefinitions")' `
        -Scope @{ UseTenantScope = $true } `
        -ProgressItemName "Policy resources"
    $WarningPreference = $prefBackup

    Write-Information ""
    Write-Information "Processing $($policyResources.Count) Policy resources (Policy Assignments, Policy Set and Policy definitionss)"
    $deployed = @{
        policydefinitions            = @{
            all      = @{}
            readOnly = @{}
            managed  = @{}
            excluded = @{}
            custom   = @{}
            counters = @{
                builtIn       = 0
                inherited     = 0
                managedBy     = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
                excluded      = 0
                unMangedScope = 0
            }
        }
        policysetdefinitions         = @{
            all      = @{}
            readOnly = @{}
            managed  = @{}
            excluded = @{}
            custom   = @{}
            counters = @{
                builtIn       = 0
                inherited     = 0
                managedBy     = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
                excluded      = 0
                unMangedScope = 0
            }
        }
        policyassignments            = @{
            all      = @{}
            managed  = @{}
            excluded = @{}
            counters = @{
                managedBy      = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
                excludedScopes = 0
                excluded       = 0
                unMangedScope  = 0
            }
        }
        roleAssignmentsByPrincipalId = @{}
        roleAssignmentsNotRetrieved  = $false
        policyExemptions             = @{
            all      = @{}
            managed  = @{}
            excluded = @{}
            orphaned = @{}
            counters = @{
                managedBy = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
            }
        }
        nonComplianceSummary         = @{}
        remediationTasks             = @{}
    }

    $desiredState = $PacEnvironment.desiredState
    $includeResourceGroups = $desiredState.includeResourceGroups
    $excludedPolicyAssignments = $desiredState.excludedPolicyAssignments

    $policyDefinitionsScopes = $PacEnvironment.policyDefinitionsScopes
    $scopesLength = $policyDefinitionsScopes.Length
    $scopesLast = $scopesLength - 1
    $customPolicyDefinitionScopes = $policyDefinitionsScopes[0..($scopesLast - 1)]
    $globalNotScopes = $PacEnvironment.globalNotScopes
    $excludedScopesRaw = @()
    $excludedScopesRaw += $globalNotScopes
    $excludedScopesRaw += $desiredState.excludedScopes
    if ($excludedScopesRaw.Count -gt 1) {
        $excludedScopesRaw = @() + (Select-Object -InputObject $excludedScopesRaw -Unique)
    }

    $scopeCollection = Build-NotScopes -ScopeTable $ScopeTable -ScopeList $customPolicyDefinitionScopes -NotScopeIn $excludedScopesRaw
    $excludedScopesHashtable = @{}
    foreach ($scope in $scopeCollection) {
        foreach ($notScope in $scope.notScope) {
            $excludedScopesHashtable[$notScope] = $notScope
        }
    }
    $excludedScopes = $excludedScopesHashtable.Keys
    $policyDefinitionsScopes = $PacEnvironment.policyDefinitionsScopes
    $scopesLength = $policyDefinitionsScopes.Length
    $scopesLast = $scopesLength - 1
    $policyAssignmentsTable = $deployed.policyassignments
    $thisPacOwnerId = $PacEnvironment.pacOwnerId
    $uniqueRoleAssignmentScopes = @{
        resources        = @{}
        resourceGroups   = @{}
        subscriptions    = @{}
        managementGroups = @{}
    }
    $uniquePrincipalIds = @{}
    $assignmentsWithIdentity = @{}
    $numberPolicyResourcesProcessed = 0
    foreach ($policyResourceRaw in $policyResources) {
        $thisTenantId = $policyResourceRaw.tenantId
        if ($thisTenantId -in @("", $tenantId)) {
            $policyResource = Get-HashtableShallowClone $policyResourceRaw
            $id = $policyResource.id
            $kind = $policyResource.kind
            $included = $true
            $resourceIdParts = $null
            # Remove-NullFields $policyResource
            if ($kind -eq "policyassignments") {
                $included, $resourceIdParts = Confirm-PolicyResourceExclusions `
                    -TestId $id `
                    -ResourceId $id `
                    -PolicyResource $policyResource `
                    -ScopeTable $ScopeTable `
                    -IncludeResourceGroups $includeResourceGroups `
                    -ExcludedScopes $excludedScopes `
                    -ExcludedIds $excludedPolicyAssignments `
                    -PolicyResourceTable $policyAssignmentsTable
                if ($CollectAllPolicies -or $included) {
                    $scope = $resourceIdParts.scope
                    $policyResource.resourceIdParts = $resourceIdParts
                    $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -Metadata $policyResource.properties.metadata -ManagedByCounters $policyAssignmentsTable.counters.managedBy
                    $null = $policyAssignmentsTable.all.Add($id, $policyResource)
                    $null = $policyAssignmentsTable.managed.Add($id, $policyResource)
                    if ($policyResource.identity -and $policyResource.identity.type -ne "None") {
                        $principalId = ""
                        if ($policyResource.identity.type -eq "SystemAssigned") {
                            $principalId = $policyResource.identity.principalId
                        }
                        else {
                            $userAssignedIdentityId = $policyResource.identity.userAssignedIdentities.PSObject.Properties.Name
                            $principalId = $policyResource.identity.userAssignedIdentities.$userAssignedIdentityId.principalId
                        }
                        Set-UniqueRoleAssignmentScopes `
                            -ScopeId $scope `
                            -UniqueRoleAssignmentScopes $uniqueRoleAssignmentScopes
                        $uniquePrincipalIds[$principalId] = $true
                        if ($policyResource.properties.metadata.roles) {
                            $roles = $policyResource.properties.metadata.roles
                            foreach ($role in $roles) {
                                Set-UniqueRoleAssignmentScopes `
                                    -ScopeId $role.scope `
                                    -UniqueRoleAssignmentScopes $uniqueRoleAssignmentScopes
                            }
                        }
                        $null = $assignmentsWithIdentity.Add($id, $policyResource)
                    }
                }
                else {
                    Write-Debug "Policy resource $id excluded"
                }
            }
            else {
                $deployedPolicyTable = $deployed.$kind
                $found = $false
                $excludedList = $desiredState.excludedPolicyDefinitions
                if ($kind -eq "policysetdefinitions") {
                    $excludedList = $desiredState.excludedPolicySetDefinitions
                }
                $included, $resourceIdParts = Confirm-PolicyResourceExclusions `
                    -TestId $id `
                    -ResourceId $id `
                    -PolicyResource $policyResource `
                    -ScopeTable $ScopeTable `
                    -IncludeResourceGroups $false `
                    -ExcludedScopes $excludedScopes `
                    -ExcludedIds $excludedList `
                    -PolicyResourceTable $deployedPolicyTable
                if ($CollectAllPolicies -or $included) {
                    $policyResource.resourceIdParts = $resourceIdParts
                    $found = $false
                    for ($i = 0; $i -lt $scopesLength -and !$found; $i++) {
                        $currentScopeId = $policyDefinitionsScopes[$i]
                        if ($resourceIdParts.scope -eq $currentScopeId) {
                            switch ($i) {
                                0 {
                                    # deploymentRootScope
                                    $null = $deployedPolicyTable.all.Add($id, $policyResource)
                                    $null = $deployedPolicyTable.managed.Add($id, $policyResource)
                                    $null = $deployedPolicyTable.custom.Add($id, $policyResource)
                                    $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -Metadata $policyResource.properties.metadata -ManagedByCounters $deployedPolicyTable.counters.managedBy
                                    $found = $true
                                }
                                $scopesLast {
                                    # BuiltIn or Static, since last entry in array is empty string ($currentPolicyDefinitionsScopeId)
                                    $null = $deployedPolicyTable.all.Add($id, $policyResource)
                                    $null = $deployedPolicyTable.readOnly.Add($id, $policyResource)
                                    $deployedPolicyTable.counters.builtIn += 1
                                    $found = $true
                                }
                                Default {
                                    # Read only definitions scopes
                                    $null = $deployedPolicyTable.all.Add($id, $policyResource)
                                    $null = $policyDefinitions.readOnly.Add($id, $policyResource)
                                    $null = $deployedPolicyTable.custom.Add($id, $policyResource)
                                    $deployedPolicyTable.counters.inherited += 1
                                    $found = $true
                                }
                            }
                        }
                    }
                    if (!$found) {
                        $deployedPolicyTable.counters.unMangedScope += 1
                        if ($CollectAllPolicies -and $policyResource.properties.policyType -eq "Custom") {
                            $null = $deployedPolicyTable.all.Add($id, $policyResource)
                            $null = $deployedPolicyTable.custom.Add($id, $policyResource)
                        }
                    }
                }
            }
        }
        $numberPolicyResourcesProcessed++
        if ($numberPolicyResourcesProcessed % 1000 -eq 0) {
            Write-Information "Processed $numberPolicyResourcesProcessed Policy resources"
        }
    }
    if ($numberPolicyResourcesProcessed % 1000 -ne 0) {
        Write-Information "Processed $numberPolicyResourcesProcessed Policy resources"
    }

    if (!$SkipRoleAssignments) {
        # Get-AzRoleAssignment from the lowest scopes up. This will reduce the number of calls to Azure
        $roleAssignmentsById = @{}
        $scopesCovered = @{}
        $scopesCollectedCount = 0
        $roleAssignmentsCount = 0
        # Write-Information "    Progress:"
        # individual resources
        Write-Information ""
        Write-Information "Collecting Role assignments (this may take a while):"
        foreach ($scope in $uniqueRoleAssignmentScopes.resources.Keys) {
            if (!$scopesCovered.ContainsKey($scope)) {
                $scopesCovered[$scope] = $true
                $results = @()
                $scopesCollectedCount++
                Write-Information "    $scope"
                $results += Get-AzRoleAssignment -Scope $scope -WarningAction SilentlyContinue
                $localScopesCovered = @{}
                foreach ($result in $results) {
                    if ($result.ObjectType -eq "ServicePrincipal" -and $uniquePrincipalIds.ContainsKey($result.ObjectId)) {
                        $localScopesCovered[$result.Scope] = $true
                        $roleAssignmentsById[$result.RoleAssignmentId] = $result
                        $roleAssignmentsCount++
                    }
                }
                foreach ($localScope in $localScopesCovered.Keys) {
                    $scopesCovered[$localScope] = $true
                }
            }
        }
        # resource groups
        foreach ($scope in $uniqueRoleAssignmentScopes.resourceGroups.Keys) {
            if (!$scopesCovered.ContainsKey($scope)) {
                $scopesCovered[$scope] = $true
                $results = @()
                Write-Information "    $scope"
                $results += Get-AzRoleAssignment -Scope $scope -WarningAction SilentlyContinue
                $scopesCollectedCount++
                $localScopesCovered = @{}
                foreach ($result in $results) {
                    if ($result.ObjectType -eq "ServicePrincipal" -and $uniquePrincipalIds.ContainsKey($result.ObjectId)) {
                        $localScopesCovered[$result.Scope] = $true
                        $roleAssignmentsById[$result.RoleAssignmentId] = $result
                        $roleAssignmentsCount++
                    }
                }
                foreach ($localScope in $localScopesCovered.Keys) {
                    $scopesCovered[$localScope] = $true
                }
            }
        }
        # subscriptions
        foreach ($scope in $uniqueRoleAssignmentScopes.subscriptions.Keys) {
            if (!$scopesCovered.ContainsKey($scope)) {
                $scopesCovered[$scope] = $true
                $results = @()
                Write-Information "    $scope"
                $results += Get-AzRoleAssignment | Where-Object {$_.scope -eq $scope}
                $scopesCollectedCount++
                $localScopesCovered = @{}
                foreach ($result in $results) {
                    if ($result.ObjectType -eq "ServicePrincipal" -and $uniquePrincipalIds.ContainsKey($result.ObjectId)) {
                        $localScopesCovered[$result.Scope] = $true
                        $roleAssignmentsById[$result.RoleAssignmentId] = $result
                        $roleAssignmentsCount++
                    }
                }
                foreach ($localScope in $localScopesCovered.Keys) {
                    $scopesCovered[$localScope] = $true
                }
            }
        }
        # management groups (we are not trying to optimize based on the management group tree structure)
        foreach ($scope in $uniqueRoleAssignmentScopes.managementGroups.Keys) {
            if (!$scopesCovered.ContainsKey($scope)) {
                $scopesCovered[$scope] = $true
                $results = @()
                Write-Information "    $scope"
                $results += Get-AzRoleAssignment -Scope $scope -WarningAction SilentlyContinue
                $scopesCollectedCount++
                $localScopesCovered = @{}
                foreach ($result in $results) {
                    if ($result.ObjectType -eq "ServicePrincipal" -and $uniquePrincipalIds.ContainsKey($result.ObjectId)) {
                        $localScopesCovered[$result.Scope] = $true
                        $roleAssignmentsById[$result.RoleAssignmentId] = $result
                        $roleAssignmentsCount++
                    }
                }
                foreach ($localScope in $localScopesCovered.Keys) {
                    $scopesCovered[$localScope] = $true
                }
            }
        }

        # loop through the collected role assignments to collate by principalId
        $deployedRoleAssignmentsByPrincipalId = $deployed.roleAssignmentsByPrincipalId
        foreach ($roleAssignment in $roleAssignmentsById.Values) {
            $principalId = $roleAssignment.ObjectId
            $normalizedRoleAssignment = @{
                id               = $roleAssignment.RoleAssignmentId
                scope            = $roleAssignment.Scope
                displayName      = $roleAssignment.DisplayName
                objectType       = $roleAssignment.ObjectType
                principalId      = $principalId
                roleDefinitionId = $roleAssignment.RoleDefinitionId
                roleDisplayName  = $roleAssignment.RoleDefinitionName
            }
            if ($deployedRoleAssignmentsByPrincipalId.ContainsKey($principalId)) {
                $normalizedRoleAssignments = $deployedRoleAssignmentsByPrincipalId.$principalId
                $normalizedRoleAssignments += $normalizedRoleAssignment
                $deployedRoleAssignmentsByPrincipalId[$principalId] = $normalizedRoleAssignments
            }
            else {
                $null = $deployedRoleAssignmentsByPrincipalId.Add($principalId, @( $normalizedRoleAssignment ))
            }
        }
    }

    # Collect Exemptions
    if (!$SkipExemptions) {
        $exemptionsProcessed = @{}
        $exemptionsTable = $deployed.policyExemptions
        $managedByCounters = $exemptionsTable.counters.managedBy
        $managedPolicyAssignmentsTable = $policyAssignmentsTable.managed
        $excludedPolicyAssignmentsTable = $policyAssignmentsTable.excluded
        $orphanedResourceTable = @{
            all      = @{}
            managed  = @{}
            excluded = @{}
            orphaned = @{}
            counters = @{
                managedBy = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
            }
        }

        Write-Information ""
        Write-Information "Collecting Policy Exemptions (this may take a while):"
        foreach ($scopeId in $ScopeTable.Keys) {
            $scopeInformation = $ScopeTable.$scopeId
            if ($scopeInformation.type -eq "microsoft.resources/subscriptions") {
                Write-Information "    $scopeId"
                Get-AzPolicyExemptionsAtScopeRestMethod -Scope $scopeId | Sort-Object Properties.PolicyAssignmentId, ResourceId |  ForEach-Object {
                    $exemption = Get-DeepClone $_
                    $id = $exemption.id
                    if (!$exemptionsProcessed.ContainsKey($id)) {
                        # Filter out duplicates in parent Management Groups

                        # Remove-NullFields $exemption
                        $null = $exemptionsProcessed.Add($id, $exemption)

                        # normalize values to az cli representation
                        $properties = $exemption.Properties
                        $description = $properties.Description
                        $displayName = $properties.DisplayName
                        $exemptionCategory = $properties.ExemptionCategory
                        $expiresOn = $properties.ExpiresOn
                        $metadata = $properties.Metadata
                        $name = $exemption.Name
                        $policyAssignmentId = $properties.PolicyAssignmentId
                        $policyDefinitionReferenceIds = $properties.PolicyDefinitionReferenceIds
                        $resourceGroup = $exemption.ResourceGroupName

                        # Find scope
                        $resourceIdParts = Split-AzPolicyResourceId -Id $id
                        $scope = $resourceIdParts.scope

                        $exemption = @{
                            id                 = $id
                            name               = $name
                            scope              = $scope
                            policyAssignmentId = $policyAssignmentId
                            exemptionCategory  = $exemptionCategory
                        }
                        if ($null -ne $displayName -and $displayName -ne "") {
                            $null = $exemption.Add("displayName", $displayName)
                        }
                        if ($null -ne $description -and $description -ne "") {
                            $null = $exemption.Add("description", $description)
                        }
                        if ($null -ne $expiresOn) {
                            $expiresOnUtc = $expiresOn.ToUniversalTime()
                            $null = $exemption.Add("expiresOn", $expiresOnUtc)
                        }
                        if ($null -ne $policyDefinitionReferenceIds -and $policyDefinitionReferenceIds.Count -gt 0) {
                            $null = $exemption.Add("policyDefinitionReferenceIds", $policyDefinitionReferenceIds)
                        }
                        if ($null -ne $metadata -and $metadata -ne @{} ) {
                            $null = $exemption.Add("metadata", $metadata)
                        }
                        if ($null -ne $resourceGroup -and $resourceGroup -ne "") {
                            $null = $exemption.Add("resourceGroup", $resourceGroup)
                        }

                        # What is the context of this exemption; it depends on the assignment being exempted
                        if ($managedPolicyAssignmentsTable.ContainsKey($policyAssignmentId)) {
                            $policyAssignment = $managedPolicyAssignmentsTable.$policyAssignmentId
                            $pacOwner = $policyAssignment.pacOwner
                            $exemption.pacOwner = $pacOwner
                            if ($pacOwner -eq "thisPaC") {
                                $managedByCounters.thisPaC += 1
                            }
                            elseif ($pacOwner -eq "otherPaC") {
                                $managedByCounters.otherPaC += 1
                            }
                            else {
                                $managedByCounters.unknown += 1
                            }
                            $null = $exemptionsTable.managed.Add($id, $exemption)
                            $null = $exemptionsTable.all.Add($id, $exemption)
                        }
                        elseif ($excludedPolicyAssignmentsTable.ContainsKey($policyAssignmentId)) {
                            $policyAssignment = $excludedPolicyAssignmentsTable.$policyAssignmentId
                            if ($CollectAllPolicies) {
                                $pacOwner = $policyAssignment.pacOwner
                                $exemption.pacOwner = $pacOwner
                                if ($pacOwner -eq "thisPaC") {
                                    $managedByCounters.thisPaC += 1
                                }
                                elseif ($pacOwner -eq "otherPaC") {
                                    $managedByCounters.otherPaC += 1
                                }
                                else {
                                    $managedByCounters.unknown += 1
                                }
                            }
                            $null = $exemptionsTable.excluded.Add($id, $exemption)
                        }
                        else {
                            $included, $resourceIdParts = Confirm-PolicyResourceExclusions `
                                -TestId $policyAssignmentId `
                                -ResourceId $id `
                                -PolicyResource $exemption `
                                -ScopeTable $ScopeTable `
                                -IncludeResourceGroups $includeResourceGroups `
                                -ExcludedScopes $excludedScopes `
                                -ExcludedIds $excludedPolicyAssignments `
                                -PolicyResourceTable $orphanedResourceTable

                            # orphaned, do not differentiate
                            if ($included) {
                                $null = $exemptionsTable.orphaned.Add($id, $exemption)
                            }
                        }
                    }
                }
            }
        }
    }

    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Policy Resources found for EPAC environment '$($PacEnvironment.pacSelector)' at root scope $($deploymentRootScope -replace '/providers/Microsoft.Management','')"
    Write-Information "==================================================================================================="

    foreach ($kind in @("policydefinitions", "policysetdefinitions")) {
        $deployedPolicyTable = $deployed.$kind
        $counters = $deployedPolicyTable.counters
        $managedBy = $counters.managedBy
        $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown
        Write-Information ""
        if ($kind -eq "policydefinitions") {
            Write-Information "Policy counts:"
        }
        else {
            Write-Information "Policy Set counts:"
        }
        if ($CollectAllPolicies) {
            Write-Information "    Custom (all)   = $($deployedPolicyTable.all.psbase.Count)"
            Write-Information "    Managed ($($managedByAny)) by:"
            Write-Information "        This PaC   = $($managedBy.thisPaC)"
            Write-Information "        Other PaC  = $($managedBy.otherPaC)"
            Write-Information "        Unknown    = $($managedBy.unknown)"
        }
        else {
            Write-Information "    BuiltIn        = $($counters.builtIn)"
            Write-Information "    Managed ($($managedByAny)) by:"
            Write-Information "        This PaC   = $($managedBy.thisPaC)"
            Write-Information "        Other PaC  = $($managedBy.otherPaC)"
            Write-Information "        Unknown    = $($managedBy.unknown)"
            Write-Information "    Inherited      = $($counters.inherited)"
            Write-Information "    Excluded       = $($counters.excluded)"
            Write-Information "    Not our scopes = $($counters.unMangedScope)"
        }
    }

    $counters = $deployed.policyassignments.counters
    $managedBy = $counters.managedBy
    $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown
    Write-Information ""
    Write-Information "Policy Assignment counts:"
    Write-Information "    Managed ($($managedByAny)) by:"
    Write-Information "        This PaC    = $($managedBy.thisPaC)"
    Write-Information "        Other PaC   = $($managedBy.otherPaC)"
    Write-Information "        Unknown     = $($managedBy.unknown)"
    Write-Information "    With identity   = $($assignmentsWithIdentity.psbase.Count)"
    Write-Information "    Excluded scopes = $($counters.excludedScopes)"
    Write-Information "    Excluded        = $($counters.excluded)"
    Write-Information "    Not our scopes  = $($counters.unMangedScope)"

    if (!$SkipRoleAssignments) {
        Write-Information ""
        if ($scopesCovered.Count -gt 0 -and $deployedRoleAssignmentsByPrincipalId.Count -eq 0) {
            Write-Warning "Role assignment retrieval failed to receive any assignments in $($scopesCovered.Count) scopes. This likely due to a missing permission for the SPN running the pipeline. Please read the pipeline documentation in EPAC. In rare cases, this can happen when a previous role assignment failed." -WarningAction Continue
            $deployed.roleAssignmentsNotRetrieved = $true
        }
        Write-Information "Role Assignments:"
        Write-Information "    Total principalIds     = $($deployedRoleAssignmentsByPrincipalId.Count)"
        Write-Information "    Total Role Assignments = $($roleAssignmentsById.Count)"
        Write-Information "    Total Scopes           = $($scopesCovered.Count)"
    }

    if (!$SkipExemptions) {
        $counters = $exemptionsTable.counters
        $managedBy = $counters.managedBy
        $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown
        Write-Information ""
        Write-Information "Policy Exemptions:"
        Write-Information "    Managed ($($managedByAny)) by:"
        Write-Information "        This PaC    = $($managedBy.thisPaC)"
        Write-Information "        Other PaC   = $($managedBy.otherPaC)"
        Write-Information "        Unknown     = $($managedBy.unknown)"
        Write-Information "    Orphaned   = $($exemptionsTable.orphaned.psbase.Count)"
    }

    return $deployed
}
