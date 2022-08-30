#Requires -PSEdition Core

function Build-AzPolicyAssignmentsPlan {
    [CmdletBinding()]
    param (
        [string] $pacEnvironmentSelector,
        [string] $assignmentsRootFolder,
        [bool] $noDelete,
        [hashtable] $rootScope,
        [string] $rootScopeId,
        [hashtable] $scopeTreeInfo,
        [array] $globalNotScopeList,
        [string] $managedIdentityLocation,
        [hashtable] $allPolicyDefinitions,
        [hashtable] $customPolicyDefinitions,
        [hashtable] $replacedPolicyDefinitions,
        [hashtable] $allInitiativeDefinitions,
        [hashtable] $customInitiativeDefinitions,
        [hashtable] $replacedInitiativeDefinitions,
        [hashtable] $policyNeededRoleDefinitionIds,
        [hashtable] $initiativeNeededRoleDefinitionIds,
        [hashtable] $allAssignments,
        [hashtable] $existingAssignments,
        [hashtable] $newAssignments,
        [hashtable] $updatedAssignments,
        [hashtable] $replacedAssignments,
        [hashtable] $deletedAssignments,
        [hashtable] $unchangedAssignments,
        [hashtable] $removedRoleAssignments,
        [hashtable] $addedRoleAssignments
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy Assignments JSON files in folder '$assignmentsRootFolder'"
    Write-Information "==================================================================================================="
    $assignmentFiles = @()
    $assignmentFiles += Get-ChildItem -Path $assignmentsRootFolder -Recurse -File -Filter "*.json"
    $assignmentFiles += Get-ChildItem -Path $assignmentsRootFolder -Recurse -File -Filter "*.jsonc"
    if ($assignmentFiles.Length -gt 0) {
        Write-Information "Number of Policy Assignment files = $($assignmentFiles.Length)"
    }
    else {
        Write-Information "There aren't any Policy Assignment files in the folder provided!"
    }

    # Cache role deinitions
    $roleDefinitionList = Invoke-AzCli role definition list
    [hashtable] $roleDefinitions = @{}
    foreach ($roleDefinition in $roleDefinitionList) {
        if (!$roleDefinitions.ContainsKey($roleDefinition.name)) {
            $roleDefinitions.Add($roleDefinition.name, $roleDefinition.roleName)
        }
    }

    $obsoleteAssignments = $existingAssignments.Clone()
    foreach ($assignmentFile in $assignmentFiles) {
        $Json = Get-Content -Path $assignmentFile.FullName -Raw -ErrorAction Stop
        if ((Test-Json $Json)) {
            Write-Information "Process '$($assignmentFile.FullName)'"
        }
        else {
            Write-Error "Assignment JSON file '$($assignmentFile.FullName)' is not valid." -ErrorAction Stop
        }
        $assignmentObject = $Json | ConvertFrom-Json -AsHashtable

        # Collect all assignment definitions (values)
        $initialAssignmentDef = @{
            nodeName                       = "/"
            assignment                     = @{
                name        = ""
                displayName = ""
                description = ""
            }
            enforcementMode                = "Default"
            parameters                     = @{}
            additionalRoleAssignments      = @()
            hasErrors                      = $false
            hasOnlyNotSelectedEnvironments = $false
            ignoreBranch                   = $false
        }
        if ($globalNotScopeList) {
            $initialAssignmentDef.notScope = $globalNotScopeList
        }
        if ($managedIdentityLocation) {
            $initialAssignmentDef.managedIdentityLocation = $managedIdentityLocation
        }
        $assignmentDefList = Get-AssignmentDefinitions `
            -scopeTreeInfo $scopeTreeInfo `
            -definitionNode $assignmentObject `
            -assignmentDef $initialAssignmentDef `
            -pacEnvironmentSelector $pacEnvironmentSelector

        #endregion

        $numberOfUnchangedAssignmentsInFile = 0
        $numberOfNotScopeChanges = 0
        foreach ($def in $assignmentDefList) {
            if ($def.hasErrors) {
                Write-Error "Assignment definitions content errors" -ErrorAction Stop
            }

            if (-not $def.ignoreBranch) {
                # Housekeeping
                $noChangedAssignments = $true
                $numberOfUnchangedAssignmentsForAssignmentDef = 0

                foreach ($policyAssignmentEntry in $def.policyAssignmentList) {

                    # Find what to assign and check if it exists
                    $friendlyName = $policyAssignmentEntry.friendlyNameToDocumentIfGuid
                    $policySpecText = ""
                    $result = $null
                    $parametersInDefinition = $null
                    $policySpec = @{}
                    $roleDefinitionIds = @()
                    $assignmentName = $policyAssignmentEntry.assignment.name
                    $assignmentDisplayName = $policyAssignmentEntry.assignment.displayName
                    $assignmentDescription = $policyAssignmentEntry.assignment.description
                    if ($policyAssignmentEntry.initiativeName) {
                        $name = $policyAssignmentEntry.initiativeName
                        if ($friendlyName) {
                            $policySpecText = "Initiative '$name' - '$friendlyName'"
                        }
                        else {
                            $policySpecText = "Initiative '$name'"
                        }
                        $result = Confirm-InitiativeDefinitionUsedExists -allInitiativeDefinitions $allInitiativeDefinitions -replacedInitiativeDefinitions $replacedInitiativeDefinitions -initiativeNameRequired $name
                        if ($result.usingUndefinedReference) {
                            continue
                        }
                        else {
                            $initiativeDefinition = $allInitiativeDefinitions[$name]
                            if ($customInitiativeDefinitions.ContainsKey($name)) {
                                # is custom
                                $policyDefinitionId = $rootScopeId + "/providers/Microsoft.Authorization/policySetDefinitions/" + $name
                                $parametersInDefinition = $initiativeDefinition.Parameter
                            }
                            else {
                                # is built in
                                $policyDefinitionId = "/providers/Microsoft.Authorization/policySetDefinitions/" + $name
                                $parametersInDefinition = $initiativeDefinition.parameters
                            }
                            $policySpec = @{ initiativeId = $policyDefinitionId }
                            if ($initiativeNeededRoleDefinitionIds.ContainsKey($name)) {
                                $roleDefinitionIds = $initiativeNeededRoleDefinitionIds.$name
                            }
                        }
                    }
                    elseif ($policyAssignmentEntry.policyName) {
                        $name = $policyAssignmentEntry.policyName
                        if ($friendlyName) {
                            $policySpecText = "Policy '$name' - '$friendlyName'"
                        }
                        else {
                            $policySpecText = "Policy '$($name)'"
                        }
                        $result = Confirm-PolicyDefinitionUsedExists -allPolicyDefinitions $allPolicyDefinitions -replacedPolicyDefinitions $replacedPolicyDefinitions -policyNameRequired $name
                        if ($result.usingUndefinedReference) {
                            continue
                        }
                        else {
                            $policyDefinition = $allPolicyDefinitions[$name]
                            if ($customPolicyDefinitions.ContainsKey($name)) {
                                # is custom
                                $policyDefinitionId = $rootScopeId + "/providers/Microsoft.Authorization/policyDefinitions/" + $name
                                $parametersInDefinition = $policyDefinition.Parameter
                            }
                            else {
                                # is built in
                                $policyDefinitionId = "/providers/Microsoft.Authorization/policyDefinitions/" + $name
                                $parametersInDefinition = $policyDefinition.parameters
                            }
                            $policySpec = @{ policyId = $policyDefinitionId }
                            if ($policyNeededRoleDefinitionIds.ContainsKey($name)) {
                                $roleDefinitionIds = $policyNeededRoleDefinitionIds.$name
                            }
                        }
                    }
                    else {
                        Write-Error "Neither policyName nor initiativeName specified for Assignment `'$($def.assignment.DisplayName)`' ($($def.assignment.Name))  - must specify exactly one"
                        continue
                    }

                    # Set parameters
                    $parametersSetInAssignment = $def.parameters
                    $parameterObject = @{}
                    if ($parametersInDefinition -and $parametersSetInAssignment) {
                        $parametersDefined = ConvertTo-HashTable $parametersInDefinition
                        foreach ($parameterName in $parametersDefined.Keys) {
                            # $definedParameter = $parametersDefined.$parameterName
                            if ($parametersSetInAssignment.ContainsKey($parameterName)) {
                                Write-Debug "              Setting param $parametername = $($parametersSetInAssignment[$parametername])"
                                $parameterObject[$parameterName] = $parametersSetInAssignment[$parameterName]
                            }
                        }
                    }
                    Write-Debug "              parameters[$($parameterObject.Count)] = $($parameterObject | ConvertTo-Json -Depth 100)"

                    # Process list of scopes in this branch
                    foreach ($scopeInfo in $def.scopeCollection) {
                        # Create the assignment splat (modified)
                        $id = $scopeInfo.scope + "/providers/Microsoft.Authorization/policyAssignments/" + $assignmentName
                        $assignmentConfig = @{
                            Id                    = $id
                            Name                  = $assignmentName
                            DisplayName           = $assignmentDisplayName
                            Description           = $assignmentDescription
                            Metadata              = @{}
                            EnforcementMode       = $def.enforcementMode
                            Scope                 = $scopeInfo.scope
                            PolicyParameterObject = $parameterObject
                            identityRequired      = $false
                        }
                        $assignmentConfig += $policySpec
                        if ($null -ne $def.metadata) {
                            $assignmentConfig.Metadata = ConvertTo-HashTable $def.metadata
                        }
                        if ($null -ne $def.managedIdentityLocation) {
                            $assignmentConfig.managedIdentityLocation = $def.managedIdentityLocation
                        }

                        # Retrieve roleDefinitionIds
                        $roleAssignmentSpecs = @()
                        if ($roleDefinitionIds.Length -gt 0) {
                            foreach ($roleDefinitionId in $roleDefinitionIds) {
                                $roleDisplayName = "Unknown"
                                $roleDefinitionName = ($roleDefinitionId.Split("/"))[-1]
                                if ($roleDefinitions.ContainsKey($roleDefinitionName)) {
                                    $roleDisplayName = $roleDefinitions.$roleDefinitionName
                                }
                                $roleAssignmentSpecs += @{
                                    scope            = $scopeInfo.scope
                                    roleDefinitionId = $roleDefinitionId
                                    roleDisplayName  = $roleDisplayName
                                }
                            }
                            if ($def.additionalRoleAssignments) {
                                foreach ($additionalRoleAssignment in $def.additionalRoleAssignments) {
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
                            $assignmentConfig.identityRequired = $true
                            $assignmentConfig.Metadata.Add("roles", $roleAssignmentSpecs)
                            if ($null -eq $assignmentConfig.managedIdentityLocation) {
                                Write-Error "Assignment requires an identity and the definition does not define a managedIdentityLocation" -ErrorAction Stop
                            }
                        }

                        if ($scopeInfo.notScope.Length -gt 0) {
                            Write-Debug "                notScope added = $($scopeInfo.notScope | ConvertTo-Json -Depth 100)"
                            $assignmentConfig.NotScope = @() + $scopeInfo.notScope
                        }

                        if ($existingAssignments.ContainsKey($id)) {
                            # Assignment already exists
                            $obsoleteAssignments.Remove($id) # do not delete
                            $assignmentInfoInAzure = $existingAssignments[$id]
                            $assignmentInAzure = $assignmentInfoInAzure.assignment
                            $value = @{
                                assignmentId    = $id
                                identity        = $assignmentInAzure.identity
                                location        = $assignmentInAzure.location
                                roleAssignments = $assignmentInfoInAzure.roleAssignments
                            }
                            $assignmentConfig += @{
                                existingAssignment = $value
                            }

                            $policyDefinitionMatches = $policyDefinitionId -eq $assignmentInAzure.policyDefinitionId
                            $replaceIn = (-not $policyDefinitionMatches) -or $result.usingReplacedReference
                            $replace, $changingRoleAssignments = Build-AzPolicyAssignmentIdentityAndRoleChanges `
                                -replacingAssignment $replaceIn `
                                -managedIdentityLocation $assignmentConfig.managedIdentityLocation `
                                -assignmentConfig $assignmentConfig `
                                -removedRoleAssignments $removedRoleAssignments `
                                -addedRoleAssignments $addedRoleAssignments

                            if ($replace) {
                                $replacedAssignments.Add($id, $assignmentConfig)
                                $changesString = ($policyDefinitionMatches ? "-" : "P") `
                                    + ($result.usingReplacedReference ? "-" : "R") `
                                    + ((!$replaceIn -and $replace) ? "-": "I")
                                Write-AssignmentDetails `
                                    -printHeader $noChangedAssignments `
                                    -assignmentName $assignmentName  `
                                    -assignmentDisplayName $assignmentDisplayName `
                                    -assignmentDescription $assignmentDescription `
                                    -policySpecText $policySpecText `
                                    -scopeInfo $scopeInfo `
                                    -roleDefinitions $roleDefinitions `
                                    -prefix "### REPLACE($changesString)"
                                $noChangedAssignments = $false
                            }
                            else {
                                $displayNameMatches = $assignmentConfig.DisplayName -eq $assignmentInAzure.displayName
                                $descriptionMatches = $assignmentConfig.Description -eq $assignmentInAzure.description
                                $notScopeMatches = Confirm-ObjectValueEqualityDeep `
                                    -existingObj $assignmentInAzure.notScopes `
                                    -definedObj $scopeInfo.notScope
                                $parametersMatch = Confirm-AssignmentParametersMatch `
                                    -existingParametersObj $assignmentInAzure.parameters `
                                    -definedParametersObj $parameterObject
                                $metadataMatches = Confirm-MetadataMatches `
                                    -existingMetadataObj $assignmentInAzure.metadata `
                                    -definedMetadataObj $assignmentConfig.Metadata
                                $enforcementModeMatches = $assignmentInAzure.enforcementMode -eq $assignmentConfig.EnforcementMode
                                $match = $displayNameMatches -and $descriptionMatches -and $parametersMatch -and $metadataMatches -and $enforcementModeMatches
                                $notScopeUpdateOnly = !$notScopeMatches -and $match
                                if ($notScopeUpdateOnly) {
                                    # notScope chnages only
                                    # Write-Information "        *** NOTSCOPE UPDATE at $($scopeInfo.scope)"
                                    $numberOfNotScopeChanges += 1
                                    $updatedAssignments.Add($Id, $assignmentConfig)
                                }
                                elseif ($match) {
                                    if ($changingRoleAssignments) {
                                        Write-AssignmentDetails `
                                            -printHeader $noChangedAssignments `
                                            -assignmentName $assignmentName  `
                                            -assignmentDisplayName $assignmentDisplayName `
                                            -assignmentDescription $assignmentDescription `
                                            -policySpecText $policySpecText `
                                            -scopeInfo $scopeInfo `
                                            -roleDefinitions $roleDefinitions `
                                            -prefix "~~~ UPDATE(------R)"
                                    }
                                    $unchangedAssignments.Add($id, $assignmentConfig.Name)
                                    $numberOfUnchangedAssignmentsForAssignmentDef++
                                    $numberOfUnchangedAssignmentsInFile++
                                }
                                else {
                                    $updatedAssignments.Add($Id, $assignmentConfig)
                                    $changesString = ($displayNameMatches ? "-" : "n") `
                                        + ($descriptionMatches ? "-" : "d") `
                                        + ($metadataMatches ? "-": "m") `
                                        + ($enforcementModeMatches ? "-": "e") `
                                        + ($parametersMatch ? "-": "p") `
                                        + ($notScopeMatches ? "-": "N") `
                                        + ($changingRoleAssignments ? "R": "-")

                                    Write-AssignmentDetails `
                                        -printHeader $noChangedAssignments `
                                        -assignmentName $assignmentName  `
                                        -assignmentDisplayName $assignmentDisplayName `
                                        -assignmentDescription $assignmentDescription `
                                        -policySpecText $policySpecText `
                                        -scopeInfo $scopeInfo `
                                        -roleDefinitions $roleDefinitions `
                                        -prefix "~~~ UPDATE($changesString)"
                                    $noChangedAssignments = $false
                                }
                            }
                        }
                        else {
                            # New Assiignment
                            $newAssignments.Add($id, $assignmentConfig)
                            if ($roleAssignmentSpecs.Length -gt 0) {
                                $addedRoleAssignments.Add($id, @{
                                        DisplayName = $assignmentConfig.DisplayName
                                        identity    = $null
                                        roles       = $roleAssignmentSpecs
                                    }
                                )
                            }
                            Write-AssignmentDetails `
                                -printHeader $noChangedAssignments `
                                -assignmentName $assignmentName  `
                                -assignmentDisplayName $assignmentDisplayName `
                                -assignmentDescription $assignmentDescription `
                                -policySpecText $policySpecText `
                                -scopeInfo $scopeInfo `
                                -roleDefinitions $roleDefinitions `
                                -prefix "+++ NEW"
                            $noChangedAssignments = $false
                        }
                        $allAssignments.Add($id, $assignmentConfig)
                    }
                }
            }
        }
        if ($numberOfNotScopeChanges -gt 0) {
            Write-Information "    *** $($numberOfNotScopeChanges) NotScope Changes only Assignments"
        }
        if ($numberOfUnchangedAssignmentsInFile -gt 0) {
            Write-Information "    === $($numberOfUnchangedAssignmentsInFile) Unchanged Assignments"
        }
    }

    if ($obsoleteAssignments.Count -gt 0) {
        if ($noDelete) {
            Write-Information "Suppressing Delete Assignments ($($obsoleteAssignments.Count))"
            foreach ($id in $obsoleteAssignments.Keys) {
                Write-Information "    '$id'"
            }
        }
        else {
            Write-Information "Delete Assignments ($($obsoleteAssignments.Count))"
            foreach ($id in $obsoleteAssignments.Keys) {
                $assignmentInfoInAzure = $existingAssignments[$id]
                $assignmentInAzure = $assignmentInfoInAzure.assignment
                $roleAssignmentsInAzure = $assignmentInfoInAzure.roleAssignments
                Write-Information "    '$id'"
                $deletedAssignment = @{
                    assignmentId = $id
                    DisplayName  = $assignmentInAzure.displayName
                }
                $deletedAssignments.Add($id, $deletedAssignment)
                if ($null -ne $roleAssignmentsInAzure -and $roleAssignmentsInAzure.Count -gt 0) {
                    $removedRoleAssignments.Add($id, @{
                            DisplayName     = $assignmentInAzure.DisplayName
                            identity        = $assignmentInAzure.identity
                            roleAssignments = $roleAssignmentsInAzure
                        }
                    )
                }
            }

        }
    }
    Write-Information ""
    Write-Information ""

}