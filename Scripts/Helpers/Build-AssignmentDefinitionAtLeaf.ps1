function Build-AssignmentDefinitionAtLeaf {
    # Recursive Function
    param(
        $pacEnvironment,
        [hashtable] $assignmentDefinition,
        [hashtable] $combinedPolicyDetails,
        [hashtable] $policyRoleIds

        # Returns a list of completed assignment definitions (each a hashtable)
    )

    #region Validate required fields

    # Must contain a definitionEntry or definitionEntryList
    $definitionEntryList = $assignmentDefinition.definitionEntryList
    $hasErrors = $false
    $nodeName = $assignmentDefinition.nodeName
    if ($definitionEntryList.Count -eq 0) {
        Write-Error "    Leaf Node $($nodeName): each tree branch must define either a definitionEntry or a non-empty definitionEntryList." -ErrorAction Continue
        $hasErrors = $true
    }
    $multipleDefinitionEntries = $definitionEntryList.Count -gt 1

    # Must contain a scopeCollection
    $scopeCollection = $assignmentDefinition.scopeCollection
    if ($null -eq $scopeCollection) {
        Write-Error "    Leaf Node $($nodeName): each tree branch requires exactly one scope definition resulting in a scope collection after notScope calculations." -ErrorAction Continue
        $hasErrors = $true
    }

    #endregion Validate required fields

    #region cache frequently used fields

    $assignmentInDefinition = $assignmentDefinition.assignment
    $parameterFileName = $assignmentDefinition.parameterFileName
    $parameterSelector = $assignmentDefinition.parameterSelector
    $parameterInstructions = @{
        csvParameterArray          = $assignmentDefinition.csvParameterArray
        effectColumn               = $assignmentDefinition.effectColumn
        parametersColumn           = $assignmentDefinition.parametersColumn
        nonComplianceMessageColumn = $assignmentDefinition.nonComplianceMessageColumn
    }

    $overrides = $assignmentDefinition.overrides
    $nonComplianceMessageColumn = $assignmentDefinition.nonComplianceMessageColumn
    $nonComplianceMessages = $assignmentDefinition.nonComplianceMessages
    $hasPolicySets = $assignmentDefinition.hasPolicySets
    $perEntryNonComplianceMessages = $assignmentDefinition.perEntryNonComplianceMessages

    $thisPacOwnerId = $pacEnvironment.pacOwnerId

    #endregion cache frequently used fields

    #region Validate optional parameterFileName, parameterSelector, nonComplianceMessageColumn

    $useCsv = $false
    if ($null -ne $parameterFileName) {
        if (!$hasPolicySets) {
            Write-Error "    Leaf Node $($nodeName): CSV parameterFileName ($parameterFileName) can only be applied to Policy Set(s). This tree branch ($nodeName) does not contain definitionEntries for Policy Sets."
            $hasErrors = $true
        }
        if ($overrides.Count -gt 0) {
            Write-Error "    Leaf Node $($nodeName): CSV parameterFileName ($parameterFileName) usage and explicit overrides are not allowed in the same branch." -ErrorAction Continue
            $hasErrors = $true
        }
        if ($null -ne $nonComplianceMessageColumn) {
            if ($nonComplianceMessages.Count -gt 0 -or $perEntryNonComplianceMessages) {
                Write-Error "    Leaf Node $($nodeName): CSV parameterFileName ($parameterFileName) usage of nonComplianceMessageColumn ($nonComplianceMessageColumn) and explicit nonComplianceMessages are not allowed in the same branch." -ErrorAction Continue
                $hasErrors = $true
            }
        }
        if ($null -ne $parameterSelector) {
            $useCsv = $true
        }
        else {
            Write-Error "    Leaf Node $($nodeName): CSV parameterFileName ($parameterFileName) usage requires a parameterSelector (missing)." -ErrorAction Continue
            $hasErrors = $true
        }
    }
    else {
        if ($null -ne $parameterSelector) {
            Write-Error "    Leaf Node $($nodeName): parameterSelector ($parameterSelector) usage requires a parameterFileName (missing)." -ErrorAction Continue
            $hasErrors = $true
        }
        if ($null -ne $nonComplianceMessageColumn) {
            Write-Error "    Leaf Node $($nodeName): nonComplianceMessageColumn ($nonComplianceMessageColumn) usage requires a parameterFileName (missing)." -ErrorAction Continue
            $hasErrors = $true
        }
    }
    if ($hasErrors) {
        return $true, $null
    }

    #endregion Validate optional parameterFileName, parameterSelector, nonComplianceMessageColumn

    #region Validate CSV columns data

    $csvParameterArray = $assignmentDefinition.csvParameterArray
    $effectColumn = $assignmentDefinition.effectColumn
    $parametersColumn = $assignmentDefinition.parametersColumn
    if ($useCsv) {
        # Validate column names
        $row = $csvParameterArray[0]
        if (-not ($row.ContainsKey("name") -and $row.ContainsKey("referencePath") -and $row.ContainsKey($effectColumn) -and $row.ContainsKey($parametersColumn))) {
            Write-Error "    Leaf Node $($nodeName): CSV parameter file ($parameterFileName) must contain the following columns: name, referencePath, $effectColumn, $parametersColumn."
            return $true, $null
        }

    }
    if ($hasErrors) {
        return $true, $null
    }

    #endregion Validate CSV data

    $assignmentsList = @()
    $policiesDetails = $combinedPolicyDetails.policies
    $policySetsDetails = $combinedPolicyDetails.policySets
    $effectProcessedForPolicy = @{}
    foreach ($definitionEntry in $definitionEntryList) {

        #region Policy definition

        $policyDefinitionId = $definitionEntry.policyDefinitionId
        $isPolicySet = $definitionEntry.isPolicySet
        $policySetDetails = $null
        $policyDetails = $null
        if ($isPolicySet) {
            $policySetDetails = $policySetsDetails.$policyDefinitionId
        }
        else {
            $policyDetails = $policiesDetails.$policyDefinitionId
        }
        # $definitionVersion = $definitionEntry.definitionVersion

        #endregion Policy definition

        #region assignment name, displayName, description, metadata, enforcementMode

        $assignmentInDefinitionEntry = $definitionEntry.assignment
        $name = ""
        $displayName = ""
        $description = ""
        if ($assignmentInDefinitionEntry.append) {
            $name = $assignmentInDefinition.name + $assignmentInDefinitionEntry.name
            $displayName = $assignmentInDefinition.displayName + $assignmentInDefinitionEntry.displayName
            $description = $assignmentInDefinition.description + $assignmentInDefinitionEntry.description
        }
        else {
            $name = $assignmentInDefinitionEntry.name + $assignmentInDefinition.name
            $displayName = $assignmentInDefinitionEntry.displayName + $assignmentInDefinition.displayName
            $description = $assignmentInDefinitionEntry.description + $assignmentInDefinition.description
        }
        if ($name.Length -eq 0 -or $displayName.Length -eq 0) {
            Write-Error "    Leaf Node $($nodeName): each tree branch must define an Assignment name and displayName.`n    name='$name'`n    displayName='$displayName'`n    description=$description"
            $hasErrors = $true
            continue
        }
        $enforcementMode = $assignmentDefinition.enforcementMode
        $metadata = $assignmentDefinition.metadata
        if ($metadata) {
            if ($metadata.ContainsKey("pacOwnerId")) {
                Write-Error "    Leaf Node $($nodeName): metadata.pacOwnerId ($($metadata.pacOwnerId)) may not be set explicitly; it is reserved for EPAC usage."
                $hasErrors = $true
                continue
            }
            if ($metadata.ContainsKey("roles")) {
                Write-Error "    Leaf Node $($nodeName): metadata.roles ($($metadata.roles)) may not be set explicitly; it is reserved for EPAC usage."
                $hasErrors = $true
                continue
            }
            $metadata.pacOwnerId = $thisPacOwnerId
        }
        else {
            $metadata = @{ pacOwnerId = $thisPacOwnerId }
        }

        #endregion assignment name, displayName, description, metadata, enforcementMode

        #region nonComplianceMessages in two variants plus in CSV

        $nonComplianceMessagesList = [System.Collections.ArrayList]::new()
        if ($null -ne $definitionEntry.nonComplianceMessages) {
            if ($definitionEntry.nonComplianceMessages.Count -gt 0) {
                $nonComplianceMessages = $definitionEntry.nonComplianceMessages
                $nonComplianceMessagesList.AddRange($nonComplianceMessages)
            }
        }
        elseif ($assignmentDefinition.nonComplianceMessages.Count -gt 0) {
            $nonComplianceMessagesRaw = $assignmentDefinition.nonComplianceMessages
            if ($multipleDefinitionEntries) {
                foreach ($nonComplianceMessageRaw in $nonComplianceMessagesRaw) {
                    if ($isPolicySet) {
                        $policySetName = $nonComplianceMessageRaw.policySetName
                        $policySetId = $nonComplianceMessageRaw.policySetId
                        if ($null -ne $policySetNamePolicySetName) {
                            if ($name -eq $policySetName) {
                                $null = $nonComplianceMessagesList.AddRange($nonComplianceMessageRaw.message)
                            }
                        }
                        elseif ($null -ne $policySetId) {
                            if ($policyDefinitionId -eq $policySetId) {
                                $null = $nonComplianceMessagesList.AddRange($nonComplianceMessageRaw.message)
                            }
                        }
                        else {
                            Write-Error "    Leaf Node $($nodeName): nonComplianceMessage must specify which Policy Set in the definitionEntryList they belong to by either using policySetName or policySetId: $($nonComplianceMessageRaw | ConvertTo-Json -Depth 3 -Compress)"
                            $hasErrors = $true
                            continue
                        }
                    }
                    else {
                        $policyName = $nonComplianceMessageRaw.policyName
                        $policyId = $nonComplianceMessageRaw.policyId
                        if ($null -ne $policyName) {
                            if ($name -eq $policyName) {
                                $null = $nonComplianceMessagesList.AddRange($nonComplianceMessageRaw.message)
                            }
                        }
                        elseif ($null -ne $policyId) {
                            if ($policyDefinitionId -eq $policyId) {
                                $null = $nonComplianceMessagesList.AddRange($nonComplianceMessageRaw.message)
                            }
                        }
                        else {
                            Write-Error "    Leaf Node $($nodeName): nonComplianceMessage must specify which Policy in the definitionEntryList they belong to by either using policyName or policyId: $($nonComplianceMessageRaw | ConvertTo-Json -Depth 3 -Compress)"
                            $hasErrors = $true
                            continue
                        }
                    }
                }
            }
            else {
                $firstNonComplianceMessagesRaw = $nonComplianceMessagesRaw[0]
                if ($assignmentDefinition.nonComplianceMessages.Count -eq 1 -and $null -ne $firstNonComplianceMessagesRaw.message) {
                    foreach ($nonComplianceMessageRaw in $nonComplianceMessagesRaw) {
                        $null = $nonComplianceMessagesList.AddRange($nonComplianceMessageRaw)
                    }
                }
                elseif ($null -eq $firstNonComplianceMessagesRaw.message) {
                    $null = $nonComplianceMessagesList.AddRange($nonComplianceMessagesRaw)
                }
                else {
                    Write-Error "    Leaf Node $($nodeName): nonComplianceMessage is not valid: $($nonComplianceMessagesRaw | ConvertTo-Json -Depth 3 -Compress)"
                    $hasErrors = $true
                    continue
                }
            }
        }

        #endregion nonComplianceMessages in two variants plus in CSV

        #region resourceSelectors

        # resourceSelectors are similar in behavior to parameters and overrides

        $resourceSelectors = @()
        if ($definitionEntry.resourceSelectors) {
            $resourceSelectors += $definitionEntry.resourceSelectors
        }
        if ($assignmentDefinition.resourceSelectors) {
            $resourceSelectors += $assignmentDefinition.resourceSelectors
        }

        $resourceSelectorsList = [System.Collections.ArrayList]::new()
        if ($resourceSelectors.Count -gt 0) {
            # resourceSelectors are similar in behavior to parameters
            foreach ($resourceSelector in $resourceSelectors) {
                $belongsToThisDefinitionEntry = $false
                if ($isPolicySet) {
                    $policySetName = $resourceSelector.policySetName
                    $policySetId = $resourceSelector.policySetId
                    if ($null -ne $policySetName) {
                        if ($name -eq $policySetName) {
                            $belongsToThisDefinitionEntry = $true
                        }
                    }
                    elseif ($null -ne $policySetId) {
                        if ($policyDefinitionId -eq $policySetId) {
                            $belongsToThisDefinitionEntry = $true
                        }
                    }
                    else {
                        $belongsToThisDefinitionEntry = $true
                    }
                }
                else {
                    $policyName = $resourceSelector.policyName
                    $policyId = $resourceSelector.policyId
                    if ($null -ne $policyName) {
                        if ($name -eq $policyName) {
                            $belongsToThisDefinitionEntry = $true
                        }
                    }
                    elseif ($null -ne $policyId) {
                        if ($policyDefinitionId -eq $policyId) {
                            $belongsToThisDefinitionEntry = $true
                        }
                    }
                    else {
                        $belongsToThisDefinitionEntry = $true
                    }
                }
                if ($belongsToThisDefinitionEntry) {
                    $name = $resourceSelector.name
                    $selectors = $resourceSelector.selectors
                    if ($null -ne $name -and $null -ne $selectors) {
                        $resourceSelectorFinal = @{
                            name      = $name
                            selectors = $selectors
                        }
                        $null = $resourceSelectorsList.Add($resourceSelectorFinal)
                    }
                    else {
                        Write-Error "    Leaf Node $($nodeName): resourceSelector is invalid: $($resourceSelector | ConvertTo-Json -Depth 3 -Compress)"
                        $hasErrors = $true
                    }
                }
            }
        }

        #endregion resourceSelectors

        #region overrides

        $overridesList = [System.Collections.ArrayList]::new()
        if ($overrides.Count -gt 0) {
            # overrides are similar in behavior to parameters
            foreach ($effectOverride in $overrides) {
                $belongsToThisDefinitionEntry = $false
                if ($isPolicySet) {
                    $policySetName = $effectOverride.policySetName
                    $policySetId = $effectOverride.policySetId
                    if ($multipleDefinitionEntries) {
                        if ($null -ne $policySetName) {
                            if ($name -eq $policySetName) {
                                $belongsToThisDefinitionEntry = $true
                            }
                        }
                        elseif ($null -ne $policySetId) {
                            if ($policyDefinitionId -eq $policySetId) {
                                $belongsToThisDefinitionEntry = $true
                            }
                        }
                        else {
                            Write-Error "    Leaf Node $($nodeName): overrides must specify which Policy Set in the definitionEntryList they belong to by either using policySetName or policySetId: $($effectOverride | ConvertTo-Json -Depth 3 -Compress)"
                            $hasErrors = $true
                        }
                    }
                    elseif ($null -ne $policySetName -or $null -ne $policySetId) {
                        Write-Error "    Leaf Node $($nodeName): overrides must NOT specify which Policy Set for a single definitionEntry it belongs to by using policySetName or policySetId: $($effectOverride | ConvertTo-Json -Depth 3 -Compress)"
                        $hasErrors = $true
                    }
                    else {
                        $belongsToThisDefinitionEntry = $true
                    }
                }
                else {
                    $policyName = $effectOverride.policyName
                    $policyId = $effectOverride.policyId
                    if ($multipleDefinitionEntries) {
                        if ($null -ne $policyName) {
                            if ($name -eq $policyName) {
                                $belongsToThisDefinitionEntry = $true
                            }
                        }
                        elseif ($null -ne $policyId) {
                            if ($policyDefinitionId -eq $policyId) {
                                $belongsToThisDefinitionEntry = $true
                            }
                        }
                        else {
                            Write-Error "    Leaf Node $($nodeName): overrides must specify which Policy in the definitionEntryList they belong to by either using policyName or policyId: $($effectOverride | ConvertTo-Json -Depth 3 -Compress)"
                            $hasErrors = $true
                        }
                    }
                    elseif ($null -ne $policySetName -or $null -ne $policySetId) {
                        Write-Error "    Leaf Node $($nodeName): overrides must NOT specify which Policy for a single definitionEntry it belongs to by using policyName or policyId: $($effectOverride | ConvertTo-Json -Depth 3 -Compress)"
                        $hasErrors = $true
                    }
                    else {
                        $belongsToThisDefinitionEntry = $true
                    }
                }
                if ($belongsToThisDefinitionEntry) {
                    $override = $null
                    $kind = $effectOverride.kind
                    $value = $effectOverride.value
                    $selectors = $effectOverride.selectors
                    if ($null -ne $kind -and $null -ne $value) {
                        # raw override
                        if ($isPolicySet) {
                            if ($null -ne $selectors) {
                                $override = @{
                                    kind      = $kind
                                    value     = $value
                                    selectors = $selectors
                                }
                            }
                            else {
                                Write-Error "    Leaf Node $($nodeName): overrides must specify a selectors element for an assignment of a Policy Set: $($effectOverride | ConvertTo-Json -Depth 3 -Compress)"
                                $hasErrors = $true
                            }
                        }
                        else {
                            if ($null -eq $selectors) {
                                $effectAllowedOverrides = $policyDetails.effectAllowedOverrides
                                if ($effectAllowedOverrides -contains $value) {
                                    $override = @{
                                        kind  = "policyEffect"
                                        value = $value
                                    }
                                }
                                else {
                                    Write-Error "    Leaf Node $($nodeName): overrides must specify a valid effect ($($effectAllowedOverrides -join ",")): $($effectOverride | ConvertTo-Json -Depth 3 -Compress)"
                                    $hasErrors = $true
                                }
                            }
                            else {
                                Write-Error "    Leaf Node $($nodeName): overrides must NOT specify a selectors element for an assignment of a Policy: $($effectOverride | ConvertTo-Json -Depth 3 -Compress)"
                                $hasErrors = $true
                            }
                        }
                        if ($null -ne $override) {
                            $null = $overridesList.Add($override)
                        }
                    }
                    else {
                        Write-Error "    Leaf Node $($nodeName): overrides must specify a kind and value element: $($effectOverride | ConvertTo-Json -Depth 3 -Compress)"
                        $hasErrors = $true
                    }
                }
            }
        }

        #endregion overrides

        #region identity (location, user-assigned, additionalRoleAssignments)

        $baseRoleAssignmentSpecs = @()
        $roleDefinitionIds = $null
        $identityRequired = $false
        $managedIdentityLocation = $null
        $identitySpec = $null
        if ($policyRoleIds.ContainsKey($policyDefinitionId)) {

            # calculate identity
            $identity = $null
            if ($assignmentDefinition.userAssignedIdentity) {
                $userAssignedIdentityRaw = $assignmentDefinition.userAssignedIdentity
                if ($userAssignedIdentityRaw -is [string]) {
                    $identity = $userAssignedIdentityRaw
                }
                elseif ($userAssignedIdentityRaw -is [array]) {
                    foreach ($item in $userAssignedIdentityRaw) {
                        if ($isPolicySet) {
                            $policySetName = $item.policySetName
                            $policySetId = $item.policySetId
                            if ($null -ne $policySetName) {
                                if ($name -eq $policySetName) {
                                    $identity = $item.identity
                                }
                            }
                            elseif ($null -ne $policySetId) {
                                if ($policyDefinitionId -eq $policySetId) {
                                    $identity = $item.identity
                                }
                            }
                            else {
                                Write-Error "    Leaf Node $($nodeName): userAssignedIdentity must specify which Policy Set in the definitionEntryList they belong to by either using policySetName or policySetId: $($userAssignedIdentityRaw | ConvertTo-Json -Depth 3 -Compress)"
                                $hasErrors = $true
                                continue
                            }
                        }
                        else {
                            $policyName = $item.policyName
                            $policyId = $item.policyId
                            if ($null -ne $policyName) {
                                if ($name -eq $policyName) {
                                    $identity = $item.identity
                                }
                            }
                            elseif ($null -ne $policyId) {
                                if ($policyDefinitionId -eq $policyId) {
                                    $identity = $item.identity
                                }
                            }
                            else {
                                Write-Error "    Leaf Node $($nodeName): userAssignedIdentity must specify which Policy in the definitionEntryList they belong to by either using policyName or policyId: $($userAssignedIdentityRaw | ConvertTo-Json -Depth 3 -Compress)"
                                $hasErrors = $true
                                continue
                            }
                        }
                    }
                }
                else {
                    Write-Error "    Leaf Node $($nodeName): userAssignedIdentity is not valid: $($userAssignedIdentityRaw | ConvertTo-Json -Depth 3 -Compress)" -ErrorAction Stop
                }
            }
            $identityRequired = $true
            if ($null -ne $assignmentDefinition.managedIdentityLocation) {
                $managedIdentityLocation = $assignmentDefinition.managedIdentityLocation
            }
            else {
                Write-Error "    Leaf Node $($nodeName): Assignment requires an identity and the definition does not define a managedIdentityLocation" -ErrorAction Stop
            }

            if ($null -eq $identity) {
                $identitySpec = @{
                    type = "SystemAssigned"
                }
            }
            else {
                $identitySpec = @{
                    type                   = "UserAssigned"
                    userAssignedIdentities = @{
                        $identity = @{}
                    }
                }
            }

            $additionalRoleAssignments = $assignmentDefinition.additionalRoleAssignments
            if ($additionalRoleAssignments -and $additionalRoleAssignments.Length -gt 0) {
                foreach ($additionalRoleAssignment in $additionalRoleAssignments) {
                    $roleDefinitionId = $additionalRoleAssignment.roleDefinitionId
                    $roleDisplayName = "Unknown"
                    $roleDefinitionName = ($roleDefinitionId.Split("/"))[-1]
                    if ($roleDefinitions.ContainsKey($roleDefinitionName)) {
                        $roleDisplayName = $roleDefinitions.$roleDefinitionName
                    }
                    $baseRoleAssignmentSpecs += @{
                        scope            = $additionalRoleAssignment.scope
                        roleDefinitionId = $roleDefinitionId
                        roleDisplayName  = $roleDisplayName
                    }
                }
            }
        }
        else {
            $identitySpec = @{
                type = "None"
            }
        }

        #endregion identity (location, user-assigned, additionalRoleAssignments)


        #region baseAssignment

        $baseAssignment = @{
            name               = $name
            identity           = $identitySpec
            identityRequired   = $identityRequired
            policyDefinitionId = $policyDefinitionId
            displayName        = $displayName
            enforcementMode    = $enforcementMode
            metadata           = $metadata
            parameters         = $assignmentDefinition.parameters
        }

        if ($identityRequired) {
            $baseAssignment.managedIdentityLocation = $managedIdentityLocation
        }
        # if ($null -ne $definitionVersion) {
        #     $baseAssignment.definitionVersion = $definitionVersion
        # }
        if ($description -ne "") {
            $baseAssignment.description = $description
        }
        if ($resourceSelectorsList.Count -gt 0) {
            $baseAssignment.resourceSelectors = $resourceSelectorsList.ToArray()
        }
        if ($overridesList.Count -gt 0) {
            $baseAssignment.overrides = $overridesList.ToArray()
        }
        if ($nonComplianceMessagesList.Count -gt 0) {
            $baseAssignment.nonComplianceMessages = $nonComplianceMessagesList.ToArray()
        }

        #endregion baseAssignment

        #region Reconcile and deduplicate: CSV, parameters, nonComplianceMessages, and overrides

        $parameterObject = $null
        $parametersInPolicyDefinition = @{}
        if ($isPolicySet) {
            $parametersInPolicyDefinition = $policySetDetails.parameters
            if ($useCsv) {
                $localHasErrors = Merge-AssignmentParametersEx `
                    -nodeName $nodeName `
                    -policySetId $policyDefinitionId `
                    -baseAssignment $baseAssignment `
                    -parameterInstructions $parameterInstructions `
                    -flatPolicyList $flatPolicyList `
                    -combinedPolicyDetails $combinedPolicyDetails `
                    -effectProcessedForPolicy $effectProcessedForPolicy
                if ($localHasErrors) {
                    $hasErrors = $true
                    continue
                }
            }
        }
        else {
            $parametersInPolicyDefinition = $policyDetails.parameters
        }

        $parameterObject = Build-AssignmentParameterObject `
            -assignmentParameters $baseAssignment.parameters `
            -parametersInPolicyDefinition $parametersInPolicyDefinition

        if ($parameterObject.psbase.Count -gt 0) {
            $baseAssignment.parameters = $parameterObject
        }
        else {
            $baseAssignment.Remove("parameters")
        }
        if ($baseAssignment.overrides.Count -eq 0) {
            $baseAssignment.Remove("overrides")
        }
        if ($baseAssignment.resourceSelectors.Count -eq 0) {
            $baseAssignment.Remove("resourceSelectors")
        }
        if ($baseAssignment.nonComplianceMessages.Count -eq 0) {
            $baseAssignment.Remove("nonComplianceMessages")
        }

        #endregion Reconcile and deduplicate: CSV, parameters, nonComplianceMessages, and overrides

        #region scopeCollection

        foreach ($scopeEntry in $scopeCollection) {

            # Clone hashtable
            [hashtable] $scopedAssignment = Get-DeepClone $baseAssignment -AsHashTable

            # Complete processing roleDefinitions and add with metadata to hashtable
            if ($identityRequired) {

                $roleAssignmentSpecs = @()
                $roleAssignmentSpecs += $baseRoleAssignmentSpecs
                $roleDefinitionIds = $policyRoleIds.$policyDefinitionId
                foreach ($roleDefinitionId in $roleDefinitionIds) {
                    $roleDisplayName = "Unknown"
                    $roleDefinitionName = ($roleDefinitionId.Split("/"))[-1]
                    if ($roleDefinitions.ContainsKey($roleDefinitionName)) {
                        $roleDisplayName = $roleDefinitions.$roleDefinitionName
                    }
                    $roleAssignmentSpecs += @{
                        scope            = $scopeEntry.scope
                        roleDefinitionId = $roleDefinitionId
                        roleDisplayName  = $roleDisplayName
                    }
                }
                $scopedAssignment.metadata.roles = $roleAssignmentSpecs
            }

            # Add scope and if defined notScopes()
            $scope = $scopeEntry.scope
            $id = "$scope/providers/Microsoft.Authorization/policyAssignments/$($baseAssignment.name)"
            $scopedAssignment.id = $id
            $scopedAssignment.scope = $scope
            if ($scopeEntry.notScope.Length -gt 0) {
                $scopedAssignment.notScopes = @() + $scopeEntry.notScope
            }
            else {
                $scopedAssignment.notScopes = @()
            }

            # Add completed hashtable to collection
            $assignmentsList += $scopedAssignment

        }

        #endregion scopeCollection

    }
    return $hasErrors, $assignmentsList
}
