#Requires -PSEdition Core

function Add-Assignments {
    param (
        [array]     $assignmentList,
        [string]    $header,
        [string]    $scope,
        [hashtable] $scopeSplat,
        [hashtable] $allPolicyDefinitions,
        [hashtable] $allInitiativeDefinitions,
        [bool]      $getAssignments,
        [bool]      $getRemediations,
        [hashtable] $assignments,
        [hashtable] $remediations,
        [bool]      $supressRoleAssignments
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
            # - especially true for subscription-level assignements
            $complianceStateSummary = (Invoke-AzCli policy state summarize `
                    --filter "`"(policyDefinitionAction eq 'deployifnotexists' or policyDefinitionAction eq 'modify')`"" `
                    -Splat $scopeSplat -AsHashTable)

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
            if (-not $supressRoleAssignments -and $null -ne $assignment.identity -and $null -ne $assignment.identity.principalId) {
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
            $assignments.Add($assignment.id, $value)
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
                        $initiativeDefinitionId = $summary.policySetDefinitionId
                        $initiativeDefinition = $null
                        if ($initiativeDefinitionId -ne "") {
                            $initiativeName = $initiativeDefinitionId.Split('/')[-1]
                            $initiativeDefinition = $allInitiativeDefinitions[$initiativeName]
                            # Write-Information "        Assigned Initiative '$($initiativeDefinition.displayName)'"
                        }
                        foreach ($policyDefinition in $summary.policyDefinitions) {
                            # Check if this PolicyDefinition needs remmediation
                            $policyDefinitionResults = $policyDefinition.results
                            if ($policyDefinitionResults.nonCompliantResources -gt 0) {
                                [hashtable] $splat = $scopeSplat.Clone()
                                $policyDefinitionId = $policyDefinition.policyDefinitionId
                                $policyName = $policyDefinitionId.Split('/')[-1]
                                $nonCompliantResources = $policyDefinitionResults.nonCompliantResources
                                $policyDefinitionReferenceId = $policyDefinition.policyDefinitionReferenceId
                                $policyDefinitionFull = $allPolicyDefinitions[$policyName]
                                # Write-Information "        NonCompliantResources=$($nonCompliantResources), Policy='$($policyDefinitionFull.displayName)'"
                                [hashtable] $policyInfo = @{
                                    policyDefinitionId          = $policyDefinitionId
                                    nonCompliantResources       = $nonCompliantResources
                                    policyDefinitionReferenceId = $policyDefinitionReferenceId
                                    policyName                  = $policyName
                                    policyDisplayName           = $policyDefinitionFull.displayName
                                }
                                $splat.Add("policy-assignment", $id)
                                $assignmentDisplayName = $assignment.name
                                $taskName = $assignmentDisplayName -replace '\s', '-'
                                if ($null -eq $initiativeDefinition) {
                                    # Single Policy
                                    $splat.Add("name", $taskName)
                                }
                                else {
                                    # Policy within an Initiative
                                    $splat.Add("name", "$($taskName)__$($policyDefinition.policyDefinitionReferenceId)")
                                    $splat.Add("definition-reference-id", $policyDefinition.policyDefinitionReferenceId)
                                }
                                $remediationTasks += @{
                                    info  = $policyInfo
                                    splat = $splat
                                }
                            }
                        }
                        $assignmentRemediation = @{
                            assignmentDisplayName = $assignment.displayName
                            initiativeId          = $initiativeDefinitionId
                            remediationTasks      = $remediationTasks
                            nonCompliantResources = $assignmentResult.nonCompliantResources
                        }
                        if ($null -ne $initiativeDefinition) {
                            $assignmentRemediation += @{
                                initiativeName        = $initiativeName
                                initiativeDisplayName = $initiativeDefinition.displayName
                            }
                        }
                        if ($remediations.ContainsKey($scope)) {
                            $remediations[$scope].Add($id, $assignmentRemediation)
                        }
                        else {
                            $remediations.Add($scope, @{
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
        [hashtable] $allInitiativeDefinitions,
        [hashtable] $assignments,
        [hashtable] $exemptions,
        [hashtable] $remediations,
        [bool]      $supressRoleAssignments
    )

    $splits = $scope.Split('/')
    if ($scope.Contains("/subscriptions/")) {
        # First element is an emoty string due to leading /
        $subscriptionId = $splits[2]
        $null = Invoke-AzCli account set --subscription $subscriptionId
        if ($splits.Length -ge 5) {
            # Resource Group scope
            if ($getAssignments -or $getRemediations) {
                $assignmentList = @() + (Invoke-AzCli policy assignment list --resource-group $scope)
                if ($assignmentList.Length -gt 0) {
                    $header = "Resource Group $scope with $($assignmentList.Length) Policy Assignments"
                    $rg = $splits[-1]
                    [hashtable] $scopeSplat = @{
                        subscription     = $subscriptionId
                        "resource-group" = $rg
                    }
                    Add-Assignments `
                        -assignmentList $assignmentList `
                        -header $header `
                        -scope $scope `
                        -scopeSplat $scopeSplat `
                        -allPolicyDefinitions $allPolicyDefinitions `
                        -allInitiativeDefinitions $allInitiativeDefinitions `
                        -getAssignments $getAssignments `
                        -getRemediations $getRemediations `
                        -assignments $assignments `
                        -remediations $remediations `
                        -supressRoleAssignments $supressRoleAssignments
                }
            }
        }
        else {
            # Subscription scope
            if ($getAssignments -or $getRemediations) {
                $assignmentList = @() + (Invoke-AzCli policy assignment list --scope $scope)
                if ($assignmentList.Length -gt 0) {
                    $header = "Subscription $subscriptionId with $($assignmentList.Length) Policy Assignments"
                    [hashtable] $scopeSplat = @{
                        subscription = $subscriptionId
                    }
                    Add-Assignments `
                        -assignmentList $assignmentList `
                        -header $header `
                        -scope $scope `
                        -scopeSplat $scopeSplat `
                        -allPolicyDefinitions $allPolicyDefinitions `
                        -allInitiativeDefinitions $allInitiativeDefinitions `
                        -getAssignments $getAssignments `
                        -getRemediations $getRemediations `
                        -assignments $assignments `
                        -remediations $remediations `
                        -supressRoleAssignments $supressRoleAssignments
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
                            $exemption.Add("displayName", $displayName)
                        }
                        if ($description -and $description -ne "") {
                            $exemption.Add("description", $description)
                        }
                        if ($expiresOn) {
                            $expiresOnUtc = $expiresOn.ToUniversalTime()
                            $exemption.Add("expiresOn", $expiresOnUtc)

                        }
                        if ($policyDefinitionReferenceIds -and $policyDefinitionReferenceIds.Count -gt 0) {
                            $exemption.Add("policyDefinitionReferenceIds", $policyDefinitionReferenceIds)
                        }
                        if ($metadata -and $metadata -ne @{} ) {
                            $exemption.Add("metadata", $metadata)
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
                [hashtable] $scopeSplat = @{
                    "management-group" = $mg
                }
                Add-Assignments `
                    -assignmentList $assignmentList `
                    -header $header `
                    -scope $scope `
                    -scopeSplat $scopeSplat `
                    -allPolicyDefinitions $allPolicyDefinitions `
                    -allInitiativeDefinitions $allInitiativeDefinitions `
                    -getAssignments $getAssignments `
                    -getRemediations $getRemediations `
                    -assignments $assignments `
                    -remediations $remediations `
                    -supressRoleAssignments $supressRoleAssignments
            }
        }
    }
}

function Get-AzAssignmentsAtScopeRecursive {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $True)] [object]     $scopeTreeInfo,
        [parameter(Mandatory = $True)] [string[]]   $notScopeIn,
        [parameter(Mandatory = $false)] [bool]      $includeResourceGroups = $false,
        [parameter(Mandatory = $false)] [bool]      $getAssignments = $true,
        [parameter(Mandatory = $false)] [bool]      $getExemptions = $true,
        [Parameter(Mandatory = $false)] [int]       $expiringInDays = 7,
        [parameter(Mandatory = $false)] [bool]      $getRemediations = $false,
        [parameter(Mandatory = $false)] [hashtable] $allPolicyDefinitions = $null,
        [parameter(Mandatory = $false)] [hashtable] $allInitiativeDefinitions = $null,
        [switch] $supressRoleAssignments
    )

    [array] $subscriptionIds = @()
    [hashtable] $assignmentsInAzure = @{}
    [hashtable] $exemptions = @{}
    [hashtable] $remediations = @{}

    # Check parameters
    if ($getRemediations) {
        if ($null -eq $allPolicyDefinitions -or $null -eq $allInitiativeDefinitions) {
            $errorText = "getRemediations require `$allPolicyDefinitions and `$allInitiativeDefinitions not to be `$null"
            Write-Error $errorText
            Throw $errorText
        }
    }
    if (-not ($getAssignments -or $getRemediations)) {

    }

    Write-Information "==================================================================================================="
    Write-Information "Get Policy and Role Assignments recursively"
    Write-Information "==================================================================================================="
    if ($scopeTreeInfo.SingleSubscription) {
        Write-Information "Single Subscription $($scopeTreeInfo.SingleSubscription) and Resource Groups"
        $subscriptionIds += $scopeTreeInfo.SingleSubscription
        Get-AzAssignmentsAtSpecificScope -scope "$($scopeTreeInfo.SingleSubscription)" `
            -getAssignments $getAssignments `
            -getExemptions $getExemptions `
            -getRemediations $getRemediations `
            -allPolicyDefinitions $allPolicyDefinitions `
            -allInitiativeDefinitions $allInitiativeDefinitions `
            -assignments $assignmentsInAzure `
            -exemptions $exemptions `
            -remediations $remediations `
            -supressRoleAssignments $supressRoleAssignments.IsPresent
    }
    elseif ($null -ne $scopeTreeInfo.ScopeTree) {
        # Management Group -> Process Management Groups and Subscriptions
        Write-Information "Management Group $($scopeTreeInfo.ScopeTree.displayName) ($($scopeTreeInfo.ScopeTree.id)), Subscriptions and Resource Groups"
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
                -allInitiativeDefinitions $allInitiativeDefinitions `
                -assignments $assignmentsInAzure `
                -remediations $remediations `
                -supressRoleAssignments $supressRoleAssignments.IsPresent
            foreach ($child in $currentMg.children) {
                if ($notScopeIn.Contains($child.id)) {
                    Write-Information "Skipping notScope $($child.name) ($($child.id))"
                }
                else {
                    if ($child.Id.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
                        $null = $queuedScope.Enqueue($child)
                        Write-Debug "    Enqueue child $($child.id)"
                    }
                    else {
                        # Subscription
                        $subscriptionEntry = $scopeTreeInfo.SubscriptionTable[$child.id]
                        if ($subscriptionEntry.state -eq "Enabled") {
                            Write-Debug "    Subscription testing list += subscription $($child.id)"
                            Get-AzAssignmentsAtSpecificScope -scope $child.id `
                                -getAssignments $getAssignments `
                                -getExemptions $getExemptions `
                                -getRemediations $getRemediations `
                                -allPolicyDefinitions $allPolicyDefinitions `
                                -allInitiativeDefinitions $allInitiativeDefinitions `
                                -assignments $assignmentsInAzure `
                                -exemptions $exemptions `
                                -remediations $remediations `
                                -supressRoleAssignments $supressRoleAssignments.IsPresent
                            $subscriptionIds += $child.id
                        }
                    }
                }
            }
        }
    }

    Write-Debug "Testing subscriptionIds($($subscriptionIds.Count)), notScopeResourceGroupIds($($notScopeResourceGroupIds.Count)), notScopePatterns($($notScopePatterns.Count))"
    # Find Resource Groups in all subscriptions in notScope
    if ($subscriptionIds.Length -gt 0 -and $includeResourceGroups) {
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
                Write-Debug "    Checking pattern '$nsi', trimmed pattern '$nspTrimmed'"
            }
        }

        $table = $scopeTreeInfo.SubscriptionTable
        foreach ($subscriptionId in $subscriptionIds) {
            $subscriptionEntry = $table[$subscriptionId]
            Write-Debug "table[$subscriptionId] = $($subscriptionEntry | ConvertTo-Json -Depth 100)"
            if ($subscriptionEntry.State -eq "Enabled") {
                # Ignore inactive subscriptions
                $originalSubscriptionResourceGroupIds = $subscriptionEntry.ResourceGroupIds
                $subscriptionResourceGroupIds = $originalSubscriptionResourceGroupIds.Clone()
                # Write-Information "    Checking $($originalSubscriptionResourceGroupIds.Count) RGs in subscription $($subscriptionEntry.Name) ($($subscriptionId))"

                # Eliminate notScope fully quified resource Group Ids
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
                        -allInitiativeDefinitions $allInitiativeDefinitions `
                        -assignments $assignmentsInAzure `
                        -remediations $remediations `
                        -supressRoleAssignments $supressRoleAssignments.IsPresent
                }
            }
        }
    }
    Write-Information ""
    Write-Information ""


    return $assignmentsInAzure, $remediations, $exemptions

}