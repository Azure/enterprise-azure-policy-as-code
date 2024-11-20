function Build-HydrationAssignmentPlan {
    [CmdletBinding()]
    param (
        [string] $AssignmentsRootFolder,
        [hashtable] $PacEnvironment,
        [hashtable] $ScopeTable,
        [hashtable] $DeployedPolicyResources,
        [hashtable] $Assignments,
        [hashtable] $RoleAssignments,
        [hashtable] $AllAssignments,
        [hashtable] $ReplaceDefinitions,
        [hashtable] $PolicyRoleIds,
        [hashtable] $CombinedPolicyDetails,
        [hashtable] $DeprecatedHash,
        [System.Collections.Specialized.OrderedDictionary] $DetailedRecord,
        [switch] $ExtendedReporting
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy Assignments JSON files in folder '$AssignmentsRootFolder'"
    Write-Information "==================================================================================================="

    if($ExtendedReporting){
        $allAssignmentRecords = [ordered]@{}
        $rRoot = (Resolve-Path (Split-Path (Split-Path $AssignmentsRootFolder))).Path
    }
    
    $assignmentFiles = @()
    $assignmentFiles += Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.json"
    $assignmentFiles += Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.jsonc"
    $csvFiles = Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.csv"
    $parameterFilesCsv = @{}
    if ($assignmentFiles.Length -gt 0) {
        Write-Information "Number of Policy Assignment files = $($assignmentFiles.Length)"
        foreach ($csvFile in $csvFiles) {
            $parameterFilesCsv.Add($csvFile.Name, $csvFile.FullName)
        }
    }
    else {
        Write-Warning "No Policy Assignment files found! Deleting any Policy Assignments."
    }

    # Cache role assignments and definitions

    $deployedPolicyAssignments = $deployedPolicyResources.policyassignments.managed
    $deployedRoleAssignmentsByPrincipalId = $DeployedPolicyResources.roleAssignmentsByPrincipalId
    $deleteCandidates = $deployedPolicyAssignments.Clone()
    $roleDefinitions = $DeployedPolicyResources.roleDefinitions

    # Process each assignment file
    foreach ($assignmentFile in $assignmentFiles) {
        $Json = Get-Content -Path $assignmentFile.FullName -Raw -ErrorAction Stop

        $includedCloudEnvironments = ($Json | ConvertFrom-Json).epacCloudEnvironments
        if ($includedCloudEnvironments) {
            if ($pacEnvironment.cloud -notIn $includedCloudEnvironments) {
                continue
            }
        }
        if($ExtendedReporting){
            Remove-Variable fileRecord -ErrorAction SilentlyContinue
            $fileRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
            if(!(Test-Path $AssignmentsRootFolder)){
                Write-Error "No Assignments folder found at $AssignmentsRootFolder"
            }
            $relativePath = -join(".",$assignmentFile.FullName.Substring(($rRoot).Length))
            $fileRecord.Set_Item('fileRelativePath', $relativePath)
        }
        # Write-Information ""
        $assignmentObject = $null
        try {
            $assignmentObject = $Json | ConvertFrom-Json -Depth 100 -AsHashtable
        }
        catch {
            Write-Error "Assignment JSON file '$($assignmentFile.FullName)' is not valid." -ErrorAction Stop
        }
        # Remove-NullFields $assignmentObject

        # Collect all assignment definitions (values)
        $rootAssignmentDefinition = @{
            nodeName                       = "/"
            metadata                       = @{
                assignedBy = $PacEnvironment.deployedBy
            }
            assignment                     = @{
                append      = $false
                name        = ""
                displayName = ""
                description = ""
            }
            enforcementMode                = "Default"
            parameters                     = @{}
            additionalRoleAssignments      = [System.Collections.ArrayList]::new()
            requiredRoleAssignments        = $null
            nonComplianceMessages          = [System.Collections.ArrayList]::new()
            overrides                      = [System.Collections.ArrayList]::new()
            resourceSelectors              = [System.Collections.ArrayList]::new()
            hasErrors                      = $false
            hasOnlyNotSelectedEnvironments = $false
            ignoreBranch                   = $false
            managedIdentityLocation        = $PacEnvironment.managedIdentityLocation
            notScopesList                  = [System.Collections.ArrayList]::new()
            csvRowsValidated               = $false
        }

        $hasErrors, $assignmentsList = Build-AssignmentDefinitionNode `
            -PacEnvironment $PacEnvironment `
            -ScopeTable $ScopeTable `
            -ParameterFilesCsv $parameterFilesCsv `
            -DefinitionNode $assignmentObject `
            -AssignmentDefinition $rootAssignmentDefinition `
            -CombinedPolicyDetails $CombinedPolicyDetails `
            -PolicyRoleIds $PolicyRoleIds `
            -RoleDefinitions $roleDefinitions `
            -DeprecatedHash $DeprecatedHash

        if ($hasErrors) {
            Write-Error "Assignment definitions content errors" -ErrorAction Stop
        }
        $isUserAssignedAny = $false
        foreach ($assignment in $assignmentsList) {
            # Remove-NullFields $assignment
            $id = $assignment.id
            $AllAssignments[$id] = $assignment
            $displayName = $assignment.displayName
            $description = $assignment.description
            $metadata = $assignment.metadata
            $parameters = $assignment.parameters
            $policyDefinitionId = $assignment.policyDefinitionId
            $definitionVersion = $assignment.definitionVersion
            $scope = $assignment.scope
            $notScopes = $assignment.notScopes
            $enforcementMode = $assignment.enforcementMode
            $nonComplianceMessages = $assignment.nonComplianceMessages
            $overrides = $assignment.overrides
            $resourceSelectors = $assignment.resourceSelectors
            if ($deployedPolicyAssignments.ContainsKey($id)) {
                # Update and replace scenarios
                Remove-Variable deployedPolicyAssignment -ErrorAction SilentlyContinue
                $deployedPolicyAssignment = $deployedPolicyAssignments[$id]
                Remove-Variable deployedPolicyAssignmentProperties -ErrorAction SilentlyContinue
                $deployedPolicyAssignmentProperties = Get-PolicyResourceProperties $deployedPolicyAssignment
                $deleteCandidates.Remove($id) # do not delete

                $replacedDefinition = $ReplaceDefinitions.ContainsKey($policyDefinitionId)
                $changedPolicyDefinitionId = $policyDefinitionId -ne $deployedPolicyAssignmentProperties.policyDefinitionId
                $definitionVersionMatches = $true
                if ($definitionVersion) {
                    $definitionVersionMatches = $definitionVersion -eq $deployedPolicyAssignmentProperties.definitionVersion
                }
                $displayNameMatches = $displayName -eq $deployedPolicyAssignmentProperties.displayName
                $descriptionMatches = $description -eq $deployedPolicyAssignmentProperties.description
                Remove-Variable notScopesMatch -ErrorAction SilentlyContinue
                $notScopesMatch = Confirm-ObjectValueEqualityDeep `
                    $deployedPolicyAssignmentProperties.notScopes `
                    $notScopes
                $parametersMatch = Confirm-ParametersUsageMatches `
                    -ExistingParametersObj $deployedPolicyAssignmentProperties.parameters `
                    -DefinedParametersObj $parameters `
                    -CompareValueEntryForExistingParametersObj
                Remove-Variable metadataMatches -ErrorAction SilentlyContinue
                Remove-Variable changePacOwnerId -ErrorAction SilentlyContinue
                $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                    -ExistingMetadataObj $deployedPolicyAssignmentProperties.metadata `
                    -DefinedMetadataObj $metadata
                $enforcementModeMatches = $enforcementMode -eq $deployedPolicyAssignmentProperties.enforcementMode
                Remove-Variable nonComplianceMessagesMatches -ErrorAction SilentlyContinue
                $nonComplianceMessagesMatches = Confirm-ObjectValueEqualityDeep `
                    $deployedPolicyAssignmentProperties.nonComplianceMessages `
                    $nonComplianceMessages
                Remove-Variable overridesMatch -ErrorAction SilentlyContinue
                $overridesMatch = Confirm-ObjectValueEqualityDeep `
                    $deployedPolicyAssignmentProperties.overrides `
                    $overrides
                Remove-Variable resourceSelectorsMatch -ErrorAction SilentlyContinue
                $resourceSelectorsMatch = Confirm-ObjectValueEqualityDeep `
                    $deployedPolicyAssignmentProperties.resourceSelectors `
                    $resourceSelectors
                Remove-Variable identityStatus -ErrorAction SilentlyContinue
                $identityStatus = Build-AssignmentIdentityChanges `
                    -Existing $deployedPolicyAssignment `
                    -Assignment $assignment `
                    -ReplacedAssignment ($replacedDefinition -or $changedPolicyDefinitionId) `
                    -DeployedRoleAssignmentsByPrincipalId $deployedRoleAssignmentsByPrincipalId
                if ($identityStatus.requiresRoleChanges) {
                    $null = $RoleAssignments.added.AddRange($identityStatus.added)
                    $null = $RoleAssignments.updated.AddRange($identityStatus.updated)
                    $null = $RoleAssignments.removed.AddRange($identityStatus.removed)
                    $RoleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                }
                if ($identityStatus.isUserAssigned) {
                    $isUserAssignedAny = $true
                }

                # Check if Policy assignment in Azure is the same as in the JSON file
                $changesStrings = @()
                $match = $displayNameMatches -and $descriptionMatches -and $parametersMatch -and $metadataMatches -and $definitionVersionMatches -and !$changePacOwnerId `
                    -and $enforcementModeMatches -and $notScopesMatch -and $nonComplianceMessagesMatches -and $overridesMatch -and $resourceSelectorsMatch -and !$identityStatus.replaced
                if ($match) {
                    # no Assignment properties changed
                    $Assignments.numberUnchanged++
                    if ($identityStatus.requiresRoleChanges) {
                        # role assignments for Managed Identity changed - caused by a mangedIdentityLocation changed or a previously failed role assignment failure
                        Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "Update($($identityStatus.changedIdentityStrings -join ','))" -IdentityStatus $identityStatus
                    }
                    else {
                        # Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "Unchanged" -IdentityStatus $identityStatus
                    }
                }
                else {
                    # One or more properties have changed
                    if ($identityStatus.replaced) {
                        # Assignment must be deleted and recreated (new)
                        if ($changedPolicyDefinitionId) {
                            $changesStrings += "definitionId"
                        }
                        if ($replacedDefinition) {
                            $changesStrings += "replacedDefinition"
                        }
                        $changesStrings += ($identityStatus.changedIdentityStrings)
                    }
                    elseif ($identityStatus.requiresRoleChanges) {
                        $changesStrings += ($identityStatus.changedIdentityStrings)
                    }

                    if (!$displayNameMatches) {
                        $changesStrings += "displayName"
                    }
                    if (!$descriptionMatches) {
                        $changesStrings += "description"
                    }
                    if ($changePacOwnerId) {
                        $changesStrings += "owner"
                    }
                    if (!$metadataMatches) {
                        $changesStrings += "metadata"
                    }
                    if (!$definitionVersionMatches) {
                        $changesStrings += "definitionVersion"
                    }
                    if (!$parametersMatch) {
                        $changesStrings += "parameters"
                    }
                    if (!$enforcementModeMatches) {
                        $changesStrings += "enforcementMode"
                    }
                    if (!$notScopesMatch) {
                        $changesStrings += "notScopes"
                    }
                    if (!$nonComplianceMessagesMatches) {
                        $changesStrings += "nonComplianceMessages"
                    }
                    if (!$overridesMatch) {
                        $changesStrings += "overrides"
                    }
                    if (!$resourceSelectorsMatch) {
                        $changesStrings += "resourceSelectors"
                    }

                    $changesString = $changesStrings -join ","
                    $updateCollection = $Assignments.update
                    $prefixText = "Update($changesString)"
                    if ($identityStatus.replaced) {
                        $prefixText = "Replace($changesString)"
                        $updateCollection = $Assignments.replace
                    }
                    if ($Assignments.update.ContainsKey($id) -or $Assignments.replace.ContainsKey($id)) {
                        Write-Error "Duplicate Policy Assignment ID '$id' found in the JSON files." -ErrorAction Stop
                    }
                    $null = $updateCollection.Add($id, $assignment)
                    Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix $prefixText -IdentityStatus $identityStatus
                    $Assignments.numberOfChanges++
                    if($ExtendedReporting){
                        # Define Changed Object Data for ExtendedReporting
                        # Populate Data Fields
                        Remove-Variable assignmentRecord -ErrorAction SilentlyContinue
                        $assignmentRecord = Get-DeepCloneAsOrderedHashtable -InputObject $fileRecord
                        $assignmentRecord.Set_Item('name', $name)
                        $assignmentRecord.Set_Item('id', $id)
                        $assignmentRecord.Set_Item('definitionType', 'assignment')
                        if ($changedPolicyDefinitionId) {
                            $assignmentRecord.Set_Item('changedPolicyDefinitionId', $changedPolicyDefinitionId)
                            $assignmentRecord.Set_Item('oldDefinitionId', $deployedPolicyAssignmentProperties.policyDefinitionId)
                            $assignmentRecord.Set_Item('newDefinitionId', $policyDefinitionId)
                            if ($(Split-Path $policyDefinitionId) -eq (Split-Path $deployedPolicyAssignmentProperties.policyDefinitionId)) {
                                $assignmentRecord.Set_Item('scopeChangedOnly', $true)
                            }
                            else {
                                $assignmentRecord.Set_Item('scopeChangedOnly', $false)
                            }
                        }
                        if ($replacedDefinition) {
                            $assignmentRecord.Set_Item('replacedReferencedDefinition', $replacedDefinition)
                            $assignmentRecord.Set_Item('newReferencedDefinition', $policyDefinitionId)
                            $assignmentRecord.Set_Item('oldReferencedDefinition', $deployedPolicyAssignmentProperties.policyDefinitionId)
                        }
                        if ($identityStatus.replaced -or $identityStatus.requiresRoleChanges) {
                            $assignmentRecord.Set_Item('requiresRoleChanges', $identityStatus.requiresRoleChanges)
                            $assignmentRecord.Set_Item('changedIdentityStrings', $identityStatus.changedIdentityStrings)
                            $assignmentRecord.Set_Item('roleAdded',$identityStatus.added)
                            $assignmentRecord.Set_Item('roleUpdated',$identityStatus.updated)
                            $assignmentRecord.Set_Item('roleRemoved',$identityStatus.removed)
                            $assignmentRecord.Set_Item('roleRReplaced',$identityStatus.replaced)
                        }
                        if (!$displayNameMatches) {
                            $assignmentRecord.Set_Item('displayNameChanged', (!($displayNameMatches)))
                            $assignmentRecord.Set_Item('newDisplayName', $displayName)
                            $assignmentRecord.Set_Item('oldDisplayName', $deployedPolicyAssignmentProperties.displayName)
                        }
                        if (!$descriptionMatches) {
                            $assignmentRecord.Set_Item('descriptionChanged', (!($descriptionMatches)))
                            $assignmentRecord.Set_Item('oldDescription', $deployedPolicyAssignmentProperties.description)
                            $assignmentRecord.Set_Item('newDescription', $description)
                        }
                        if ($changePacOwnerId) {
                            $assignmentRecord.Set_Item('ownerChanged', $changePacOwnerId)
                            $assignmentRecord.Set_Item('oldOwner', $deployedPolicyAssignmentProperties.metadata.pacOwnerId)
                            $assignmentRecord.Set_Item('newOwner', $metadata.pacOwnerId)
                        }              
                        if (!$descriptionMatches) {
                            $assignmentRecord.Set_Item('descriptionChanged', !($descriptionMatches))
                            $assignmentRecord.Set_Item('oldDescription', $deployedPolicyAssignmentProperties.description)
                            $assignmentRecord.Set_Item('newDescription', $description)
                        }
                        if (!$metadataMatches) {
                            $assignmentRecord.Set_Item('metadataChanged', !($metadataMatches))
                            $assignmentRecord.Set_Item('oldMetadata', $deployedPolicyAssignmentProperties.metadata)
                            $assignmentRecord.Set_Item('newMetadata', $metadata)
                        }          
                        if (!$definitionVersionMatches) {
                            $assignmentRecord.Set_Item('definitionVersionChanged', !($definitionVersionMatches))
                            $assignmentRecord.Set_Item('oldDefinitionVersion', $deployedPolicyAssignmentProperties.definitionVersion)
                            $assignmentRecord.Set_Item('newDefinitionVersion', $definitionVersion)
                        }
                        if (!$parametersMatch) {
                            $assignmentRecord.Set_Item('parametersChanged', !($parametersMatch))
                            $assignmentRecord.Set_Item('oldParameters', $deployedPolicyAssignmentProperties.parameters)
                            $assignmentRecord.Set_Item('newParameters', $parameters)
                        }
                        if (!$enforcementModeMatches) {
                            $assignmentRecord.Set_Item('enforcementModeChanged', !($enforcementModeMatches))
                            $assignmentRecord.Set_Item('oldEnforcementMode', $deployedPolicyAssignmentProperties.enforcementMode)
                            $assignmentRecord.Set_Item('newEnforcementMode', $enforcementMode)
                        }
                        if (!$notScopesMatch) {
                            $assignmentRecord.Set_Item('notScopesChanged', !($notScopesMatch))
                            $assignmentRecord.Set_Item('oldNotScopes', $deployedPolicyAssignmentProperties.notScopes)
                            $assignmentRecord.Set_Item('newNotScopes', $notScopes)
                        }
                        if (!$nonComplianceMessagesMatches) {
                            $assignmentRecord.Set_Item('nonComplianceMessagesChanged', !($nonComplianceMessagesMatches))
                            $assignmentRecord.Set_Item('oldNonComplianceMessages', $deployedPolicyAssignmentProperties.nonComplianceMessages)
                            $assignmentRecord.Set_Item('newNonComplianceMessages', $nonComplianceMessages)
                        }
                        if (!$overridesMatch) {
                            $assignmentRecord.Set_Item('overridesChanged', !($overridesMatch))
                            $assignmentRecord.Set_Item('oldOverrides', $deployedPolicyAssignmentProperties.overrides)
                            $assignmentRecord.Set_Item('newOverrides', $overrides)
                        }
                        if (!$resourceSelectorsMatch) {
                            $assignmentRecord.Set_Item('resourceSelectorsChanged', !($resourceSelectorsMatch))
                            $assignmentRecord.Set_Item('oldResourceSelectors', $deployedPolicyAssignmentProperties.resourceSelectors)
                            $assignmentRecord.Set_Item('newResourceSelectors', $resourceSelectors)
                        }
                        if ($changesString) {
                            $assignmentRecord.Set_Item('changes', $changesString)
                            $assignmentRecord.Set_Item('changeList', $changesStrings)
                        }
                        # Define update type
                        if($assignmentRecord.scopeChangedOnly -and $changedPolicyDefinitionId -and $changesStrings.count -eq 1){
                            $assignmentRecord.Set_Item('evaluationResult', 'DefinitionScopeUpdate')
                        }elseif($changesStrings.count -eq 1 -and $changePacOwnerId){
                            $assignmentRecord.Set_Item('evaluationResult', 'OnwerOnly')
                        }elseif($identityStatus.replaced -or $identityStatus.requiresRoleChanges){
                            # Confirm that RequiresRoleChanges and ParametersMatch trigger thism confirm 
                            $assignmentRecord.Set_Item('evaluationResult', 'Replaced')
                        }
                        elseif($changesStrings.count -gt 0){
                            $assignmentRecord.Set_Item('evaluationResult', 'Update')
                        }
                    }
                }
            }
            else {
                # New Assignment
                $null = $Assignments.new.Add($id, $assignment)
                $Assignments.numberOfChanges++
                Remove-Variable identityStatus -ErrorAction SilentlyContinue
                $identityStatus = Build-AssignmentIdentityChanges `
                    -Existing $null `
                    -Assignment $assignment `
                    -ReplacedAssignment $false `
                    -DeployedRoleAssignmentsByPrincipalId $deployedRoleAssignmentsByPrincipalId
                if ($identityStatus.requiresRoleChanges) {
                    $null = $RoleAssignments.added.AddRange($identityStatus.added)
                    $RoleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                }
                if ($identityStatus.isUserAssigned) {
                    $isUserAssignedAny = $true
                }
                if($ExtendedReporting){
                    # Add details to the NEW record
                    Remove-Variable assignmentRecord -ErrorAction SilentlyContinue
                    $assignmentRecord = Get-DeepCloneAsOrderedHashtable -InputObject $fileRecord
                    $assignmentRecord.Set_Item('name', $name)
                    $assignmentRecord.Set_Item('id', $id)
                    $assignmentRecord.Set_Item('evaluationResult', 'New')
                    $assignmentRecord.Set_Item('definitionType', 'assignment')
                    $assignmentRecord.Set_Item('changes', '*')
                    $assignmentRecord.Set_Item('changeList', @('*'))
                    $assignmentRecord.Set_Item('identityReplaced',"")
                    $assignmentRecord.Set_Item('replacedReferencedDefinition',"")
                    $assignmentRecord.Set_Item('displayNameChanged',"")
                    $assignmentRecord.Set_Item('descriptionChanged',"")
                    $assignmentRecord.Set_Item('definitionVersionChanged',"")
                    $assignmentRecord.Set_Item('parametersChanged',"")
                    $assignmentRecord.Set_Item('modeChanged',"")
                    $assignmentRecord.Set_Item('resourceSelectorsChanged',"")
                    $assignmentRecord.Set_Item('policyRuleChanged',"")
                    $assignmentRecord.Set_Item('replacedPolicy',"")
                    $assignmentRecord.Set_Item('policyDefinitionsChanged',"")
                    $assignmentRecord.Set_Item('policyDefinitionGroupsChanged',"")
                    $assignmentRecord.Set_Item('deletedPolicyDefinitionGroups',"")
                }
                Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "New" -IdentityStatus $identityStatus
            }
            if($ExtendedReporting){
                try{
                    if(!$match){
                        $allAssignmentRecords.add($(@($assignmentRecord.fileRelativePath,$assignmentRecord.definitionType,$assignmentRecord.id) -join "_"),$assignmentRecord)
                    }
                    
                }catch{
                    Write-Host "Test"
                }                
            }
        }
    }

    $strategy = $PacEnvironment.desiredState.strategy
    $keepDfcSecurityAssignments = $PacEnvironment.desiredState.keepDfcSecurityAssignments
    if ($deleteCandidates.psbase.Count -gt 0) {
        foreach ($id in $deleteCandidates.Keys) {
            $deleteCandidate = $deleteCandidates.$id
            $deleteCandidateProperties = Get-PolicyResourceProperties $deleteCandidate
            $name = $deleteCandidate.name
            $displayName = $deleteCandidateProperties.displayName
            $scope = $deleteCandidateProperties.scope
            $pacOwner = $deleteCandidate.pacOwner
            $shallDelete = Confirm-DeleteForStrategy `
                -PacOwner $pacOwner `
                -Strategy $strategy `
                -KeepDfcSecurityAssignments $keepDfcSecurityAssignments
            if ($shallDelete) {
                # always delete if owned by this Policy as Code solution
                # never delete if owned by another Policy as Code solution
                # if strategy is "full", delete with unknown owner (missing pacOwnerId)
                Remove-Variable identityStatus -ErrorAction SilentlyContinue
                $identityStatus = Build-AssignmentIdentityChanges `
                    -Existing $deleteCandidate `
                    -Assignment $null `
                    -ReplacedAssignment $false `
                    -DeployedRoleAssignmentsByPrincipalId $deployedRoleAssignmentsByPrincipalId
                if ($identityStatus.requiresRoleChanges) {
                    $null = $RoleAssignments.removed.AddRange($identityStatus.removed)
                    $RoleAssignments.numberOfChanges += ($identityStatus.numberOfChanges)
                }
                if ($identityStatus.isUserAssigned) {
                    $isUserAssignedAny = $true
                }
                Write-AssignmentDetails -DisplayName $displayName -Scope $scope -Prefix "Delete" -IdentityStatus $identityStatus
                $splat = @{
                    id          = $id
                    name        = $name
                    scopeId     = $scope
                    displayName = $displayName
                }

                $AllAssignments.Remove($id)
                $Assignments.delete.Add($id, $splat)
                $Assignments.numberOfChanges++
                # Process Extended Reporting for items that are not part of the EPAC repository, but exist in the managed scope
                if($ExtendedReporting){
                    # Add record for any items that remain that will be deleted
                    Remove-Variable assignmentRecord -ErrorAction SilentlyContinue
                    $assignmentRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
                    $assignmentRecord.Set_Item('name', $name)
                    $assignmentRecord.Set_Item('id', $id)
                    $assignmentRecord.Set_Item('evaluationResult', 'Delete')
                    $assignmentRecord.Set_Item('fileRelativePath', "NoAssignmentFile")
                    $assignmentRecord.Set_Item('definitionType', 'assignment')
                }
            }
            else {
                $identityStatus = @{
                    requiresRoleChanges    = $false
                    numberOfChanges        = 0
                    added                  = @()
                    removed                = @()
                    changedIdentityStrings = @()
                    replaced               = $false
                    isUserAssigned         = $false
                }
                # Add record for any items that remain that will not be managed by EPAC

                $shortScope = $scope -replace "/providers/Microsoft.Management", ""
                switch ($pacOwner) {
                    thisPaC { 
                        Write-Error "Policy Assignment '$displayName' at $shortScope owned by this Policy as Code solution should have been deleted." -ErrorAction Stop
                        if($ExtendedReporting){
                            Remove-Variable assignmentRecord -ErrorAction SilentlyContinue
                            $assignmentRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
                            $assignmentRecord.Set_Item('name', $name)
                            $assignmentRecord.Set_Item('id', $id)
                            $assignmentRecord.Set_Item('evaluationResult', 'outOfScope-notFullDesiredState')
                            $assignmentRecord.Set_Item('fileRelativePath', "NoAssignmentFile")
                            $assignmentRecord.Set_Item('definitionType', 'assignment')
                            # $allAssignmentRecords.add($(@($assignmentRecord.fileRelativePath,$assignmentRecord.definitionType,$assignmentRecord.id) -join "_"),$assignmentRecord)
                        }
                    }
                    otherPaC {
                        if ($VerbosePreference -eq "Continue") {
                            Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete (owned by other PaC):" -IdentityStatus $identityStatus
                        }
                        if($ExtendedReporting){
                            Remove-Variable assignmentRecord -ErrorAction SilentlyContinue
                            $assignmentRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
                            $assignmentRecord.Set_Item('name', $name)
                            $assignmentRecord.Set_Item('id', $id)
                            $assignmentRecord.Set_Item('evaluationResult', 'outOfScope-otherEpacManaged')
                            $assignmentRecord.Set_Item('fileRelativePath', "NoAssignmentFile")
                            $assignmentRecord.Set_Item('definitionType', 'assignment')
                            # $allAssignmentRecords.add($(@($assignmentRecord.fileRelativePath,$assignmentRecord.definitionType,$assignmentRecord.id) -join "_"),$assignmentRecord)
                        }
                    }
                    unknownOwner {
                        if ($VerbosePreference -eq "Continue") {
                            Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete owned by unknown (strategy $strategy):" -IdentityStatus $identityStatus
                        }
                        if($ExtendedReporting){
                            Remove-Variable assignmentRecord -ErrorAction SilentlyContinue
                            $assignmentRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
                            $assignmentRecord.Set_Item('name', $name)
                            $assignmentRecord.Set_Item('id', $id)
                            $assignmentRecord.Set_Item('evaluationResult', 'outOfScope-notEpacManaged')
                            $assignmentRecord.Set_Item('fileRelativePath', "NoAssignmentFile")
                            $assignmentRecord.Set_Item('definitionType', 'assignment')
                            # $allAssignmentRecords.add($(@($assignmentRecord.fileRelativePath,$assignmentRecord.definitionType,$assignmentRecord.id) -join "_"),$assignmentRecord)
                        }
                    }
                    managedByDfcSecurityPolicies {
                        if ($VerbosePreference -eq "Continue") {
                            Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete (DfC Security Policies):" -IdentityStatus $identityStatus
                        }
                        if($ExtendedReporting){
                            Remove-Variable assignmentRecord -ErrorAction SilentlyContinue
                            $assignmentRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
                            $assignmentRecord.Set_Item('name', $name)
                            $assignmentRecord.Set_Item('id', $id)
                            $assignmentRecord.Set_Item('evaluationResult', 'outOfScope-dfcManaged')
                            $assignmentRecord.Set_Item('fileRelativePath', "NoAssignmentFile")
                            $assignmentRecord.Set_Item('definitionType', 'assignment')
                            # $allAssignmentRecords.add($(@($assignmentRecord.fileRelativePath,$assignmentRecord.definitionType,$assignmentRecord.id) -join "_"),$assignmentRecord)
                        }
                    }
                    managedByDfcDefenderPlans {
                        if ($VerbosePreference -eq "Continue") {
                            Write-AssignmentDetails -DisplayName $displayName -Scope $shortScope -Prefix "Skipping delete (DfC Defender Plans):" -IdentityStatus $identityStatus
                        }
                        if($ExtendedReporting){
                            Remove-Variable assignmentRecord -ErrorAction SilentlyContinue
                            $assignmentRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
                            $assignmentRecord.Set_Item('name', $name)
                            $assignmentRecord.Set_Item('id', $id)
                            $assignmentRecord.Set_Item('evaluationResult', 'outOfScope-dfcManaged')
                            $assignmentRecord.Set_Item('fileRelativePath', "NoAssignmentFile")
                            $assignmentRecord.Set_Item('definitionType', 'assignment')
                            # $allAssignmentRecords.add($(@($assignmentRecord.fileRelativePath,$assignmentRecord.definitionType,$assignmentRecord.id) -join "_"),$assignmentRecord)
                        }
                    }
                }
            } 
            if($ExtendedReporting){
                $allAssignmentRecords.add($(@($assignmentRecord.fileRelativePath,$assignmentRecord.definitionType,$assignmentRecord.id) -join "_"),$assignmentRecord)
            }
        }
    }
    foreach($aRec in $allAssignmentRecords.keys){
        $detailedRecordList.Add($aRec,$allAssignmentRecords.$aRec)
    }
    if ($isUserAssignedAny) {
        Write-Warning "EPAC does not manage role assignments for Policy Assignments with user-assigned Managed Identities."
    }
    Write-Information "Number of unchanged Policy Assignments = $($Assignments.numberUnchanged)"
    Write-Information ""
}
