#Requires -PSEdition Core

function Add-Assignments {
    param (
        [array]     $assignmentList,
        [string]    $header,
        [string]    $scope,
        [hashtable] $allPolicyDefinitions,
        [hashtable] $allPolicySetDefinitions,
        [bool]      $getAssignments,
        [bool]      $getRemediations,
        [hashtable] $assignments,
        [hashtable] $remediations,
        [bool]      $suppressRoleAssignments
    )

    #region $maybeRemediations
    $maybeRemediations = $false
    $complianceStateSummaryCollection = $null
    if ($getRemediations) {
        foreach ($assignment in $assignmentList) {
            if ($null -ne $assignment.identity -and $null -ne $assignment.identity.principalId) {
                $maybeRemediations = $true
                break
            }
        }
        if ($maybeRemediations) {
            # This call is expensive, only issue if at least one assignment may need a remediation
            # - especially true for subscription-level assignments
            $complianceStateSummary = (Invoke-AzCli policy state summarize -assignmentScopeId $scope `
                    --filter "`"(policyDefinitionAction eq 'deployifnotexists' or policyDefinitionAction eq 'modify')`"" `
                    -AsHashTable)

            if ($null -ne $complianceStateSummary) {
                $complianceStateSummaryCollection = $complianceStateSummary.policyAssignments
                if ($complianceStateSummary.Length -eq 0) {
                    $maybeRemediations = $false
                }
            }
            else {
                $maybeRemediations = $false
            }
        }
    }
    #     policyresources
    #     | where type == "microsoft.policyinsights/policystates"
    #     | where properties.complianceState == "NonCompliant" and properties.policyDefinitionAction in ( "modify", "deployifnotexists" )
    # |

    #     policyresources
    #     | where type == "microsoft.policyinsights/policystates"
    #     | where properties.complianceState == "NonCompliant" and properties.policyDefinitionAction in ( "modify", "deplyifnotecists" )
    #     | summarize count() by tostring(properties.policyAssignmentId), tostring(properties.policyDefinitionAction), tostring(properties.policyDefinitionReferenceId)
    #     | order by properties_policyAssignmentId asc
    #endregion

    $numberOfAssignmentsWithRemediations = 0 # How many assignment requiring remediation(s) are at this scope
    $headerDisplayed = $false
    foreach ($assignment in $assignmentList) {

        #region Assignment details and Role Assignments
        if ($getAssignments) {
            if (-not $headerDisplayed) {
                Write-Information $header
                $headerDisplayed = $true
            }
            $existingRoleAssignments = @()
            if (-not $suppressRoleAssignments -and $null -ne $assignment.identity -and $null -ne $assignment.identity.principalId) {
                # Collate existing role assignments at Policy assignment scope and at additionalRoleAssignments scope(s)
                $existingRoleAssignments = @() + (Invoke-AzCli role assignment list --scope $scope --assignee $assignment.identity.principalId --only-show-errors)
                $principalId = $assignment.identity.principalId
                $scopesChecked = @{
                    $assignment.scope = $true
                }
                if ($assignment.metadata -and $assignment.metadata.roles) {
                    foreach ($role in $assignment.metadata.roles) {
                        if (-not $scopesChecked.ContainsKey($role.scope)) {
                            $additionalRoleAssignmentsInAzure = @() + (Invoke-AzCli role assignment list --scope $role.scope --assignee $principalId --only-show-errors)
                            $null = $scopesChecked.Add($role.scope, $true)
                            $existingRoleAssignments += $additionalRoleAssignmentsInAzure
                        }
                    }
                }
                Write-Information "    `'$($assignment.displayName)`': $($existingRoleAssignments.Length) Role Assignments"
            }
            else {
                Write-Information "    `'$($assignment.displayName)`'"
            }

            $value = @{
                assignment      = $assignment
                roleAssignments = $existingRoleAssignments
            }
            $null = $assignments.Add($assignment.id, $value)
        }

        #endregion

        #region Remediations
        if ($maybeRemediations -and $null -ne $assignment.identity -and $null -ne $assignment.identity.principalId) {
            foreach ($summary in $complianceStateSummaryCollection) {
                $id = $summary.policyAssignmentId
                if ($id -eq $assignment.id) {
                    # Match
                    $assignmentResult = $summary.results
                    if ($assignmentResult.nonCompliantResources -gt 0) {
                        if (-not $headerDisplayed) {
                            Write-Information "$header"
                            $headerDisplayed = $true
                        }
                        if ($getAssignments) {
                            Write-Information "        NonCompliant Resources=$($assignmentResult.nonCompliantResources)"
                        }
                        else {
                            # Display subheader
                            Write-Information "    '$($assignment.displayName)', NonCompliant Resources=$($assignmentResult.nonCompliantResources)"
                        }
                        # Write-Information "        NonCompliantResources Total=$($assignmentResultNonCompliantResources)"
                        $numberOfAssignmentsWithRemediations++
                        $remediationTasks = @()
                        $policySetDefinitionId = $summary.policySetDefinitionId
                        $policySetDefinition = $null
                        if ($policySetDefinitionId -ne "") {
                            $policySetDefinition = $allPolicySetDefinitions[$policySetDefinitionId]
                            # Write-Information "        Assigned Policy Set '$($policySetDefinition.displayName)'"
                        }
                        foreach ($policyDefinition in $summary.policyDefinitions) {
                            # Check if this PolicyDefinition needs remediation
                            $policyDefinitionResults = $policyDefinition.results
                            if ($policyDefinitionResults.nonCompliantResources -gt 0) {
                                $policyDefinitionId = $policyDefinition.policyDefinitionId
                                $nonCompliantResources = $policyDefinitionResults.nonCompliantResources
                                $policyDefinitionReferenceId = $policyDefinition.policyDefinitionReferenceId
                                $policyDefinitionFull = $allPolicyDefinitions[$policyDefinitionId]
                                $assignmentName = $assignment.name
                                $assignmentDisplayName = $assignment.displayName
                                $taskName = $assignmentName -replace '\s', '-'
                                if ($null -ne $policySetDefinition) {
                                    $taskName = "$($taskName)__$($policyDefinitionReferenceId)"
                                }
                                $remediationTask = @{
                                    assignmentId                = $id
                                    assignmentName              = $assignmentName
                                    assignmentDisplayName       = $assignmentDisplayName
                                    taskName                    = $taskName
                                    policyDefinitionId          = $policyDefinitionId
                                    nonCompliantResources       = $nonCompliantResources
                                    policySetName               = $policySetDefinition.name
                                    policySetDisplayName        = $policySetDefinition.displayName
                                    policyDefinitionReferenceId = $policyDefinitionReferenceId
                                    policyName                  = $policyDefinitionFull.name
                                    policyDisplayName           = $policyDefinitionFull.displayName
                                }
                                $remediationTasks += $remediationTask
                            }
                        }
                        if ($remediations.ContainsKey($scope)) {
                            $remediationsAtScope = $remediations.$scope
                            $null = $remediationsAtScope.Add($id, $assignmentRemediation)
                        }
                        else {
                            $null = $remediations.Add($scope, @{
                                    $id = $assignmentRemediation
                                }
                            )
                        }
                    }
                    break
                }
            }
        }
        #endregion
    }

}

