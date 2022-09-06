#Requires -PSEdition Core

function Get-AssignmentDefinitions {
    # Recursive Function
    param(
        [parameter(Mandatory = $True,
            HelpMessage = "Prefetechetd tree of scopes starting at root scope")]
        [hashtable] $scopeTreeInfo,

        [parameter(Mandatory = $True,
            HelpMessage = "Selects the scope list for the environemt deployment")]
        [string] $pacEnvironmentSelector,

        [parameter(Mandatory = $True,
            HelpMessage = "Current node containing a definition fragment")]
        [PSObject] $definitionNode,

        [parameter(Mandatory = $True,
            HelpMessage = "The values collected so far in this tree")]
        [hashtable] $assignmentDef

        # Returns a list os completed assignmentValues
    )

    # Each tree branch needs a private copy
    $def = Get-DeepClone -InputObject $assignmentDef -AsHashTable

    # Process mandatory nodeName
    $nodeName = ""
    if ($definitionNode.nodeName) {
        $nodeName += $definitionNode.nodeName
        $def.nodeName += $nodeName
        # ignore "comment" field
        Write-Debug "        nodePath = $($def.nodeName):"
    }
    else {
        $nodeName = "$($def.nodeName)//Unknown//"
        Write-Error "    Missing nodename at child of $($def.nodeName)"
        $def.hasErrors = $true
    }

    if ($definitionNode.ignoreBranch) {
        # ignoring a branch can be useful for prep work to an upcumming state
        Write-Verbose "        Ignore branch at $($def.nodeName) reason ignore branch"
        $def.ignoreBranch = $definitionNode.ignoreBranch
    }
    # Process assignment name, displayName and description (need at least one per tree). Strings are concatenated
    if ($definitionNode.assignment) {
        $def.assignment.name += $definitionNode.assignment.name
        $def.assignment.displayName += $definitionNode.assignment.displayName
        $def.assignment.description += $definitionNode.assignment.description
        Write-Debug "        assignment = $($def.assignment | ConvertTo-Json -Depth 100)"
    }

    # Process name of Policy or Initiative
    if ($definitionNode.definitionEntry) {
        if ($def.definitionEntry) {
            Write-Error "    Node $($nodeName): multiple Policy/Initiative definitionEntry or definitionEntryList are not allowed.`n    Previous definitionEntry=$($def.definitionEntry | ConvertTo-Json -Compress)`n    Current definitionEntry=$($definitionNode.definitionEntry | ConvertTo-Json -Compress)"
            $def.hasErrors = $true
        }
        elseif ($def.definitionEntryList) {
            Write-Error "   Node $($nodeName): multiple Policy/Initiative definitionEntry or definitionEntryList are not allowed.`n    Previous definitionEntryList=$($def.definitionEntryList | ConvertTo-Json -Compress)`n    Current definitionEntry=$($definitionNode.definitionEntry | ConvertTo-Json -Compress)"
            $def.hasErrors = $true
        }
        else {
            # Can contain one or more items at ONE level
            $def.definitionEntry = Get-DeepClone $definitionNode.definitionEntry -AsHashTable
            Write-Debug "        definitionEntry = $($def.definitionEntry | ConvertTo-Json -Depth 100)"
        }
    }

    # Process name of Policy or Initiative
    if ($definitionNode.definitionEntryList) {
        if ($def.definitionEntry) {
            Write-Error "    Node $($nodeName): multiple Policy/Initiative definitionEntry or definitionEntryList are not allowed.`n    Previous definitionEntry=$($def.definitionEntry | ConvertTo-Json -Compress)`n    Current definitionEntryList=$($definitionNode.definitionEntryList | ConvertTo-Json -Compress)"
            $def.hasErrors = $true
        }
        elseif ($def.definitionEntryList) {
            Write-Error "    Node $($nodeName): multiple Policy/Initiative definitionEntry or definitionEntryList are not allowed.`n    Previous definitionEntryList=$($def.definitionEntryList | ConvertTo-Json -Compress)`n    Current definitionEntry=$($definitionNode.definitionEntryList | ConvertTo-Json -Compress)"
            $def.hasErrors = $true
        }
        else {
            # Can contain one or more items at ONE level
            $def.definitionEntryList = Get-DeepClone $definitionNode.definitionEntryList -AsHashTable
            Write-Debug "        definitionEntryList = $($def.definitionEntryList | ConvertTo-Json -Depth 100)"
        }
    }

    # Process meta data
    if ($definitionNode.metadata) {
        if ($def.metadata) {
            Write-Error "    Node $($nodeName): multiple metadata definitions at different tree levels are not allowed"
            $def.hasErrors = $true
        }
        else {
            # Can contain one or more items at ONE level
            $def.metadata = Get-DeepClone $definitionNode.metadata -AsHashTable
            Write-Debug "        metadata = $($def.metadata)"
        }
    }

    # Process enforcementMode
    if ($definitionNode.enforcementMode) {
        $enforcementMode = $definitionNode.enforcementMode
        if ("Default", "DoNotEnforce" -contains $enforcementMode) {
            $def.enforcementMode = $enforcementMode
        }
        else {
            Write-Error "    Node $($nodeName): enforcementMode must be Default or DoNotEnforce. It is ""$($enforcementMode)."
            $def.hasErrors = $true
        }
    }

    # Process parameters; parameters defined at a deeper level override previous parameters (union operator)
    if ($definitionNode.parameters) {
        $inheritedParameters = $def.parameters
        $addedParameters = $definitionNode.parameters
        Write-Debug "        parameters inherited $($inheritedParameters | ConvertTo-Json -Depth 100)"
        Write-Debug "        parameters at node   $($addedParameters | ConvertTo-Json -Depth 100)"
        foreach ($parameterName in $addedParameters.Keys) {
            if ($addedParameters.$parameterName -is [array]) {
                $parameterValue = $addedParameters.$parameterName
            }
            else {
                $parameterValue = Get-DeepClone $addedParameters.$parameterName -AsHashTable
            }
            if ($inheritedParameters.ContainsKey($parameterName)) {
                $def.parameters[$parameterName] = $parameterValue
            }
            else {
                $def.parameters.Add($parameterName, $parameterValue)
            }
        }
        Write-Debug "        parameters = $($def.parameters.Count)"
    }

    # Process additional permissions needed to execute remediations; for example permissions to log to Event Hub, Storgae Account or Log Analytics
    # Entries are cumulative (added to an array)
    if ($definitionNode.additionalRoleAssignments) {
        $additionalRoleAssignments = $definitionNode.additionalRoleAssignments
        Write-Debug "        additionalRoleAssignments at node   $($additionalRoleAssignments | ConvertTo-Json -Depth 100)"
        foreach ($selector in $additionalRoleAssignments.Keys) {
            if ($selector -eq "*" -or $selector -eq $pacEnvironmentSelector) {
                $additionalRoleAssignmentsList = Get-DeepClone $additionalRoleAssignments.$selector -AsHashTable
                if ($def.additionalRoleAssignments) {
                    $def.additionalRoleAssignments += $additionalRoleAssignmentsList
                }
                else {
                    $def.additionalRoleAssignments = @() + $additionalRoleAssignmentsList
                }
            }
        }
    }

    if ($definitionNode.managedIdentityLocation) {
        $managedIdentityLocationValue = $null
        $managedIdentityLocation = $definitionNode.managedIdentityLocation
        foreach ($selector in $managedIdentityLocation.Keys) {
            if ($selector -eq "*" -or $selector -eq $pacEnvironmentSelector) {
                $managedIdentityLocationValue = $managedIdentityLocation.$selector
                break
            }
        }
        if ($null -ne $managedIdentityLocationValue) {
            $def.managedIdentityLocation = $managedIdentityLocationValue
        }
    }

    if ($def.scopeCollection) {
        # Once a scopeList is defined at a parent, no descendant may define scopeList or notScope
        if ($definitionNode.scope) {
            Write-Error "    Node $($nodeName): multiple ScopeList definition at different tree levels are not allowed"
            $def.hasErrors = $true
        }
        if ($definitionNode.notScope) {
            Write-Error "    Node $($nodeName): detected notScope definition in in a child node when the scope was already defined"
            $def.hasErrors = $true
        }
    }
    else {
        # may define notScope
        if ($definitionNode.notScope) {
            $notScope = $definitionNode.notScope
            Write-Debug "         notScope defined at $($nodeName) = $($notScope | ConvertTo-Json -Depth 100)"
            foreach ($selector in $notScope.Keys) {
                if ($selector -eq "*" -or $selector -eq $pacEnvironmentSelector) {
                    $notScopeList = $notScope.$selector
                    if ($def.notScope) {
                        $def.notScope += $notScopeList
                    }
                    else {
                        $def.notScope = @() + $notScopeList
                    }
                }
            }
        }

        if ($definitionNode.scope) {
            ## Found a scope list - process notScope
            $scopeList = $null
            $scope = $definitionNode.scope
            foreach ($selector in $scope.Keys) {
                if ($selector -eq "*" -or $selector -eq $pacEnvironmentSelector) {
                    $scopeList = @() + $scope.$selector
                    break
                }
            }
            if ($null -eq $scopeList) {
                # This branch does not have a scope for this assignmetSelector; ignore branch
                $def.hasOnlyNotSelectedEnvironments = $true
            }
            else {
                Write-Debug "        scopeList = $($scopeList | ConvertTo-Json -Depth 100)"
                if ($def.notScope) {
                    $uniqueNotScope = @() + ($def.notScope | Sort-Object | Get-Unique)
                    Write-Debug "        Get-NotScope"
                    $def.scopeCollection = Get-NotScope -scopeList $scopeList -notScope $uniqueNotScope -scopeTreeInfo $scopeTreeInfo
                }
                else {
                    $def.scopeCollection = @()
                    foreach ($scope in $scopeList) {
                        $def.scopeCollection += @{
                            scope    = $scope
                            notScope = @()
                        }
                    }
                }
            }
        }
    }

    $defList = @()
    if ($definitionNode.children) {
        # Process child nodes
        Write-Debug " $($definitionNode.children.Count) children below at $($nodeName)"
        foreach ($child in $definitionNode.children) {
            $defList += Get-AssignmentDefinitions `
                -scopeTreeInfo $scopeTreeInfo `
                -definitionNode $child `
                -assignmentDef $def `
                -pacEnvironmentSelector $pacEnvironmentSelector
        }
    }
    else {
        # Arrived at a leaf node - return the values colelcted in this branch after checking validity

        if (-not $def.ignoreBranch) {

            # Start assembling Assignment name, displayName and description
            $name = ""
            $displayName = ""
            $description = ""
            if ($def.assignment) {
                $assignment = $def.assignment
                $name = $assignment.name
                $displayName = $assignment.displayName
                $description = $assignment.description
            }

            # Must contain a definitionEntry or definitionEntryList
            $definitionEntry = $def.definitionEntry
            $definitionEntryList = $def.definitionEntryList
            $policyAssignmentList = @()
            if ($definitionEntry) {
                if ($name.Length -eq 0 -or $displayName.Length -eq 0) {
                    Write-Error "    Leaf Node $($nodeName): each tree branch must specify an Assignment  with a name and a displayName.`n    name=$name`n    displayName=$displayName"
                    $def.hasErrors = $true
                }
                $initiativeName = $definitionEntry.initiativeName
                $policyName = $definitionEntry.policyName
                $friendlyNameToDocumentIfGuid = $definitionEntry.friendlyNameToDocumentIfGuid
                if ($definitionEntry.initiativeName -xor $definitionEntry.policyName) {
                    $policyAssignmentEntry = @{
                        assignment = @{
                            name        = $name
                            displayName = $displayName
                            description = $description
                        }
                    }
                    if ($initiativeName) {
                        $policyAssignmentEntry.Add("initiativeName", $initiativeName)
                    }
                    elseif ($policyName) {
                        $policyAssignmentEntry.Add("policyName", $policyName)
                    }
                    if ($friendlyNameToDocumentIfGuid) {
                        $policyAssignmentEntry.Add("friendlyNameToDocumentIfGuid", $friendlyNameToDocumentIfGuid)
                    }
                    $policyAssignmentList += $policyAssignmentEntry
                }
                else {
                    Write-Error "    Leaf Node $($nodeName): each tree branch must define a definitionEntry with either an initiativeName or a policyName.`n    $($definitionEntry | ConvertTo-Json -Compress)"
                    $def.hasErrors = $true
                }
            }
            elseif ($definitionEntryList -and $definitionEntryList.Count -gt 0) {
                foreach ($definitionEntry in $definitionEntryList) {
                    $finalName = ""
                    $finalDisplayName = ""
                    $finalDescription = ""
                    $assignmentOk = $false
                    if ($definitionEntry.assignment) {
                        $localAssignment = $definitionEntry.assignment
                        $localName = ""
                        $localDisplayName = ""
                        $localDescription = ""
                        $append = $false
                        if ($localAssignment.name) {
                            $localName = $localAssignment.name
                        }
                        if ($localAssignment.displayName) {
                            $localDisplayName = $localAssignment.displayName
                        }
                        if ($localAssignment.description) {
                            $localDescription = $localAssignment.description
                        }
                        if ($localAssignment.append) {
                            $append = $localAssignment.append
                        }
                        if ($localName.Length -gt 0 -and $localDisplayName.Length -gt 0) {
                            $assignmentOk = $true
                        }
                        if ($append) {
                            $finalName = $name + $localName
                            $finalDisplayName = $displayName + $localDisplayName
                            $finalDescription = $description + $localDescription
                        }
                        else {
                            $finalName = $localName + $name
                            $finalDisplayName = $localDisplayName + $displayName
                            $finalDescription = $localDescription + $description
                        }
                    }
                    if (-not $assignmentOk) {
                        Write-Error "    Leaf Node $($nodeName): each definitionEntry in a definitionEntryList must specify an Assignment with a name and a displayName.`n    name=$localName`n    displayName=$localDisplayName"
                        $def.hasErrors = $true
                    }

                    $initiativeName = $definitionEntry.initiativeName
                    $policyName = $definitionEntry.policyName
                    $friendlyNameToDocumentIfGuid = $definitionEntry.friendlyNameToDocumentIfGuid
                    if ($definitionEntry.initiativeName -xor $definitionEntry.policyName) {
                        $policyAssignmentEntry = @{
                            assignment = @{
                                name        = $finalName
                                displayName = $finalDisplayName
                                description = $finalDescription
                            }
                        }
                        if ($initiativeName) {
                            $policyAssignmentEntry.Add("initiativeName", $initiativeName)
                        }
                        if ($policyName) {
                            $policyAssignmentEntry.Add("policyName", $policyName)
                        }
                        if ($friendlyNameToDocumentIfGuid) {
                            $policyAssignmentEntry.Add("friendlyNameToDocumentIfGuid", $friendlyNameToDocumentIfGuid)
                        }
                        $policyAssignmentList += $policyAssignmentEntry
                    }
                    else {
                        Write-Error "    Leaf Node $($nodeName): each definitionEntry in a definitionEntryList must specify either an initiativeName or a policyName.`n    $($definitionEntry | ConvertTo-Json -Compress)"
                        $def.hasErrors = $true
                    }
                }
            }
            else {
                Write-Error "    Leaf Node $($nodeName): each tree branch must define either a definitionEntry or a non-empty definitionEntryList."
                $def.hasErrors = $true
            }
            $def.policyAssignmentList = $policyAssignmentList

            # Must contain one scopeCollection
            if (-not ($def.hasOnlyNotSelectedEnvironments -or $null -ne $def.scopeCollection)) {
                Write-Error "    Leaf Node $($nodeName): each tree branch requires excactly one scope definition."
                $def.hasErrors = $true
            }
            $defList += $def
        }
        else {
            Write-Information "    Leaf Node $($nodeName): tree branch ignored (ignoreBranch)"
        }
    }
    return , $defList
}
