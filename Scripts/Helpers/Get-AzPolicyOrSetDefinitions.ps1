function Get-AzPolicyOrSetDefinitions {
    [CmdletBinding()]
    param (
        $DefinitionType,
        $PolicyResourcesTable,
        $PacEnvironment,
        $ScopeTable,
        $CollectAllPolicies
    )

    $desiredState = $PacEnvironment.desiredState
    $rootScopeDetails = $ScopeTable.root
    $excludedScopesTable = $rootScopeDetails.excludedScopesTable
    $policyDefinitionsScopes = $PacEnvironment.policyDefinitionsScopes
    $scopesLength = $policyDefinitionsScopes.Length
    $scopesLast = $scopesLength - 1
    $thisPacOwnerId = $PacEnvironment.pacOwnerId
    $environmentTenantId = $PacEnvironment.tenantId


    $query = $null
    $progressItemName = $null
    $excludedIds = $null
    switch ($DefinitionType) {
        policyDefinitions {
            $query = "PolicyResources | where type == 'microsoft.authorization/policydefinitions'"
            $progressItemName = "Policy definitions"
            $excludedIds = $desiredState.excludedPolicyDefinitions
        }
        policySetDefinitions {
            $query = "PolicyResources | where type == 'microsoft.authorization/policysetdefinitions'"
            $progressItemName = "Policy Set definitions"
            $excludedIds = $desiredState.excludedPolicySetDefinitions
        }
    }

    $policyResources = Search-AzGraphAllItems -Query $query -ProgressItemName $progressItemName
    foreach ($policyResource in $policyResources) {
        $resourceTenantId = $policyResource.tenantId
        if ($resourceTenantId -in @($null, "", $environmentTenantId)) {
            $id = $policyResource.id
            $testId = $id
            $included, $resourceIdParts = Confirm-PolicyResourceExclusions `
                -TestId $testId `
                -ResourceId $id `
                -ScopeTable $ScopeTable `
                -ExcludedScopesTable $excludedScopesTable `
                -ExcludedIds $excludedIds `
                -PolicyResourceTable $PolicyResourcesTable
            if ($included) {
                $scope = $resourceIdParts.scope
                $policyResource.resourceIdParts = $resourceIdParts
                $policyResource.scope = $scope
                $found = $false
                for ($i = 0; $i -lt $scopesLength -and !$found; $i++) {
                    $currentScopeId = $policyDefinitionsScopes[$i]
                    if ($resourceIdParts.scope -eq $currentScopeId) {
                        switch ($i) {
                            0 {
                                # deploymentRootScope
                                $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -PolicyResource $policyResource -Scope $scope -ManagedByCounters $PolicyResourcesTable.counters.managedBy
                                $null = $PolicyResourcesTable.all.Add($id, $policyResource)
                                $null = $PolicyResourcesTable.managed.Add($id, $policyResource)
                                $found = $true
                            }
                            $scopesLast {
                                # BuiltIn or Static, since last entry in array is empty string ($currentPolicyDefinitionsScopeId)
                                $policyResource.pacOwner = "readOnly"
                                $null = $PolicyResourcesTable.all.Add($id, $policyResource)
                                $null = $PolicyResourcesTable.readOnly.Add($id, $policyResource)
                                $PolicyResourcesTable.counters.builtIn += 1
                                $found = $true
                            }
                            Default {
                                # Read only definitions scopes
                                $policyResource.pacOwner = "builtin"
                                $null = $PolicyResourcesTable.all.Add($id, $policyResource)
                                $null = $PolicyResourcesTable.readOnly.Add($id, $policyResource)
                                $PolicyResourcesTable.counters.inherited += 1
                                $found = $true
                            }
                        }
                    }
                }
                if (!$found) {
                    if ($CollectAllPolicies) {
                        $policyResource.pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -PolicyResource $policyResource -ManagedByCounters $PolicyResourcesTable.counters.managedBy
                        $null = $PolicyResourcesTable.all.Add($id, $policyResource)
                        $null = $PolicyResourcesTable.managed.Add($id, $policyResource)
                    }
                    else {
                        $PolicyResourcesTable.counters.unmanagedScopes += 1
                    }
                }
            }
            else {
                Write-Verbose "Policy resource $id excluded"
            }
        }
    }
}