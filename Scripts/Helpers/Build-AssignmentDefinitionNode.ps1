#Requires -PSEdition Core

function Build-AssignmentDefinitionNode {
    # Recursive Function
    param(
        [hashtable] $pacEnvironment,
        [hashtable] $scopeTable,
        [hashtable] $parameterFilesCsv,
        [hashtable] $definitionNode, # Current node
        [hashtable] $assignmentDefinition, # Collected values in tree branch
        [hashtable] $combinedPolicyDetails,
        [hashtable] $policyRoleIds

        # Returns a list os completed assignmentValues
    )

    # Each tree branch needs a private copy
    $definition = Get-DeepClone -InputObject $assignmentDefinition -AsHashTable

    # Process mandatory nodeName
    $nodeName = ""
    if ($definitionNode.nodeName) {
        $nodeName += $definitionNode.nodeName
        $definition.nodeName += $nodeName
        # ignore "comment" field
        Write-Debug "        nodePath = $($nodeName):"
    }
    else {
        $nodeName = "$($nodeName)//Unknown//"
        Write-Error "    Missing nodeName at child of $($nodeName)"
        $definition.hasErrors = $true
    }

    if ($definitionNode.ignoreBranch) {
        # ignoring a branch can be useful for prep work to an future state
        Write-Verbose "        Ignore branch at $($nodeName) reason ignore branch"
        $definition.ignoreBranch = $definitionNode.ignoreBranch
    }
    # Process assignment name, displayName and description (need at least one per tree). Strings are concatenated
    if ($null -ne $definitionNode.assignment) {
        $assignment = $definitionNode.assignment
        if ($null -ne $assignment.name -and ($assignment.name).Length -gt 0 -and $null -ne $assignment.displayName -and ($assignment.displayName).Length -gt 0) {
            $normalizedAssignment = ConvertTo-HashTable $assignment
            if (!$normalizedAssignment.ContainsKey("description")) {
                $normalizedAssignment.description = ""
            }
            # Concatenate information
            $definition.assignment.name += $normalizedAssignment.name
            $definition.assignment.displayName += $normalizedAssignment.displayName
            $definition.assignment.description += $normalizedAssignment.description
        }
        else {
            Write-Error "   Node $($nodeName): each assignment field must define an assignment name and displayName."
            $definition.hasErrors = $true
        }
    }

    # Process definitionEntry or definitionEntryList
    $definitionEntry = $definitionNode.definitionEntry
    $definitionEntryList = $definitionNode.definitionEntryList
    $defEntryList = $definition.definitionEntryList
    if ($null -ne $definitionEntry -or $null -ne $definitionEntryList) {
        if ($null -eq $defEntryList -and ($null -ne $definitionEntry -xor $null -ne $definitionEntryList)) {
            # OK; first and only occurrence in tree branch
            $hasErrors = $false
            if ($null -ne $definitionEntry) {
                # Convert to list
                $definitionEntryList = @( $definitionEntry )
            }
            # Validate list
            $normalizedDefinitionEntryList = @()
            $mustDefineAssignment = $definitionEntryList.Count -gt 1
            foreach ($definitionEntry in $definitionEntryList) {
                $isValid, $normalizedEntry = Build-AssignmentDefinitionEntry `
                    -definitionEntry $definitionEntry `
                    -nodeName $nodeName `
                    -policyDefinitionsScopes $pacEnvironment.policyDefinitionsScopes `
                    -combinedPolicyDetails $combinedPolicyDetails `
                    -mustDefineAssignment:$mustDefineAssignment
                if ($isValid) {
                    $normalizedDefinitionEntryList += $normalizedEntry
                }
                else {
                    $hasErrors = $true
                }
            }
            if ($hasErrors) {
                $definition.hasErrors = $true
            }
            $definition.definitionEntryList = $normalizedDefinitionEntryList
        }
        else {
            if ($null -ne $definitionEntry -or $null -ne $definitionEntryList) {
                Write-Error "   Node $($nodeName): only one definitionEntry or definitionEntryList can appear in any branch."
                $definition.hasErrors = $true
            }
        }
    }

    # Process meta data
    if ($definitionNode.metadata) {
        if ($definition.metadata) {
            # merge metadata
            $metadata = $definition.metadata
            $merge = Get-DeepClone $definitionNode.metadata -AsHashTable
            foreach ($key in $merge) {
                $metadata[$key] = $merge.$key
            }
        }
        else {
            $definition.metadata = Get-DeepClone $definitionNode.metadata -AsHashTable
        }
    }

    # Process enforcementMode
    if ($definitionNode.enforcementMode) {
        $enforcementMode = $definitionNode.enforcementMode
        if ("Default", "DoNotEnforce" -contains $enforcementMode) {
            $definition.enforcementMode = $enforcementMode
        }
        else {
            Write-Error "    Node $($nodeName): enforcementMode must be Default or DoNotEnforce. It is ""$($enforcementMode)."
            $definition.hasErrors = $true
        }
    }

    #region Parameters

    # Process parameters in JSON; parameters defined at a deeper level override previous parameters (union operator)
    if ($definitionNode.parameters) {
        $allParameters = $definition.parameters
        $addedParameters = $definitionNode.parameters
        foreach ($parameterName in $addedParameters.Keys) {
            $rawParameterValue = $addedParameters.$parameterName
            $parameterValue = Get-DeepClone $rawParameterValue -AsHashTable
            $allParameters[$parameterName] = $parameterValue
        }
    }

    # Process parameterFileName and parameterSelector
    if ($definitionNode.parameterSelector) {
        if ($definition.ContainsKey("parameterSelector")) {
            Write-Error "    Node $($nodeName): multiple parameterFileName definitions at different tree levels are not allowed"
            $definition.hasErrors = $true
        }
        else {
            $definition.parameterSelector = $definitionNode.parameterSelector
        }
    }
    if ($definitionNode.parameterFile) {
        if ($definition.ContainsKey("parameterFileName")) {
            Write-Error "    Node $($nodeName): multiple parameterFileName definitions at different tree levels are not allowed."
            $definition.hasErrors = $true
        }
        else {
            $parameterFileName = $definitionNode.parameterFile
            if ($parameterFilesCsv.ContainsKey($parameterFileName)) {
                $fullName = $parameterFilesCsv.$parameterFileName
                $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                $xlsArray = @() + ($content | ConvertFrom-Csv -ErrorAction Stop)
                $csvParameterArray = Get-DeepClone $xlsArray -AsHashTable
                $definition.parameterFileName = $parameterFileName
                $definition.csvParameterArray = $csvParameterArray
                if ($csvParameterArray.Count -eq 0) {
                    Write-Error "    Node $($nodeName):  CSV parameterFile '$parameterFileName'  is empty (zero rows)."
                    $definition.hasErrors = $true
                }
            }
            else {
                Write-Error "    Node $($nodeName):  CSV parameterFileName '$parameterFileName'  does not exist."
                $definition.hasErrors = $true
            }
        }
    }
    if (!$definition.effectColumn -and $definition.ContainsKey("parameterFileName") -and $definition.ContainsKey("parameterSelector")) {
        # Collected a parameterFileName and a parameterSelector, not yet validated column in CSV file
        $csvParameterArray = $definition.csvParameterArray
        $row = $csvParameterArray[0]
        $parameterFileName = $definition.parameterFileName
        $parameterSelector = $definition.parameterSelector
        $effectColumn = "$($parameterSelector)Effect"
        $parametersColumn = "$($parameterSelector)Parameters"
        if (-not ($row.ContainsKey("name") -and $row.ContainsKey("referencePath") -and $row.ContainsKey($effectColumn) -and $row.ContainsKey($parametersColumn))) {
            Write-Error "    Node $($nodeName): CSV parameterFile ($parameterFileName) must contain the following columns: name, referencePath, $effectColumn, $parametersColumn."
            $hasErrors = $true
        }
        $definition.effectColumn = $effectColumn
        $definition.parametersColumn = $parametersColumn
        # $parameterFileNonComplianceMessage = $firstRow.ContainsKey("nonComplianceMessage")
        # if ($definition.ContainsKey("nonComplianceMessage") -and $parameterFileNonComplianceMessage) {
        #     Write-Error "    Node $($nodeName): specifying nonComplianceMessage in JSON and nonComplianceMessage in CSV parameter file is not allowed."
        #     $definition.hasErrors = $true
        # }
        # else {
        #     $definition.parameterFileNonComplianceMessage = $parameterFileNonComplianceMessage
        # }
    }

    #endregion Parameters

    # Process nonComplianceMessage
    # if ($definitionNode.nonComplianceMessage) {
    #     if ($definition.ContainsKey("nonComplianceMessage")) {
    #         Write-Error "    Node $($nodeName): multiple nonComplianceMessage definitions at different tree levels are not allowed."
    #         $definition.hasErrors = $true
    #     }
    #     if ($definition.ContainsKey("parameterFileNonComplianceMessage")) {
    #         Write-Error "    Node $($nodeName): specifying nonComplianceMessage in JSON and nonComplianceMessage in CSV parameter file is not allowed."
    #         $definition.hasErrors = $true
    #     }
    #     else {
    #         $definition.nonComplianceMessage = $definitionNode.nonComplianceMessage
    #     }
    # }

    # Process additional permissions needed to execute remediations; for example permissions to log to Event Hub, Storage Account or Log Analytics
    # Entries are cumulative (added to an array)
    if ($definitionNode.additionalRoleAssignments) {
        $additionalRoleAssignments = $definitionNode.additionalRoleAssignments
        foreach ($selector in $additionalRoleAssignments.Keys) {
            if ($selector -eq "*" -or $selector -eq $pacEnvironment) {
                $additionalRoleAssignmentsList = Get-DeepClone $additionalRoleAssignments.$selector -AsHashTable
                if ($definition.additionalRoleAssignments) {
                    $definition.additionalRoleAssignments += $additionalRoleAssignmentsList
                }
                else {
                    $definition.additionalRoleAssignments = @() + $additionalRoleAssignmentsList
                }
            }
        }
    }

    # Process managedIdentityLocation; can be overridden on the tree
    if ($definitionNode.managedIdentityLocation) {
        $managedIdentityLocationValue = $null
        $managedIdentityLocations = $definitionNode.managedIdentityLocations
        foreach ($selector in $managedIdentityLocations.Keys) {
            if ($selector -eq "*" -or $selector -eq $pacEnvironment) {
                $managedIdentityLocationValue = $managedIdentityLocation.$selector
                break
            }
        }
        if ($null -ne $managedIdentityLocationValue) {
            $definition.managedIdentityLocation = $managedIdentityLocationValue
        }
    }

    # Process scope
    if ($definition.scopeCollection) {
        # Once a scopeList is defined at a parent, no descendant may define scopeList or notScope
        if ($definitionNode.scope) {
            Write-Error "    Node $($nodeName): multiple scope definitions at different tree levels are not allowed"
            $definition.hasErrors = $true
        }
        if ($definitionNode.notScope) {
            Write-Error "    Node $($nodeName): detected notScope definition in in a child node when the scope was already defined"
            $definition.hasErrors = $true
        }
    }
    else {
        # may define notScope
        $pacEnvironmentSelector = $pacEnvironment.pacSelector
        if ($definitionNode.notScope) {
            $notScope = $definitionNode.notScope
            Write-Debug "         notScope defined at $($nodeName) = $($notScope | ConvertTo-Json -Depth 100)"
            foreach ($selector in $notScope.Keys) {
                if ($selector -eq "*" -or $selector -eq $pacEnvironmentSelector) {
                    $notScopeList = $notScope.$selector
                    if ($definition.notScope) {
                        $definition.notScope += $notScopeList
                    }
                    else {
                        $definition.notScope = @() + $notScopeList
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
                # This branch does not have a scope for this assignment's pacSelector; ignore branch
                $definition.hasOnlyNotSelectedEnvironments = $true
            }
            else {
                if ($scopeList -is [array] -and $scopeList.Length -gt 0) {
                    $scopeCollection = @()
                    if ($definition.notScope) {
                        $uniqueNotScope = @() + ($definition.notScope | Sort-Object | Get-Unique)
                        $scopeCollection = Build-NotScopes -scopeList $scopeList -notScope $uniqueNotScope -scopeTable $scopeTable
                    }
                    else {
                        foreach ($scope in $scopeList) {
                            $scopeCollection += @{
                                scope    = $scope
                                notScope = @()
                            }
                        }
                    }
                    $definition.scopeCollection = $scopeCollection
                }
                else {
                    Write-Error "    Node $($nodeName): scope array must not be empty"
                    $definition.hasErrors = $true
                }
            }
        }
    }

    $assignmentsList = @()
    if ($definitionNode.children) {
        # Process child nodes
        Write-Debug " $($definitionNode.children.Count) children below at $($nodeName)"
        $hasErrors = $false
        foreach ($child in $definitionNode.children) {
            $hasErrorsLocal, $assignmentsListLocal = Build-AssignmentDefinitionNode `
                -pacEnvironment $pacEnvironment `
                -scopeTable $scopeTable `
                -parameterFilesCsv $parameterFilesCsv `
                -definitionNode $child `
                -assignmentDefinition $definition `
                -combinedPolicyDetails $combinedPolicyDetails `
                -policyRoleIds $policyRoleIds

            if ($hasErrorsLocal) {
                $hasErrors = $true
            }
            elseif ($null -ne $assignmentsListLocal) {
                $assignmentsList += $assignmentsListLocal
            }
        }
    }
    else {
        # Arrived at a leaf node - return the values collected in this branch after checking validity
        if ($definition.ignoreBranch -or $definition.hasOnlyNotSelectedEnvironments -or $definition.hasErrors) {
            return $definition.hasErrors, @()
        }
        else {
            $hasErrors, $assignmentsList = Build-AssignmentDefinitionAtLeaf `
                -pacEnvironment $pacEnvironment `
                -assignmentDefinition $definition `
                -combinedPolicyDetails $combinedPolicyDetails `
                -policyRoleIds $policyRoleIds
        }
    }
    if ($hasErrors) {
        return $true, $null
    }
    elseif (($assignmentsList -is [array])) {
        return $false, $assignmentsList
    }
    else {
        return $false, $( $assignmentsList )
    }
}
