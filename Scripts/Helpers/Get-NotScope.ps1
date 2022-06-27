#Requires -PSEdition Core
function Get-NotScope {
    param(
        [parameter(Mandatory = $True)] [object]          $scopeTreeInfo,
        [parameter(Mandatory = $True)] [string[]]        $scopeList,
        [parameter(Mandatory = $True)] [string[]]        $notScopeIn
    )

    $scopeCollection = @()
    foreach ($scope in $scopeList) {
        # Write-Host "##[command] processing scope $($scope)"

        if ($scope.Contains("/resourceGroups/")) {
            $scopeCollection += @{
                scope    = "$scope"
                notScope = @()
            }
        }
        else {
            $notScope = @()
            $subscriptionIds = @()
            if ($scope.StartsWith("/subscriptions/")) {
                # Subscription --> Add to list of subscriptions to test Resource Groups -- List will contain one entry
                $subscriptionIds += $scope
                # Write-Host "##[debug] adding subscription to test RGs $($scope.Id)"
            }
            elseif ($scope.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
                if ($null -eq $scopeTreeInfo.ScopeTree) {
                    # Root scope is a subscription, assignment scope is not allowed to be a Management Group
                    # Flag as error
                    Write-Error "Error Management Group '$scope' not allowed when root scope is subscription '$($scopeTreeInfo.SubscriptionTable.values[0].Name)'" -ErrorAction Stop
                }
                else {
                    # Management Group -> Process Management Groups and Subscriptions
                    $queuedManagementGroups = [System.Collections.Queue]::new()
                    $null = $queuedManagementGroups.Enqueue($scopeTreeInfo.ScopeTree)
                    $rootFound = $false
                    # Write-Host "##[debug] enqueue $($scopeTreeInfo.ScopeTree.Id)"
                    while ($queuedManagementGroups.Count -gt 0) {
                        $currentMg = $queuedManagementGroups.Dequeue()
                        # Write-Host "##[debug] testing $($currentMg.Id)"
                        if ($rootFound) {
                            foreach ($child in $currentMg.children) {
                                if ($notScopeIn.Contains($child.id)) {
                                    $notScope += "$($child.id)"
                                    # Write-Host "##[debug] notScope added $($child.Id)"
                                }
                                elseif ($child.type -eq "Microsoft.Management/managementGroups") {
                                    $null = $queuedManagementGroups.Enqueue($child)
                                    # Write-Host "##[debug] enqueue child $($child.Id)"
                                }
                                elseif ($child.type -eq "/subscriptions") {
                                    # Write-Host "##[debug] subscription testing list += subscription $($child.Id)"
                                    $subscriptionIds += $child.id
                                }
                                else {
                                    Write-Error "Traversal of scopeTree to find notScopes in scope '$scope' yielded an unknown type '$($child.type)' name='$($child.name)'" -ErrorAction Stop
                                }
                            }
                        }
                        else {
                            # Are we at $root?
                            if ($scope -eq $currentMg.id) {
                                # Root found
                                # Write-Host "Found root $scope"
                                $null = $queuedManagementGroups.Clear()
                                $null = $queuedManagementGroups.Enqueue($currentMg)
                                $rootFound = $true
                            }
                            else {
                                foreach ($child in $currentMg.children) {
                                    if ($child.type -eq "Microsoft.Management/managementGroups") {
                                        $null = $queuedManagementGroups.Enqueue($child)
                                        # Write-Host "##[command] finding root enqueue child $($child.Id)"
                                    }
                                    elseif ($child.type -ne "/subscriptions") {
                                        Write-Error "Traversal of scopeTree to find scope '$scope' yielded an unknown type '$($child.type)' name='$($child.name)'" -ErrorAction Stop
                                    }
                                }
                            }
                        }
                    }
                }
            }
            else {
                Write-Error "Invalid scope '$scope' specified" -ErrorAction Stop
            }

            if ($subscriptionIds.Length -gt 0) {
                # Find out if we need to process any Resource Groups
                $notScopeResourceGroupIds = $()
                $notScopePatterns = @()
                foreach ($nsi in $notScopeIn) {
                    if ($nsi.Contains("/resourceGroups/")) {
                        $notScopeResourceGroupIds += $nsi
                    }
                    elseif ($nsi.Contains("/resourceGroupPatterns/")) {
                        $nspTrimmed = $nsi.Split("/")[-1]
                        $notScopePatterns += $nspTrimmed
                        # Write-Host "##[debug] Checking pattern $nsi, trimmed pattern against $nspTrimmed, nsp starts with $($nspTrimmed.Substring(0,1))"
                    }
                }

                # Write-Host "Testing subscriptionIds($($subscriptionIds.Count)), notScopeResourceGroupIds($($notScopeResourceGroupIds.Count)), notScopePatterns($($notScopePatterns.Count))"
                # Find Resource Groups in all subscriptions in notScope
                $table = $scopeTreeInfo.SubscriptionTable
                foreach ($subscriptionId in $subscriptionIds) {
                    $subscriptionEntry = $table[$subscriptionId]
                    # Write-Host "table[$trimmedSubscriptionId] = $($subscriptionEntry | ConvertTo-Json -Depth 100)"
                    if ($subscriptionEntry.State -ne "Enabled") {
                        # Auto-notScope inactive subscriptions
                        # Write-Host "##[debug] Added inactive subscription (State $($subscriptionEntry.State)) to notScope: $($subscriptionEntry.Name), $($trimmedSubscriptionId)"
                        $notScope += $subscriptionId
                    }
                    else {
                        $subscriptionResourceGroupIds = $subscriptionEntry.ResourceGroupIds
                        # Write-Host "Testing `$ResourceGroupIds($($subscriptionResourceGroupIds.Count)), `$notScopeResourceGroupIds($($notScopeResourceGroupIds.Count)), `$notScopePatterns($($notScopePatterns.Count))"

                        # Process fully quified resource Group Ids
                        foreach ($nrg in $notScopeResourceGroupIds) {
                            if ($subscriptionResourceGroupIds.ContainsKey($nrg)) {
                                # Write-Host "##[debug] Added Resource Group from full resourceId to notScope: $nrg"
                                $notScope += $nrg
                            }
                        }

                        # Process patterns
                        foreach ($nsp in $notScopePatterns) {
                            foreach ($nrg in $subscriptionResourceGroupIds.Keys) {
                                $rgShort = $nrg.Split("/")[-1]
                                if ($rgShort -like $nsp) {
                                    # Write-Host "##[debug] Added Resource Group $rg from pattern $nsp to notScope"
                                    $notScope += $nrg
                                }
                            }
                        }
                    }
                }
            }
            $scopeCollection += @{
                scope    = $scope
                notScope = $notScope
            }
        }
    }
    # Write-Host("##[debug] scopeCollection = $($scopeCollection | ConvertTo-Json -Depth 100)")
    return , $scopeCollection
}
