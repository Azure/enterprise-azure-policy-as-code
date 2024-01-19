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
                    dfcSecurityPolicies = 0
                    dfcDefenderPlans = 0
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
        roleDefinitions              = @{}
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
                    $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -PolicyResource $policyResource -Scope $scope -ManagedByCounters $policyAssignmentsTable.counters.managedBy
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
                        $uniquePrincipalIds[$principalId] = $true
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
                                    $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -PolicyResource $policyResource -ManagedByCounters $deployedPolicyTable.counters.managedBy
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
                            $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -PolicyResource $policyResource -ManagedByCounters $deployedPolicyTable.counters.managedBy
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
                    $pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -PolicyResource $policyResourceRaw -ManagedByCounters $managedByCounters
                    if ($managedPolicyAssignmentsTable.ContainsKey($policyAssignmentId)) {
                        $status = "active"
                    }
                    else {
                        $status = "orphaned"
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

    $deployedRoleAssignmentsByPrincipalId = $deployed.roleAssignmentsByPrincipalId
    if (!$SkipRoleAssignments) {
        $prefBackup = $WarningPreference
        $WarningPreference = 'SilentlyContinue'

        Write-Information ""
        $principalIds = '"' + ($uniquePrincipalIds.Keys -join '", "') + '"'
        $roleAssignments = Search-AzGraphAllItems `
            -Query "authorizationresources | where type == `"microsoft.authorization/roleassignments`" and properties.principalId in ( $principalIds )" `
            -Scope @{ UseTenantScope = $true } `
            -ProgressItemName "Role Assignments"
        $roleDefinitions = Search-AzGraphAllItems 'authorizationresources | where type == "microsoft.authorization/roledefinitions"' `
            -Scope @{ UseTenantScope = $true } `
            -ProgressItemName "Role Definitions"

        $roleDefinitionsHt = $deployed.roleDefinitions
        foreach ($roleDefinition in $roleDefinitions) {
            $roleDefinitionId = $roleDefinition.id
            $roleDefinitionName = $roleDefinition.properties.roleName
            $null = $roleDefinitionsHt.Add($roleDefinitionId, $roleDefinitionName)
        }
        $WarningPreference = $prefBackup

        # loop through the collected role assignments to collate by principalId
        $roleAssignmentsCount = 0
        foreach ($roleAssignment in $roleAssignments) {
            $properties = $roleAssignment.properties
            $principalId = $roleAssignment.properties.principalId
            $roleDefinitionId = $properties.roleDefinitionId
            $roleDefinitionName = $roleDefinitionId
            if ($roleDefinitionsHt.ContainsKey($roleDefinitionId)) {
                $roleDefinitionName = $roleDefinitionsHt.$roleDefinitionId
            }
            $normalizedRoleAssignment = @{
                id               = $roleAssignment.id
                name             = $roleAssignment.name
                scope            = $properties.scope
                displayName      = ""
                objectType       = $properties.principalType
                principalId      = $principalId
                roleDefinitionId = $roleDefinitionId
                roleDisplayName  = $roleDefinitionName
            }
            if ($deployedRoleAssignmentsByPrincipalId.ContainsKey($principalId)) {
                $normalizedRoleAssignments = $deployedRoleAssignmentsByPrincipalId.$principalId
                $normalizedRoleAssignments += $normalizedRoleAssignment
                $deployedRoleAssignmentsByPrincipalId[$principalId] = $normalizedRoleAssignments
            }
            else {
                $null = $deployedRoleAssignmentsByPrincipalId.Add($principalId, @( $normalizedRoleAssignment ))
            }
            $roleAssignmentsCount++
            if ($roleAssignmentsCount % 1000 -eq 0) {
                Write-Information "Processed $roleAssignmentsCount Role Assignments"
            }
        }
        if ($roleAssignmentsCount % 1000 -ne 0) {
            Write-Information "Processed $roleAssignmentsCount Policy Exemptions"
        }
    }

    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Policy Resources found for EPAC environment '$($PacEnvironment.pacSelector)' at root scope $($deploymentRootScope -replace '/providers/Microsoft.Management', '')"
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
    $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown + $managedBy.dfcSecurityPolicies + $managedBy.dfcDefenderPlans
    Write-Information ""
    Write-Information "Policy Assignment counts:"
    Write-Information "    Managed ($($managedByAny)) by:"
    Write-Information "        This PaC              = $($managedBy.thisPaC)"
    Write-Information "        Other PaC             = $($managedBy.otherPaC)"
    Write-Information "        Unknown               = $($managedBy.unknown)"
    Write-Information "        DfC Security Policies = $($managedBy.dfcSecurityPolicies)"
    Write-Information "        DfC Defender Plans    = $($managedBy.dfcDefenderPlans)"
    Write-Information "    With identity             = $($assignmentsWithIdentity.psbase.Count)"
    Write-Information "    Excluded                  = $($counters.excluded)"
    Write-Verbose "    Not our scopes = $($counters.unmanagedScopes)"

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
        if ($uniquePrincipalIds.Count -gt 0 -and $deployedRoleAssignmentsByPrincipalId.Count -eq 0) {
            Write-Warning "Role assignment retrieval failed to receive any role assignments. This likely due to a missing permission for the SPN running the pipeline. Please read the pipeline documentation in EPAC. In rare cases, this can happen when a previous role assignment failed." -WarningAction Continue
            $deployed.roleAssignmentsNotRetrieved = $true
        }
        Write-Information "Role Assignments:"
        Write-Information "    Total principalIds     = $($deployedRoleAssignmentsByPrincipalId.Count)"
        Write-Information "    Total Role Assignments = $($roleAssignmentsCount)"
    }

    return $deployed
}
