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
    $pacSelector = $pacEnvironment.pacSelector

    #region nodeName (required)

    $nodeName = $definition.nodeName
    if ($definitionNode.nodeName) {
        $nodeName += $definitionNode.nodeName
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
    if ($definitionNode.ignoreBranch) {
        # Does not deploy assignment(s), precedes Azure Policy feature enforcementMode
        Write-Warning "    Node $($nodeName): ignoreBranch is legacy, consider using enforcementMode instead."
        $definition.ignoreBranch = $definitionNode.ignoreBranch
    }
    if ($definitionNode.enforcementMode) {
        # Does deploy assignment(s), Azure Policy Engine will not evaluate the Policy Assignment
        $enforcementMode = $definitionNode.enforcementMode
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

    #endregion assignment (required at least once per branch, concatenate strings)

    #region definitionEntry or definitionEntryList (required exactly once per branch)

    $definitionEntry = $definitionNode.definitionEntry
    $definitionEntryList = $definitionNode.definitionEntryList
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
            $itemArrayList = [System.Collections.ArrayList]::new()
            $perEntryNonComplianceMessages = $false

            foreach ($definitionEntry in $definitionEntryList) {

                $isValid, $normalizedEntry = Build-AssignmentDefinitionEntry `
                    -definitionEntry $definitionEntry `
                    -nodeName $nodeName `
                    -policyDefinitionsScopes $pacEnvironment.policyDefinitionsScopes `
                    -combinedPolicyDetails $combinedPolicyDetails `
                    -mustDefineAssignment:$mustDefineAssignment
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
                        $null = $itemArrayList.Add($itemEntry)
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
            $hasPolicySets = $itemArrayList.Count -gt 0
            if ($hasPolicySets) {
                $flatPolicyList = Convert-PolicySetsToFlatList `
                    -itemList $itemArrayList.ToArray() `
                    -details $combinedPolicyDetails.policySets
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
    #endregion metadata

    #region parameters

    # parameters in JSON; parameters defined at a deeper level override previous parameters (union operator)
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
        $parameterSelector = $definitionNode.parameterSelector
        $definition.parameterSelector = $parameterSelector
        $definition.effectColumn = "$($parameterSelector)Effect"
        $definition.parametersColumn = "$($parameterSelector)Parameters"
    }
    if ($definitionNode.parameterFile) {
        $parameterFileName = $definitionNode.parameterFile
        if ($parameterFilesCsv.ContainsKey($parameterFileName)) {
            $fullName = $parameterFilesCsv.$parameterFileName
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
                Write-Warning "    Node $($nodeName): CSV parameterFile '$parameterFileName' has an empty row."
                continue
            }

            # generate the key into the flatPolicyList
            $policyId = Confirm-PolicyDefinitionUsedExists -name $name -policyDefinitionsScopes $pacEnvironment.policyDefinitionsScopes -allDefinitions $combinedPolicyDetails.policies -suppressErrorMessage
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

    if ($definitionNode.overrides) {
        # Cumulative in branch
        # overrides behave like parameters, we define them similarly (simplified from Azure Policy)
        $definition.overrides += $definitionNode.overrides
    }

    if ($definitionNode.resourceSelectors) {
        # Cumulative in branch
        # resourceSelectors behave like parameters, we define them similarly (simplified from Azure Policy)
        $definition.resourceSelectors += $definitionNode.resourceSelectors
    }

    if ($definitionNode.nonComplianceMessageColumn) {
        # nonComplianceMessages are in a column in the parameters csv file
        $definition.nonComplianceMessageColumn = $definitionNode.nonComplianceMessageColumn
    }
    if ($definitionNode.nonComplianceMessages) {
        $definition.nonComplianceMessages += $definitionNode.nonComplianceMessages
    }

    #endregion advanced parameters - overrides and resourceSelectors

    #region scopes, notScopes
    if ($definition.scopeCollection -or $definition.hasOnlyNotSelectedEnvironments) {
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
        if ($definitionNode.notScope) {
            $notScope = $definitionNode.notScope
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
        if ($definitionNode.scope) {
            ## Found a scope list - process notScope
            $scopeList = $null
            $scope = $definitionNode.scope
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
    #endregion scopes, notScopes

    #region identity and additionalRoleAssignments (optional, specific to an EPAC environment)

    if ($definitionNode.additionalRoleAssignments) {
        # Process additional permissions needed to execute remediations; for example permissions to log to Event Hub, Storage Account or Log Analytics
        $additionalRoleAssignments = $definitionNode.additionalRoleAssignments
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

    if ($definitionNode.managedIdentityLocations) {
        # Process managedIdentityLocation; can be overridden
        $managedIdentityLocations = $definitionNode.managedIdentityLocations
        $localManagedIdentityLocationValue = Get-SelectedPacValue $managedIdentityLocations -pacSelector $pacSelector
        if ($null -ne $localManagedIdentityLocationValue) {
            $definition.managedIdentityLocation = $localManagedIdentityLocationValue
        }
    }

    if ($definitionNode.userAssignedIdentity) {
        # Process userAssignedIdentity; can be overridden
        $localUserAssignedIdentityRaw = Get-SelectedPacValue $definitionNode.userAssignedIdentity -pacSelector $pacSelector
        if ($null -ne $localUserAssignedIdentityRaw) {
            $definition.userAssignedIdentity = $localUserAssignedIdentityRaw
        }
    }

    #endregion identity and additionalRoleAssignments (optional, specific to an EPAC environment)

    #region children and the leaf node
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
            # Empty collection
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
