#Requires -PSEdition Core

function Get-AssignmentDefs {
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
    $def = Get-DeepClone -InputObject $assignmentDef

    # Process mandatory nodeName
    if ($definitionNode.nodeName) {
        $def.nodeName += $definitionNode.nodeName
        # ignore "comment" field
        Write-Debug "        nodePath = $($def.nodeName):"
    }
    else {
        Write-Error "Missing nodename at child"
        $def.hasErrors = $true
    }

    if ($definitionNode.ignoreBranch) {
        # ignoring a branch can be useful for prep work to an upcumming state
        Write-Verbose "        Ignore branch at $($def.nodeName) reason ignore branch"
        $def.ignoreBranch = $definitionNode.ignoreBranch
    }
    # Process assignment name, displayName and description (need at least one per tree). Strings are concatenated
    if ($definitionNode.assignment) {
        $def.assignment.name += $definitionNode.assignment.Name
        $def.assignment.displayName += $definitionNode.assignment.displayName
        $def.assignment.description += $definitionNode.assignment.description
        Write-Debug "        assignment = $($def.assignment | ConvertTo-Json -Depth 100)"
    }

    # Process name of Policy or Initiative
    if ($definitionNode.definitionEntry) {
        if ($def.definitionEntry) {
            Write-Error "Node $($values.nodeName): multiple Policy/Initiative definition at different tree levels are not allowed"
            $def.hasErrors = $true
        }
        else {
            # Can contain one or more items at ONE level
            $def.definitionEntry = $definitionNode.definitionEntry
            Write-Debug "        definitionEntry = $($def.definitionEntry | ConvertTo-Json -Depth 100)"
        }
    }

    # Process meta data
    if ($definitionNode.metadata) {
        if ($def.metadata) {
            Write-Error "Node $($def.nodeName): multiple metadata definitions at different tree levels are not allowed"
            $def.hasErrors = $true
        }
        else {
            # Can contain one or more items at ONE level
            $def.metadata = $definitionNode.metadata
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
            Write-Error "Node $($def.nodeName): enforcementMode must be Default or DoNotEnforce. It is ""$($enforcementMode)."
            $def.hasErrors = $true
        }
    }

    # Process parameters; parameters defined at a deeper level override previous parmeters (union operator)
    if ($definitionNode.parameters) {
        Write-Debug "        parameters inherited $($def.parameters | ConvertTo-Json -Depth 100)"
        Write-Debug "        parameters at node   $($definitionNode.parameters | ConvertTo-Json -Depth 100)"
        foreach ($definedParameterAtNode in $definitionNode.parameters.psobject.Properties) {
            $parameterName = $definedParameterAtNode.Name
            $def.parameters[$parameterName] = $definedParameterAtNode.Value
        }
        Write-Debug "        parameters = $($def.parameters.Count)"
    }

    # Process additional permissions needed to execute remediations; for example permissions to log to Event Hub, Storgae Account or Log Analytics
    # Entries are cumulative (added to an array)
    if ($definitionNode.additionalRoleAssignments) {
        Write-Debug "        additionalRoleAssignments at node   $($definitionNode.additionalRoleAssignments | ConvertTo-Json -Depth 100)"
        foreach ($possibleAdditionalRoleAssignment in $definitionNode.additionalRoleAssignments.psobject.Properties) {
            $selector = $possibleAdditionalRoleAssignment.Name
            if ($selector -eq "*" -or $selector -eq $pacEnvironmentSelector) {
                if ($def.additionalRoleAssignments) {
                    $def.additionalRoleAssignments += $possibleAdditionalRoleAssignment.Value
                }
                else {
                    $def.additionalRoleAssignments = @() + $possibleAdditionalRoleAssignment.Value
                }
            }
        }
    }

    if ($definitionNode.managedIdentityLocation) {
        $managedIdentityLocation = $null
        foreach ($possibleManagedIdentityLocation in $definitionNode.managedIdentityLocation.psobject.Properties) {
            $selector = $possibleManagedIdentityLocation.Name
            if ($selector -eq "*" -or $selector -eq $pacEnvironmentSelector) {
                $managedIdentityLocation = $possibleManagedIdentityLocation.Value
                break
            }
        }
        if ($null -ne $managedIdentityLocation) {
            $def.managedIdentityLocation = $managedIdentityLocation
        }
    }

    if ($def.scopeCollection) {
        # Once a scopeList is defined at a parent, no descendant may define scopeList or notScope
        if ($definitionNode.scope) {
            Write-Error "Node $($values.nodeName): multiple ScopeList definition at different tree levels are not allowed"
            $def.hasErrors = $true
        }
        if ($definitionNode.notScope) {
            Write-Error "Node $($values.nodeName): detected notScope definition in in a child node when the scope was already defined"
            $def.hasErrors = $true
        }
    }
    else {
        # may define notScope
        if ($definitionNode.notScope) {
            Write-Debug "         notScope defined at $($def.nodeName) = $($definitionNode.notScope | ConvertTo-Json -Depth 100)"
            foreach ($possibleNotScopeList in $definitionNode.notScope.psobject.Properties) {
                $selector = $possibleNotScopeList.Name
                if ($selector -eq "*" -or $selector -eq $pacEnvironmentSelector) {
                    if ($def.notScope) {
                        $def.notScope += $possibleNotScopeList.Value
                    }
                    else {
                        $def.notScope = @() + $possibleNotScopeList.Value
                    }
                }
            }
        }

        if ($definitionNode.scope) {
            ## Found a scope list - process notScope
            $scopeList = $null
            foreach ($possibleScopeList in $definitionNode.scope.psobject.Properties) {
                $selector = $possibleScopeList.Name
                if ($selector -eq "*" -or $selector -eq $pacEnvironmentSelector) {
                    $scopeList = @() + $possibleScopeList.Value
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
        Write-Debug " $($definitionNode.children.Count) children below at $($def.nodeName)"
        foreach ($child in $definitionNode.children) {
            $defList += Get-AssignmentDefs `
                -scopeTreeInfo $scopeTreeInfo `
                -definitionNode $child `
                -assignmentDef $def `
                -pacEnvironmentSelector $pacEnvironmentSelector
        }
    }
    else {
        # Arrived at a leaf node - return the values colelcted in this branch

        # Must contain one scope
        if (-not ($null -ne $def.scopeCollection -or $def.hasOnlyNotSelectedEnvironments -or $def.ignoreBranch)) {
            Write-Error "Node $($values.nodeName): no scope defined in tree - requires excactly one scope definition in each tree branch"
            $def.hasErrors = $true
        }

        $defList += $def
    }
    return , $defList
}
