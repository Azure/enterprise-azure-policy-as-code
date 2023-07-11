function Set-UniqueRoleAssignmentScopes {
    [CmdletBinding()]
    param (
        [string] $ScopeId,
        [hashtable] $UniqueRoleAssignmentScopes
    )

    $splits = $ScopeId -split "/"
    $segments = $splits.Length

    $ScopeType = switch ($segments) {
        3 {
            "subscriptions"
            break
        }
        5 {
            $splits[3]
            break
        }
        { $_ -gt 5 } {
            "resources"
            break
        }
        Default {
            "unknown"
        }
    }
    $table = $UniqueRoleAssignmentScopes.$ScopeType
    $table[$ScopeId] = $ScopeType
}

function Confirm-PolicyResourceExclusions {
    [CmdletBinding()]
    param (
        $TestId,
        $ResourceId,
        $PolicyResource,
        $ScopeTable,
        $IncludeResourceGroups,
        $ExcludedScopes,
        $ExcludedIds,
        $PolicyResourceTable
    )

    $ResourceIdParts = Split-AzPolicyResourceId -Id $TestId
    $Scope = $ResourceIdParts.scope
    $ScopeType = $ResourceIdParts.scopeType

    if ($ScopeType -eq "builtin") {
        return $true, $ResourceIdParts
    }
    if (!$ScopeTable.ContainsKey($Scope)) {
        $PolicyResourceTable.counters.unMangedScope += 1
        $null = $PolicyResourceTable.excluded.Add($ResourceId, $PolicyResource)
        return $false, $ResourceIdParts
    }
    $ScopeEntry = $ScopeTable.$Scope
    $parentList = $ScopeEntry.parentList
    if ($null -eq $parentList) {
        Write-Error "Code bug parentList is $null $($ScopeEntry | ConvertTo-Json -Depth 100 -Compress)"
    }
    if (!$IncludeResourceGroups -and $ScopeType -eq "resourceGroups") {
        # Write-Information "    Exclude(resourceGroup) $($ResourceId)"
        $PolicyResourceTable.counters.excludedScopes += 1
        $null = $PolicyResourceTable.excluded.Add($ResourceId, $PolicyResource)
        return $false, $ResourceIdParts
    }
    foreach ($testScope in $ExcludedScopes) {
        if ($Scope -eq $testScope -or $parentList.ContainsKey($testScope)) {
            # Write-Information "Exclude(scope,$testScope) $($ResourceId)"
            $PolicyResourceTable.counters.excludedScopes += 1
            $null = $PolicyResourceTable.excluded.Add($ResourceId, $PolicyResource)
            return $false, $ResourceIdParts
        }
    }
    foreach ($testExcludedId in $ExcludedIds) {
        if ($TestId -like $testExcludedId) {
            # Write-Information "Exclude(id,$testExcludedId) $($ResourceId)"
            $PolicyResourceTable.counters.excluded += 1
            $null = $PolicyResourceTable.excluded.Add($ResourceId, $PolicyResource)
            return $false, $ResourceIdParts
        }
    }
    return $true, $ResourceIdParts
}

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
    $TenantId = $PacEnvironment.tenantId
    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Get Policy Resources for EPAC environment '$($PacEnvironment.pacSelector)' at root scope $($deploymentRootScope -replace '/providers/Microsoft.Management','')"
    Write-Information "==================================================================================================="
    $prefBackup = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    $PolicyResources = Search-AzGraphAllItems `
        -Query 'PolicyResources | where (type == "microsoft.authorization/policyassignments") or (type == "microsoft.authorization/policysetdefinitions") or (type == "microsoft.authorization/policydefinitions")' `
        -Scope @{ UseTenantScope = $true } `
        -ProgressItemName "Policy resources"
    $WarningPreference = $prefBackup

    Write-Information ""
    Write-Information "Processing $($PolicyResources.Count) Policy resources (Policy Assignments, Policy Set and Policy definitionss)"
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
    $IncludeResourceGroups = $desiredState.includeResourceGroups
    $excludedPolicyAssignments = $desiredState.excludedPolicyAssignments

    $PolicyDefinitionsScopes = $PacEnvironment.policyDefinitionsScopes
    $ScopesLength = $PolicyDefinitionsScopes.Length
    $ScopesLast = $ScopesLength - 1
    $customPolicyDefinitionScopes = $PolicyDefinitionsScopes[0..($ScopesLast - 1)]
    $GlobalNotScopes = $PacEnvironment.globalNotScopes
    $ExcludedScopesRaw = @()
    $ExcludedScopesRaw += $GlobalNotScopes
    $ExcludedScopesRaw += $desiredState.excludedScopes
    if ($ExcludedScopesRaw.Count -gt 1) {
        $ExcludedScopesRaw = @() + (Select-Object -InputObject $ExcludedScopesRaw -Unique)
    }

    $ScopeCollection = Build-NotScopes -ScopeTable $ScopeTable -ScopeList $customPolicyDefinitionScopes -NotScopeIn $ExcludedScopesRaw
    $ExcludedScopesHashtable = @{}
    foreach ($Scope in $ScopeCollection) {
        foreach ($notScope in $Scope.notScope) {
            $ExcludedScopesHashtable[$notScope] = $notScope
        }
    }
    $ExcludedScopes = $ExcludedScopesHashtable.Keys
    $PolicyDefinitionsScopes = $PacEnvironment.policyDefinitionsScopes
    $ScopesLength = $PolicyDefinitionsScopes.Length
    $ScopesLast = $ScopesLength - 1
    $PolicyAssignmentsTable = $deployed.policyassignments
    $ThisPacOwnerId = $PacEnvironment.pacOwnerId
    $UniqueRoleAssignmentScopes = @{
        resources        = @{}
        resourceGroups   = @{}
        subscriptions    = @{}
        managementGroups = @{}
    }
    $uniquePrincipalIds = @{}
    $AssignmentsWithIdentity = @{}
    $numberPolicyResourcesProcessed = 0
    foreach ($PolicyResourceRaw in $PolicyResources) {
        $thisTenantId = $PolicyResourceRaw.tenantId
        if ($thisTenantId -in @("", $TenantId)) {
            $PolicyResource = Get-HashtableShallowClone $PolicyResourceRaw
            $Id = $PolicyResource.id
            $kind = $PolicyResource.kind
            $included = $true
            $ResourceIdParts = $null
            # Remove-NullFields $PolicyResource
            if ($kind -eq "policyassignments") {
                $included, $ResourceIdParts = Confirm-PolicyResourceExclusions `
                    -TestId $Id `
                    -ResourceId $Id `
                    -PolicyResource $PolicyResource `
                    -ScopeTable $ScopeTable `
                    -IncludeResourceGroups $IncludeResourceGroups `
                    -ExcludedScopes $ExcludedScopes `
                    -ExcludedIds $excludedPolicyAssignments `
                    -PolicyResourceTable $PolicyAssignmentsTable
                if ($included) {
                    $Scope = $ResourceIdParts.scope
                    $PolicyResource.resourceIdParts = $ResourceIdParts
                    $PolicyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $ThisPacOwnerId -Metadata $PolicyResource.properties.metadata -ManagedByCounters $PolicyAssignmentsTable.counters.managedBy
                    $null = $PolicyAssignmentsTable.all.Add($Id, $PolicyResource)
                    $null = $PolicyAssignmentsTable.managed.Add($Id, $PolicyResource)
                    if ($PolicyResource.identity -and $PolicyResource.identity.type -ne "None") {
                        $principalId = ""
                        if ($PolicyResource.identity.type -eq "SystemAssigned") {
                            $principalId = $PolicyResource.identity.principalId
                        }
                        else {
                            $userAssignedIdentityId = $PolicyResource.identity.userAssignedIdentities.PSObject.Properties.Name
                            $principalId = $PolicyResource.identity.userAssignedIdentities.$userAssignedIdentityId.principalId
                        }
                        Set-UniqueRoleAssignmentScopes `
                            -ScopeId $Scope `
                            -UniqueRoleAssignmentScopes $UniqueRoleAssignmentScopes
                        $uniquePrincipalIds[$principalId] = $true
                        if ($PolicyResource.properties.metadata.roles) {
                            $roles = $PolicyResource.properties.metadata.roles
                            foreach ($role in $roles) {
                                Set-UniqueRoleAssignmentScopes `
                                    -ScopeId $role.scope `
                                    -UniqueRoleAssignmentScopes $UniqueRoleAssignmentScopes
                            }
                        }
                        $null = $AssignmentsWithIdentity.Add($Id, $PolicyResource)
                    }
                }
                else {
                    Write-Debug "Policy resource $Id excluded"
                }
            }
            else {
                $deployedPolicyTable = $deployed.$kind
                $found = $false
                $excludedList = $desiredState.excludedPolicyDefinitions
                if ($kind -eq "policysetdefinitions") {
                    $excludedList = $desiredState.excludedPolicySetDefinitions
                }
                $included, $ResourceIdParts = Confirm-PolicyResourceExclusions `
                    -TestId $Id `
                    -ResourceId $Id `
                    -PolicyResource $PolicyResource `
                    -ScopeTable $ScopeTable `
                    -IncludeResourceGroups $false `
                    -ExcludedScopes $ExcludedScopes `
                    -ExcludedIds $excludedList `
                    -PolicyResourceTable $deployedPolicyTable
                if ($included) {
                    $PolicyResource.resourceIdParts = $ResourceIdParts
                    $found = $false
                    for ($i = 0; $i -lt $ScopesLength -and !$found; $i++) {
                        $currentScopeId = $PolicyDefinitionsScopes[$i]
                        if ($ResourceIdParts.scope -eq $currentScopeId) {
                            switch ($i) {
                                0 {
                                    # deploymentRootScope
                                    $null = $deployedPolicyTable.all.Add($Id, $PolicyResource)
                                    $null = $deployedPolicyTable.managed.Add($Id, $PolicyResource)
                                    $null = $deployedPolicyTable.custom.Add($Id, $PolicyResource)
                                    $PolicyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $ThisPacOwnerId -Metadata $PolicyResource.properties.metadata -ManagedByCounters $deployedPolicyTable.counters.managedBy
                                    $found = $true
                                }
                                $ScopesLast {
                                    # BuiltIn or Static, since last entry in array is empty string ($currentPolicyDefinitionsScopeId)
                                    $null = $deployedPolicyTable.all.Add($Id, $PolicyResource)
                                    $null = $deployedPolicyTable.readOnly.Add($Id, $PolicyResource)
                                    $deployedPolicyTable.counters.builtIn += 1
                                    $found = $true
                                }
                                Default {
                                    # Read only definitions scopes
                                    $null = $deployedPolicyTable.all.Add($Id, $PolicyResource)
                                    $null = $PolicyDefinitions.readOnly.Add($Id, $PolicyResource)
                                    $null = $deployedPolicyTable.custom.Add($Id, $PolicyResource)
                                    $deployedPolicyTable.counters.inherited += 1
                                    $found = $true
                                }
                            }
                        }
                    }
                    if (!$found) {
                        $deployedPolicyTable.counters.unMangedScope += 1
                        if ($CollectAllPolicies -and $PolicyResource.properties.policyType -eq "Custom") {
                            $null = $deployedPolicyTable.all.Add($Id, $PolicyResource)
                            $null = $deployedPolicyTable.custom.Add($Id, $PolicyResource)
                        }
                    }
                }
            }
        }
        $numberPolicyResourcesProcessed++
        if ($numberPolicyResourcesProcessed % 500 -eq 0) {
            Write-Information "Processed $numberPolicyResourcesProcessed Policy resources"
        }
    }
    if ($numberPolicyResourcesProcessed % 500 -ne 0) {
        Write-Information "Processed $numberPolicyResourcesProcessed Policy resources"
    }

    if (!$SkipRoleAssignments) {
        # Get-AzRoleAssignment from the lowest scopes up. This will reduce the number of calls to Azure
        $RoleAssignmentsById = @{}
        $ScopesCovered = @{}
        $ScopesCollectedCount = 0
        $RoleAssignmentsCount = 0
        # Write-Information "    Progress:"
        # individual resources
        Write-Information ""
        Write-Information "Collecting Role assignments (this may take a while):"
        foreach ($Scope in $UniqueRoleAssignmentScopes.resources.Keys) {
            if (!$ScopesCovered.ContainsKey($Scope)) {
                $ScopesCovered[$Scope] = $true
                $results = @()
                $ScopesCollectedCount++
                Write-Information "    $Scope"
                $results += Get-AzRoleAssignment -Scope $Scope -WarningAction SilentlyContinue
                $localScopesCovered = @{}
                foreach ($result in $results) {
                    if ($result.ObjectType -eq "ServicePrincipal" -and $uniquePrincipalIds.ContainsKey($result.ObjectId)) {
                        $localScopesCovered[$result.Scope] = $true
                        $RoleAssignmentsById[$result.RoleAssignmentId] = $result
                        $RoleAssignmentsCount++
                    }
                }
                foreach ($localScope in $localScopesCovered.Keys) {
                    $ScopesCovered[$localScope] = $true
                }
            }
        }
        # resource groups
        foreach ($Scope in $UniqueRoleAssignmentScopes.resourceGroups.Keys) {
            if (!$ScopesCovered.ContainsKey($Scope)) {
                $ScopesCovered[$Scope] = $true
                $results = @()
                Write-Information "    $Scope"
                $results += Get-AzRoleAssignment -Scope $Scope -WarningAction SilentlyContinue
                $ScopesCollectedCount++
                $localScopesCovered = @{}
                foreach ($result in $results) {
                    if ($result.ObjectType -eq "ServicePrincipal" -and $uniquePrincipalIds.ContainsKey($result.ObjectId)) {
                        $localScopesCovered[$result.Scope] = $true
                        $RoleAssignmentsById[$result.RoleAssignmentId] = $result
                        $RoleAssignmentsCount++
                    }
                }
                foreach ($localScope in $localScopesCovered.Keys) {
                    $ScopesCovered[$localScope] = $true
                }
            }
        }
        # subscriptions
        foreach ($Scope in $UniqueRoleAssignmentScopes.subscriptions.Keys) {
            if (!$ScopesCovered.ContainsKey($Scope)) {
                $ScopesCovered[$Scope] = $true
                $results = @()
                Write-Information "    $Scope"
                $results += Get-AzRoleAssignment -Scope $Scope -WarningAction SilentlyContinue
                $ScopesCollectedCount++
                $localScopesCovered = @{}
                foreach ($result in $results) {
                    if ($result.ObjectType -eq "ServicePrincipal" -and $uniquePrincipalIds.ContainsKey($result.ObjectId)) {
                        $localScopesCovered[$result.Scope] = $true
                        $RoleAssignmentsById[$result.RoleAssignmentId] = $result
                        $RoleAssignmentsCount++
                    }
                }
                foreach ($localScope in $localScopesCovered.Keys) {
                    $ScopesCovered[$localScope] = $true
                }
            }
        }
        # management groups (we are not trying to optimize based on the management group tree structure)
        foreach ($Scope in $UniqueRoleAssignmentScopes.managementGroups.Keys) {
            if (!$ScopesCovered.ContainsKey($Scope)) {
                $ScopesCovered[$Scope] = $true
                $results = @()
                Write-Information "    $Scope"
                $results += Get-AzRoleAssignment -Scope $Scope -WarningAction SilentlyContinue
                $ScopesCollectedCount++
                $localScopesCovered = @{}
                foreach ($result in $results) {
                    if ($result.ObjectType -eq "ServicePrincipal" -and $uniquePrincipalIds.ContainsKey($result.ObjectId)) {
                        $localScopesCovered[$result.Scope] = $true
                        $RoleAssignmentsById[$result.RoleAssignmentId] = $result
                        $RoleAssignmentsCount++
                    }
                }
                foreach ($localScope in $localScopesCovered.Keys) {
                    $ScopesCovered[$localScope] = $true
                }
            }
        }

        # loop through the collected role assignments to collate by principalId
        $DeployedRoleAssignmentsByPrincipalId = $deployed.roleAssignmentsByPrincipalId
        foreach ($roleAssignment in $RoleAssignmentsById.Values) {
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
            if ($DeployedRoleAssignmentsByPrincipalId.ContainsKey($principalId)) {
                $normalizedRoleAssignments = $DeployedRoleAssignmentsByPrincipalId.$principalId
                $normalizedRoleAssignments += $normalizedRoleAssignment
                $DeployedRoleAssignmentsByPrincipalId[$principalId] = $normalizedRoleAssignments
            }
            else {
                $null = $DeployedRoleAssignmentsByPrincipalId.Add($principalId, @( $normalizedRoleAssignment ))
            }
        }
    }

    # Collect Exemptions
    if (!$SkipExemptions) {
        $ExemptionsProcessed = @{}
        $ExemptionsTable = $deployed.policyExemptions
        $ManagedByCounters = $ExemptionsTable.counters.managedBy
        $managedPolicyAssignmentsTable = $PolicyAssignmentsTable.managed
        $excludedPolicyAssignmentsTable = $PolicyAssignmentsTable.excluded
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
        foreach ($ScopeId in $ScopeTable.Keys) {
            $ScopeInformation = $ScopeTable.$ScopeId
            if ($ScopeInformation.type -eq "microsoft.resources/subscriptions") {
                Write-Information "    $ScopeId"
                Get-AzPolicyExemptionsAtScopeRestMethod -Scope $ScopeId | Sort-Object Properties.PolicyAssignmentId, ResourceId |  ForEach-Object {
                    $exemption = Get-DeepClone $_
                    $Id = $exemption.id
                    if (!$ExemptionsProcessed.ContainsKey($Id)) {
                        # Filter out duplicates in parent Management Groups

                        # Remove-NullFields $exemption
                        $null = $ExemptionsProcessed.Add($Id, $exemption)

                        # normalize values to az cli representation
                        $properties = $exemption.Properties
                        $description = $properties.Description
                        $DisplayName = $properties.DisplayName
                        $exemptionCategory = $properties.ExemptionCategory
                        $expiresOn = $properties.ExpiresOn
                        $Metadata = $properties.Metadata
                        $Name = $exemption.Name
                        $PolicyAssignmentId = $properties.PolicyAssignmentId
                        $PolicyDefinitionReferenceIds = $properties.PolicyDefinitionReferenceIds
                        $resourceGroup = $exemption.ResourceGroupName

                        # Find scope
                        $ResourceIdParts = Split-AzPolicyResourceId -Id $Id
                        $Scope = $ResourceIdParts.scope

                        $exemption = @{
                            id                 = $Id
                            name               = $Name
                            scope              = $Scope
                            policyAssignmentId = $PolicyAssignmentId
                            exemptionCategory  = $exemptionCategory
                        }
                        if ($null -ne $DisplayName -and $DisplayName -ne "") {
                            $null = $exemption.Add("displayName", $DisplayName)
                        }
                        if ($null -ne $description -and $description -ne "") {
                            $null = $exemption.Add("description", $description)
                        }
                        if ($null -ne $expiresOn) {
                            $expiresOnUtc = $expiresOn.ToUniversalTime()
                            $null = $exemption.Add("expiresOn", $expiresOnUtc)
                        }
                        if ($null -ne $PolicyDefinitionReferenceIds -and $PolicyDefinitionReferenceIds.Count -gt 0) {
                            $null = $exemption.Add("policyDefinitionReferenceIds", $PolicyDefinitionReferenceIds)
                        }
                        if ($null -ne $Metadata -and $Metadata -ne @{} ) {
                            $null = $exemption.Add("metadata", $Metadata)
                        }
                        if ($null -ne $resourceGroup -and $resourceGroup -ne "") {
                            $null = $exemption.Add("resourceGroup", $resourceGroup)
                        }

                        # What is the context of this exemption; it depends on the assignment being exempted
                        if ($managedPolicyAssignmentsTable.ContainsKey($PolicyAssignmentId)) {
                            $PolicyAssignment = $managedPolicyAssignmentsTable.$PolicyAssignmentId
                            $PacOwner = $PolicyAssignment.pacOwner
                            $exemption.pacOwner = $PacOwner
                            if ($PacOwner -eq "thisPaC") {
                                $ManagedByCounters.thisPaC += 1
                            }
                            elseif ($PacOwner -eq "otherPaC") {
                                $ManagedByCounters.otherPaC += 1
                            }
                            else {
                                $ManagedByCounters.unknown += 1
                            }
                            $null = $ExemptionsTable.managed.Add($Id, $exemption)
                            $null = $ExemptionsTable.all.Add($Id, $exemption)
                        }
                        elseif ($excludedPolicyAssignmentsTable.ContainsKey($PolicyAssignmentId)) {
                            $PolicyAssignment = $excludedPolicyAssignmentsTable.$PolicyAssignmentId
                            if ($CollectAllPolicies) {
                                $PacOwner = $PolicyAssignment.pacOwner
                                $exemption.pacOwner = $PacOwner
                                if ($PacOwner -eq "thisPaC") {
                                    $ManagedByCounters.thisPaC += 1
                                }
                                elseif ($PacOwner -eq "otherPaC") {
                                    $ManagedByCounters.otherPaC += 1
                                }
                                else {
                                    $ManagedByCounters.unknown += 1
                                }
                            }
                            $null = $ExemptionsTable.excluded.Add($Id, $exemption)
                        }
                        else {
                            $included, $ResourceIdParts = Confirm-PolicyResourceExclusions `
                                -TestId $PolicyAssignmentId `
                                -ResourceId $Id `
                                -PolicyResource $exemption `
                                -ScopeTable $ScopeTable `
                                -IncludeResourceGroups $IncludeResourceGroups `
                                -ExcludedScopes $ExcludedScopes `
                                -ExcludedIds $excludedPolicyAssignments `
                                -PolicyResourceTable $orphanedResourceTable

                            # orphaned, do not differentiate
                            if ($included) {
                                $null = $ExemptionsTable.orphaned.Add($Id, $exemption)
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
    Write-Information "    With identity   = $($AssignmentsWithIdentity.psbase.Count)"
    Write-Information "    Excluded scopes = $($counters.excludedScopes)"
    Write-Information "    Excluded        = $($counters.excluded)"
    Write-Information "    Not our scopes  = $($counters.unMangedScope)"

    if (!$SkipRoleAssignments) {
        Write-Information ""
        if ($ScopesCovered.Count -gt 0 -and $DeployedRoleAssignmentsByPrincipalId.Count -eq 0) {
            Write-Warning "Role assignment retrieval failed to receive any assignments in $($ScopesCovered.Count) scopes. This likely due to a missing permission for the SPN running the pipeline. Please read the pipeline documentation in EPAC. In rare cases, this can happen when a previous role assignment failed." -WarningAction Continue
            $deployed.roleAssignmentsNotRetrieved = $true
        }
        Write-Information "Role Assignments:"
        Write-Information "    Total principalIds     = $($DeployedRoleAssignmentsByPrincipalId.Count)"
        Write-Information "    Total Role Assignments = $($RoleAssignmentsById.Count)"
        Write-Information "    Total Scopes           = $($ScopesCovered.Count)"
    }

    if (!$SkipExemptions) {
        $counters = $ExemptionsTable.counters
        $managedBy = $counters.managedBy
        $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown
        Write-Information ""
        Write-Information "Policy Exemptions:"
        Write-Information "    Managed ($($managedByAny)) by:"
        Write-Information "        This PaC    = $($managedBy.thisPaC)"
        Write-Information "        Other PaC   = $($managedBy.otherPaC)"
        Write-Information "        Unknown     = $($managedBy.unknown)"
        Write-Information "    Orphaned   = $($ExemptionsTable.orphaned.psbase.Count)"
    }

    return $deployed
}
