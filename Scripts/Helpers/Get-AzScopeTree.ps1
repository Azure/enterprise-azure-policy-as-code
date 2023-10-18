function Get-AzScopeTree {

    param(
        [hashtable] $PacEnvironment,
        [switch] $IgnoreScopeTreeErrors
    )

    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    $tenantId = $PacEnvironment.tenantId
    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Get scope tree for EPAC environment '$($PacEnvironment.pacSelector)' at root scope $($deploymentRootScope -replace '/providers/Microsoft.Management','')"
    Write-Information "==================================================================================================="
    $prefBackup = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    $scope = Split-ScopeId `
        -ScopeId $deploymentRootScope `
        -ParameterNameForManagementGroup "ManagementGroup" `
        -ParameterNameForSubscription "Subscription" `
        -AsSplat
    $resourceContainers = Search-AzGraphAllItems `
        -Query "ResourceContainers" `
        -Scope $scope `
        -ProgressItemName "resource containers"
    $WarningPreference = $prefBackup
    Write-Information ""
    Write-Information "Processing $($resourceContainers.Count) resource containers:"

    # Process subscriptions and management groups
    $scopeTable = @{}
    $numberOfManagementGroups = 0
    $numberOfSubscriptions = 0
    foreach ($resourceContainer in $resourceContainers) {
        # resource groups require a second pass
        $type = $resourceContainer.type
        if ($resourceContainer.tenantId -eq $tenantId -and $type -ne "microsoft.resources/subscriptions/resourcegroups") {
            $id = $resourceContainer.id
            $rootScopeReached = $id -eq $deploymentRootScope
            $managementGroupAncestorsChain = @()
            if ($type -eq "microsoft.management/managementgroups") {
                $managementGroupAncestorsChain = $resourceContainer.properties.details.managementGroupAncestorsChain
            }
            else {
                $managementGroupAncestorsChain = $resourceContainer.properties.managementGroupAncestorsChain
            }
            $numberOfAncestors = $managementGroupAncestorsChain.Count
            $newNodeCandidates = [System.Collections.ArrayList]::new()
            $parentList = @{}
            $childrenList = @{ $id = $type }
            $i = 0
            while (!$rootScopeReached -and $i -lt $numberOfAncestors) {
                $currentParent = $managementGroupAncestorsChain[$i]
                $currentId = "/providers/Microsoft.Management/managementGroups/$($currentParent.name)"
                if ($currentId -eq $deploymentRootScope) {
                    $rootScopeReached = $true
                }
                $null = $parentList.Add($currentId, "microsoft.management/managementgroups")
                if ($scopeTable.ContainsKey($currentId)) {
                    $currentScopeInformation = $scopeTable.$currentId
                    $currentChildrenList = $currentScopeInformation.childrenList
                    foreach ($child in $childrenList.Keys) {
                        $currentChildrenList[$child] = $childrenList.$child
                    }
                }
                else {
                    $scopeInformation = @{
                        id             = $currentId
                        type           = "microsoft.management/managementgroups"
                        name           = $currentParent.name
                        displayName    = $currentParent.displayName
                        parentList     = @{}
                        childrenList   = Get-HashtableShallowClone $childrenList
                        resourceGroups = @{}
                        state          = $null
                        location       = "global"
                    }
                    $null = $newNodeCandidates.Add($scopeInformation)
                }
                $i++
            }
            if ($rootScopeReached) {
                # candidates become actual nodes (not yet completed)
                foreach ($newNodeCandidate in $newNodeCandidates) {
                    $null = $scopeTable.Add($newNodeCandidate.id, $newNodeCandidate)
                }
                if ($scopeTable.ContainsKey($id)) {
                    # has any children already; needs parentList
                    $scopeInformation = $scopeTable.$id
                    $scopeInformation.parentList = $parentList
                    $scopeInformation.state = $resourceContainer.properties.state
                }
                else {
                    $scopeInformation = $null
                    if ($resourceContainer.type -eq "microsoft.management/managementgroups") {
                        $scopeInformation = @{
                            id             = $id
                            type           = $type
                            name           = $resourceContainer.name
                            displayName    = $resourceContainer.properties.displayName
                            parentList     = $parentList
                            childrenList   = @{}
                            resourceGroups = @{}
                            state          = $null
                            location       = "global"
                        }
                    }
                    else {
                        $scopeInformation = @{
                            id             = $id
                            type           = $type
                            name           = $resourceContainer.name
                            displayName    = $resourceContainer.name
                            parentList     = $parentList
                            childrenList   = @{}
                            resourceGroups = @{}
                            state          = $resourceContainer.properties.state
                            location       = "global"
                        }
                    }
                    $null = $scopeTable.Add($id, $scopeInformation)
                }
                if ($resourceContainer.type -eq "microsoft.management/managementgroups") {
                    $numberOfManagementGroups++
                }
                else {
                    $numberOfSubscriptions++
                }
            }
            else {
                # should not be possible
                if ($IgnoreScopeTreeErrors) {
                    Write-Error "Code bug: Our root is not in this tree" -ErrorAction SilentlyContinue
                }
                else {
                    Write-Error "Code bug: Our root is not in this tree" -ErrorAction Stop
                }
                
            }
        }
    }
    Write-Information "    Management groups = $($numberOfManagementGroups)"
    Write-Information "    Subscriptions     = $($numberOfSubscriptions)"

    # Process resourceGroups since the only contain the subscription information, needs managementGroup information as well
    $numberOfResourceGroups = 0
    foreach ($resourceContainer in $resourceContainers) {
        # resource groups require a second pass
        $type = $resourceContainer.type
        if ($resourceContainer.tenantId -eq $tenantId -and $type -eq "microsoft.resources/subscriptions/resourcegroups") {
            $id = $resourceContainer.id
            $name = $resourceContainer.name
            $subscriptionId = "/subscriptions/$($resourceContainer.subscriptionId)"
            if ($scopeTable.ContainsKey($subscriptionId)) {
                $subscriptionInformation = $scopeTable.$subscriptionId
                $subscriptionParentList = $subscriptionInformation.parentList
                $parentList = Get-HashtableShallowClone $subscriptionParentList
                $null = $parentList.Add($subscriptionId, $subscriptionInformation.type)
                foreach ($parentId in $parentList.Keys) {
                    $parentInformation = $scopeTable.$parentId
                    $parentChildrenList = $parentInformation.childrenList
                    $parentResourceGroups = $parentInformation.resourceGroups
                    $null = $parentChildrenList.Add($id, "microsoft.resources/subscriptions/resourcegroups")
                    $null = $parentResourceGroups.Add($id, "microsoft.resources/subscriptions/resourcegroups")
                }
                $scopeInformation = @{
                    id             = $id
                    type           = $type
                    name           = $name
                    displayName    = $name
                    parentList     = $parentList
                    childrenList   = @{}
                    resourceGroups = @{}
                    state          = $null
                    location       = $resourceContainer.location
                }
                $null = $scopeTable.Add($id, $scopeInformation)
                $numberOfResourceGroups++
            }
            else {
                # should not be possible
            }
        }
    }
    Write-Information "    Resource groups   = $($numberOfResourceGroups)"

    if ($PacEnvironment.policyDefinitionsScopes.Count -gt 2) {
        # Process policy definitions scopes
        $numberOfPolicyDefinitionsScopes = 0
        foreach ($policyDefinitionsScope in $PacEnvironment.policyDefinitionsScopes) {
            if ($scopeTable.ContainsKey($policyDefinitionsScope) -or $policyDefinitionsScope -eq "") {}
            else {
                $scopeInformation = @{
                    id             = $policyDefinitionsScope
                    type           = "microsoft.management/managementgroups"
                    name           = $policyDefinitionsScope
                    displayName    = $policyDefinitionsScope
                    parentList     = @{}
                    childrenList   = @{}
                    resourceGroups = @{}
                    state          = $null
                    location       = "global"
                }
                $null = $scopeTable.Add($policyDefinitionsScope, $scopeInformation)
                $numberOfPolicyDefinitionsScopes++
            }
        }
        Write-Information "    Policy definitions scopes = $($numberOfPolicyDefinitionsScopes)"
    }

    return $scopeTable
}
