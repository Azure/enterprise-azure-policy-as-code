function Build-PolicyPlan {
    [CmdletBinding()]
    param (
        [string] $DefinitionsRootFolder,
        [hashtable] $PacEnvironment,
        [hashtable] $DeployedDefinitions,
        [hashtable] $Definitions,
        [hashtable] $AllDefinitions,
        [hashtable] $ReplaceDefinitions,
        [hashtable] $PolicyRoleIds
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy JSON files in folder '$DefinitionsRootFolder'"
    Write-Information "==================================================================================================="

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

        $definitionProperties = Get-PolicyResourceProperties -PolicyResource $definitionObject
        $name = $definitionObject.name
            
        $id = "$deploymentRootScope/providers/Microsoft.Authorization/policyDefinitions/$name"
        $displayName = $definitionProperties.displayName
        $description = $definitionProperties.description
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
            $deployedDefinitionProperties = Get-PolicyResourceProperties -PolicyResource $deployedDefinition

            # Remove defined Policy entry from deleted hashtable (the hashtable originally contains all custom Policy in the scope)
            $null = $deleteCandidates.Remove($id)

            # Check if Policy in Azure is the same as in the JSON file
            $displayNameMatches = $deployedDefinitionProperties.displayName -eq $displayName
            $descriptionMatches = $deployedDefinitionProperties.description -eq $description
            $modeMatches = $deployedDefinitionProperties.mode -eq $definition.Mode
            $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                -ExistingMetadataObj $deployedDefinitionProperties.metadata `
                -DefinedMetadataObj $metadata
            $parametersMatch, $incompatible = Confirm-ParametersDefinitionMatch `
                -ExistingParametersObj $deployedDefinitionProperties.parameters `
                -DefinedParametersObj $parameters
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
            }
        }
        else {
            $null = $definitionsNew.Add($id, $definition)
            Write-Information "New '$($displayName)'"
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
                DisplayName = $displayName
            }
            $null = $Definitions.delete.Add($id, $splat)
            if ($AllDefinitions.policydefinitions.ContainsKey($id)) {
                # should always be true
                $null = $AllDefinitions.policydefinitions.Remove($id)
            }
        }
        else {
            if ($VerbosePreference -eq "Continue") {
                Write-Information "No delete($pacOwner,$strategy) '$($displayName)'"
            }
        }
    }

    $Definitions.numberUnchanged = $definitionsUnchanged
    $Definitions.numberOfChanges = $Definitions.new.Count + $Definitions.update.Count + $Definitions.replace.Count + $Definitions.delete.Count

    Write-Information "Number of unchanged Policies = $($Definitions.numberUnchanged)"
    Write-Information ""
}
