function Build-PolicySetPlan {
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
    Write-Information "Processing Policy Set JSON files in folder '$DefinitionsRootFolder'"
    Write-Information "==================================================================================================="

    # Calculate roleDefinitionIds for built-in and inherited PolicySets
    $readOnlyPolicySetDefinitions = $DeployedDefinitions.readOnly
    foreach ($id in $readOnlyPolicySetDefinitions.Keys) {
        $policySetProperties = Get-PolicyResourceProperties -PolicyResource $readOnlyPolicySetDefinitions.$id
        $roleIds = @{}
        foreach ($policyDefinition in $policySetProperties.policyDefinitions) {
            $policyId = $policyDefinition.policyDefinitionId
            if ($PolicyRoleIds.ContainsKey($policyId)) {
                $addRoleDefinitionIds = $PolicyRoleIds.$policyId
                foreach ($roleDefinitionId in $addRoleDefinitionIds) {
                    $roleIds[$roleDefinitionId] = "added"
                }
            }
        }
        if ($roleIds.psbase.Count -gt 0) {
            $null = $PolicyRoleIds.Add($id, $roleIds.Keys)
        }
    }


    # Populate allDefinitions with deployed definitions
    $managedDefinitions = $DeployedDefinitions.managed
    $deleteCandidates = Get-HashtableShallowClone $managedDefinitions
    $allDeployedDefinitions = $DeployedDefinitions.all
    foreach ($id in $allDeployedDefinitions.Keys) {
        $AllDefinitions.policysetdefinitions[$id] = $allDeployedDefinitions.$id
    }
    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    $policyDefinitionsScopes = $PacEnvironment.policyDefinitionsScopes
    $duplicateDefinitionTracking = @{}
    $thisPacOwnerId = $PacEnvironment.pacOwnerId

    # Process Policy Set JSON files if any
    if (!(Test-Path $DefinitionsRootFolder -PathType Container)) {
        Write-Warning "Policy Set definitions 'policySetDefinitions' folder not found. Policy Set definitions not managed by this EPAC instance."
    }
    else {

        $definitionFiles = @()
        $definitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.json"
        $definitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
        if ($definitionFiles.Length -gt 0) {
            Write-Information "Number of Policy Set files = $($definitionFiles.Length)"
        }
        else {
            Write-Warning "No Policy Set files found! Deleting any custom Policy Set definitions."
        }


        foreach ($file in $definitionFiles) {
            $Json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop

            try {
                $definitionObject = $Json | ConvertFrom-Json -Depth 100
            }
            catch {
                Write-Error "Assignment JSON file '$($file.Name)' is not valid." -ErrorAction Stop
            }

            $definitionProperties = Get-PolicyResourceProperties -PolicyResource $definitionObject
            $name = $definitionObject.name
            $id = "$deploymentRootScope/providers/Microsoft.Authorization/policySetDefinitions/$name"
            $displayName = $definitionProperties.displayName
            $description = $definitionProperties.description
            $metadata = Get-DeepClone $definitionProperties.metadata -AsHashTable
            # $version = $definitionProperties.version
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
            # Core syntax error checking
            if ($null -eq $name) {
                Write-Error "Policy Set from file '$($file.Name)' requires a name" -ErrorAction Stop
            }
            if (-not (Confirm-ValidPolicyResourceName -Name $name)) {
                Write-Error "Policy Set from file '$($file.Name) has a name '$name' containing invalid charachters <>*%&:?.+/ or ends with a space." -ErrorAction Stop
            }
            if ($null -eq $displayName) {
                Write-Error "Policy Set '$name' from file '$($file.Name)' requires a displayName" -ErrorAction Stop
            }
            if ($null -eq $policyDefinitions -or $policyDefinitions.Count -eq 0) {
                Write-Error "Policy Set '$displayName' from file '$($file.Name)' requires a policyDefinitions array with at least one entry" -ErrorAction Stop
            }
            if ($duplicateDefinitionTracking.ContainsKey($id)) {
                Write-Error "Duplicate Policy Set '$($name)' in '$(($duplicateDefinitionTracking[$id]).FullName)' and '$($file.FullName)'" -ErrorAction Stop
            }
            else {
                $null = $duplicateDefinitionTracking.Add($id, $policyFile)
            }

            # Calculate included policyDefinitions
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
                # Explicitly defined policyDefinitionGroups
                $null = $policyDefinitionGroups | ForEach-Object {
                    $groupName = $_.name
                    if ($usedPolicyGroupDefinitions.ContainsKey($groupName)) {
                        # Covered this use of a group name
                        $usedPolicyGroupDefinitions.Remove($groupName)
                    }
                    if (!$policyDefinitionGroupsHashTable.ContainsKey($groupName)) {
                        # Ignore duplicates
                        $policyDefinitionGroupsHashTable.Add($groupName, $_)
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
                # version                = $version
                parameters             = $parameters
                policyDefinitions      = $policyDefinitionsFinal
                policyDefinitionGroups = $policyDefinitionGroupsFinal
            }
            # Remove-NullFields $definition
            $AllDefinitions.policysetdefinitions[$id] = $definition

            if ($managedDefinitions.ContainsKey($id)) {
                # Update or replace scenarios
                $deployedDefinition = $managedDefinitions[$id]
                $deployedDefinition = Get-PolicyResourceProperties -PolicyResource $deployedDefinition

                # Remove defined Policy Set entry from deleted hashtable (the hashtable originally contains all custom Policy Sets in the scope)
                $null = $deleteCandidates.Remove($id)

                # Check if Policy Set in Azure is the same as in the JSON file
                $displayNameMatches = $deployedDefinition.displayName -eq $displayName
                $descriptionMatches = $deployedDefinition.description -eq $description
                $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                    -ExistingMetadataObj $deployedDefinition.metadata `
                    -DefinedMetadataObj $metadata
                # $versionMatches = $version -eq $deployedDefinition.version
                $versionMatches = $true
                $parametersMatch, $incompatible = Confirm-ParametersDefinitionMatch `
                    -ExistingParametersObj $deployedDefinition.parameters `
                    -DefinedParametersObj $parameters
                $policyDefinitionsMatch = Confirm-PolicyDefinitionsInPolicySetMatch `
                    $deployedDefinition.policyDefinitions `
                    $policyDefinitionsFinal
                $policyDefinitionGroupsMatch = Confirm-ObjectValueEqualityDeep `
                    $deployedDefinition.policyDefinitionGroups `
                    $policyDefinitionGroupsFinal
                $deletedPolicyDefinitionGroups = !$policyDefinitionGroupsMatch -and ($null -eq $policyDefinitionGroupsFinal -or $policyDefinitionGroupsFinal.Length -eq 0)

                # Update Policy Set in Azure if necessary
                $containsReplacedPolicy = $false
                foreach ($policyDefinitionEntry in $policyDefinitionsFinal) {
                    $policyId = $policyDefinitionEntry.policyDefinitionId
                    if ($ReplaceDefinitions.ContainsKey($policyId)) {
                        $containsReplacedPolicy = $true
                        break
                    }
                }
                if (!$containsReplacedPolicy -and $displayNameMatches -and $descriptionMatches -and $metadataMatches -and $versionMatches -and !$changePacOwnerId -and $parametersMatch -and $policyDefinitionsMatch -and $policyDefinitionGroupsMatch) {
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
                    if (!$versionMatches) {
                        $changesStrings += "version"
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
                }
            }
            else {
                Write-Information "New '$($displayName)'"
                $null = $Definitions.new.Add($id, $definition)
                $Definitions.numberOfChanges++

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
            }
            else {
                # Write-Information "No delete($pacOwner,$strategy) '$($displayName)'"
            }
        }

        Write-Information "Number of unchanged Policy SetPolicy Sets definition = $($Definitions.numberUnchanged)"
    }
    Write-Information ""
}