function Get-AzAssignmentsAtSpecificScope {
    [CmdletBinding()]
    param (
        [string]    $scope,
        [bool]      $getAssignments,
        [bool]      $getExemptions,
        [bool]      $getRemediations,
        [hashtable] $allPolicyDefinitions,
        [hashtable] $allPolicySetDefinitions,
        [hashtable] $assignments,
        [hashtable] $exemptions,
        [hashtable] $remediations,
        [bool]      $suppressRoleAssignments
    )

    $splits = $scope.Split('/')
    if ($scope.Contains("/subscriptions/")) {

        # First element is an empty string due to leading forward slash (/)
        # $subscriptionId = $splits[2]
        # $null = (Invoke-AzCli account set --subscription $subscriptionId)

        if ($splits.Length -ge 5) {
            # Resource Group scope
            if ($getAssignments -or $getRemediations) {
                $assignmentList = @() + (Invoke-AzCli policy assignment list --scope $scope)
                if ($assignmentList.Length -gt 0) {
                    $header = "Resource Group $scope with $($assignmentList.Length) Policy Assignments"
                    Add-Assignments `
                        -assignmentList $assignmentList `
                        -header $header `
                        -scope $scope `
                        -allPolicyDefinitions $allPolicyDefinitions `
                        -allPolicySetDefinitions $allPolicySetDefinitions `
                        -getAssignments $getAssignments `
                        -getRemediations $getRemediations `
                        -assignments $assignments `
                        -remediations $remediations `
                        -suppressRoleAssignments $suppressRoleAssignments
                }
            }
        }
        else {
            # Subscription scope
            if ($getAssignments -or $getRemediations) {
                $assignmentList = @() + (Invoke-AzCli policy assignment list --scope $scope)
                if ($assignmentList.Length -gt 0) {
                    $header = "Subscription $subscriptionId with $($assignmentList.Length) Policy Assignments"
                    Add-Assignments `
                        -assignmentList $assignmentList `
                        -header $header `
                        -scope $scope `
                        -allPolicyDefinitions $allPolicyDefinitions `
                        -allPolicySetDefinitions $allPolicySetDefinitions `
                        -getAssignments $getAssignments `
                        -getRemediations $getRemediations `
                        -assignments $assignments `
                        -remediations $remediations `
                        -suppressRoleAssignments $suppressRoleAssignments
                }
            }
            if ($getExemptions) {
                $exemptionList = (Invoke-AzCli policy exemption list --disable-scope-strict-match --scope $scope)
                foreach ($exemptionRaw in $exemptionList) {
                    $exemptionId = $exemptionRaw.id
                    if (-not $exemptions.ContainsKey($exemptionId)) {
                        $name = $exemptionRaw.name

                        [array] $splits = $exemptionId -split "/"
                        $numberOfSplits = $splits.Count
                        $scopeLastIndex = $numberOfSplits - 5
                        $scopeSplits = $splits[0..$scopeLastIndex]
                        $scope = $scopeSplits -join "/"

                        $displayName = $exemptionRaw.displayName
                        $description = $exemptionRaw.description
                        $exemptionCategory = $exemptionRaw.exemptionCategory
                        $expiresOn = $exemptionRaw.expiresOn
                        $policyAssignmentId = $exemptionRaw.policyAssignmentId
                        $policyDefinitionReferenceIds = $exemptionRaw.policyDefinitionReferenceIds
                        $metadata = $exemptionRaw.metadata
                        $exemption = @{
                            name               = $name
                            scope              = $scope
                            policyAssignmentId = $policyAssignmentId
                            exemptionCategory  = $exemptionCategory
                        }
                        if ($displayName -and $displayName -ne "") {
                            $null = $exemption.Add("displayName", $displayName)
                        }
                        if ($description -and $description -ne "") {
                            $null = $exemption.Add("description", $description)
                        }
                        if ($expiresOn) {
                            $expiresOnUtc = $expiresOn.ToUniversalTime()
                            $null = $exemption.Add("expiresOn", $expiresOnUtc)

                        }
                        if ($policyDefinitionReferenceIds -and $policyDefinitionReferenceIds.Count -gt 0) {
                            $null = $exemption.Add("policyDefinitionReferenceIds", $policyDefinitionReferenceIds)
                        }
                        if ($metadata -and $metadata -ne @{} ) {
                            $null = $exemption.Add("metadata", $metadata)
                        }
                        $null = $exemptions.Add($exemptionId, $exemption)
                    }
                }
            }
        }
    }
    else {
        # Management Groups scope
        if ($getAssignments -or $getRemediations) {
            $assignmentList = @() + (Invoke-AzCli policy assignment list --scope $scope)
            $mg = $splits[-1]
            if ($assignmentList.Length -gt 0) {
                $header = "Management Group $mg with $($assignmentList.Length) Policy Assignments"
                Add-Assignments `
                    -assignmentList $assignmentList `
                    -header $header `
                    -scope $scope `
                    -allPolicyDefinitions $allPolicyDefinitions `
                    -allPolicySetDefinitions $allPolicySetDefinitions `
                    -getAssignments $getAssignments `
                    -getRemediations $getRemediations `
                    -assignments $assignments `
                    -remediations $remediations `
                    -suppressRoleAssignments $suppressRoleAssignments
            }
        }
    }
}

