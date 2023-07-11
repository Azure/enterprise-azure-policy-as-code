function Get-AzScopeTree {

    param(
        [hashtable] $PacEnvironment
    )

    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    $TenantId = $PacEnvironment.tenantId
    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Get scope tree for EPAC environment '$($PacEnvironment.pacSelector)' at root scope $($deploymentRootScope -replace '/providers/Microsoft.Management','')"
    Write-Information "==================================================================================================="
    $prefBackup = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    $Scope = Split-ScopeId `
        -ScopeId $deploymentRootScope `
        -ParameterNameForManagementGroup "ManagementGroup" `
        -ParameterNameForSubscription "Subscription" `
        -AsSplat
    $resourceContainers = Search-AzGraphAllItems `
        -Query "ResourceContainers" `
        -Scope $Scope `
        -ProgressItemName "resource containers"
    $WarningPreference = $prefBackup
    Write-Information ""
    Write-Information "Processing $($resourceContainers.Count) resource containers:"

    # Process subscriptions and management groups
    $ScopeTable = @{}
    $numberOfManagementGroups = 0
    $numberOfSubscriptions = 0
    foreach ($resourceContainer in $resourceContainers) {
        # resource groups require a second pass
        $type = $resourceContainer.type
        if ($resourceContainer.tenantId -eq $TenantId -and $type -ne "microsoft.resources/subscriptions/resourcegroups") {
            $Id = $resourceContainer.id
            $rootScopeReached = $Id -eq $deploymentRootScope
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
            $childrenList = @{ $Id = $type }
            $i = 0
            while (!$rootScopeReached -and $i -lt $numberOfAncestors) {
                $currentParent = $managementGroupAncestorsChain[$i]
                $currentId = "/providers/Microsoft.Management/managementGroups/$($currentParent.name)"
                if ($currentId -eq $deploymentRootScope) {
                    $rootScopeReached = $true
                }
                $null = $parentList.Add($currentId, "microsoft.management/managementgroups")
                if ($ScopeTable.ContainsKey($currentId)) {
                    $currentScopeInformation = $ScopeTable.$currentId
                    $currentChildrenList = $currentScopeInformation.childrenList
                    foreach ($child in $childrenList.Keys) {
                        $currentChildrenList[$child] = $childrenList.$child
                    }
                }
                else {
                    $ScopeInformation = @{
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
                    $null = $newNodeCandidates.Add($ScopeInformation)
                }
                $i++
            }
            if ($rootScopeReached) {
                # candidates become actual nodes (not yet completed)
                foreach ($newNodeCandidate in $newNodeCandidates) {
                    $null = $ScopeTable.Add($newNodeCandidate.id, $newNodeCandidate)
                }
                if ($ScopeTable.ContainsKey($Id)) {
                    # has any children already; needs parentList
                    $ScopeInformation = $ScopeTable.$Id
                    $ScopeInformation.parentList = $parentList
                    $ScopeInformation.state = $resourceContainer.properties.state
                }
                else {
                    $ScopeInformation = $null
                    if ($resourceContainer.type -eq "microsoft.management/managementgroups") {
                        $ScopeInformation = @{
                            id             = $Id
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
                        $ScopeInformation = @{
                            id             = $Id
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
                    $null = $ScopeTable.Add($Id, $ScopeInformation)
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
                Write-Error "Code bug: Our root is not in this tree" -ErrorAction Stop
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
        if ($resourceContainer.tenantId -eq $TenantId -and $type -eq "microsoft.resources/subscriptions/resourcegroups") {
            $Id = $resourceContainer.id
            $Name = $resourceContainer.name
            $subscriptionId = "/subscriptions/$($resourceContainer.subscriptionId)"
            if ($ScopeTable.ContainsKey($subscriptionId)) {
                $subscriptionInformation = $ScopeTable.$subscriptionId
                $subscriptionParentList = $subscriptionInformation.parentList
                $parentList = Get-HashtableShallowClone $subscriptionParentList
                $null = $parentList.Add($subscriptionId, $subscriptionInformation.type)
                foreach ($parentId in $parentList.Keys) {
                    $parentInformation = $ScopeTable.$parentId
                    $parentChildrenList = $parentInformation.childrenList
                    $parentResourceGroups = $parentInformation.resourceGroups
                    $null = $parentChildrenList.Add($Id, "microsoft.resources/subscriptions/resourcegroups")
                    $null = $parentResourceGroups.Add($Id, "microsoft.resources/subscriptions/resourcegroups")
                }
                $ScopeInformation = @{
                    id             = $Id
                    type           = $type
                    name           = $Name
                    displayName    = $Name
                    parentList     = $parentList
                    childrenList   = @{}
                    resourceGroups = @{}
                    state          = $null
                    location       = $resourceContainer.location
                }
                $null = $ScopeTable.Add($Id, $ScopeInformation)
                $numberOfResourceGroups++
            }
            else {
                # should not be possible
            }
        }
    }
    Write-Information "    Resource groups   = $($numberOfResourceGroups)"

    return $ScopeTable
}
