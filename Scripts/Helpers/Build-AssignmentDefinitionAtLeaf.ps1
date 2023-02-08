#Requires -PSEdition Core

function Build-AssignmentDefinitionAtLeaf {
    # Recursive Function
    param(
        $pacEnvironment,
        [hashtable] $assignmentDefinition,
        [hashtable] $combinedPolicyDetails,
        [hashtable] $policyRoleIds

        # Returns a list of completed assignment definitions (each a hashtable)
    )

    # Must contain a definitionEntry or definitionEntryList
    $definitionEntryList = $assignmentDefinition.definitionEntryList
    $hasErrors = $assignmentDefinition.hasErrors
    $nodeName = $assignmentDefinition.nodeName
    if ($definitionEntryList.Count -eq 0) {
        Write-Error "    Leaf Node $($nodeName): each tree branch must define either a definitionEntry or a non-empty definitionEntryList."
        $hasErrors = $true
    }

    # Must contain a scopeCollection
    $scopeCollection = $assignmentDefinition.scopeCollection
    if ($null -eq $scopeCollection) {
        Write-Error "    Leaf Node $($nodeName): each tree branch requires exactly one scope definition resulting in a scope collection after notScope calculations."
        $hasErrors = $true
    }

    # Validate optional parameterFileName
    $parameterSuppressDefaultValues = $true
    if ($null -ne $assignmentDefinition.parameterSuppressDefaultValues) {
        $parameterSuppressDefaultValues = $assignmentDefinition.parameterSuppressDefaultValues
    }
    $parameterFileName = $assignmentDefinition.parameterFileName
    $parameterSelector = $assignmentDefinition.parameterSelector
    $useCsv = $false
    if ($null -ne $parameterFileName) {
        if ($null -ne $parameterSelector) {
            $useCsv = $true
        }
        else {
            Write-Error "    Leaf Node $($nodeName): parameterFile ($parameterFileName) usage requires a parameterSelector string."
            $hasErrors = $true
        }
    }

    if (!$hasErrors) {

        # Assemble entries without scopes or parameters and prepare for parameter processing
        $assignmentInDefinition = $assignmentDefinition.assignment
        $assignmentsList = @()
        $assignmentEntryList = [System.Collections.ArrayList]::new()
        $itemArrayList = [System.Collections.ArrayList]::new()
        $thisPacOwnerId = $pacEnvironment.pacOwnerId
        $policyDefinitionsScopes = $pacEnvironment.policyDefinitionsScopes
        foreach ($definitionEntry in $definitionEntryList) {
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
            if ($definitionEntry.nonComplianceMessages) {
                $nonComplianceMessages = $definitionEntry.nonComplianceMessages
            }
            else {
                $nonComplianceMessages = $assignmentDefinition.nonComplianceMessages
            }

            $enforcementMode = $assignmentDefinition.enforcementMode
            $metadata = $assignmentDefinition.metadata
            if ($metadata) {
                if ($metadata.ContainsKey("pacOwnerId")) {
                    $metadata.Remove("pacOwnerId")
                }
                $metadata.pacOwnerId = $thisPacOwnerId
            }
            else {
                $metadata = @{ pacOwnerId = $thisPacOwnerId }
            }
            


            $assignmentEntry = $null
            $policyDefinitionId = $definitionEntry.policyDefinitionId
            if ($definitionEntry.isPolicySet) {
                # Set Policy Set id
                $assignmentEntry = @{
                    isPolicySet           = $true
                    policyDefinitionId    = $policyDefinitionId
                    name                  = $name
                    displayName           = $displayName
                    description           = $description
                    enforcementMode       = $enforcementMode
                    metadata              = $metadata
                    nonComplianceMessages = $nonComplianceMessages
                }

                if ($useCsv) {
                    $itemEntry = @{
                        shortName    = $policyDefinitionId
                        itemId       = $policyDefinitionId
                        policySetId  = $policyDefinitionId
                        assignmentId = $null
                    }
                    $null = $itemArrayList.Add($itemEntry)
                }
            }
            else {
                # Set Policy id
                $assignmentEntry = @{
                    isPolicySet           = $false
                    policyDefinitionId    = $policyDefinitionId
                    name                  = $name
                    displayName           = $displayName
                    description           = $description
                    enforcementMode       = $enforcementMode
                    metadata              = $metadata
                    nonComplianceMessages = $nonComplianceMessages
                }
            }
            $null = $assignmentEntryList.Add($assignmentEntry)
        }

        if ($hasErrors) {
            return $true, $null
        }

        $flatPolicyList = $null
        if ($useCsv) {
            if ($itemArrayList.Count -gt 0) {
                $flatPolicyList = Convert-PolicySetsToFlatList `
                    -itemList $itemArrayList.ToArray() `
                    -details $combinedPolicyDetails.policySets

                # Validate compatibility between spreadsheet and definition entry list
                $rowHashtable = @{}
                foreach ($row in $assignmentDefinition.csvParameterArray) {

                    # Ignore empty lines with a warning
                    $name = $row.name
                    if ($null -eq $name -or $name -eq "") {
                        Write-Warning "    Node $($nodeName): CSV parameterFile '$parameterFileName' has an empty row."
                        continue
                    }

                    # generate the key into the flatPolicyList
                    $policyId = Confirm-PolicyDefinitionUsedExists -name $name -policyDefinitionsScopes $policyDefinitionsScopes -allDefinitions $combinedPolicyDetails.policies -suppressErrorMessage
                    if ($null -eq $policyId) {
                        Write-Error "    Node $($nodeName): CSV parameterFile '$parameterFileName' has a row containing an unknown Policy name '$name'."
                        $hasErrors = $true
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
                        Write-Warning "        $($displayString)"
                    }
                }
                if ($missingInCsv.Count -gt 0) {
                    Write-Warning "    Node $($nodeName): CSV parameterFile '$parameterFileName' is missing rows for Policies included in the Policy Sets:"
                    foreach ($missing in $missingInCsv) {
                        Write-Warning "        $($missing)"
                    }
                }
            }
            else {
                $useCsv = $false
            }
        }

        $effectProcessedForPolicy = @{}
        foreach ($assignmentEntry in $assignmentEntryList) {

            # Finish processing definitions, parameters and compliance messages
            $parameterObject = $null
            $policyDefinitionId = $assignmentEntry.policyDefinitionId
            if ($assignmentEntry.isPolicySet) {

                $policySetsDetails = $combinedPolicyDetails.policySets
                $policySetDetails = $policySetsDetails.$policyDefinitionId

                if ($useCsv) {
                    $finalParameters, $localHasErrors = Build-AssignmentCsvAndJsonParameters `
                        -nodeName $nodeName `
                        -policySetId $policyDefinitionId `
                        -policyDefinitionsScopes $policyDefinitionsScopes `
                        -assignmentDefinition $assignmentDefinition `
                        -flatPolicyList $flatPolicyList `
                        -combinedPolicyDetails $combinedPolicyDetails `
                        -effectProcessedForPolicy $effectProcessedForPolicy
                    if ($localHasErrors) {
                        $hasErrors = $true
                        continue
                    }

                    $parameterObject = Build-AssignmentParameterObject `
                        -assignmentParameters $finalParameters `
                        -parametersInPolicyDefinition $policySetDetails.parameters `
                        -parameterSuppressDefaultValues:$parameterSuppressDefaultValues
                }
                else {
                    $parameterObject = Build-AssignmentParameterObject `
                        -assignmentParameters $assignmentDefinition.parameters `
                        -parametersInPolicyDefinition $policySetDetails.parameters `
                        -parameterSuppressDefaultValues:$parameterSuppressDefaultValues
                }

            }
            else {

                $policiesDetails = $combinedPolicyDetails.policies
                $policyDetails = $policiesDetails.$policyDefinitionId

                $parameterObject = Build-AssignmentParameterObject `
                    -assignmentParameters $assignmentDefinition.parameters `
                    -parametersInPolicyDefinition $policyDetails.parameters `
                    -parameterSuppressDefaultValues:$parameterSuppressDefaultValues

            }
            if ($parameterObject.Count -gt 0) {
                $assignmentEntry.parameters = $parameterObject
            }
            else {
                $assignmentEntry.parameters = @{}
            }

            # Process scopeCollection
            foreach ($scopeEntry in $scopeCollection) {

                # Clone hashtable
                $scopedAssignment = Get-DeepClone $assignmentEntry -AsHashTable

                # Complete processing roleDefinitions and additionalRoleAssignments and add with metadata to hashtable
                $roleAssignmentSpecs = @()
                $roleDefinitionIds = $null
                if ($policyRoleIds.ContainsKey($policyDefinitionId)) {
                    $scopedAssignment.identity = @{
                        type = "SystemAssigned"
                    }
                    $roleDefinitionIds = $policyRoleIds.$policyDefinitionId
                    $scopedAssignment.identityRequired = $true
                    if ($null -ne $assignmentDefinition.managedIdentityLocation) {
                        $scopedAssignment.managedIdentityLocation = $assignmentDefinition.managedIdentityLocation
                    }
                    else {
                        Write-Error "Assignment requires an identity and the definition does not define a managedIdentityLocation" -ErrorAction Stop
                    }
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
                    $additionalRoleAssignments = $assignmentDefinition.additionalRoleAssignments
                    if ($additionalRoleAssignments -and $additionalRoleAssignments.Length -gt 0) {
                        foreach ($additionalRoleAssignment in $additionalRoleAssignments) {
                            $roleDefinitionId = $additionalRoleAssignment.roleDefinitionId
                            $roleDisplayName = "Unknown"
                            $roleDefinitionName = ($roleDefinitionId.Split("/"))[-1]
                            if ($roleDefinitions.ContainsKey($roleDefinitionName)) {
                                $roleDisplayName = $roleDefinitions.$roleDefinitionName
                            }
                            $roleAssignmentSpecs += @{
                                scope            = $additionalRoleAssignment.scope
                                roleDefinitionId = $roleDefinitionId
                                roleDisplayName  = $roleDisplayName
                            }
                        }
                    }
                    if ($scopedAssignment.metadata.ContainsKey("roles")) {
                        $scopedAssignment.metadata.Remove("roles")
                    }
                    $null = $scopedAssignment.metadata.Add("roles", $roleAssignmentSpecs)
                }
                else {
                    $scopedAssignment.identity = @{
                        type = "None"
                    }
                }

                # Add scope and notScopes(if defined)
                $scope = $scopeEntry.scope
                $id = "$scope/providers/Microsoft.Authorization/policyAssignments/$($assignmentEntry.name)"
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
        }
    }
    return $hasErrors, $assignmentsList
}