function Get-AzAssignmentsAtScopeRecursive {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $True)] [object]     $scopeTreeInfo,
        [parameter(Mandatory = $false)] [array]     $notScopeIn = @(),
        [parameter(Mandatory = $false)] [bool]      $includeResourceGroups = $false,
        [parameter(Mandatory = $false)] [bool]      $getAssignments = $true,
        [parameter(Mandatory = $false)] [bool]      $getExemptions = $true,
        [Parameter(Mandatory = $false)] [int]       $expiringInDays = 7,
        [parameter(Mandatory = $false)] [bool]      $getRemediations = $false,
        [parameter(Mandatory = $false)] [hashtable] $allPolicyDefinitions = $null,
        [parameter(Mandatory = $false)] [hashtable] $allPolicySetDefinitions = $null,
        [switch] $suppressRoleAssignments
    )

    [array] $subscriptionIds = @()
    [hashtable] $assignmentsInAzure = @{}
    [hashtable] $exemptions = @{}
    [hashtable] $remediations = @{}

    # Check parameters
    if ($getRemediations) {
        if ($null -eq $allPolicyDefinitions -or $null -eq $allPolicySetDefinitions) {
            $errorText = "getRemediations require `$allPolicyDefinitions and `$allPolicySetDefinitions not to be `$null"
            Write-Error $errorText
            Throw $errorText
        }
    }
    if (-not ($getAssignments -or $getRemediations)) {

    }

    Write-Information "==================================================================================================="
    Write-Information "Get Policy and Role Assignments recursively"
    Write-Information "==================================================================================================="

    if ($null -ne $scopeTreeInfo.ScopeTree) {
        # Management Group -> Process Management Groups and Subscriptions
        if ($includeResourceGroups) {
            Write-Information "Management Group $($scopeTreeInfo.ScopeTree.displayName) ($($scopeTreeInfo.ScopeTree.id)), Subscriptions and Resource Groups"
        }
        else {
            Write-Information "Management Group $($scopeTreeInfo.ScopeTree.displayName) ($($scopeTreeInfo.ScopeTree.id)) and Subscriptions"
        }
        $queuedScope = [System.Collections.Queue]::new()
        $null = $queuedScope.Enqueue($scopeTreeInfo.ScopeTree)
        Write-Debug "    Enqueue $($scopeTreeInfo.ScopeTree.id)"
        while ($queuedScope.Count -gt 0) {
            $currentMg = $queuedScope.Dequeue()
            Write-Debug "Testing $($currentMg.id)"
            Get-AzAssignmentsAtSpecificScope -scope $currentMg.id `
                -getAssignments $getAssignments `
                -getRemediations $getRemediations `
                -allPolicyDefinitions $allPolicyDefinitions `
                -allPolicySetDefinitions $allPolicySetDefinitions `
                -assignments $assignmentsInAzure `
                -remediations $remediations `
                -suppressRoleAssignments $suppressRoleAssignments
            foreach ($child in $currentMg.children) {
                if (!$notScopeIn -and $notScopeIn.Contains($child.id)) {
                    Write-Information "Skipping notScope $($child.name) ($($child.id))"
                }
                else {
                    if ($child.Id.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
                        $null = $queuedScope.Enqueue($child)
                        Write-Debug "    Enqueue child $($child.id)"
                    }
                    else {
                        # Subscription
                        $subscription = $scopeTreeInfo.SubscriptionTable[$child.id]
                        if ($subscription.state -eq "Enabled") {
                            $subscriptionIds += $child.id
                        }
                    }
                }
            }
        }
    }
    else {
        $subscriptionTable = $scopeTreeInfo.SubscriptionTable
        $fullSubscriptionId = $subscriptionTable.Keys[0]
        $subscription = $subscriptionTable.$fullSubscriptionId
        if ($includeResourceGroups) {
            Write-Information "Single Subscription $($subscription.name) ($($subscription.id)) and Resource Groups"
        }
        else {
            Write-Information "Single Subscription $($subscription.name) ($($subscription.id))"
        }
        $subscriptionIds += $fullSubscriptionId
    }

    # Find Resource Groups in all subscriptions in notScope
    if ($subscriptionIds.Length -gt 0) {
        # Find out if we need to process any Resource Groups
        $notScopeResourceGroupIds = $()
        $notScopePatterns = @()
        if ($notScopeIn -and $includeResourceGroups) {
            foreach ($nsi in $notScopeIn) {
                if ($nsi.Contains("/resourceGroups/")) {
                    $notScopeResourceGroupIds += $nsi
                }
                elseif ($nsi.Contains("/resourceGroupPatterns/")) {
                    $nspTrimmed = $nsi.Split("/")[-1]
                    $notScopePatterns += $nspTrimmed
                }
            }
        }

        $subscriptionTable = $scopeTreeInfo.SubscriptionTable
        foreach ($subscriptionId in $subscriptionIds) {
            $subscriptionEntry = $subscriptionTable[$subscriptionId]
            if ($subscriptionEntry.State -eq "Enabled") {
                Get-AzAssignmentsAtSpecificScope -scope $subscriptionId `
                    -getAssignments $getAssignments `
                    -getExemptions $getExemptions `
                    -getRemediations $getRemediations `
                    -allPolicyDefinitions $allPolicyDefinitions `
                    -allPolicySetDefinitions $allPolicySetDefinitions `
                    -assignments $assignmentsInAzure `
                    -exemptions $exemptions `
                    -remediations $remediations `
                    -suppressRoleAssignments $suppressRoleAssignments

                if ($includeResourceGroups) {
                    # Ignore inactive subscriptions
                    $originalSubscriptionResourceGroupIds = $subscriptionEntry.ResourceGroupIds
                    if ($originalSubscriptionResourceGroupIds){$subscriptionResourceGroupIds = $originalSubscriptionResourceGroupIds.clone()}else{$subscriptionResourceGroupIds=@{}}
                    # Write-Information "    Checking $($originalSubscriptionResourceGroupIds.Count) RGs in subscription $($subscriptionEntry.Name) ($($subscriptionId))"

                    # Eliminate notScope fully qualified resource Group Ids
                    foreach ($nrg in $notScopeResourceGroupIds) {
                        if ($originalSubscriptionResourceGroupIds.ContainsKey($nrg)) {
                            Write-Debug "    Added Resource Group from full resourceId to notScope: $nrg"
                            $null = $subscriptionResourceGroupIds.Remove($nrg)
                        }
                    }

                    # Eliminate notScope patterns
                    foreach ($nsp in $notScopePatterns) {
                        foreach ($rg in $originalSubscriptionResourceGroupIds.Keys) {
                            $rgShort = $rg.Split("/")[-1]
                            if ($rgShort -like $nsp) {
                                Write-Debug "    Added Resource Group $rg from pattern $nsp to notScope"
                                $null = $subscriptionResourceGroupIds.Remove($rg)
                            }
                        }
                    }

                    # Find assignments
                    foreach ($rg in $subscriptionResourceGroupIds.Keys) {
                        Write-Debug "    Added Resource Group $rg Assignments"
                        Get-AzAssignmentsAtSpecificScope -scope $rg `
                            -getAssignments $getAssignments `
                            -getRemediations $getRemediations `
                            -allPolicyDefinitions $allPolicyDefinitions `
                            -allPolicySetDefinitions $allPolicySetDefinitions `
                            -assignments $assignmentsInAzure `
                            -remediations $remediations `
                            -suppressRoleAssignments $suppressRoleAssignments
                    }
                }
            }
        }
    }
    Write-Information ""
    Write-Information ""


    return $assignmentsInAzure, $remediations, $exemptions

}