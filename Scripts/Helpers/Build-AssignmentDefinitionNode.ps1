function Build-AssignmentDefinitionNode {
    # Recursive Function
    param(
        [hashtable] $PacEnvironment,
        [hashtable] $ScopeTable,
        [hashtable] $ParameterFilesCsv,
        [hashtable] $DefinitionNode, # Current node
        [hashtable] $AssignmentDefinition, # Collected values in tree branch
        [hashtable] $CombinedPolicyDetails,
        [hashtable] $PolicyRoleIds

        # Returns a list os completed assignmentValues
    )

    # Each tree branch needs a private copy
    $Definition = Get-DeepClone -InputObject $AssignmentDefinition -AsHashtable
    $PacSelector = $PacEnvironment.pacSelector

    #region nodeName (required)

    $NodeName = $Definition.nodeName
    if ($DefinitionNode.nodeName) {
        $NodeName += $DefinitionNode.nodeName
    }
    else {
        $NodeName = "$($NodeName)//Unknown//"
        Write-Error "    Missing nodeName at child of $($NodeName)"
        $Definition.hasErrors = $true
    }
    $Definition.nodeName = $NodeName

    #endregion nodeName (required)

    #region ignoreBranch and enforcementMode

    # Ignoring a branch can be useful for prep work to an future state
    # Due to the history of EPAC, there are two ways ignoreBranch and enforcementMode
    if ($DefinitionNode.ignoreBranch) {
        # Does not deploy assignment(s), precedes Azure Policy feature enforcementMode
        Write-Warning "    Node $($NodeName): ignoreBranch is legacy, consider using enforcementMode instead."
        $Definition.ignoreBranch = $DefinitionNode.ignoreBranch
    }
    if ($DefinitionNode.enforcementMode) {
        # Does deploy assignment(s), Azure Policy Engine will not evaluate the Policy Assignment
        $enforcementMode = $DefinitionNode.enforcementMode
        if ("Default", "DoNotEnforce" -contains $enforcementMode) {
            $Definition.enforcementMode = $enforcementMode
        }
        else {
            Write-Error "    Node $($NodeName): enforcementMode must be Default or DoNotEnforce (actual is ""$($enforcementMode))."
            $Definition.hasErrors = $true
        }
    }
    #endregion ignoreBranch and enforcementMode

    #region assignment (required at least once per branch, concatenate strings)
    #           name (required)
    #           displayName (required)
    #           description (optional)
    if ($null -ne $DefinitionNode.assignment) {
        $Assignment = $DefinitionNode.assignment
        if ($null -ne $Assignment.name -and ($Assignment.name).Length -gt 0 -and $null -ne $Assignment.displayName -and ($Assignment.displayName).Length -gt 0) {
            $normalizedAssignment = ConvertTo-HashTable $Assignment
            if (!$normalizedAssignment.ContainsKey("description")) {
                $normalizedAssignment.description = ""
            }
            # Concatenate information
            $Definition.assignment.name += $normalizedAssignment.name
            $Definition.assignment.displayName += $normalizedAssignment.displayName
            $Definition.assignment.description += $normalizedAssignment.description
        }
        else {
            Write-Error "   Node $($NodeName): each assignment field must define an assignment name and displayName."
            $Definition.hasErrors = $true
        }
    }

    #endregion assignment (required at least once per branch, concatenate strings)

    #region definitionEntry or definitionEntryList (required exactly once per branch)

    $DefinitionEntry = $DefinitionNode.definitionEntry
    $DefinitionEntryList = $DefinitionNode.definitionEntryList
    $defEntryList = $Definition.definitionEntryList
    if ($null -ne $DefinitionEntry -or $null -ne $DefinitionEntryList) {
        if ($null -eq $defEntryList -and ($null -ne $DefinitionEntry -xor $null -ne $DefinitionEntryList)) {
            # OK; first and only occurrence in tree branch

            #region  Validate and normalize definitionEntryList

            if ($null -ne $DefinitionEntry) {
                # Convert to list
                $DefinitionEntryList = @( $DefinitionEntry )
            }

            $normalizedDefinitionEntryList = @()
            $MustDefineAssignment = $DefinitionEntryList.Count -gt 1
            $itemArrayList = [System.Collections.ArrayList]::new()
            $perEntryNonComplianceMessages = $false

            foreach ($DefinitionEntry in $DefinitionEntryList) {

                $isValid, $normalizedEntry = Build-AssignmentDefinitionEntry `
                    -DefinitionEntry $DefinitionEntry `
                    -NodeName $NodeName `
                    -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                    -CombinedPolicyDetails $CombinedPolicyDetails `
                    -MustDefineAssignment:$MustDefineAssignment
                if ($isValid) {
                    $PolicyDefinitionId = $normalizedEntry.policyDefinitionId
                    $isPolicySet = $normalizedEntry.isPolicySet
                    if ($isPolicySet) {
                        $itemEntry = @{
                            shortName    = $PolicyDefinitionId
                            itemId       = $PolicyDefinitionId
                            policySetId  = $PolicyDefinitionId
                            assignmentId = $null
                        }
                        $null = $itemArrayList.Add($itemEntry)
                    }
                    if ($null -ne $normalizedEntry.nonComplianceMessages -and $normalizedEntry.nonComplianceMessages.Count -gt 0) {
                        $perEntryNonComplianceMessages = $true
                    }

                    $normalizedDefinitionEntryList += $normalizedEntry
                }
                else {
                    $Definition.hasErrors = $true
                }
            }

            #region compile flat Policy List for all Policy Sets used in this branch

            $FlatPolicyList = $null
            $hasPolicySets = $itemArrayList.Count -gt 0
            if ($hasPolicySets) {
                $FlatPolicyList = Convert-PolicySetsToFlatList `
                    -ItemList $itemArrayList.ToArray() `
                    -Details $CombinedPolicyDetails.policySets
            }

            #endregion compile flat Policy List for all Policy Sets used in this branch

            $Definition.definitionEntryList = $normalizedDefinitionEntryList
            $Definition.hasPolicySets = $hasPolicySets
            $Definition.flatPolicyList = $FlatPolicyList
            $Definition.perEntryNonComplianceMessages = $perEntryNonComplianceMessages
        }
        else {
            Write-Error "   Node $($NodeName): only one definitionEntry or definitionEntryList can appear in any branch."
            $Definition.hasErrors = $true
        }
    }

    #endregion definitionEntry or definitionEntryList (required exactly once per branch)

    #region metadata

    if ($DefinitionNode.metadata) {
        if ($Definition.metadata) {
            # merge metadata
            $Metadata = $Definition.metadata
            $merge = Get-DeepClone $DefinitionNode.metadata -AsHashtable
            foreach ($key in $merge) {
                $Metadata[$key] = $merge.$key
            }
        }
        else {
            $Definition.metadata = Get-DeepClone $DefinitionNode.metadata -AsHashtable
        }
    }
    #endregion metadata

    #region parameters

    # parameters in JSON; parameters defined at a deeper level override previous parameters (union operator)
    if ($DefinitionNode.parameters) {
        $allParameters = $Definition.parameters
        $addedParameters = $DefinitionNode.parameters
        foreach ($parameterName in $addedParameters.Keys) {
            $rawParameterValue = $addedParameters.$parameterName
            $parameterValue = Get-DeepClone $rawParameterValue -AsHashtable
            $allParameters[$parameterName] = $parameterValue
        }
    }

    # Process parameterFileName and parameterSelector
    if ($DefinitionNode.parameterSelector) {
        $Parameterselector = $DefinitionNode.parameterSelector
        $Definition.parameterSelector = $Parameterselector
        $Definition.effectColumn = "$($Parameterselector)Effect"
        $Definition.parametersColumn = "$($Parameterselector)Parameters"
    }
    if ($DefinitionNode.parameterFile) {
        $parameterFileName = $DefinitionNode.parameterFile
        if ($ParameterFilesCsv.ContainsKey($parameterFileName)) {
            $fullName = $ParameterFilesCsv.$parameterFileName
            $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
            $xlsArray = @() + ($content | ConvertFrom-Csv -ErrorAction Stop)
            $csvParameterArray = Get-DeepClone $xlsArray -AsHashtable
            $Definition.parameterFileName = $parameterFileName
            $Definition.csvParameterArray = $csvParameterArray
            $Definition.csvRowsValidated = $false
            if ($csvParameterArray.Count -eq 0) {
                Write-Error "    Node $($NodeName): CSV parameterFile '$parameterFileName'  is empty (zero rows)."
                $Definition.hasErrors = $true
            }
        }
        else {
            Write-Error "    Node $($NodeName): CSV parameterFileName '$parameterFileName'  does not exist."
            $Definition.hasErrors = $true
        }
    }

    #region Validate CSV rows

    if (!($Definition.csvRowsValidated) -and $Definition.hasPolicySets -and $Definition.parameterFileName -and $Definition.definitionEntryList) {

        $csvParameterArray = $Definition.csvParameterArray
        $parameterFileName = $Definition.parameterFileName
        $Definition.csvRowsValidated = $true
        $rowHashtable = @{}
        foreach ($row in $csvParameterArray) {

            # Ignore empty lines with a warning
            $Name = $row.name
            if ($null -eq $Name -or $Name -eq "") {
                Write-Warning "    Node $($NodeName): CSV parameterFile '$parameterFileName' has an empty row."
                continue
            }

            # generate the key into the flatPolicyList
            $PolicyId = Confirm-PolicyDefinitionUsedExists -Name $Name -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes -AllDefinitions $CombinedPolicyDetails.policies -SuppressErrorMessage
            if ($null -eq $PolicyId) {
                Write-Error "    Node $($NodeName): CSV parameterFile '$parameterFileName' has a row containing an unknown Policy name '$Name'."
                $Definition.hasErrors = $true
                continue
            }
            $flatPolicyEntryKey = $PolicyId
            $flatPolicyReferencePath = $row.referencePath
            if ($null -ne $flatPolicyReferencePath -and $flatPolicyReferencePath -ne "") {
                $flatPolicyEntryKey = "$PolicyId\\$flatPolicyReferencePath"
                $null = $rowHashtable.Add($flatPolicyEntryKey, "$($row.displayName) ($Name -- $flatPolicyReferencePath)")
            }
            else {
                $null = $rowHashtable.Add($flatPolicyEntryKey, "$($row.displayName) ($Name)")
            }
            $row.policyId = $PolicyId
            $row.flatPolicyEntryKey = $flatPolicyEntryKey
        }
        $missingInCsv = [System.Collections.ArrayList]::new()
        $FlatPolicyList = $Definition.flatPolicyList
        foreach ($flatPolicyEntryKey in $FlatPolicyList.Keys) {
            if ($rowHashtable.ContainsKey($flatPolicyEntryKey)) {
                $rowHashtable.Remove($flatPolicyEntryKey)
            }
            else {
                $flatPolicyEntry = $FlatPolicyList.$flatPolicyEntryKey
                if ($flatPolicyEntry.isEffectParameterized) {
                    # Complain only about Policies with parameterized effect value
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
            Write-Warning "    Node $($NodeName): CSV parameterFile '$parameterFileName' contains rows for Policies not included in any of the Policy Sets:"
            foreach ($displayString in $rowHashtable.Values) {
                Write-Information "                         $($displayString)"
            }
        }
        if ($missingInCsv.Count -gt 0) {
            Write-Warning "    Node $($NodeName): CSV parameterFile '$parameterFileName' is missing rows for Policies included in the Policy Sets:"
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
        $Definition.overrides += $DefinitionNode.overrides
    }

    if ($DefinitionNode.resourceSelectors) {
        # Cumulative in branch
        # resourceSelectors behave like parameters, we define them similarly (simplified from Azure Policy)
        $Definition.resourceSelectors += $DefinitionNode.resourceSelectors
    }

    if ($DefinitionNode.nonComplianceMessageColumn) {
        # nonComplianceMessages are in a column in the parameters csv file
        $Definition.nonComplianceMessageColumn = $DefinitionNode.nonComplianceMessageColumn
    }
    if ($DefinitionNode.nonComplianceMessages) {
        $Definition.nonComplianceMessages += $DefinitionNode.nonComplianceMessages
    }

    #endregion advanced parameters - overrides and resourceSelectors

    #region scopes, notScopes
    if ($Definition.scopeCollection -or $Definition.hasOnlyNotSelectedEnvironments) {
        # Once a scopeList is defined at a parent, no descendant may define scopeList or notScope
        if ($DefinitionNode.scope) {
            Write-Error "    Node $($NodeName): multiple scope definitions at different tree levels are not allowed"
            $Definition.hasErrors = $true
        }
        if ($DefinitionNode.notScope) {
            Write-Error "    Node $($NodeName): detected notScope definition in in a child node when the scope was already defined"
            $Definition.hasErrors = $true
        }
    }
    else {
        # may define notScope
        if ($DefinitionNode.notScope) {
            $notScope = $DefinitionNode.notScope
            Write-Debug "         notScope defined at $($NodeName) = $($notScope | ConvertTo-Json -Depth 100)"
            foreach ($selector in $notScope.Keys) {
                if ($selector -eq "*" -or $selector -eq $PacSelector) {
                    $notScopeList = $notScope.$selector
                    if ($Definition.notScope) {
                        $Definition.notScope += $notScopeList
                    }
                    else {
                        $Definition.notScope = @() + $notScopeList
                    }
                }
            }
        }
        if ($DefinitionNode.scope) {
            ## Found a scope list - process notScope
            $ScopeList = $null
            $Scope = $DefinitionNode.scope
            foreach ($selector in $Scope.Keys) {
                if ($selector -eq "*" -or $selector -eq $PacSelector) {
                    $ScopeList = @() + $Scope.$selector
                    break
                }
            }
            if ($null -eq $ScopeList) {
                # This branch does not have a scope for this assignment's pacSelector; ignore branch
                $Definition.hasOnlyNotSelectedEnvironments = $true
            }
            else {
                if ($ScopeList -is [array] -and $ScopeList.Length -gt 0) {
                    $ScopeCollection = @()
                    if ($Definition.notScope) {
                        $uniqueNotScope = @() + ($Definition.notScope | Sort-Object | Get-Unique)
                        $ScopeCollection = Build-NotScopes -ScopeList $ScopeList -notScope $uniqueNotScope -ScopeTable $ScopeTable
                    }
                    else {
                        foreach ($Scope in $ScopeList) {
                            $ScopeCollection += @{
                                scope    = $Scope
                                notScope = @()
                            }
                        }
                    }
                    $Definition.scopeCollection = $ScopeCollection
                }
                else {
                    Write-Error "    Node $($NodeName): scope array must not be empty"
                    $Definition.hasErrors = $true
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
            if ($selector -eq "*" -or $selector -eq $PacSelector) {
                $additionalRoleAssignmentsList = Get-DeepClone $additionalRoleAssignments.$selector -AsHashtable
                if ($Definition.additionalRoleAssignments) {
                    $Definition.additionalRoleAssignments += $additionalRoleAssignmentsList
                }
                else {
                    $Definition.additionalRoleAssignments = @() + $additionalRoleAssignmentsList
                }
            }
        }
    }

    if ($DefinitionNode.managedIdentityLocations) {
        # Process managedIdentityLocation; can be overridden
        $managedIdentityLocations = $DefinitionNode.managedIdentityLocations
        $localManagedIdentityLocationValue = Get-SelectedPacValue $managedIdentityLocations -PacSelector $PacSelector
        if ($null -ne $localManagedIdentityLocationValue) {
            $Definition.managedIdentityLocation = $localManagedIdentityLocationValue
        }
    }

    if ($DefinitionNode.userAssignedIdentity) {
        # Process userAssignedIdentity; can be overridden
        $localUserAssignedIdentityRaw = Get-SelectedPacValue $DefinitionNode.userAssignedIdentity -PacSelector $PacSelector
        if ($null -ne $localUserAssignedIdentityRaw) {
            $Definition.userAssignedIdentity = $localUserAssignedIdentityRaw
        }
    }

    #endregion identity and additionalRoleAssignments (optional, specific to an EPAC environment)

    #region children and the leaf node
    $AssignmentsList = @()
    if ($DefinitionNode.children) {
        # Process child nodes
        Write-Debug " $($DefinitionNode.children.Count) children below at $($NodeName)"
        $hasErrors = $false
        foreach ($child in $DefinitionNode.children) {
            $hasErrorsLocal, $AssignmentsListLocal = Build-AssignmentDefinitionNode `
                -PacEnvironment $PacEnvironment `
                -ScopeTable $ScopeTable `
                -ParameterFilesCsv $ParameterFilesCsv `
                -DefinitionNode $child `
                -AssignmentDefinition $Definition `
                -CombinedPolicyDetails $CombinedPolicyDetails `
                -PolicyRoleIds $PolicyRoleIds

            if ($hasErrorsLocal) {
                $hasErrors = $true
            }
            elseif ($null -ne $AssignmentsListLocal) {
                $AssignmentsList += $AssignmentsListLocal
            }
        }
    }
    else {
        # Arrived at a leaf node - return the values collected in this branch after checking validity
        if ($Definition.ignoreBranch -or $Definition.hasOnlyNotSelectedEnvironments -or $Definition.hasErrors) {
            # Empty collection
            return $Definition.hasErrors, @()
        }
        else {
            $hasErrors, $AssignmentsList = Build-AssignmentDefinitionAtLeaf `
                -PacEnvironment $PacEnvironment `
                -AssignmentDefinition $Definition `
                -CombinedPolicyDetails $CombinedPolicyDetails `
                -PolicyRoleIds $PolicyRoleIds
        }
    }
    #endregion children and the leaf node

    #region recursive return
    if ($hasErrors) {
        return $true, $null
    }
    elseif (($AssignmentsList -is [array])) {
        return $false, $AssignmentsList
    }
    else {
        return $false, $( $AssignmentsList )
    }
    #endregion recursive return
}
