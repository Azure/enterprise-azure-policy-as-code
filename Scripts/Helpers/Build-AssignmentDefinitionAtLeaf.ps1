function Build-AssignmentDefinitionAtLeaf {
    # Recursive Function
    param(
        $PacEnvironment,
        [hashtable] $AssignmentDefinition,
        [hashtable] $CombinedPolicyDetails,
        [hashtable] $PolicyRoleIds

        # Returns a list of completed assignment definitions (each a hashtable)
    )

    #region Validate required fields

    # Must contain a definitionEntry or definitionEntryList
    $DefinitionEntryList = $AssignmentDefinition.definitionEntryList
    $hasErrors = $false
    $NodeName = $AssignmentDefinition.nodeName
    if ($DefinitionEntryList.Count -eq 0) {
        Write-Error "    Leaf Node $($NodeName): each tree branch must define either a definitionEntry or a non-empty definitionEntryList." -ErrorAction Continue
        $hasErrors = $true
    }
    $multipleDefinitionEntries = $DefinitionEntryList.Count -gt 1

    # Must contain a scopeCollection
    $ScopeCollection = $AssignmentDefinition.scopeCollection
    if ($null -eq $ScopeCollection) {
        Write-Error "    Leaf Node $($NodeName): each tree branch requires exactly one scope definition resulting in a scope collection after notScope calculations." -ErrorAction Continue
        $hasErrors = $true
    }

    #endregion Validate required fields

    #region cache frequently used fields

    $AssignmentInDefinition = $AssignmentDefinition.assignment
    $parameterFileName = $AssignmentDefinition.parameterFileName
    $Parameterselector = $AssignmentDefinition.parameterSelector
    $ParameterInstructions = @{
        csvParameterArray          = $AssignmentDefinition.csvParameterArray
        effectColumn               = $AssignmentDefinition.effectColumn
        parametersColumn           = $AssignmentDefinition.parametersColumn
        nonComplianceMessageColumn = $AssignmentDefinition.nonComplianceMessageColumn
    }

    $overrides = $AssignmentDefinition.overrides
    $nonComplianceMessageColumn = $AssignmentDefinition.nonComplianceMessageColumn
    $nonComplianceMessages = $AssignmentDefinition.nonComplianceMessages
    $hasPolicySets = $AssignmentDefinition.hasPolicySets
    $perEntryNonComplianceMessages = $AssignmentDefinition.perEntryNonComplianceMessages

    $ThisPacOwnerId = $PacEnvironment.pacOwnerId

    #endregion cache frequently used fields

    #region Validate optional parameterFileName, parameterSelector, nonComplianceMessageColumn

    $useCsv = $false
    if ($null -ne $parameterFileName) {
        if (!$hasPolicySets) {
            Write-Error "    Leaf Node $($NodeName): CSV parameterFileName ($parameterFileName) can only be applied to Policy Set(s). This tree branch ($NodeName) does not contain definitionEntries for Policy Sets."
            $hasErrors = $true
        }
        if ($overrides.Count -gt 0) {
            Write-Error "    Leaf Node $($NodeName): CSV parameterFileName ($parameterFileName) usage and explicit overrides are not allowed in the same branch." -ErrorAction Continue
            $hasErrors = $true
        }
        if ($null -ne $nonComplianceMessageColumn) {
            if ($nonComplianceMessages.Count -gt 0 -or $perEntryNonComplianceMessages) {
                Write-Error "    Leaf Node $($NodeName): CSV parameterFileName ($parameterFileName) usage of nonComplianceMessageColumn ($nonComplianceMessageColumn) and explicit nonComplianceMessages are not allowed in the same branch." -ErrorAction Continue
                $hasErrors = $true
            }
        }
        if ($null -ne $Parameterselector) {
            $useCsv = $true
        }
        else {
            Write-Error "    Leaf Node $($NodeName): CSV parameterFileName ($parameterFileName) usage requires a parameterSelector (missing)." -ErrorAction Continue
            $hasErrors = $true
        }
    }
    else {
        if ($null -ne $Parameterselector) {
            Write-Error "    Leaf Node $($NodeName): parameterSelector ($Parameterselector) usage requires a parameterFileName (missing)." -ErrorAction Continue
            $hasErrors = $true
        }
        if ($null -ne $nonComplianceMessageColumn) {
            Write-Error "    Leaf Node $($NodeName): nonComplianceMessageColumn ($nonComplianceMessageColumn) usage requires a parameterFileName (missing)." -ErrorAction Continue
            $hasErrors = $true
        }
    }
    if ($hasErrors) {
        return $true, $null
    }

    #endregion Validate optional parameterFileName, parameterSelector, nonComplianceMessageColumn

    #region Validate CSV columns data

    $csvParameterArray = $AssignmentDefinition.csvParameterArray
    $EffectColumn = $AssignmentDefinition.effectColumn
    $ParametersColumn = $AssignmentDefinition.parametersColumn
    if ($useCsv) {
        # Validate column names
        $row = $csvParameterArray[0]
        if (-not ($row.ContainsKey("name") -and $row.ContainsKey("referencePath") -and $row.ContainsKey($EffectColumn) -and $row.ContainsKey($ParametersColumn))) {
            Write-Error "    Leaf Node $($NodeName): CSV parameter file ($parameterFileName) must contain the following columns: name, referencePath, $EffectColumn, $ParametersColumn."
            return $true, $null
        }

    }
    if ($hasErrors) {
        return $true, $null
    }

    #endregion Validate CSV data

    $AssignmentsList = @()
    $policiesDetails = $CombinedPolicyDetails.policies
    $PolicySetsDetails = $CombinedPolicyDetails.policySets
    $EffectProcessedForPolicy = @{}
    foreach ($DefinitionEntry in $DefinitionEntryList) {

        #region Policy definition

        $PolicyDefinitionId = $DefinitionEntry.policyDefinitionId
        $isPolicySet = $DefinitionEntry.isPolicySet
        $PolicySetDetails = $null
        $PolicyDetails = $null
        if ($isPolicySet) {
            $PolicySetDetails = $PolicySetsDetails.$PolicyDefinitionId
        }
        else {
            $PolicyDetails = $policiesDetails.$PolicyDefinitionId
        }
        # $DefinitionVersion = $DefinitionEntry.definitionVersion

        #endregion Policy definition

        #region assignment name, displayName, description, metadata, enforcementMode

        $AssignmentInDefinitionEntry = $DefinitionEntry.assignment
        $Name = ""
        $DisplayName = ""
        $description = ""
        if ($AssignmentInDefinitionEntry.append) {
            $Name = $AssignmentInDefinition.name + $AssignmentInDefinitionEntry.name
            $DisplayName = $AssignmentInDefinition.displayName + $AssignmentInDefinitionEntry.displayName
            $description = $AssignmentInDefinition.description + $AssignmentInDefinitionEntry.description
        }
        else {
            $Name = $AssignmentInDefinitionEntry.name + $AssignmentInDefinition.name
            $DisplayName = $AssignmentInDefinitionEntry.displayName + $AssignmentInDefinition.displayName
            $description = $AssignmentInDefinitionEntry.description + $AssignmentInDefinition.description
        }
        if ($Name.Length -eq 0 -or $DisplayName.Length -eq 0) {
            Write-Error "    Leaf Node $($NodeName): each tree branch must define an Assignment name and displayName.`n    name='$Name'`n    displayName='$DisplayName'`n    description=$description"
            $hasErrors = $true
            continue
        }
        $enforcementMode = $AssignmentDefinition.enforcementMode
        $Metadata = $AssignmentDefinition.metadata
        if ($Metadata) {
            if ($Metadata.ContainsKey("pacOwnerId")) {
                Write-Error "    Leaf Node $($NodeName): metadata.pacOwnerId ($($Metadata.pacOwnerId)) may not be set explicitly; it is reserved for EPAC usage."
                $hasErrors = $true
                continue
            }
            if ($Metadata.ContainsKey("roles")) {
                Write-Error "    Leaf Node $($NodeName): metadata.roles ($($Metadata.roles)) may not be set explicitly; it is reserved for EPAC usage."
                $hasErrors = $true
                continue
            }
            $Metadata.pacOwnerId = $ThisPacOwnerId
        }
        else {
            $Metadata = @{ pacOwnerId = $ThisPacOwnerId }
        }

        #endregion assignment name, displayName, description, metadata, enforcementMode

        #region nonComplianceMessages in two variants

        $nonComplianceMessagesList = [System.Collections.ArrayList]::new()
        if ($null -ne $DefinitionEntry.nonComplianceMessages -and $DefinitionEntry.nonComplianceMessages.Count -gt 0) {
            $nonComplianceMessages = $DefinitionEntry.nonComplianceMessages
            $null = $nonComplianceMessagesList.AddRange($nonComplianceMessages)
        }
        if ($null -ne $AssignmentDefinition.nonComplianceMessages -and $AssignmentDefinition.nonComplianceMessages.Count -gt 0) {
            if ($multipleDefinitionEntries) {
                Write-Error "    Leaf Node $($NodeName): nonComplianceMessage for an assignment file with a definitionEntryList must be contained in each definitionEntry or specified in a CSV file"
                $hasErrors = $true
            }
            $nonComplianceMessages = $AssignmentDefinition.nonComplianceMessages
            $null = $nonComplianceMessagesList.AddRange($nonComplianceMessages)
        }
        foreach ($nonComplianceMessageRaw in $nonComplianceMessagesList) {
            if ($null -eq $nonComplianceMessageRaw.message -or $nonComplianceMessageRaw.message -eq "") {
                Write-Error "    Leaf Node $($NodeName): each nonComplianceMessage must conatin a message string: $($nonComplianceMessageRaw | ConvertTo-Json -Depth 3 -Compress)"
                $hasErrors = $true
            }
        }

        #endregion nonComplianceMessages in two variants

        #region resourceSelectors

        # resourceSelectors are similar in behavior to parameters and overrides

        $resourceSelectors = @()
        if ($DefinitionEntry.resourceSelectors) {
            $resourceSelectors += $DefinitionEntry.resourceSelectors
        }
        if ($AssignmentDefinition.resourceSelectors) {
            $resourceSelectors += $AssignmentDefinition.resourceSelectors
        }

        $resourceSelectorsList = [System.Collections.ArrayList]::new()
        if ($resourceSelectors.Count -gt 0) {
            # resourceSelectors are similar in behavior to parameters
            foreach ($resourceSelector in $resourceSelectors) {
                $belongsToThisDefinitionEntry = $false
                if ($isPolicySet) {
                    $PolicySetName = $resourceSelector.policySetName
                    $PolicySetId = $resourceSelector.policySetId
                    if ($null -ne $PolicySetName) {
                        if ($Name -eq $PolicySetName) {
                            $belongsToThisDefinitionEntry = $true
                        }
                    }
                    elseif ($null -ne $PolicySetId) {
                        if ($PolicyDefinitionId -eq $PolicySetId) {
                            $belongsToThisDefinitionEntry = $true
                        }
                    }
                    else {
                        $belongsToThisDefinitionEntry = $true
                    }
                }
                else {
                    $PolicyName = $resourceSelector.policyName
                    $PolicyId = $resourceSelector.policyId
                    if ($null -ne $PolicyName) {
                        if ($Name -eq $PolicyName) {
                            $belongsToThisDefinitionEntry = $true
                        }
                    }
                    elseif ($null -ne $PolicyId) {
                        if ($PolicyDefinitionId -eq $PolicyId) {
                            $belongsToThisDefinitionEntry = $true
                        }
                    }
                    else {
                        $belongsToThisDefinitionEntry = $true
                    }
                }
                if ($belongsToThisDefinitionEntry) {
                    $Name = $resourceSelector.name
                    $selectors = $resourceSelector.selectors
                    if ($null -ne $Name -and $null -ne $selectors) {
                        $resourceSelectorFinal = @{
                            name      = $Name
                            selectors = $selectors
                        }
                        $null = $resourceSelectorsList.Add($resourceSelectorFinal)
                    }
                    else {
                        Write-Error "    Leaf Node $($NodeName): resourceSelector is invalid: $($resourceSelector | ConvertTo-Json -Depth 3 -Compress)"
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
            foreach ($EffectOverride in $overrides) {
                $belongsToThisDefinitionEntry = $false
                if ($isPolicySet) {
                    $PolicySetName = $EffectOverride.policySetName
                    $PolicySetId = $EffectOverride.policySetId
                    if ($multipleDefinitionEntries) {
                        if ($null -ne $PolicySetName) {
                            if ($Name -eq $PolicySetName) {
                                $belongsToThisDefinitionEntry = $true
                            }
                        }
                        elseif ($null -ne $PolicySetId) {
                            if ($PolicyDefinitionId -eq $PolicySetId) {
                                $belongsToThisDefinitionEntry = $true
                            }
                        }
                        else {
                            Write-Error "    Leaf Node $($NodeName): overrides must specify which Policy Set in the definitionEntryList they belong to by either using policySetName or policySetId: $($EffectOverride | ConvertTo-Json -Depth 3 -Compress)"
                            $hasErrors = $true
                        }
                    }
                    elseif ($null -ne $PolicySetName -or $null -ne $PolicySetId) {
                        Write-Error "    Leaf Node $($NodeName): overrides must NOT specify which Policy Set for a single definitionEntry it belongs to by using policySetName or policySetId: $($EffectOverride | ConvertTo-Json -Depth 3 -Compress)"
                        $hasErrors = $true
                    }
                    else {
                        $belongsToThisDefinitionEntry = $true
                    }
                }
                else {
                    $PolicyName = $EffectOverride.policyName
                    $PolicyId = $EffectOverride.policyId
                    if ($multipleDefinitionEntries) {
                        if ($null -ne $PolicyName) {
                            if ($Name -eq $PolicyName) {
                                $belongsToThisDefinitionEntry = $true
                            }
                        }
                        elseif ($null -ne $PolicyId) {
                            if ($PolicyDefinitionId -eq $PolicyId) {
                                $belongsToThisDefinitionEntry = $true
                            }
                        }
                        else {
                            Write-Error "    Leaf Node $($NodeName): overrides must specify which Policy in the definitionEntryList they belong to by either using policyName or policyId: $($EffectOverride | ConvertTo-Json -Depth 3 -Compress)"
                            $hasErrors = $true
                        }
                    }
                    elseif ($null -ne $PolicySetName -or $null -ne $PolicySetId) {
                        Write-Error "    Leaf Node $($NodeName): overrides must NOT specify which Policy for a single definitionEntry it belongs to by using policyName or policyId: $($EffectOverride | ConvertTo-Json -Depth 3 -Compress)"
                        $hasErrors = $true
                    }
                    else {
                        $belongsToThisDefinitionEntry = $true
                    }
                }
                if ($belongsToThisDefinitionEntry) {
                    $override = $null
                    $kind = $EffectOverride.kind
                    $value = $EffectOverride.value
                    $selectors = $EffectOverride.selectors
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
                                Write-Error "    Leaf Node $($NodeName): overrides must specify a selectors element for an assignment of a Policy Set: $($EffectOverride | ConvertTo-Json -Depth 3 -Compress)"
                                $hasErrors = $true
                            }
                        }
                        else {
                            if ($null -eq $selectors) {
                                $EffectAllowedOverrides = $PolicyDetails.effectAllowedOverrides
                                if ($EffectAllowedOverrides -contains $value) {
                                    $override = @{
                                        kind  = "policyEffect"
                                        value = $value
                                    }
                                }
                                else {
                                    Write-Error "    Leaf Node $($NodeName): overrides must specify a valid effect ($($EffectAllowedOverrides -join ",")): $($EffectOverride | ConvertTo-Json -Depth 3 -Compress)"
                                    $hasErrors = $true
                                }
                            }
                            else {
                                Write-Error "    Leaf Node $($NodeName): overrides must NOT specify a selectors element for an assignment of a Policy: $($EffectOverride | ConvertTo-Json -Depth 3 -Compress)"
                                $hasErrors = $true
                            }
                        }
                        if ($null -ne $override) {
                            $null = $overridesList.Add($override)
                        }
                    }
                    else {
                        Write-Error "    Leaf Node $($NodeName): overrides must specify a kind and value element: $($EffectOverride | ConvertTo-Json -Depth 3 -Compress)"
                        $hasErrors = $true
                    }
                }
            }
        }

        #endregion overrides

        #region identity (location, user-assigned, additionalRoleAssignments)

        $baseRoleAssignmentSpecs = @()
        $roleDefinitionIds = $null
        $IdentityRequired = $false
        $managedIdentityLocation = $null
        $IdentitySpec = $null
        if ($PolicyRoleIds.ContainsKey($PolicyDefinitionId)) {

            # calculate identity
            $Identity = $null
            if ($AssignmentDefinition.userAssignedIdentity) {
                $userAssignedIdentityRaw = $AssignmentDefinition.userAssignedIdentity
                if ($userAssignedIdentityRaw -is [string]) {
                    $Identity = $userAssignedIdentityRaw
                }
                elseif ($userAssignedIdentityRaw -is [array]) {
                    foreach ($item in $userAssignedIdentityRaw) {
                        if ($isPolicySet) {
                            $PolicySetName = $item.policySetName
                            $PolicySetId = $item.policySetId
                            if ($null -ne $PolicySetName) {
                                if ($Name -eq $PolicySetName) {
                                    $Identity = $item.identity
                                }
                            }
                            elseif ($null -ne $PolicySetId) {
                                if ($PolicyDefinitionId -eq $PolicySetId) {
                                    $Identity = $item.identity
                                }
                            }
                            else {
                                Write-Error "    Leaf Node $($NodeName): userAssignedIdentity must specify which Policy Set in the definitionEntryList they belong to by either using policySetName or policySetId: $($userAssignedIdentityRaw | ConvertTo-Json -Depth 3 -Compress)"
                                $hasErrors = $true
                                continue
                            }
                        }
                        else {
                            $PolicyName = $item.policyName
                            $PolicyId = $item.policyId
                            if ($null -ne $PolicyName) {
                                if ($Name -eq $PolicyName) {
                                    $Identity = $item.identity
                                }
                            }
                            elseif ($null -ne $PolicyId) {
                                if ($PolicyDefinitionId -eq $PolicyId) {
                                    $Identity = $item.identity
                                }
                            }
                            else {
                                Write-Error "    Leaf Node $($NodeName): userAssignedIdentity must specify which Policy in the definitionEntryList they belong to by either using policyName or policyId: $($userAssignedIdentityRaw | ConvertTo-Json -Depth 3 -Compress)"
                                $hasErrors = $true
                                continue
                            }
                        }
                    }
                }
                else {
                    Write-Error "    Leaf Node $($NodeName): userAssignedIdentity is not valid: $($userAssignedIdentityRaw | ConvertTo-Json -Depth 3 -Compress)" -ErrorAction Stop
                }
            }
            $IdentityRequired = $true
            if ($null -ne $AssignmentDefinition.managedIdentityLocation) {
                $managedIdentityLocation = $AssignmentDefinition.managedIdentityLocation
            }
            else {
                Write-Error "    Leaf Node $($NodeName): Assignment requires an identity and the definition does not define a managedIdentityLocation" -ErrorAction Stop
            }

            if ($null -eq $Identity) {
                $IdentitySpec = @{
                    type = "SystemAssigned"
                }
            }
            else {
                $IdentitySpec = @{
                    type                   = "UserAssigned"
                    userAssignedIdentities = @{
                        $Identity = @{}
                    }
                }
            }

            $additionalRoleAssignments = $AssignmentDefinition.additionalRoleAssignments
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
            $IdentitySpec = @{
                type = "None"
            }
        }

        #endregion identity (location, user-assigned, additionalRoleAssignments)


        #region baseAssignment

        $BaseAssignment = @{
            name               = $Name
            identity           = $IdentitySpec
            identityRequired   = $IdentityRequired
            policyDefinitionId = $PolicyDefinitionId
            displayName        = $DisplayName
            enforcementMode    = $enforcementMode
            metadata           = $Metadata
            parameters         = $AssignmentDefinition.parameters
        }

        if ($IdentityRequired) {
            $BaseAssignment.managedIdentityLocation = $managedIdentityLocation
        }
        # if ($null -ne $DefinitionVersion) {
        #     $BaseAssignment.definitionVersion = $DefinitionVersion
        # }
        if ($description -ne "") {
            $BaseAssignment.description = $description
        }
        if ($resourceSelectorsList.Count -gt 0) {
            $BaseAssignment.resourceSelectors = $resourceSelectorsList.ToArray()
        }
        if ($overridesList.Count -gt 0) {
            $BaseAssignment.overrides = $overridesList.ToArray()
        }
        $BaseAssignment.nonComplianceMessages = $nonComplianceMessagesList

        #endregion baseAssignment

        #region Reconcile and deduplicate: CSV, parameters, nonComplianceMessages, and overrides

        $parameterObject = $null
        $ParametersInPolicyDefinition = @{}
        if ($isPolicySet) {
            $ParametersInPolicyDefinition = $PolicySetDetails.parameters
            if ($useCsv) {
                $localHasErrors = Merge-AssignmentParametersEx `
                    -NodeName $NodeName `
                    -PolicySetId $PolicyDefinitionId `
                    -BaseAssignment $BaseAssignment `
                    -ParameterInstructions $ParameterInstructions `
                    -FlatPolicyList $FlatPolicyList `
                    -CombinedPolicyDetails $CombinedPolicyDetails `
                    -EffectProcessedForPolicy $EffectProcessedForPolicy
                if ($localHasErrors) {
                    $hasErrors = $true
                    continue
                }
            }
        }
        else {
            $ParametersInPolicyDefinition = $PolicyDetails.parameters
        }

        $parameterObject = Build-AssignmentParameterObject `
            -AssignmentParameters $BaseAssignment.parameters `
            -ParametersInPolicyDefinition $ParametersInPolicyDefinition

        if ($parameterObject.psbase.Count -gt 0) {
            $BaseAssignment.parameters = $parameterObject
        }
        else {
            $BaseAssignment.Remove("parameters")
        }
        if ($BaseAssignment.overrides.Count -eq 0) {
            $BaseAssignment.Remove("overrides")
        }
        if ($BaseAssignment.resourceSelectors.Count -eq 0) {
            $BaseAssignment.Remove("resourceSelectors")
        }
        if ($nonComplianceMessagesList.Count -eq 0) {
            $BaseAssignment.Remove("nonComplianceMessages")
        }
        else {
            $BaseAssignment.nonComplianceMessages = $nonComplianceMessagesList.ToArray()
        }

        #endregion Reconcile and deduplicate: CSV, parameters, nonComplianceMessages, and overrides

        #region scopeCollection

        foreach ($ScopeEntry in $ScopeCollection) {

            # Clone hashtable
            [hashtable] $ScopedAssignment = Get-DeepClone $BaseAssignment -AsHashtable

            # Complete processing roleDefinitions and add with metadata to hashtable
            if ($IdentityRequired) {

                $RoleAssignmentspecs = @()
                $RoleAssignmentspecs += $baseRoleAssignmentSpecs
                $roleDefinitionIds = $PolicyRoleIds.$PolicyDefinitionId
                foreach ($roleDefinitionId in $roleDefinitionIds) {
                    $roleDisplayName = "Unknown"
                    $roleDefinitionName = ($roleDefinitionId.Split("/"))[-1]
                    if ($roleDefinitions.ContainsKey($roleDefinitionName)) {
                        $roleDisplayName = $roleDefinitions.$roleDefinitionName
                    }
                    $RoleAssignmentspecs += @{
                        scope            = $ScopeEntry.scope
                        roleDefinitionId = $roleDefinitionId
                        roleDisplayName  = $roleDisplayName
                    }
                }
                $ScopedAssignment.metadata.roles = $RoleAssignmentspecs
            }

            # Add scope and if defined notScopes()
            $Scope = $ScopeEntry.scope
            $Id = "$Scope/providers/Microsoft.Authorization/policyAssignments/$($BaseAssignment.name)"
            $ScopedAssignment.id = $Id
            $ScopedAssignment.scope = $Scope
            if ($ScopeEntry.notScope.Length -gt 0) {
                $ScopedAssignment.notScopes = @() + $ScopeEntry.notScope
            }
            else {
                $ScopedAssignment.notScopes = @()
            }

            # Add completed hashtable to collection
            $AssignmentsList += $ScopedAssignment

        }

        #endregion scopeCollection

    }
    return $hasErrors, $AssignmentsList
}
