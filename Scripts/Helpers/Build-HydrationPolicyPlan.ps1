function Build-HydrationPolicyPlan {
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
    Write-Information "Processing Policy JSON files in folder '$DefinitionsRootFolder'"
    Write-Information "==================================================================================================="

    if($ExtendedReporting){
        # Define Script Variables for ExtendedReporting
        $allPolicyRecords = [ordered]@{}
        $rRoot = (Resolve-Path (Split-Path (Split-Path $DefinitionsRootFolder))).Path
    }
    # Process Policy definitions JSON files, if any
    $definitionFiles = @()
    $definitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.json"
    $definitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
    if ($definitionFiles.Length -gt 0) {
        Write-Information "Number of Policy files = $($definitionFiles.Length)"
    }
    else {
        Write-Warning "No Policy files found! Deleting any custom Policy definitions."
    }

    $managedDefinitions = $DeployedDefinitions.managed
    $deleteCandidates = $managedDefinitions.Clone()
    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    $duplicateDefinitionTracking = @{}
    $definitionsNew = $Definitions.new
    $definitionsUpdate = $Definitions.update
    $definitionsReplace = $Definitions.replace
    $definitionsUnchanged = 0
    $thisPacOwnerId = $PacEnvironment.pacOwnerId

    foreach ($file in $definitionFiles) {

        # Write-Information "Processing $($definitionFilesSet.Length) Policy files in this parallel execution."
        $Json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        $definitionObject = $null
        try {
            $definitionObject = ConvertFrom-Json $Json -Depth 100
        }
        catch {
            Write-Error "Assignment JSON file '$($file.FullName)' is not valid." -ErrorAction Stop
        }
        if($ExtendedReporting){
            # Define File Specific Variables for ExtendedReporting
            Remove-Variable fileRecord -ErrorAction SilentlyContinue
            $fileRecord = Get-DeepCloneAsOrderedHashtable -InputObject $DetailedRecord
            $relativePath = -join(".",$file.FullName.Substring(($rRoot).Length))
        }        
        Remove-Variable definitionProperties -ErrorAction SilentlyContinue
        $definitionProperties = Get-PolicyResourceProperties -PolicyResource $definitionObject
        $name = $definitionObject.name
            
        $id = "$deploymentRootScope/providers/Microsoft.Authorization/policyDefinitions/$name"
        $displayName = $definitionProperties.displayName
        $description = $definitionProperties.description
        Remove-Variable metadata -ErrorAction SilentlyContinue
        $metadata = Get-DeepCloneAsOrderedHashtable $definitionProperties.metadata
        $mode = $definitionProperties.mode
        $parameters = $definitionProperties.parameters
        $policyRule = $definitionProperties.policyRule
        
        if ($null -ne $metadata) {
            $metadata.pacOwnerId = $thisPacOwnerId
        }
        else {
            $metadata = @{ pacOwnerId = $thisPacOwnerId }
        }
        if ($metadata.epacCloudEnvironments) {
            if ($pacEnvironment.cloud -notIn $metadata.epacCloudEnvironments) {
                continue
            }
        }
        if (!$metadata.ContainsKey("deployedBy")) {
            $metadata.deployedBy = $PacEnvironment.deployedBy
        }

        # Core syntax error checking
        if ($null -eq $name) {
            Write-Error "Policy from file '$($file.Name)' requires a name" -ErrorAction Stop
        }
        if (-not (Confirm-ValidPolicyResourceName -Name $name)) {
            Write-Error "Policy from file '$($file.Name) has a name '$name' containing invalid characters <>*%&:?.+/ or ends with a space." -ErrorAction Stop
        }
        if ($null -eq $displayName) {
            Write-Error "Policy '$name' from file '$($file.Name)' requires a displayName" -ErrorAction Stop
        }
        if ($null -eq $mode) {
            $mode = "All" # Default
        }
        if ($null -eq $policyRule) {
            Write-Error "Policy '$displayName' from file '$($file.Name)' requires a policyRule" -ErrorAction Stop
        }
        if ($duplicateDefinitionTracking.ContainsKey($id)) {
            Write-Error "Duplicate Policy '$($name)' in '$(($duplicateDefinitionTracking[$id]).FullName)' and '$($file.FullName)'" -ErrorAction Stop
        }
        else {
            $null = $duplicateDefinitionTracking.Add($id, $file)
        }

        # Calculate roleDefinitionIds for this Policy
        if ($null -ne $definitionProperties.policyRule.then.details) {
            $details = $definitionProperties.policyRule.then.details
            if ($details -isnot [array]) {
                $roleDefinitionIdsInPolicy = $details.roleDefinitionIds
                if ($null -ne $roleDefinitionIdsInPolicy) {
                    $null = $PolicyRoleIds.Add($id, $roleDefinitionIdsInPolicy)
                }
            }
        }

        # Constructing Policy parameters for splatting
        $definition = @{
            id          = $id
            name        = $name
            scopeId     = $deploymentRootScope
            displayName = $displayName
            description = $description
            mode        = $mode
            metadata    = $metadata
            parameters  = $parameters
            policyRule  = $policyRule
        }
        $AllDefinitions.policydefinitions[$id] = $definition


        if ($managedDefinitions.ContainsKey($id)) {
            # Update and replace scenarios
            $deployedDefinition = $managedDefinitions[$id]
            Remove-Variable deployedDefinitionProperties -ErrorAction SilentlyContinue
            $deployedDefinitionProperties = Get-PolicyResourceProperties -PolicyResource $deployedDefinition

            # Remove defined Policy entry from deleted hashtable (the hashtable originally contains all custom Policy in the scope)
            $null = $deleteCandidates.Remove($id)

            # Check if Policy in Azure is the same as in the JSON file
            $displayNameMatches = $deployedDefinitionProperties.displayName -eq $displayName
            $descriptionMatches = $deployedDefinitionProperties.description -eq $description
            $modeMatches = $deployedDefinitionProperties.mode -eq $definition.Mode
            Remove-Variable metadataMatches -ErrorAction SilentlyContinue
            Remove-Variable changePacOwnerId -ErrorAction SilentlyContinue
            $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                -ExistingMetadataObj $deployedDefinitionProperties.metadata `
                -DefinedMetadataObj $metadata
            Remove-Variable parametersMatch -ErrorAction SilentlyContinue
            Remove-Variable incompatible -ErrorAction SilentlyContinue  
            $parametersMatch, $incompatible = Confirm-ParametersDefinitionMatch `
                -ExistingParametersObj $deployedDefinitionProperties.parameters `
                -DefinedParametersObj $parameters
            Remove-Variable policyRuleMatches -ErrorAction SilentlyContinue
            $policyRuleMatches = Confirm-ObjectValueEqualityDeep `
                $deployedDefinitionProperties.policyRule `
                $policyRule
            # Update Policy in Azure if necessary
            if ($displayNameMatches -and $descriptionMatches -and $modeMatches -and $metadataMatches -and !$changePacOwnerId -and $parametersMatch -and $policyRuleMatches) {
                # Write-Information "Unchanged '$($displayName)'"
                $definitionsUnchanged++
            }
            else {
                $changesStrings = @()
                if ($incompatible) {
                    $changesStrings += "param-incompat"
                }
                if (!$displayNameMatches) {
                    $changesStrings += "display"
                }
                if (!$descriptionMatches) {
                    $changesStrings += "description"
                }
                if (!$modeMatches) {
                    $changesStrings += "mode"
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
                if (!$policyRuleMatches) {
                    $changesStrings += "rule"
                }
                $changesString = $changesStrings -join ","

                if ($incompatible) {
                    # check if parameters are compatible with an update. Otherwise the Policy will need to be deleted (and any PolicySets and Assignments referencing the Policy)
                    Write-Information "Replace ($changesString) '$($displayName)'"
                    $null = $definitionsReplace.Add($id, $definition)
                    $null = $ReplaceDefinitions.Add($id, $definition)
                }
                else {
                    Write-Information "Update ($changesString) '$($displayName)'"
                    $null = $definitionsUpdate.Add($id, $definition)
                }
                if($ExtendedReporting){
                    # Define Changed Object Data for ExtendedReporting
                    # Populate Data Fields
                    $fileRecord.Set_Item('name', $name)
                    $fileRecord.Set_Item('definitionType', 'policy')
                    $fileRecord.Set_Item('id', $id)
                    $fileRecord.Set_Item('changes', $changesString)
                    $fileRecord.Set_Item('changeList', $changesStrings)
                    $fileRecord.Set_Item('fileRelativePath', $relativePath)
                    if ($incompatible) {
                        $fileRecord.Set_Item('parametersChanged', $incompatible)
                        $fileRecord.Set_Item('oldParameters', $deployedDefinitionProperties.parameters)
                        $fileRecord.Set_Item('newParameters', $parameters)
                    }
                    if (!$displayNameMatches) {
                        $fileRecord.Set_Item('displayNameChanged', (!($displayNameMatches)))
                        $fileRecord.Set_Item('oldDisplayName', $deployedDefinitionProperties.displayName)
                        $fileRecord.Set_Item('newDisplayName', $displayName)
                    }
                    if (!$descriptionMatches) {
                        $fileRecord.Set_Item('descriptionChanged', !($descriptionMatches))
                        $fileRecord.Set_Item('oldDescription', $deployedDefinitionProperties.description)
                        $fileRecord.Set_Item('newDescription', $description)
                    }
                    if (!$modeMatches) {
                        $changesStrings += "mode"
                        $fileRecord.Set_Item('modeChanged', !($modeMatches))
                        $fileRecord.Set_Item('oldMode', $deployedDefinitionProperties.mode)
                        $fileRecord.Set_Item('newMode', $definition.Mode)
                    }
                    if ($changePacOwnerId) {
                        $fileRecord.Set_Item('ownerChanged', $changePacOwnerId)
                        $fileRecord.Set_Item('oldOwner', $deployedDefinitionProperties.metadata.pacOwnerId)
                        $fileRecord.Set_Item('newOwner', $metadata.pacOwnerId)
                    }
                    if (!$metadataMatches) {
                        $fileRecord.Set_Item('metadataChanged', !($metadataMatches))
                        $fileRecord.Set_Item('oldMetadata', $deployedDefinitionProperties.metadata)
                        $fileRecord.Set_Item('newMetadata', $metadata)
                    }
                    if (!$parametersMatch -and !$incompatible) {
                        $fileRecord.Set_Item('parametersChanged', !($parametersMatch))
                        $fileRecord.Set_Item('oldParameters', $deployedDefinitionProperties.parameters)
                        $fileRecord.Set_Item('newParameters', $parameters)
                    }
                    if (!$policyRuleMatches) {
                        $fileRecord.Set_Item('policyRuleChanged', !($policyRuleMatches))
                        $fileRecord.Set_Item('oldPolicyRule', $deployedDefinitionProperties.policyRule)
                        $fileRecord.Set_Item('newPolicyRule', $policyRule)
                    }
                    # Update Evaluation Result
                    if ($incompatible) {
                        $fileRecord.Set_Item('evaluationResult', 'replace')
                    }
                    else {
                        $fileRecord.Set_Item('evaluationResult', 'update')
                    }
                    $allpolicyRecords.add($(@($relativePath,$fileRecord.id) -join "_"),$fileRecord) 
                }
            }
        }
        else {
            $null = $definitionsNew.Add($id, $definition)
            Write-Information "New '$($displayName)'"
            if($ExtendedReporting){
                $fileRecord.Set_Item('name', $name)
                $fileRecord.Set_Item('definitionType', 'policy')
                $fileRecord.Set_Item('evaluationResult', 'new')
                $fileRecord.Set_Item('id', $id)
                $fileRecord.Set_Item('fileRelativePath', $relativePath)
                $fileRecord.Set_Item('changes', '*')
                $fileRecord.Set_Item('changeList', @('*'))
                $fileRecord.Set_Item('identityReplaced',"")
                $fileRecord.Set_Item('replacedReferencedDefinition',"")
                $fileRecord.Set_Item('displayNameChanged',"")
                $fileRecord.Set_Item('descriptionChanged',"")
                $fileRecord.Set_Item('definitionVersionChanged',"")
                $fileRecord.Set_Item('parametersChanged',"")
                $fileRecord.Set_Item('modeChanged',"")
                $fileRecord.Set_Item('resourceSelectorsChanged',"")
                $fileRecord.Set_Item('policyRuleChanged',"")
                $fileRecord.Set_Item('replacedPolicy',"")
                $fileRecord.Set_Item('policyDefinitionsChanged',"")
                $fileRecord.Set_Item('policyDefinitionGroupsChanged',"")
                $fileRecord.Set_Item('deletedPolicyDefinitionGroups',"")
                $allPolicyRecords.add($(@($relativePath,$fileRecord.id) -join "_"),$fileRecord)
            }
        }
    }
       

    $strategy = $PacEnvironment.desiredState.strategy
    foreach ($id in $deleteCandidates.Keys) {
        $deleteCandidate = $deleteCandidates.$id
        Remove-Variable deleteCandidateProperties -ErrorAction SilentlyContinue
        $deleteCandidateProperties = Get-PolicyResourceProperties $deleteCandidate
        $displayName = $deleteCandidateProperties.displayName
        $pacOwner = $deleteCandidate.pacOwner
        Remove-Variable shallDelete -ErrorAction SilentlyContinue
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
                DisplayName = $displayName
            }
            $null = $Definitions.delete.Add($id, $splat)
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
                $detailRecord.Set_Item('definitionType', 'policySet')
                $detailRecord.Set_Item('fileRelativePath', 'noPolicyFile')
                $detailRecord.Set_Item('changes', '*')
                $detailRecord.Set_Item('changeList', @('*'))
                $detailRecord.Set_Item('identityReplaced',"")
                $detailRecord.Set_Item('replacedReferencedDefinition',"")
                $detailRecord.Set_Item('displayNameChanged',"")
                $detailRecord.Set_Item('descriptionChanged',"")
                $detailRecord.Set_Item('definitionVersionChanged',"")
                $detailRecord.Set_Item('parametersChanged',"")
                $detailRecord.Set_Item('modeChanged',"")
                $detailRecord.Set_Item('resourceSelectorsChanged',"")
                $detailRecord.Set_Item('policyRuleChanged',"")
                $detailRecord.Set_Item('replacedPolicy',"")
                $detailRecord.Set_Item('policyDefinitionsChanged',"")
                $detailRecord.Set_Item('policyDefinitionGroupsChanged',"")
                $detailRecord.Set_Item('deletedPolicyDefinitionGroups',"")
                $allpolicyRecords.add($(@($relativePath,$detailRecord.id) -join "_"),$detailRecord)
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
                $detailRecord.Set_Item('definitionType', 'policy')
                $detailRecord.Set_Item('fileRelativePath', 'noPolicyFile')
                $detailRecord.Set_Item('changes', '*')
                $detailRecord.Set_Item('changeList', @('*'))
                $detailRecord.Set_Item('identityReplaced',"")
                $detailRecord.Set_Item('replacedReferencedDefinition',"")
                $detailRecord.Set_Item('displayNameChanged',"")
                $detailRecord.Set_Item('descriptionChanged',"")
                $detailRecord.Set_Item('definitionVersionChanged',"")
                $detailRecord.Set_Item('parametersChanged',"")
                $detailRecord.Set_Item('modeChanged',"")
                $detailRecord.Set_Item('resourceSelectorsChanged',"")
                $detailRecord.Set_Item('policyRuleChanged',"")
                $detailRecord.Set_Item('replacedPolicy',"")
                $detailRecord.Set_Item('policyDefinitionsChanged',"")
                $detailRecord.Set_Item('policyDefinitionGroupsChanged',"")
                $detailRecord.Set_Item('deletedPolicyDefinitionGroups',"")
                $allPolicyRecords.add($(@($relativePath,$detailRecord.id) -join "_"),$detailRecord)
            }
        }
    }
    foreach($pRec in $allPolicyRecords.keys){
        $detailedRecordList.Add($pRec,$allPolicyRecords.$pRec)
    }

    $Definitions.numberUnchanged = $definitionsUnchanged
    $Definitions.numberOfChanges = $Definitions.new.Count + $Definitions.update.Count + $Definitions.replace.Count + $Definitions.delete.Count

    Write-Information "Number of unchanged Policies = $($Definitions.numberUnchanged)"
    Write-Information ""
}
