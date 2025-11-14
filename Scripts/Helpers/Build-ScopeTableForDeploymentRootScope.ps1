function Build-ScopeTableForDeploymentRootScope {

    param(
        [hashtable] $PacEnvironment
    )

    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    $tenantId = $PacEnvironment.tenantId
    
    Write-ModernSection -Title "Building Scope Tree" -Color Blue
    Write-ModernStatus -Message "Environment: $($PacEnvironment.pacSelector)" -Status "info" -Indent 2
    Write-ModernStatus -Message "Root scope: $($deploymentRootScope -replace '/providers/Microsoft.Management','')" -Status "info" -Indent 2

    $scopeTable = @{}
    $tenantId = $PacEnvironment.tenantId
    $resourceGroupsBySubscriptionId = @{}
    $deploymentRootScopeSubscriptionId = $null
    $deploymentRootScopeManagementGroupName = $null
    $scopeSplat = $null
    $resourceGroupQuery = "resourcecontainers | where type == 'microsoft.resources/subscriptions/resourcegroups'"
    if ($deploymentRootScope.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
        $deploymentRootScopeManagementGroupName = $deploymentRootScope -replace "/providers/Microsoft.Management/managementGroups/"
        $scopeSplat = @{
            ManagementGroup = $deploymentRootScopeManagementGroupName
        }
    }
    elseif ($deploymentRootScope.StartsWith("/subscriptions/") -and $deploymentRootScope -notLike "*/resourceGroups/*") {
        $deploymentRootScopeSubscriptionId = $deploymentRootScope -replace "/subscriptions/"
        $scopeSplat = @{
            Subscription = $deploymentRootScopeSubscriptionId
        }
        $resourceGroupQuery = "resourcecontainers | where type == 'microsoft.resources/subscriptions/resourcegroups' and subscriptionId == '$($deploymentRootScopeSubscriptionId)'"
    }
    else {
        throw "Invalid deploymentRootScope: $deploymentRootScope"
    }

    #region collect resource groups
    $resourceGroups = Search-AzGraphAllItems `
        -Query $resourceGroupQuery `
        -ScopeSplat $scopeSplat `
        -ProgressItemName "Resource Groups"
    Write-ModernStatus -Message "Processing $($resourceGroups.Count) Resource Groups..." -Status "info" -Indent 2
    foreach ($resourceGroup in $resourceGroups) {
        $subscriptionId = $resourceGroup.subscriptionId
        $id = $resourceGroup.id
        if ($PacEnvironment.desiredState.excludeSubscriptions) {
            $isExcluded = $true
        }
        else {
            $isExcluded = $false
        }
        $isInGlobalNotScope = $false
        foreach ($globalNotScope in $PacEnvironment.globalNotScopesResourceGroups) {
            if ($id -like $globalNotScope) {
                $isExcluded = $true
                $isInGlobalNotScope = $true
                break
            }
        }
        if (!$isExcluded) {
            foreach ($excludedScope in $PacEnvironment.globalExcludedScopesResourceGroups) {
                if ($id -like $excludedScope) {
                    $isExcluded = $true
                    break
                }
            }
        }
        $scopeDetails = @{
            id                  = $resourceGroup.id
            type                = $resourceGroup.type
            name                = $resourceGroup.name
            displayName         = $resourceGroup.name
            parentTable         = @{}
            childrenTable       = @{}
            resourceGroupsTable = @{}
            notScopesList       = [System.Collections.ArrayList]::new()
            notScopesTable      = @{}
            excludedScopesTable = @{}
            isExcluded          = $isExcluded
            isInGlobalNotScope  = $isInGlobalNotScope
            state               = $resourceGroup.properties.provisioningState
            location            = $resourceContainer.location
        }

        $resourceGroupList = $null
        if ($resourceGroupsBySubscriptionId.ContainsKey($subscriptionId)) {
            $resourceGroupList = $resourceGroupsBySubscriptionId.$subscriptionId
        }
        else {
            $resourceGroupList = [System.Collections.ArrayList]::new()
            $null = $resourceGroupsBySubscriptionId.Add($subscriptionId, $resourceGroupList)
        }
        $null = $resourceGroupList.Add($scopeDetails)
    }
    #endregion collect resource groups

    #region process subscriptions and/or management groups
    $scopeDetails = $null
    if ($null -ne $deploymentRootScopeSubscriptionId) {
        $subscription = Get-AzSubscription -SubscriptionId $deploymentRootScopeSubscriptionId -TenantId $tenantId -ErrorAction Stop
        $subscriptionId = $subscription.Id
        $scopeDetails = Build-ScopeTableForSubscription `
            -SubscriptionId $subscriptionId `
            -SubscriptionName $subscription.Name `
            -ResourceGroupsBySubscriptionId $resourceGroupsBySubscriptionId `
            -PacEnvironment $PacEnvironment `
            -ScopeTable $scopeTable
    }
    else {
        $managementGroup = Get-AzManagementGroupRestMethod -GroupId $deploymentRootScopeManagementGroupName -Expand  -Recurse  -ErrorAction Stop
        $scopeDetails = Build-ScopeTableForManagementGroup `
            -ManagementGroup $managementGroup `
            -ResourceGroupsBySubscriptionId $resourceGroupsBySubscriptionId `
            -PacEnvironment $PacEnvironment `
            -ScopeTable $scopeTable
    }
    $null = $scopeTable.Add($scopeDetails.id, $scopeDetails)
    $null = $scopeTable.Add("root", $scopeDetails)

    # count each type of scope
    $numberOfManagementGroups = 0
    $numberOfSubscriptions = 0
    $numberofResourceGroups = 0
    foreach ($scopeDetails in $scopeTable.Values) {
        if ($scopeDetails.type -eq "Microsoft.Management/managementGroups") {
            $numberOfManagementGroups++
        }
        elseif ($scopeDetails.type -eq "/subscriptions") {
            $numberOfSubscriptions++
        }
        elseif ($scopeDetails.type -eq "microsoft.resources/subscriptions/resourcegroups") {
            $numberofResourceGroups++
        }
    }
    #endregion process subscriptions and/or management groups

    Write-ModernSection -Title "Scope Tree Complete" -Color Green
    if ($numberOfManagementGroups -gt 0) {
        $numberOfManagementGroups-- # subtract 1 for the root scope
        Write-ModernStatus -Message "Management groups: $($numberOfManagementGroups)" -Status "success" -Indent 2
    }
    if ($deploymentRootScope.StartsWith("/subscriptions/")) {
        $numberOfSubscriptions-- # subtract 1 for the root scope
    }
    Write-ModernStatus -Message "Subscriptions: $($numberOfSubscriptions)" -Status "success" -Indent 2
    Write-ModernStatus -Message "Resource groups: $($numberofResourceGroups)" -Status "success" -Indent 2

    return $scopeTable
}