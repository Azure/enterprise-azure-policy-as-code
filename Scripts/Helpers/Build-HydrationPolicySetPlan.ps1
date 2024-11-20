function Build-HydrationPolicySetPlan {
    [CmdletBinding()]
    param (
        [string] $DefinitionsRootFolder,
        [hashtable] $PacEnvironment,
        [hashtable] $DeployedDefinitions,
        [hashtable] $Definitions,
        [hashtable] $AllDefinitions,
        [hashtable] $ReplaceDefinitions,
        [hashtable] $PolicyRoleIds,
        [System.Collections.Specialized.OrderedDictionary] $DetailedRecord,
        [switch] $ExtendedReporting
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy Set JSON files in folder '$DefinitionsRootFolder'"
    Write-Information "==================================================================================================="

    if($ExtendedReporting){
        $allPolicySetRecords = [ordered]@{}
        $rRoot = (Resolve-Path (Split-Path (Split-Path $DefinitionsRootFolder))).Path
    }

    # Process Policy Set JSON files if any
    $definitionFiles = @()
    $definitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.json"
    $definitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
    if ($definitionFiles.Length -gt 0) {
        Write-Information "Number of Policy Set files = $($definitionFiles.Length)"
    }
    else {
        Write-Warning "No Policy Set files found! Deleting any custom Policy Set definitions."
    }

    $managedDefinitions = $DeployedDefinitions.managed
    $deleteCandidates = $managedDefinitions.Clone()
    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    $policyDefinitionsScopes = $PacEnvironment.policyDefinitionsScopes
    $duplicateDefinitionTracking = @{}
    $thisPacOwnerId = $PacEnvironment.pacOwnerId

    foreach ($file in $definitionFiles) {
        $Json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        $definitionObject = $null
        try {
            $definitionObject = $Json | ConvertFrom-Json -Depth 100
        }
        catch {
            Write-Error "PolicySet JSON file '$($file.Name)' is not valid." -ErrorAction Stop
        }
        if($ExtendedReporting){
            Remove-Variable fileRecord -ErrorAction SilentlyContinue
            $fileRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
            $relativePath = -join(".",$file.FullName.Substring(($rRoot).Length))
        }
        Remove-Variable definitionProperties -ErrorAction SilentlyContinue
        $definitionProperties = Get-PolicyResourceProperties -PolicyResource $definitionObject
        $name = $definitionObject.name
        $id = "$deploymentRootScope/providers/Microsoft.Authorization/policySetDefinitions/$name"
        $displayName = $definitionProperties.displayName
        $description = $definitionProperties.description
        Remove-Variable metadata -ErrorAction SilentlyContinue
        $metadata = Get-DeepCloneAsOrderedHashtable $definitionProperties.metadata
        $parameters = $definitionProperties.parameters
        $policyDefinitions = $definitionProperties.policyDefinitions
        $policyDefinitionGroups = $definitionProperties.policyDefinitionGroups
        $importPolicyDefinitionGroups = $definitionProperties.importPolicyDefinitionGroups
        if ($metadata) {
            $metadata.pacOwnerId = $thisPacOwnerId
        }
        else {
            $metadata = @{ pacOwnerId = $thisPacOwnerId }
        }
        if ($metadata.epacCloudEnvironments) {
            if ($pacEnvironment.cloud -notIn $metadata.epacCloudEnvironments) {
                #Need to come back and add this file to deleteCandidates
                continue
            }
        }
        if (!$metadata.ContainsKey("deployedBy")) {
            $metadata.deployedBy = $PacEnvironment.deployedBy
        }

        # Core syntax error checking
        if ($null -eq $name) {
            Write-Error "Policy Set from file '$($file.Name)' requires a name" -ErrorAction Stop
        }
        if (-not (Confirm-ValidPolicyResourceName -Name $name)) {
            Write-Error "Policy Set from file '$($file.Name) has a name '$name' containing invalid characters <>*%&:?.+/ or ends with a space." -ErrorAction Stop
        }
        if ($null -eq $displayName) {
            Write-Error "Policy Set '$name' from file '$($file.Name)' requires a displayName" -ErrorAction Stop
        }
        if ($null -eq $policyDefinitions) {
            Write-Error "Policy Set '$displayName' from file '$($file.Name)' requires a policyDefinitions entry; it is null. Did you misspell policyDefinitions (it is case sensitive)?" -ErrorAction Stop
        }
        elseif ($policyDefinitions -isnot [System.Collections.IList]) {
            Write-Error "Policy Set '$displayName' from file '$($file.Name)' requires a policyDefinitions array; it is not an array." -ErrorAction Stop
        }
        elseif ($policyDefinitions.Count -eq 0) {
            Write-Error "Policy Set '$displayName' from file '$($file.Name)' requires a policyDefinitions array with at least one entry; it has zero entries." -ErrorAction Stop
        }
        if ($duplicateDefinitionTracking.ContainsKey($id)) {
            Write-Error "Duplicate Policy Set with name '$($name)' in '$($duplicateDefinitionTracking[$id])' and '$($file.FullName)'" -ErrorAction Stop
        }
        else {
            $null = $duplicateDefinitionTracking.Add($id, $file.FullName)
        }

        # Calculate included policyDefinitions
        Remove-Variable validPolicyDefinitions -ErrorAction SilentlyContinue
        Remove-Variable policyDefinitionsFinal -ErrorAction SilentlyContinue
        Remove-Variable policyRoleIdsInSet -ErrorAction SilentlyContinue
        Remove-Variable usedPolicyGroupDefinitions -ErrorAction SilentlyContinue
        $validPolicyDefinitions, $policyDefinitionsFinal, $policyRoleIdsInSet, $usedPolicyGroupDefinitions = Build-PolicySetPolicyDefinitionIds `
            -DisplayName $displayName `
            -PolicyDefinitions $policyDefinitions `
            -PolicyDefinitionsScopes $policyDefinitionsScopes `
            -AllDefinitions $AllDefinitions.policydefinitions `
            -PolicyRoleIds $PolicyRoleIds
        $policyDefinitions = $policyDefinitionsFinal.ToArray()
        if ($policyRoleIdsInSet.psbase.Count -gt 0) {
            $null = $PolicyRoleIds.Add($id, $policyRoleIdsInSet.Keys)
        }


        # Process policyDefinitionGroups
        $policyDefinitionGroupsHashTable = @{}
        if ($null -ne $policyDefinitionGroups) {
            # Check for group defined as policyDefinitionGroups but not used in policies and add them to a new object
            # Add each group to the object as Azure allows non used groups
            $policyDefinitionGroups | ForEach-Object {
                $policyDefinitionGroupsHashTable.Add($_.name, $_)
            }
            # Now check each used group defined by policyDefinitions to make sure that it exists in the policyDefinitionGroups as this causes an error when deploying
            $usedPolicyGroupDefinitions.Keys | ForEach-Object {
                if (!$policyDefinitionGroupsHashTable.ContainsKey($_)) {
                    Write-Error "$($displayName): PolicyDefinitionGroup '$_' not found in policyDefinitionGroups." -ErrorAction Stop
                }
            }
        }

        # Importing policyDefinitionGroups from built-in PolicySets?
        if ($null -ne $importPolicyDefinitionGroups) {
            $limitReachedPolicyDefinitionGroups = $false

            # Trying to import missing policyDefinitionGroups entries
            foreach ($importPolicyDefinitionGroup in $importPolicyDefinitionGroups) {
                if ($usedPolicyGroupDefinitions.psbase.Count -eq 0 -or $limitReachedPolicyDefinitionGroups) {
                    break
                }
                $importPolicySetId = $importPolicyDefinitionGroup
                if (!($importPolicyDefinitionGroup.StartsWith("/providers/Microsoft.Authorization/policySetDefinitions/", [System.StringComparison]::OrdinalIgnoreCase))) {
                    $importPolicySetId = "/providers/Microsoft.Authorization/policySetDefinitions/$importPolicyDefinitionGroup"
                }
                if (!($DeployedDefinitions.readOnly.ContainsKey($importPolicySetId))) {
                    Write-Error "$($displayName): Policy Set '$importPolicySetId' for group name import not found." -ErrorAction Stop
                }
                $importedPolicySetDefinition = $DeployedDefinitions.readOnly[$importPolicySetId]
                $importedPolicyDefinitionGroups = $importedPolicySetDefinition.properties.policyDefinitionGroups
                if ($null -ne $importedPolicyDefinitionGroups -and $importedPolicyDefinitionGroups.Count -gt 0) {
                    # Write-Information "$($displayName): Importing PolicyDefinitionGroups from '$($importedPolicySetDefinition.displayName)'"
                    foreach ($importedPolicyDefinitionGroup in $importedPolicyDefinitionGroups) {
                        $groupName = $importedPolicyDefinitionGroup.name
                        if ($usedPolicyGroupDefinitions.ContainsKey($groupName)) {
                            $usedPolicyGroupDefinitions.Remove($groupName)
                            $policyDefinitionGroupsHashTable.Add($groupName, $importedPolicyDefinitionGroup)
                            if ($policyDefinitionGroupsHashTable.psbase.Count -ge 1000) {
                                $limitReachedPolicyDefinitionGroups = $true
                                if ($usedPolicyGroupDefinitions.psbase.Count -gt 0) {
                                    Write-Warning "$($displayName): Too many PolicyDefinitionGroups (1000+) - ignore remaining imports."
                                }
                                break
                            }
                        }
                    }
                    # Write-Information "$($displayName): Imported $($policyDefinitionGroupsHashTable.psbase.psbase.Count) PolicyDefinitionGroups from '$($importedPolicySetDefinition.displayName)'."
                }
                else {
                    Write-Error "$($displayName): Policy Set $($importedPolicySet.displayName) does not contain PolicyDefinitionGroups to import." -ErrorAction Stop
                }
            }
        }
        $policyDefinitionGroupsFinal = $null
        if ($policyDefinitionGroupsHashTable.Count -gt 0) {
            $policyDefinitionGroupsFinal = @() + ($policyDefinitionGroupsHashTable.Values | Sort-Object -Property "name")
        }

        if (!$validPolicyDefinitions) {
            Write-Error "$($displayName): One or more invalid Policy entries referenced in Policy Set '$($displayName)' from '$($file.Name)'." -ErrorAction Stop
        }

        # Constructing Policy Set parameters for splatting
        $definition = @{
            id                     = $id
            name                   = $name
            scopeId                = $deploymentRootScope
            displayName            = $displayName
            description            = $description
            metadata               = $metadata
            parameters             = $parameters
            policyDefinitions      = $policyDefinitionsFinal
            policyDefinitionGroups = $policyDefinitionGroupsFinal
        }
        # Remove-NullFields $definition
        $AllDefinitions.policysetdefinitions[$id] = $definition

        if ($managedDefinitions.ContainsKey($id)) {
            # Update or replace scenarios
            Remove-Variable deployedDefinition -ErrorAction SilentlyContinue
            $deployedDefinition = $managedDefinitions[$id]
            $deployedDefinition = Get-PolicyResourceProperties -PolicyResource $deployedDefinition

            # Remove defined Policy Set entry from deleted hashtable (the hashtable originally contains all custom Policy Sets in the scope)
            $null = $deleteCandidates.Remove($id)

            # Check if Policy Set in Azure is the same as in the JSON file
            $displayNameMatches = $deployedDefinition.displayName -eq $displayName
            $descriptionMatches = $deployedDefinition.description -eq $description
            Remove-Variable metadataMatches -ErrorAction SilentlyContinue
            Remove-Variable changePacOwnerId -ErrorAction SilentlyContinue
            $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                -ExistingMetadataObj $deployedDefinition.metadata `
                -DefinedMetadataObj $metadata
            Remove-Variable parametersMatch -ErrorAction SilentlyContinue
            Remove-Variable incompatible -ErrorAction SilentlyContinue
            $parametersMatch, $incompatible = Confirm-ParametersDefinitionMatch `
                -ExistingParametersObj $deployedDefinition.parameters `
                -DefinedParametersObj $parameters
            Remove-Variable policyDefinitionsMatch -ErrorAction SilentlyContinue
            $policyDefinitionsMatch = Confirm-PolicyDefinitionsInPolicySetMatch `
                $deployedDefinition.policyDefinitions `
                $policyDefinitionsFinal
            Remove-Variable policyDefinitionGroupsMatch -ErrorAction SilentlyContinue
            $policyDefinitionGroupsMatch = Confirm-ObjectValueEqualityDeep `
                $deployedDefinition.policyDefinitionGroups `
                $policyDefinitionGroupsFinal
            $deletedPolicyDefinitionGroups = !$policyDefinitionGroupsMatch -and ($null -eq $policyDefinitionGroupsFinal -or $policyDefinitionGroupsFinal.Length -eq 0)            
            # Update Policy Set in Azure if necessary
            $containsReplacedPolicy = $false
            $replacedPolicyList = @()
            foreach ($policyDefinitionEntry in $policyDefinitionsFinal) {
                $policyId = $policyDefinitionEntry.policyDefinitionId
                if ($ReplaceDefinitions.ContainsKey($policyId)) {
                    $containsReplacedPolicy = $true
                    if(!$ExtendedReporting){
                        break
                    }
                    else{
                        # Capture full list of replaced policies for ExtendedReporting
                        $replacedPolicyList += $policyId
                    }
                }
            }
            if (!$containsReplacedPolicy -and $displayNameMatches -and $descriptionMatches -and $metadataMatches -and !$changePacOwnerId -and $parametersMatch -and $policyDefinitionsMatch -and $policyDefinitionGroupsMatch) {
                # Write-Information "Unchanged '$($displayName)'"
                $Definitions.numberUnchanged++
            }
            else {
                $Definitions.numberOfChanges++
                $changesStrings = @()
                if ($incompatible) {
                    $changesStrings += "paramIncompat"
                }
                if ($containsReplacedPolicy) {
                    $changesStrings += "replacedPolicy"
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
                if (!$parametersMatch -and !$incompatible) {
                    $changesStrings += "param"
                }
                if (!$policyDefinitionsMatch) {
                    $changesStrings += "policies"
                }
                if (!$policyDefinitionGroupsMatch) {
                    if ($deletedPolicyDefinitionGroups) {
                        $changesStrings += "groupsDeleted"
                    }
                    else {
                        $changesStrings += "groups"
                    }
                }
                $changesString = $changesStrings -join ","

                if ($incompatible -or $containsReplacedPolicy) {
                    # Check if parameters are compatible with an update or id the set includes at least one Policy which is being replaced.
                    Write-Information "Replace ($changesString) '$($displayName)'"
                    $null = $Definitions.replace.Add($id, $definition)
                    $null = $ReplaceDefinitions.Add($id, $definition)
                }
                else {
                    Write-Information "Update ($changesString) '$($displayName)'"
                    $null = $Definitions.update.Add($id, $definition)
                }
                if($ExtendedReporting){
                    # Define Changed Object Data for ExtendedReporting
                    # Populate Data Fields
                    $fileRecord.Set_Item('name', $name)
                    $fileRecord.Set_Item('definitionType', 'policySet')
                    $fileRecord.Set_Item('id', $id)
                    $fileRecord.Set_Item('changes', $changesString)
                    $fileRecord.Set_Item('changeList', $changesStrings)
                    $fileRecord.Set_Item('fileRelativePath', $relativePath)
                    if ($incompatible) {
                        $fileRecord.Set_Item('parametersChanged', $incompatible)
                        $fileRecord.Set_Item('oldParameters', $deployedDefinition.parameters)
                        $fileRecord.Set_Item('newParameters', $parameters)
                    }
                    if($containsReplacedPolicy){
                        $fileRecord.Set_Item('replacedPolicy', $containsReplacedPolicy)
                        $fileRecord.Set_Item('replacedPolicyList', $replacedPolicyList)
                    }
                    if (!$policyDefinitionsMatch) {
                        $fileRecord.Set_Item('updatedMemberPolicyDefinitions',!($policyDefinitionsMatch))
                        $fileRecord.Set_Item('oldPolicyDefinitions', "Review replacedPolicyList contents for a list of definitions to review specific changes, review current deployed definition for policySet in Azure.")
                        $fileRecord.Set_Item('newPolicyDefinitions', "Review replacedPolicyList contents for a list of definitions to review specific changes, review definition file for policySet in repo.")
                    }
                    if (!$displayNameMatches) {
                        $fileRecord.Set_Item('displayNameChanged', (!($displayNameMatches)))
                        $fileRecord.Set_Item('oldDisplayName', $deployedDefinition.displayName)
                        $fileRecord.Set_Item('newDisplayName', $displayName)
                    }
                    if (!$descriptionMatches) {
                        $fileRecord.Set_Item('descriptionChanged', !($descriptionMatches))
                        $fileRecord.Set_Item('oldDescription', $deployedDefinition.description)
                        $fileRecord.Set_Item('newDescription', $description)
                    }
                    if ($changePacOwnerId) {
                        $fileRecord.Set_Item('ownerChanged', $changePacOwnerId)
                        $fileRecord.Set_Item('oldOwner', $deployedDefinition.metadata.pacOwnerId)
                        $fileRecord.Set_Item('newOwner', $metadata.pacOwnerId)
                    }
                    if (!$metadataMatches) {
                        $fileRecord.Set_Item('metadataChanged', !($metadataMatches))
                        $fileRecord.Set_Item('oldMetadata', $deployedDefinition.metadata)
                        $fileRecord.Set_Item('newMetadata', $metadata)
                    }
                    if (!$parametersMatch -and !$incompatible) { # I don't think this is really useful, we don't test on it anywhere, we test on incompatible... which appears to be the same intended outcome.
                        $fileRecord.Set_Item('parametersChanged', !($parametersMatch))
                        $fileRecord.Set_Item('oldParameters', $deployedDefinition.parameters)
                        $fileRecord.Set_Item('newParameters', $parameters)
                    }
                    if (!$policyDefinitionGroupsMatch) {
                        if ($deletedPolicyDefinitionGroups) {
                            $fileRecord.Set_Item('deletedPolicyDefinitionGroups', $deletedPolicyDefinitionGroups)
                        }
                        $fileRecord.Set_Item('oldPolicyDefinitionGroups', $deployedDefinition.policyDefinitionGroups)
                        $fileRecord.Set_Item('newPolicyDefinitionGroups', $policyDefinitionGroupsFinal)
                    }
                    # Update evaluationResult
                    if ($incompatible -or $containsReplacedPolicy) {
                        # Check if parameters are compatible with an update or id the set includes at least one Policy which is being replaced.
                        $fileRecord.Set_Item('evaluationResult', 'replace')
                    }
                    else {
                        $fileRecord.Set_Item('evaluationResult', 'update')
                    }
                    $allPolicySetRecords.add($(@($relativePath,$fileRecord.id) -join "_"),$fileRecord)                    
                }
            }
        }
        else {
            Write-Information "New '$($displayName)'"
            $null = $Definitions.new.Add($id, $definition)
            $Definitions.numberOfChanges++
            if($ExtendedReporting){
                $fileRecord.Set_Item('name', $name)
                $fileRecord.Set_Item('definitionType', 'policySet')
                $fileRecord.Set_Item('evaluationResult', 'new')
                $fileRecord.Set_Item('id', $id)
                $fileRecord.Set_Item('fileRelativePath', $relativePath)
                $allPolicySetRecords.add($(@($relativePath,$fileRecord.id) -join "_"),$fileRecord)
            }
        }
    }

    $strategy = $PacEnvironment.desiredState.strategy
    foreach ($id in $deleteCandidates.Keys) {
        $deleteCandidate = $deleteCandidates.$id
        $deleteCandidateProperties = Get-PolicyResourceProperties $deleteCandidate
        $displayName = $deleteCandidateProperties.displayName
        $pacOwner = $deleteCandidate.pacOwner
        $shallDelete = Confirm-DeleteForStrategy -PacOwner $pacOwner -Strategy $strategy
        if ($shallDelete) {
            # always delete if owned by this Policy as Code solution
            # never delete if owned by another Policy as Code solution
            # if strategy is "full", delete with unknown owner (missing pacOwnerId)
            Write-Information "Delete '$($deleteCandidateProperties.displayName)'"
            $splat = @{
                id          = $id
                name        = $deleteCandidate.name
                scopeId     = $deploymentRootScope
                displayName = $displayName
            }
            $null = $Definitions.delete.Add($id, $splat)
            $Definitions.numberOfChanges++
            if ($AllDefinitions.policydefinitions.ContainsKey($id)) {
                # should always be true
                $null = $AllDefinitions.policydefinitions.Remove($id)
            }
            if($ExtendedReporting){
                # Add record for any items that remain that will be deleted
                Remove-Variable detailRecord -ErrorAction SilentlyContinue
                $detailRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
                $detailRecord.Set_Item('name', $name)
                $detailRecord.Set_Item('id', $id)
                $detailRecord.Set_Item('evaluationResult', 'delete')
                $detailRecord.Set_Item('fileRelativePath', "n/a")
                $detailRecord.Set_Item('definitionType', 'policySet')
                $detailRecord.Set_Item('fileRelativePath', 'noPolicySetFile')
                $allPolicySetRecords.add($(@($relativePath,$detailRecord.id) -join "_"),$detailRecord)

            }
        }
        else {
            if ($VerbosePreference -eq "Continue") {
                Write-Information "No delete($pacOwner,$strategy) '$($displayName)'"
            }
            if($ExtendedReporting){
                # Add record for any items that remain that will not be deleted
                Remove-Variable detailRecord -ErrorAction SilentlyContinue
                $detailRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
                $detailRecord.Set_Item('name', $name)
                $detailRecord.Set_Item('id', $id)
                $detailRecord.Set_Item('evaluationResult', 'outOfScope-notFullDesiredState')
                $detailRecord.Set_Item('fileRelativePath', "n/a")
                $detailRecord.Set_Item('definitionType', 'policySet')
                $detailRecord.Set_Item('fileRelativePath', 'noPolicySetFile')
                $allPolicySetRecords.add($(@("NoPolicySetFile",$detailRecord.id) -join "_"),$detailRecord)
            }
        }
    }
    foreach($pSetRec in $allPolicySetRecords.keys){
        $detailedRecordList.Add($pSetRec,$allPolicySetRecords.$pSetRec)
    }
    Write-Information "Number of unchanged Policy SetPolicy Sets definition = $($Definitions.numberUnchanged)"
    Write-Information ""
}
