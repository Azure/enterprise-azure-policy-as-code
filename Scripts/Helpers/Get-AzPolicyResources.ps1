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
        -ProgressItemName "Policy definitions, Policy Set definitions, and Policy Assignments"
    $WarningPreference = $prefBackup

    $deployed = @{
        policydefinitions            = @{
            all      = @{}
            readOnly = @{}
            managed  = @{}
            counters = @{
                builtIn         = 0
                inherited       = 0
                managedBy       = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
                excluded        = 0
                unmanagedScopes = 0
            }
        }
        policysetdefinitions         = @{
            all      = @{}
            readOnly = @{}
            managed  = @{}
            counters = @{
                builtIn         = 0
                inherited       = 0
                managedBy       = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
                excluded        = 0
                unmanagedScopes = 0
            }
        }
        policyassignments            = @{
            managed  = @{}
            counters = @{
                managedBy       = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
                excluded        = 0
                unmanagedScopes = 0
            }
        }
        policyExemptions             = @{
            managed  = @{}
            counters = @{
                managedBy       = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                    orphaned = 0
                }
                excluded        = 0
                unmanagedScopes = 0
            }
        }
        roleAssignmentsByPrincipalId = @{}
        roleAssignmentsNotRetrieved  = $false
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
        $excludedScopesRaw = @() + (Sort-Object -InputObject $excludedScopesRaw -Unique)
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
            if ($kind -eq "policyassignments") {
                $included, $resourceIdParts = Confirm-PolicyResourceExclusions `
                    -TestId $id `
                    -ResourceId $id `
                    -ScopeTable $ScopeTable `
                    -IncludeResourceGroups $includeResourceGroups `
                    -ExcludedScopes $excludedScopes `
                    -ExcludedIds $excludedPolicyAssignments `
                    -PolicyResourceTable $policyAssignmentsTable
                if ($included) {
                    $scope = $resourceIdParts.scope
                    $policyResource.resourceIdParts = $resourceIdParts
                    $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -Metadata $policyResource.properties.metadata -ManagedByCounters $policyAssignmentsTable.counters.managedBy
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
                    Write-Verbose "Policy resource $id excluded"
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
                    -ScopeTable $ScopeTable `
                    -IncludeResourceGroups $false `
                    -ExcludedScopes $excludedScopes `
                    -ExcludedIds $excludedList `
                    -PolicyResourceTable $deployedPolicyTable
                if ($included) {
                    $policyResource.resourceIdParts = $resourceIdParts
                    $found = $false
                    for ($i = 0; $i -lt $scopesLength -and !$found; $i++) {
                        $currentScopeId = $policyDefinitionsScopes[$i]
                        if ($resourceIdParts.scope -eq $currentScopeId) {
                            switch ($i) {
                                0 {
                                    # deploymentRootScope
                                    $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -Metadata $policyResource.properties.metadata -ManagedByCounters $deployedPolicyTable.counters.managedBy
                                    $null = $deployedPolicyTable.all.Add($id, $policyResource)
                                    $null = $deployedPolicyTable.managed.Add($id, $policyResource)
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
                                    $null = $deployedPolicyTable.readOnly.Add($id, $policyResource)
                                    $deployedPolicyTable.counters.inherited += 1
                                    $found = $true
                                }
                            }
                        }
                    }
                    if (!$found) {
                        if ($CollectAllPolicies) {
                            $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -Metadata $policyResource.properties.metadata -ManagedByCounters $deployedPolicyTable.counters.managedBy
                            $null = $deployedPolicyTable.all.Add($id, $policyResource)
                            $null = $deployedPolicyTable.managed.Add($id, $policyResource)
                        }
                        else {
                            $deployedPolicyTable.counters.unmanagedScopes += 1
                        }
                        $deployedPolicyTable.counters.unmanagedScopes += 1
                    }
                }
            }
        }
        $numberPolicyResourcesProcessed++
        if ($numberPolicyResourcesProcessed % 1000 -eq 0) {
            Write-Information "Processed $numberPolicyResourcesProcessed Policy definitions, Policy Set definitions, and Policy Assignments"
        }
    }
    if ($numberPolicyResourcesProcessed % 1000 -ne 0) {
        Write-Information "Processed $numberPolicyResourcesProcessed Policy definitions, Policy Set definitions, and Policy Assignments"
    }

    if (!$SkipExemptions) {
        $prefBackup = $WarningPreference
        $WarningPreference = 'SilentlyContinue'
        Write-Information ""
        $policyResources = Search-AzGraphAllItems `
            -Query 'PolicyResources | where type == "microsoft.authorization/policyexemptions"' `
            -Scope @{ UseTenantScope = $true } `
            -ProgressItemName "Policy Exemptions"
        $WarningPreference = $prefBackup

        $exemptionsTable = $deployed.policyExemptions
        $managedByCounters = $exemptionsTable.counters.managedBy
        $managedPolicyAssignmentsTable = $policyAssignmentsTable.managed
        $numberPolicyResourcesProcessed = 0
        $now = [datetime]::UtcNow
        foreach ($policyResourceRaw in $policyResources) {
            $thisTenantId = $policyResourceRaw.tenantId
            if ($thisTenantId -in @("", $tenantId)) {
                $id = $policyResourceRaw.id
                $name = $policyResourceRaw.name
                $properties = $policyResourceRaw.properties
                $displayName = $properties.displayName
                if ($null -ne $displayName -and $displayName -eq "") {
                    $displayName = $null
                }
                $description = $properties.description
                if ($null -ne $description -and $description -eq "") {
                    $description = $null
                }
                $exemptionCategory = $properties.exemptionCategory
                $expiresOnRaw = $properties.expiresOn
                $expiresOn = $null
                if ($null -ne $expiresOnRaw -and $expiresOnRaw -ne "") {
                    if ($expiresOnRaw -is [datetime]) {
                        $expiresOn = $expiresOnRaw.ToUniversalTime
                    }
                    else {
                        $expiresOnDate = [datetime]::Parse($expiresOnRaw)
                        $expiresOn = $expiresOnDate.ToUniversalTime()
                    }
                    $expiresOn = $expiresOnRaw.ToUniversalTime()
                }
                $metadataRaw = $properties.metadata
                $metadata = $null
                if ($null -ne $metadataRaw -and $metadataRaw -ne @{} ) {
                    $metadata = $metadataRaw
                }
                $policyAssignmentId = $properties.policyAssignmentId
                $policyDefinitionReferenceIdsRaw = $properties.policyDefinitionReferenceIds
                $policyDefinitionReferenceIds = $null
                if ($null -ne $policyDefinitionReferenceIdsRaw -and $policyDefinitionReferenceIdsRaw.Count -gt 0) {
                    $policyDefinitionReferenceIds = $policyDefinitionReferenceIdsRaw
                }
                $resourceSelectors = $properties.resourceSelectors
                $assignmentScopeValidation = $properties.assignmentScopeValidation
                $included, $resourceIdParts = Confirm-PolicyResourceExclusions `
                    -TestId $policyAssignmentId `
                    -ResourceId $id `
                    -ScopeTable $ScopeTable `
                    -IncludeResourceGroups $false `
                    -ExcludedScopes $excludedScopes `
                    -ExcludedIds $excludedPolicyAssignments `
                    -PolicyResourceTable $exemptionsTable
                if ($included) {
                    $status = "unknown"
                    $pacOwner = "unknownOwner"
                    $assignmentPacOwner = "unknownOwner"
                    $exemptionPacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -Metadata $metadata -ManagedByCounters $managedByCounters
                    if ($managedPolicyAssignmentsTable.ContainsKey($policyAssignmentId)) {
                        $status = "active"
                        $policyAssignment = $managedPolicyAssignmentsTable.$policyAssignmentId
                        $assignmentPacOwner = $policyAssignment.pacOwner
                        if ($exemptionPacOwner -eq "unknownOwner") {
                            $pacOwner = $assignmentPacOwner
                        }
                        else {
                            $pacOwner = $exemptionPacOwner
                        }
                    }
                    else {
                        $status = "orphaned"
                        $pacOwner = $exemptionPacOwner
                    }
                    $expiresInDays = [Int32]::MaxValue
                    if ($expiresOn) {
                        if ($expiresOn -lt $now) {
                            if ($status -eq "active") {
                                $status = "expired"
                            }
                        }
                        else {
                            $expiresIn = New-TimeSpan -Start $now -End $expiresOn
                            $expiresInDays = $expiresIn.Days
                        }
                    }
                    $exemption = @{
                        id                           = $id
                        name                         = $name
                        scope                        = $resourceIdParts.scope
                        displayName                  = $displayName
                        description                  = $description
                        exemptionCategory            = $exemptionCategory
                        expiresOn                    = $expiresOn
                        metadata                     = $metadata
                        policyAssignmentId           = $policyAssignmentId
                        policyDefinitionReferenceIds = $policyDefinitionReferenceIds
                        resourceSelectors            = $resourceSelectors
                        assignmentScopeValidation    = $assignmentScopeValidation
                        pacOwner                     = $pacOwner
                        status                       = $status
                        expiresInDays                = $expiresInDays
                    }

                    # What is the context of this exemption; it depends on the assignment being exempted
                    if ($pacOwner -eq "thisPaC") {
                        $managedByCounters.thisPaC += 1
                    }
                    elseif ($pacOwner -eq "otherPaC") {
                        $managedByCounters.otherPaC += 1
                    }
                    elseif ($pacOwner -eq "unknownOwner") {
                        $managedByCounters.unknown += 1
                    }
                    if ($status -eq "orphaned") {
                        $managedByCounters.orphaned += 1
                    }
                    $null = $exemptionsTable.managed.Add($id, $exemption)
                }
            }
            $numberPolicyResourcesProcessed++
            if ($numberPolicyResourcesProcessed % 1000 -eq 0) {
                Write-Information "Processed $numberPolicyResourcesProcessed Policy Exemptions"
            }
        }
        if ($numberPolicyResourcesProcessed % 1000 -ne 0) {
            Write-Information "Processed $numberPolicyResourcesProcessed Policy Exemptions"
        }
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
                $subscriptionId = $scope.Replace("/subscriptions/", "")
                $null = Set-AzContext -SubscriptionId $subscriptionId -Tenant $PacEnvironment.tenantId
                $results += Get-AzRoleAssignment
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
        Write-Information "    BuiltIn        = $($counters.builtIn)"
        Write-Information "    Managed ($($managedByAny)) by:"
        Write-Information "        This PaC   = $($managedBy.thisPaC)"
        Write-Information "        Other PaC  = $($managedBy.otherPaC)"
        Write-Information "        Unknown    = $($managedBy.unknown)"
        Write-Information "    Inherited      = $($counters.inherited)"
        Write-Information "    Excluded       = $($counters.excluded)"
        Write-Verbose "    Not our scopes = $($counters.unmanagedScopes)"
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
    Write-Information "    Excluded        = $($counters.excluded)"
    Write-Verbose "    Not our scopes  = $($counters.unmanagedScopes)"

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
        Write-Information "        Orphaned    = $($managedBy.orphaned)"
        Write-Information "    Excluded        = $($counters.excluded)"
        Write-Verbose "    Not our scopes  = $($counters.unmanagedScopes)"
    }

    if (!$SkipRoleAssignments) {
        Write-Information ""
        if ($scopesCovered.Count -gt 0 -and $deployedRoleAssignmentsByPrincipalId.Count -eq 0) {
            Write-Warning "Role assignment retrieval failed to receive any assignments in $($scopesCovered.Count) scopes. This likely due to a missing permission for the SPN running the pipeline. Please read the pipeline documentation in EPAC. In rare cases, this can happen when a previous role assignment failed." -WarningAction Continue
            $deployed.roleAssignmentsNotRetrieved = $true
        }
        Write-Information "Role Assignments:"
        Write-Information "    Total principalIds     = $($deployedRoleAssignmentsByPrincipalId.Count)"
        Write-Information "    Total Scopes           = $($scopesCovered.Count)"
        Write-Information "    Total Role Assignments = $($roleAssignmentsById.Count)"
    }

    return $deployed
}
