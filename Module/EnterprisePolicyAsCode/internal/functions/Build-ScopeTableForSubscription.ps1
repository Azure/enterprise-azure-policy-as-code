function Build-ScopeTableForSubscription {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)] [string] $SubscriptionId,
        [parameter(Mandatory = $true)] [string] $SubscriptionName,
        [parameter(Mandatory = $true)] [hashtable] $ResourceGroupsBySubscriptionId,
        [parameter(Mandatory = $true)] $PacEnvironment,
        [parameter(Mandatory = $false)] [hashtable] $ScopeTable = @{},
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
    $thisSubscriptionResourceGroups = [System.Collections.ArrayList]::new()
    if ($resourceGroupsBySubscriptionId.ContainsKey($subscriptionId)) {
        $thisSubscriptionResourceGroups = $resourceGroupsBySubscriptionId.$subscriptionId
    }
    $subscriptionResourceId = "/subscriptions/$SubscriptionId"
    #endregion initialize variables

    #region build scope details
    $thisNotScope = $null
    if ($PacEnvironment.desiredState.excludeSubscriptions) {
        $IsExcluded = $true
    }
    if ($null -ne $ParentScopeDetails) {
        # the root node is never not in scope or excluded
        if (!$IsInGlobalNotScope) {
            # optimized
            foreach ($globalNotScope in $PacEnvironment.globalNotScopesSubscriptions) {
                if ($subscriptionResourceId -like $globalNotScope) {
                    $thisNotScope = $subscriptionResourceId
                    $IsInGlobalNotScope = $true
                    $IsExcluded = $true
                    break
                }
            }
        }
        if (!$IsExcluded) {
            # optimized
            foreach ($globalExcludedScope in $PacEnvironment.desiredState.globalExcludedScopesSubscriptions) {
                if ($subscriptionResourceId -like $globalExcludedScope) {
                    $IsExcluded = $true
                    break
                }
                if ($SubscriptionName -like $globalExcludedScope) {
                    $IsExcluded = $true
                    break
                }
                if ($globalExcludedScope -match "/subscriptions/subscriptionsPattern/") {
                    if ($SubscriptionName -match $globalExcludedScope.Split("/")[-1]) {
                        $IsExcluded = $true
                        break
                    }
                }
            }
        }
    }
    $scopeDetails = @{
        id                  = $subscriptionResourceId
        type                = "/subscriptions"
        name                = $subscriptionId
        displayName         = $subscriptionName
        parentTable         = $ParentTable
        childrenTable       = $childrenTable
        resourceGroupsTable = $resourceGroupsTable
        notScopesList       = $notScopesList
        notScopesTable      = $notScopesTable
        excludedScopesTable = $excludedScopesTable
        isExcluded          = $IsExcluded
        isInGlobalNotScope  = $IsInGlobalNotScope
        state               = $resourceContainer.State
        location            = "global"
    }
    if ($IsExcluded) {
        $null = $excludedScopesTable.Add($subscriptionResourceId, $scopeDetails)
    }
    if ($IsInGlobalNotScope) {
        $null = $notScopesTable.Add($subscriptionResourceId, $scopeDetails)
        if ($null -ne $thisNotScope) {
            $null = $notScopesList.Add($thisNotScope)
        }
    }
    $myChildrensParentTable = $ParentTable.Clone()
    $null = $myChildrensParentTable.Add($subscriptionResourceId, $scopeDetails)
    #endregion build scope details

    #region augment resource groups scope details
    foreach ($thisSubscriptionResourceGroup in $thisSubscriptionResourceGroups) {
        $resourceGroupId = $thisSubscriptionResourceGroup.id
        $thisSubscriptionResourceGroup.parentTable = $myChildrensParentTable
        If ($IsInGlobalNotScope) {
            $thisSubscriptionResourceGroup.isInGlobalNotScope = $true
        }
        elseif ($thisSubscriptionResourceGroup.isInGlobalNotScope) {
            $null = $notScopesList.Add($resourceGroupId)
        }
        if ($IsExcluded) {
            $thisSubscriptionResourceGroup.isExcluded = $true
        }
        
        $null = $ScopeTable.Add($resourceGroupId, $thisSubscriptionResourceGroup)
        $null = $childrenTable.Add($resourceGroupId, $thisSubscriptionResourceGroup)
        $null = $resourceGroupsTable.Add($resourceGroupId, $thisSubscriptionResourceGroup)
        if ($thisSubscriptionResourceGroup.isInGlobalNotScope) {
            $null = $notScopesTable.Add($resourceGroupId, $thisSubscriptionResourceGroup)
        }
        if ($thisSubscriptionResourceGroup.isExcluded) {
            $null = $excludedScopesTable.Add($resourceGroupId, $thisSubscriptionResourceGroup)
        }
    }
    #endregion augment resource groups scope details

    #region augment this parents scope's details with this subscription's details
    if ($null -ne $ParentScopeDetails) {
        $parentScopeChildrenTable = $ParentScopeDetails.childrenTable
        $parentScopeResourceGroupsTable = $ParentScopeDetails.resourceGroupsTable
        $parentScopeNotScopesList = $ParentScopeDetails.notScopesList
        $parentScopeNotScopesTable = $ParentScopeDetails.notScopesTable
        $parentScopeExcludedScopesTable = $ParentScopeDetails.excludedScopesTable

        foreach ($child in $childrenTable.Keys) {
            $null = $parentScopeChildrenTable.Add($child, $childrenTable.$child)
        }
        $null = $ParentScopeDetails.childrenTable.Add($subscriptionResourceId, $scopeDetails)

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
    #endregion augment this parents scope's details with this subscription's details

    return $scopeDetails
}