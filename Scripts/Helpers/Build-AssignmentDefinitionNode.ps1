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
        [hashtable] $RoleDefinitions,
        [hashtable] $DeprecatedHash

        # Returns a list os completed assignmentValues
    )

    # Each tree branch needs a private copy
    $definition = Get-DeepCloneAsOrderedHashtable -InputObject $AssignmentDefinition
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
    #   Ignoring a branch can be useful for prep work to an future state
    #   Due to the history of EPAC, there are two ways ignoreBranch and enforcementMode
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

            #region validate and normalize definitionEntryList
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
            #endregion validate and normalize definitionEntryList

            #region compile flat Policy List for all Policy Sets used in this branch
            $flatPolicyList = $null
            $hasPolicySets = $itemList.Count -gt 0
            if ($hasPolicySets) {
                $flatPolicyList = Convert-PolicyResourcesDetailsToFlatList `
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
        # merge metadata
        $metadata = $definition.metadata
        $merge = Get-DeepCloneAsOrderedHashtable $DefinitionNode.metadata

        foreach ($key in $merge.Keys) {
            $metadata[$key] = $merge.$key
        }
    }
    #endregion metadata

    #region parameters in JSON; parameters defined at a deeper level override previous parameters (union operator)
    
    # create parameter Hash to Policy Def
    $parameterHash = @{}
    foreach ($key in $flatPolicyList.keys) {
        foreach ($paramKey in $flatPolicyList.$key.parameters.keys) {
            $parameterHash.$paramKey = $flatPolicyList.$key
        }
    }

    $deprecatedInJSON = [System.Collections.ArrayList]::new()
    if ($DefinitionNode.parameters) {
        $allParameters = $definition.parameters
        $addedParameters = $DefinitionNode.parameters
        foreach ($parameterName in $addedParameters.Keys) {
            $rawParameterValue = $addedParameters.$parameterName
            $currentParameterHash = $parameterHash.$parameterName
            if ($null -ne $currentParameterHash.name) {
                if ($DeprecatedHash.ContainsKey($($currentParameterHash.name)) -and $currentParameterHash.parameters.$parameterName.isEffect) {
                    $null = $deprecatedInJSON.Add("Assignment: '$($assignment.name)' with Parameter: '$parameterName' ($($currentParameterHash))")
                    if (!$PacEnvironment.desiredState.doNotDisableDeprecatedPolicies) {
                        $rawParameterValue = "Disabled"
                    }
                }
            }
            $parameterValue = Get-DeepCloneAsOrderedHashtable $rawParameterValue
            $allParameters.$parameterName = $parameterValue
        }
    }
    if ($deprecatedInJSON.Count -gt 0) {
        Write-Warning "Node $($nodeName): Assignment contains JSON effect parameter for Policies that has been deprecated in the Policy Sets. Update Policy Sets."
        foreach ($deprecated in $deprecatedInJSON) {
            Write-Information "    $($deprecated)"
        }
    }
    #endregion parameters in JSON; parameters defined at a deeper level override previous parameters (union operator)

    #region process parameterFileName and parameterSelector
    if ($DefinitionNode.parameterSelector) {
        $parameterSelector = $DefinitionNode.parameterSelector
        $definition.parameterSelector = $parameterSelector
        $definition.effectColumn = "$($parameterSelector)Effect"
        $definition.parametersColumn = "$($parameterSelector)Parameters"
    }
    $deprecatedInCSV = [System.Collections.ArrayList]::new()
    if ($DefinitionNode.parameterFile) {
        $parameterFileName = $DefinitionNode.parameterFile
        if ($ParameterFilesCsv.ContainsKey($parameterFileName)) {
            $fullName = $ParameterFilesCsv.$parameterFileName
            $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
            $xlsArray = @() + ($content | ConvertFrom-Csv -ErrorAction Stop)
            $csvParameterArray = Get-DeepCloneAsOrderedHashtable $xlsArray
            # Replace CSV effect with Disabled if Deprecated
            foreach ($entry in $csvParameterArray) {
                # If policy in csv is found to be deprecated
                if ($DeprecatedHash.ContainsKey($entry.name)) {
                    # For each child in the assignment
                    foreach ($child in $DefinitionNode.children) {
                        # If that child is using a parameterSelector with the CSV
                        if ($child.ContainsKey('parameterSelector')) {
                            $key = "$($child.parameterSelector)" + "Effect"
                            # If the parameter is not set to Disabled already
                            if ($entry.$key -ne "Disabled") {
                                if (!$PacEnvironment.desiredState.doNotDisableDeprecatedPolicies) {
                                    $entry.$key = 'Disabled'
                                }
                                $null = $deprecatedInCSV.Add("$($entry.displayName) ($($entry.name))")
                            }
                        }
                    }
                    break
                }
            }
            
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
    #endregion process parameterFileName and parameterSelector

    #region validate CSV rows
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
            Write-Warning "Node $($nodeName): CSV parameterFile '$parameterFileName' contains rows for Policies not included in any of the Policy Sets. Remove the obsolete rows or regenerate the CSV file."
            foreach ($displayString in $rowHashtable.Values) {
                Write-Information "    $($displayString)"
            }
        }
        if ($missingInCsv.Count -gt 0) {
            Write-Warning "Node $($nodeName): CSV parameterFile '$parameterFileName' is missing rows for Policies included in the Policy Sets. Regenerate the CSV file."
            foreach ($missing in $missingInCsv) {
                Write-Information "    $($missing)"
            }
        }
        if ($deprecatedInCSV.Count -gt 0) {
            Write-Warning "Node $($nodeName): CSV parameterFile '$parameterFileName' contains rows for Policies that have been deprecated in the Policy Sets. Update Policy Sets."
            foreach ($deprecated in $deprecatedInCSV) {
                Write-Information "    $($deprecated)"
            }
        }
    }
    #endregion validate CSV rows

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
        if ($DefinitionNode.notScope -or $DefinitionNode.notScopes) {
            Write-Error "    Node $($nodeName): detected notScope definition in in a child node when the scope was already defined"
            $definition.hasErrors = $true
        }
    }
    else {
        # may define notScope or notScopes
        if ($DefinitionNode.notScope) {
            Write-Warning "    Node $($nodeName): notScope is legacy, consider using notScopes instead."
            $definition.notScopesList = Add-SelectedPacArray -InputObject $DefinitionNode.notScope -PacSelector $pacSelector -ExistingList $definition.notScopesList
        }
        if ($DefinitionNode.notScopes) {
            $definition.notScopesList = Add-SelectedPacArray -InputObject $DefinitionNode.notScopes -PacSelector $pacSelector -ExistingList $definition.notScopesList
        }
        if ($DefinitionNode.scope) {
            ## Found a scope list - process scope notScopes
            $scopeList = Add-SelectedPacArray -InputObject $DefinitionNode.scope -PacSelector $pacSelector
            if ($scopeList.Count -eq 0) {
                # This branch does not have a scope for this assignment's pacSelector; ignore branch
                $definition.hasOnlyNotSelectedEnvironments = $true
            }
            else {
                $scopeCollection = [System.Collections.ArrayList]::new()
                foreach ($scope in $scopeList) {
                    $thisScopeDetails = $ScopeTable.$scope
                    if ($null -eq $thisScopeDetails) {
                        Write-Error "    Node $($nodeName): scope '$scope' is not defined in the ScopeTable."
                        $definition.hasErrors = $true
                        continue
                    }
                    elseif ($thisScopeDetails.isExcluded) {
                        Write-Error "    Node $($nodeName): scope '$scope' is excluded in the ScopeTable."
                        $definition.hasErrors = $true
                        continue
                    }
                    $thisNotScopeList = [System.Collections.ArrayList]::new()
                    $thisScopeChildren = $thisScopeDetails.childrenTable
                    $thisScopeGlobalNotScopeList = $thisScopeDetails.notScopesList
                    $thisScopeGlobalNotScopeTable = $thisScopeDetails.notScopesTable
                    foreach ($notScope in $definition.notScopesList) {
                        $individualResource = $false
                        if ($notScope -match "subscriptionsPattern") {
                            $thisScopeChildren.Keys | Foreach-Object {
                                if ($thisScopeChildren.$_.type -eq "/subscriptions") {
                                    if ($thisScopeChildren.$_.displayName -like $notScope.split("/")[-1]) {
                                        $null = $thisNotScopeList.Add($thisScopeChildren.$_.id)
                                    }
                                }
                            }
                        }
                        $notScopeTrimmed = $notScope
                        $splits = $notScope -split "/"
                        if ($splits.Count -gt 5) {
                            $individualResource = $true
                            $notScopeTrimmed = $splits[0..4] -join "/"
                        }
                        if (-not $thisScopeGlobalNotScopeTable.ContainsKey($notScopeTrimmed) -or ($notScope -match "subscriptionsPattern")) {
                            if ($thisScopeChildren.ContainsKey($notScopeTrimmed)) {
                                $null = $thisNotScopeList.Add($notScope)
                            }
                            elseif (!$individualResource -and $notScope.Contains("*")) {
                                foreach ($scopeChildId in $thisScopeChildren.Keys) {
                                    if ($scopeChildId -like $notScope) {
                                        $null = $thisNotScopeList.Add($scopeChildId)
                                    }
                                }
                            }
                        }
                    }
                    $null = $thisNotScopeList.AddRange($thisScopeGlobalNotScopeList)
                    $thisNotScopeListUnique = $thisNotScopeList | Select-Object -Unique
                    if ($null -eq $thisNotScopeListUnique) {
                        $thisNotScopeListUnique = @()
                    }
                    elseif ($thisNotScopeListUnique -isnot [array]) {
                        $thisNotScopeListUnique = @($thisNotScopeListUnique)
                    }
                    $scopeResult = @{
                        scope         = $scope
                        notScopesList = $thisNotScopeListUnique
                    }
                    $null = $scopeCollection.Add($scopeResult)
                }
                $definition.scopeCollection = $scopeCollection
            }
        }
    }
    #endregion scopes, notScopes

    #region identity and additionalRoleAssignments (optional, specific to an EPAC environment)
    if ($DefinitionNode.additionalRoleAssignments) {
        # Process additional permissions needed to execute remediations; for example permissions to log to Event Hub, Storage Account or Log Analytics
        $definition.additionalRoleAssignments = Add-SelectedPacArray -InputObject $DefinitionNode.additionalRoleAssignments -PacSelector $pacSelector -ExistingList $definition.additionalRoleAssignments
    }

    if ($DefinitionNode.managedIdentityLocations) {
        # Process managedIdentityLocation; can be overridden
        Add-SelectedPacValue -InputObject $DefinitionNode.managedIdentityLocations -PacSelector $pacSelector -OutputObject $definition -OutputKey "managedIdentityLocation"
    }

    if ($DefinitionNode.userAssignedIdentity) {
        # Process userAssignedIdentity; can be overridden
        Add-SelectedPacValue -InputObject $DefinitionNode.userAssignedIdentity -PacSelector $pacSelector -OutputObject $definition -OutputKey "userAssignedIdentity"
    }
    #endregion identity and additionalRoleAssignments (optional, specific to an EPAC environment)

    #region children and the leaf node
    if ($DefinitionNode.children) {
        # Process child nodes
        Write-Debug " $($DefinitionNode.children.Count) children below at $($nodeName)"
        $hasErrors = $false
        $assignmentsList = [System.Collections.ArrayList]::new()
        foreach ($child in $DefinitionNode.children) {
            $hasErrorsLocal, $assignmentsListLocal = Build-AssignmentDefinitionNode `
                -PacEnvironment $PacEnvironment `
                -ScopeTable $ScopeTable `
                -ParameterFilesCsv $ParameterFilesCsv `
                -DefinitionNode $child `
                -AssignmentDefinition $definition `
                -CombinedPolicyDetails $CombinedPolicyDetails `
                -PolicyRoleIds $PolicyRoleIds `
                -RoleDefinitions $RoleDefinitions `
                -DeprecatedHash $DeprecatedHash

            if ($hasErrorsLocal) {
                $hasErrors = $true
            }
            elseif ($null -ne $assignmentsListLocal) {
                $null = $assignmentsList.AddRange($assignmentsListLocal)
            }
        }
        return $hasErrors, $assignmentsList
    }
    else {
        # Arrived at a leaf node - return the values collected in this branch after checking validity
        if ($definition.ignoreBranch -or $definition.hasOnlyNotSelectedEnvironments -or $definition.hasErrors) {
            # Empty collection
            return $definition.hasErrors, [System.Collections.ArrayList]::new()
        }
        else {
            $hasErrors, $assignmentsListAtLeaf = Build-AssignmentDefinitionAtLeaf `
                -PacEnvironment $PacEnvironment `
                -AssignmentDefinition $definition `
                -CombinedPolicyDetails $CombinedPolicyDetails `
                -PolicyRoleIds $PolicyRoleIds `
                -RoleDefinitions $RoleDefinitions
            return $hasErrors, $assignmentsListAtLeaf
        }
    }
    #endregion children and the leaf node

}
