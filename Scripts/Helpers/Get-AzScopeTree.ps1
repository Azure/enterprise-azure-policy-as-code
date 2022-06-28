#Requires -PSEdition Core
<#
.SYNOPSIS
    Finds all Management Groups, Subscriptions and Resource Groups and collects them into a scope Tree structure.
    Parameters tenantId and scopeParam determine the root of the tree
#>

function Get-AzResourceGroupsForSubscription {
    [CmdletBinding()]
    param (
        [string] $SubscriptionId
    )

    $resourceGroups = Invoke-AzCli group list --subscription $SubscriptionId
    $resourceGroupIdsHashTable = @{}
    $null = $resourceGroups | ForEach-Object { $resourceGroupIdsHashTable[$_.id] = $_ }

    return $resourceGroupIdsHashTable
}
function Get-AzScopeTree {

    param(
        [Parameter(Mandatory = $true,
            HelpMessage = "tenantID is required to disambiguate users known in multiple teannts.")]
        [string]$tenantId,

        [parameter(Mandatory = $true,
            HelpMessage = "scopeParam is the root scope.")]
        [hashtable] $scopeParam,

        [parameter(Mandatory = $false)]
        [string] $defaultSubscriptionId = $null
    )

    # Management Group -> Find all MGs, Subscriptions
    $prefBackup = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    $subscriptionTable = @{}
    $singleSubscription = $null
    $scopeTree = $null
    Write-Information "==================================================================================================="
    Write-Information "Get scope tree information (Mangement Groups, Subscriptions and Resource Groups)"
    Write-Information "==================================================================================================="

    if ($scopeParam.ContainsKey("SubscriptionId")) {
        $subscriptionId = $scopeParam.SubscriptionId
        $subscription = Invoke-AzCli account subscription show --subscription-id $scopeParam.SubscriptionId --only-show-errors
        $resourceGroupIdsHashTable = Get-AzResourceGroupsForSubscription -SubscriptionId $subscriptionId
        Write-Information "Single Subscription $($subscription.displayName) ($($subscriptionId)) with $($resourceGroupIdsHashTable.Count) Resource Groups"
        $singleSubscription = $subscription.id
        $subscriptionTable[$singleSubscription] = @{
            Name             = $subscription.displayName
            State            = $subscription.state
            Id               = $singleSubscriptionsubscriptionId
            FullId           = $singleSubscription
            ResourceGroupIds = $resourceGroupIdsHashTable
        }
    }
    elseif ($scopeParam.ContainsKey("ManagementGroupName")) {

        $scopeTree = Invoke-AzCli account management-group show --name $scopeParam.ManagementGroupName --expand --recurse
        Write-Information "Management Group $($scopeTree.displayName) ($($scopeTree.id))"

        # Get all subscriptions and their resource groups and put them in a hashtable by subscription id
        # Write-Host "##[command] Get-AzSubscription"
        $subscriptions = Invoke-AzCli account list --all
        foreach ($subscription in $subscriptions) {
            if ($tenantId -eq $subscription.tenantId) {
                # Ignore subscriptions in other tenants the identity has access permissions (only for interactive users)
                $resourceGroupIdsHashTable = @{}
                if ($subscription.state -eq "Enabled") {
                    $resourceGroupIdsHashTable = Get-AzResourceGroupsForSubscription -SubscriptionId $subscription.id
                }
                $fullSubscriptionId = "/subscriptions/$($subscription.id)"
                Write-Information "Subscription $($subscription.name) ($($fullSubscriptionId)) with $($resourceGroupIdsHashTable.Count) Resource Groups"
                $subscriptionTable[$fullSubscriptionId] = @{
                    Name             = $subscription.name
                    State            = $subscription.state
                    Id               = $subscription.id
                    FullId           = $fullSubscriptionId
                    ResourceGroupIds = $resourceGroupIdsHashTable
                }
            }
        }
    }
    else {
        Write-Error "##[Error] Scope must be Management Group or a Subscription"
    }
    $WarningPreference = $prefBackup

    Write-Information ""
    Write-Information ""

    $scopeTreeInfo = @{
        ScopeTree          = $scopeTree
        SingleSubscription = $singleSubscription
        SubscriptionTable  = $subscriptionTable
    }
    $scopeTreeInfo
}