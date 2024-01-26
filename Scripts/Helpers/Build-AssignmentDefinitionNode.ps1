function Build-AssignmentDefinitionNode {
    # Recursive Function
    param(
        [hashtable] $PacEnvironment,
        [hashtable] $ScopeTable,
        [hashtable] $ParameterFilesCsv,
        [hashtable] $DefinitionNode, # Current node
        [hashtable] $AssignmentDefinition, # Collected values in tree branch
        [hashtable] $CombinedPolicyDetails,
        [hashtable] $PolicyRoleIds,
        [hashtable] $RoleDefinitions

        # Returns a list os completed assignmentValues
    )

    # Each tree branch needs a private copy
    $definition = Get-DeepClone -InputObject $AssignmentDefinition -AsHashTable
    $pacSelector = $PacEnvironment.pacSelector

    #region nodeName (required)

    $nodeName = $definition.nodeName
    if ($DefinitionNode.nodeName) {
        $nodeName += $DefinitionNode.nodeName
    }
    else {
        $nodeName = "$($nodeName)//Unknown//"
        Write-Error "    Missing nodeName at child of $($nodeName)"
        $definition.hasErrors = $true
    }
    $definition.nodeName = $nodeName

    #endregion nodeName (required)

    #region ignoreBranch and enforcementMode

    # Ignoring a branch can be useful for prep work to an future state
    # Due to the history of EPAC, there are two ways ignoreBranch and enforcementMode
    if ($DefinitionNode.ignoreBranch) {
        # Does not deploy assignment(s), precedes Azure Policy feature enforcementMode
        Write-Warning "    Node $($nodeName): ignoreBranch is legacy, consider using enforcementMode instead."
        $definition.ignoreBranch = $DefinitionNode.ignoreBranch
    }
    if ($DefinitionNode.enforcementMode) {
        # Does deploy assignment(s), Azure Policy Engine will not evaluate the Policy Assignment
        $enforcementMode = $DefinitionNode.enforcementMode
        if ("Default", "DoNotEnforce" -contains $enforcementMode) {
            $definition.enforcementMode = $enforcementMode
        }
        else {
            Write-Error "    Node $($nodeName): enforcementMode must be Default or DoNotEnforce (actual is ""$($enforcementMode))."
            $definition.hasErrors = $true
        }
    }
    #endregion ignoreBranch and enforcementMode

    #region assignment (required at least once per branch, concatenate strings)
    #           name (required)
    #           displayName (required)
    #           description (optional)
    if ($null -ne $DefinitionNode.assignment) {
        $assignment = $DefinitionNode.assignment
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

    #endregion assignment (required at least once per branch, concatenate strings)

    #region definitionEntry or definitionEntryList (required exactly once per branch)

    $definitionEntry = $DefinitionNode.definitionEntry
    $definitionEntryList = $DefinitionNode.definitionEntryList
    $defEntryList = $definition.definitionEntryList
    if ($null -ne $definitionEntry -or $null -ne $definitionEntryList) {
        if ($null -eq $defEntryList -and ($null -ne $definitionEntry -xor $null -ne $definitionEntryList)) {
            # OK; first and only occurrence in tree branch

            #region  Validate and normalize definitionEntryList

            if ($null -ne $definitionEntry) {
                # Convert to list
                $definitionEntryList = @( $definitionEntry )
            }

            $normalizedDefinitionEntryList = @()
            $mustDefineAssignment = $definitionEntryList.Count -gt 1
            $itemList = @{}
            $perEntryNonComplianceMessages = $false

            foreach ($definitionEntry in $definitionEntryList) {

                $isValid, $normalizedEntry = Build-AssignmentDefinitionEntry `
                    -DefinitionEntry $definitionEntry `
                    -NodeName $nodeName `
                    -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                    -CombinedPolicyDetails $CombinedPolicyDetails `
                    -MustDefineAssignment:$mustDefineAssignment
                if ($isValid) {
                    $policyDefinitionId = $normalizedEntry.policyDefinitionId
                    $isPolicySet = $normalizedEntry.isPolicySet
                    if ($isPolicySet) {
                        $itemEntry = @{
                            shortName    = $policyDefinitionId
                            itemId       = $policyDefinitionId
                            policySetId  = $policyDefinitionId
                            assignmentId = $null
                        }
                        if ($itemList.ContainsKey($policyDefinitionId)) {
                            Write-Error "    Node $($nodeName): policySet '$($policyDefinitionId)' is defined more than once in this definitionEntryList." -ErrorAction Stop
                            $definition.hasErrors = $true
                        }
                        else {
                            $null = $itemList.Add($policyDefinitionId, $itemEntry)
                        }
                    }
                    if ($null -ne $normalizedEntry.nonComplianceMessages -and $normalizedEntry.nonComplianceMessages.Count -gt 0) {
                        $perEntryNonComplianceMessages = $true
                    }

                    $normalizedDefinitionEntryList += $normalizedEntry
                }
                else {
                    $definition.hasErrors = $true
                }
            }

            #region compile flat Policy List for all Policy Sets used in this branch

            $flatPolicyList = $null
            $hasPolicySets = $itemList.Count -gt 0

            if ($hasPolicySets) {
                $flatPolicyList = Convert-PolicySetsToFlatList `
                    -ItemList $itemList.Values `
                    -Details $CombinedPolicyDetails.policySets
            }

            #endregion compile flat Policy List for all Policy Sets used in this branch

            $definition.definitionEntryList = $normalizedDefinitionEntryList
            $definition.hasPolicySets = $hasPolicySets
            $definition.flatPolicyList = $flatPolicyList
            $definition.perEntryNonComplianceMessages = $perEntryNonComplianceMessages
        }
        else {
            Write-Error "   Node $($nodeName): only one definitionEntry or definitionEntryList can appear in any branch."
            $definition.hasErrors = $true
        }
    }

    #endregion definitionEntry or definitionEntryList (required exactly once per branch)

    #region metadata

    if ($DefinitionNode.metadata) {
        if ($definition.metadata) {
            # merge metadata
            $metadata = $definition.metadata
            $merge = Get-DeepClone $DefinitionNode.metadata -AsHashTable
            foreach ($key in $merge) {
                $metadata[$key] = $merge.$key
            }
        }
        else {
            $definition.metadata = Get-DeepClone $DefinitionNode.metadata -AsHashTable
        }
    }
    #endregion metadata

    #region parameters

    # parameters in JSON; parameters defined at a deeper level override previous parameters (union operator)
    if ($DefinitionNode.parameters) {
        $allParameters = $definition.parameters
        $addedParameters = $DefinitionNode.parameters
        foreach ($parameterName in $addedParameters.Keys) {
            $rawParameterValue = $addedParameters.$parameterName
            $parameterValue = Get-DeepClone $rawParameterValue -AsHashTable
            $allParameters[$parameterName] = $parameterValue
        }
    }

    # Process parameterFileName and parameterSelector
    if ($DefinitionNode.parameterSelector) {
        $parameterSelector = $DefinitionNode.parameterSelector
        $definition.parameterSelector = $parameterSelector
        $definition.effectColumn = "$($parameterSelector)Effect"
        $definition.parametersColumn = "$($parameterSelector)Parameters"
    }
    if ($DefinitionNode.parameterFile) {
        $parameterFileName = $DefinitionNode.parameterFile
        if ($ParameterFilesCsv.ContainsKey($parameterFileName)) {
            $fullName = $ParameterFilesCsv.$parameterFileName
            $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
            $xlsArray = @() + ($content | ConvertFrom-Csv -ErrorAction Stop)
            $csvParameterArray = Get-DeepClone $xlsArray -AsHashTable
            $definition.parameterFileName = $parameterFileName
            $definition.csvParameterArray = $csvParameterArray
            $definition.csvRowsValidated = $false
            if ($csvParameterArray.Count -eq 0) {
                Write-Error "    Node $($nodeName): CSV parameterFile '$parameterFileName'  is empty (zero rows)."
                $definition.hasErrors = $true
            }
        }
        else {
            Write-Error "    Node $($nodeName): CSV parameterFileName '$parameterFileName'  does not exist."
            $definition.hasErrors = $true
        }
    }

    #region Validate CSV rows

    if (!($definition.csvRowsValidated) -and $definition.hasPolicySets -and $definition.parameterFileName -and $definition.definitionEntryList) {

        $csvParameterArray = $definition.csvParameterArray
        $parameterFileName = $definition.parameterFileName
        $definition.csvRowsValidated = $true
        $rowHashtable = @{}
        foreach ($row in $csvParameterArray) {

            # Ignore empty lines with a warning
            $name = $row.name
            if ($null -eq $name -or $name -eq "") {
                Write-Verbose "    Node $($nodeName): CSV parameterFile '$parameterFileName' has an empty row."
                continue
            }

            # generate the key into the flatPolicyList
            $policyId = Confirm-PolicyDefinitionUsedExists -Name $name -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes -AllDefinitions $CombinedPolicyDetails.policies -SuppressErrorMessage
            if ($null -eq $policyId) {
                Write-Error "    Node $($nodeName): CSV parameterFile '$parameterFileName' has a row containing an unknown Policy name '$name'."
                $definition.hasErrors = $true
                continue
            }
            $flatPolicyEntryKey = $policyId
            $flatPolicyReferencePath = $row.referencePath
            if ($null -ne $flatPolicyReferencePath -and $flatPolicyReferencePath -ne "") {
                $flatPolicyEntryKey = "$policyId\\$flatPolicyReferencePath"
                $null = $rowHashtable.Add($flatPolicyEntryKey, "$($row.displayName) ($name -- $flatPolicyReferencePath)")
            }
            else {
                $null = $rowHashtable.Add($flatPolicyEntryKey, "$($row.displayName) ($name)")
            }
            $row.policyId = $policyId
            $row.flatPolicyEntryKey = $flatPolicyEntryKey
        }
        $missingInCsv = [System.Collections.ArrayList]::new()
        $flatPolicyList = $definition.flatPolicyList
        foreach ($flatPolicyEntryKey in $flatPolicyList.Keys) {
            if ($rowHashtable.ContainsKey($flatPolicyEntryKey)) {
                $rowHashtable.Remove($flatPolicyEntryKey)
            }
            else {
                $flatPolicyEntry = $flatPolicyList.$flatPolicyEntryKey
                if ($VerbosePreference -eq "Continue" -or ($flatPolicyEntry.effectDefault -ne "Manual" -and $flatPolicyEntry.effectDefault -ne "Disabled")) {
                    # Complain only about Policies NOT with  Manual or Disabled effect default or when Verbose is on
                    if ($flatPolicyEntry.referencePath) {
                        $null = $missingInCsv.Add("$($flatPolicyEntry.displayName) ($($flatPolicyEntry.name) -- $($flatPolicyEntry.referencePath))")
                    }
                    else {
                        $null = $missingInCsv.Add("$($flatPolicyEntry.displayName) ($($flatPolicyEntry.name))")
                    }
                }
            }
        }
        if ($rowHashtable.Count -gt 0) {
            Write-Warning "    Node $($nodeName): CSV parameterFile '$parameterFileName' contains rows for Policies not included in any of the Policy Sets:"
            foreach ($displayString in $rowHashtable.Values) {
                Write-Information "                         $($displayString)"
            }
        }
        if ($missingInCsv.Count -gt 0) {
            Write-Warning "    Node $($nodeName): CSV parameterFile '$parameterFileName' is missing rows for Policies included in the Policy Sets:"
            foreach ($missing in $missingInCsv) {
                Write-Information "                         $($missing)"
            }
        }

    }
    #endregion parameters

    #region advanced - overrides, resourceSelectors and nonComplianceMessages

    if ($DefinitionNode.overrides) {
        # Cumulative in branch
        # overrides behave like parameters, we define them similarly (simplified from Azure Policy)
        $definition.overrides += $DefinitionNode.overrides
    }

    if ($DefinitionNode.resourceSelectors) {
        # Cumulative in branch
        # resourceSelectors behave like parameters, we define them similarly (simplified from Azure Policy)
        $definition.resourceSelectors += $DefinitionNode.resourceSelectors
    }

    if ($DefinitionNode.nonComplianceMessageColumn) {
        # nonComplianceMessages are in a column in the parameters csv file
        $definition.nonComplianceMessageColumn = $DefinitionNode.nonComplianceMessageColumn
    }
    if ($DefinitionNode.nonComplianceMessages) {
        $definition.nonComplianceMessages += $DefinitionNode.nonComplianceMessages
    }

    #endregion advanced parameters - overrides and resourceSelectors

    #region scopes, notScopes
    if ($definition.scopeCollection -or $definition.hasOnlyNotSelectedEnvironments) {
        # Once a scopeList is defined at a parent, no descendant may define scopeList or notScope
        if ($DefinitionNode.scope) {
            Write-Error "    Node $($nodeName): multiple scope definitions at different tree levels are not allowed"
            $definition.hasErrors = $true
        }
        if ($DefinitionNode.notScope) {
            Write-Error "    Node $($nodeName): detected notScope definition in in a child node when the scope was already defined"
            $definition.hasErrors = $true
        }
    }
    else {
        # may define notScope
        if ($DefinitionNode.notScope) {
            $notScope = $DefinitionNode.notScope
            Write-Debug "         notScope defined at $($nodeName) = $($notScope | ConvertTo-Json -Depth 100)"
            foreach ($selector in $notScope.Keys) {
                if ($selector -eq "*" -or $selector -eq $pacSelector) {
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
        if ($DefinitionNode.scope) {
            ## Found a scope list - process notScope
            $scopeList = $null
            $scope = $DefinitionNode.scope
            foreach ($selector in $scope.Keys) {
                if ($selector -eq "*" -or $selector -eq $pacSelector) {
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
                        $scopeCollection = Build-NotScopes -ScopeList $scopeList -notScope $uniqueNotScope -ScopeTable $ScopeTable
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
    #endregion scopes, notScopes

    #region identity and additionalRoleAssignments (optional, specific to an EPAC environment)

    if ($DefinitionNode.additionalRoleAssignments) {
        # Process additional permissions needed to execute remediations; for example permissions to log to Event Hub, Storage Account or Log Analytics
        $additionalRoleAssignments = $DefinitionNode.additionalRoleAssignments
        foreach ($selector in $additionalRoleAssignments.Keys) {
            if ($selector -eq "*" -or $selector -eq $pacSelector) {
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

    if ($DefinitionNode.managedIdentityLocations) {
        # Process managedIdentityLocation; can be overridden
        $managedIdentityLocations = $DefinitionNode.managedIdentityLocations
        $localManagedIdentityLocationValue = Get-SelectedPacValue $managedIdentityLocations -PacSelector $pacSelector
        if ($null -ne $localManagedIdentityLocationValue) {
            $definition.managedIdentityLocation = $localManagedIdentityLocationValue
        }
    }

    if ($DefinitionNode.userAssignedIdentity) {
        # Process userAssignedIdentity; can be overridden
        $localUserAssignedIdentityRaw = Get-SelectedPacValue $DefinitionNode.userAssignedIdentity -PacSelector $pacSelector
        if ($null -ne $localUserAssignedIdentityRaw) {
            $definition.userAssignedIdentity = $localUserAssignedIdentityRaw
        }
    }

    #endregion identity and additionalRoleAssignments (optional, specific to an EPAC environment)

    #region children and the leaf node
    $assignmentsList = @()
    if ($DefinitionNode.children) {
        # Process child nodes
        Write-Debug " $($DefinitionNode.children.Count) children below at $($nodeName)"
        $hasErrors = $false
        foreach ($child in $DefinitionNode.children) {
            $hasErrorsLocal, $assignmentsListLocal = Build-AssignmentDefinitionNode `
                -PacEnvironment $PacEnvironment `
                -ScopeTable $ScopeTable `
                -ParameterFilesCsv $ParameterFilesCsv `
                -DefinitionNode $child `
                -AssignmentDefinition $definition `
                -CombinedPolicyDetails $CombinedPolicyDetails `
                -PolicyRoleIds $PolicyRoleIds `
                -RoleDefinitions $RoleDefinitions

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
            # Empty collection
            return $definition.hasErrors, @()
        }
        else {
            $hasErrors, $assignmentsList = Build-AssignmentDefinitionAtLeaf `
                -PacEnvironment $PacEnvironment `
                -AssignmentDefinition $definition `
                -CombinedPolicyDetails $CombinedPolicyDetails `
                -PolicyRoleIds $PolicyRoleIds `
                -RoleDefinitions $RoleDefinitions
        }
    }
    #endregion children and the leaf node

    #region recursive return
    if ($hasErrors) {
        return $true, $null
    }
    elseif (($assignmentsList -is [array])) {
        return $false, $assignmentsList
    }
    else {
        return $false, $( $assignmentsList )
    }
    #endregion recursive return
}
