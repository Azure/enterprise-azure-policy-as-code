function Build-ScopeTableForManagementGroup {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)] $ManagementGroup,
        [parameter(Mandatory = $true)] [hashtable] $ResourceGroupsBySubscriptionId,
        [parameter(Mandatory = $true)] $PacEnvironment,
        [parameter(Mandatory = $true)] [hashtable] $ScopeTable,
        [parameter(Mandatory = $false)] [bool] $IsExcluded = $false,
        [parameter(Mandatory = $false)] [bool] $IsInGlobalNotScope = $false,
        [parameter(Mandatory = $false)] [hashtable] $ParentTable = @{},
        [parameter(Mandatory = $false)] [hashtable] $ParentScopeDetails = $null
    )
    
    #region initialize variables
    $childrenTable = @{}
    $resourceGroupsTable = @{}
    $notScopesList = [System.Collections.ArrayList]::new()
    $notScopesTable = @{}
    $excludedScopesTable = @{}
    #endregion initialize variables

    #region get management group details
    $managementGroupType = $ManagementGroup.type
    $managementGroupId = $ManagementGroup.id
    $managementGroupName = $ManagementGroup.name
    $managementGroupDisplayName = $ManagementGroup.displayName
    $managementGroupChildren = $ManagementGroup.children
    if ($ManagementGroup.properties) {
        $managementGroupDisplayName = $ManagementGroup.properties.displayName
        $managementGroupChildren = $ManagementGroup.properties.children
    }
    #endregion get management group details

    #region build scope details
    $thisNotScope = $null
    if ($null -ne $ParentScopeDetails) {
        # the root node is never not in scope or excluded
        if (!$IsInGlobalNotScope) {
            # optimized
            foreach ($globalNotScope in $PacEnvironment.globalNotScopesManagementGroups) {
                if ($managementGroupId -like $globalNotScope) {
                    $thisNotScope = $managementGroupId
                    $IsInGlobalNotScope = $true
                    $IsExcluded = $true
                    break
                }
            }
        }
        if (!$IsExcluded) {
            # optimized
            foreach ($globalExcludedScope in $PacEnvironment.desiredState.globalExcludedScopesManagementGroups) {
                if ($managementGroupId -like $globalExcludedScope) {
                    $IsExcluded = $true
                    break
                }
            }
        }
    }
    $scopeDetails = @{
        id                  = $managementGroupId
        type                = $managementGroupType
        name                = $managementGroupName
        displayName         = $managementGroupDisplayName
        parentTable         = $ParentTable
        childrenTable       = $childrenTable
        resourceGroupsTable = $resourceGroupsTable
        notScopesList       = $notScopesList
        notScopesTable      = $notScopesTable
        excludedScopesTable = $excludedScopesTable
        isExcluded          = $IsExcluded
        isInGlobalNotScope  = $IsInGlobalNotScope
        state               = "Enabled"
        location            = "global"
    }
    if ($IsExcluded) {
        $null = $excludedScopesTable.Add($managementGroupId, $scopeDetails)
    }
    if ($IsInGlobalNotScope) {
        $null = $notScopesTable.Add($managementGroupId, $scopeDetails)
        if ($null -ne $thisNotScope) {
            $null = $notScopesList.Add($thisNotScope)
        }
    }
    $myChildrensParentTable = $ParentTable.Clone()
    $null = $myChildrensParentTable.Add($managementGroupId, $scopeDetails)
    #endregion build scope details

    #region recurse down the tree
    if ($null -ne $managementGroupChildren) {
        foreach ($child in $managementGroupChildren) {
            $childId = $child.id
            $childScopeDetails = $null
            if ($child.type -eq "/subscriptions") {
                $childScopeDetails = Build-ScopeTableForSubscription `
                    -SubscriptionId $child.name `
                    -SubscriptionName $child.displayName `
                    -ResourceGroupsBySubscriptionId $ResourceGroupsBySubscriptionId `
                    -PacEnvironment $PacEnvironment `
                    -ScopeTable $ScopeTable `
                    -IsExcluded $IsExcluded `
                    -IsInGlobalNotScope $IsInGlobalNotScope `
                    -ParentTable $myChildrensParentTable `
                    -ParentScopeDetails $scopeDetails
            }
            else {
                $childScopeDetails = Build-ScopeTableForManagementGroup `
                    -ManagementGroup $child `
                    -ResourceGroupsBySubscriptionId $ResourceGroupsBySubscriptionId `
                    -PacEnvironment $PacEnvironment `
                    -ScopeTable $ScopeTable `
                    -IsExcluded $IsExcluded `
                    -IsInGlobalNotScope $IsInGlobalNotScope `
                    -ParentTable $myChildrensParentTable `
                    -ParentScopeDetails $scopeDetails
            }
            $null = $ScopeTable.Add($childId, $childScopeDetails)
        }
    }
    #endregion recurse down the tree

    #region augment this parents scope's details with this management group's details
    if ($null -ne $ParentScopeDetails) {
        $parentScopeChildrenTable = $ParentScopeDetails.childrenTable
        $parentScopeResourceGroupsTable = $ParentScopeDetails.resourceGroupsTable
        $parentScopeNotScopesList = $ParentScopeDetails.notScopesList
        $parentScopeNotScopesTable = $ParentScopeDetails.notScopesTable
        $parentScopeExcludedScopesTable = $ParentScopeDetails.excludedScopesTable

        foreach ($child in $childrenTable.Keys) {
            $null = $parentScopeChildrenTable.Add($child, $childrenTable.$child)
        }
        $null = $parentScopeChildrenTable.Add($managementGroupId, $scopeDetails)

        foreach ($resourceGroup in $resourceGroupsTable.Keys) {
            $null = $parentScopeResourceGroupsTable.Add($resourceGroup, $resourceGroupsTable.$resourceGroup)
        }

        $null = $parentScopeNotScopesList.AddRange($notScopesList)
        foreach ($notScope in $notScopesTable.Keys) {
            $null = $parentScopeNotScopesTable.Add($notScope, $notScopesTable.$notScope)
        }

        foreach ($excludedScope in $excludedScopesTable.Keys) {
            $null = $parentScopeExcludedScopesTable.Add($excludedScope, $excludedScopesTable.$excludedScope)
        }
    }
    #endregion augment this parents scope's details with this management group's details

    return $scopeDetails
}