function Build-PolicySetPlan {
    [CmdletBinding()]
    param (
        [string] $definitionsRootFolder,
        [hashtable] $pacEnvironment,
        [hashtable] $deployedDefinitions,
        [hashtable] $definitions,
        [hashtable] $allDefinitions,
        [hashtable] $replaceDefinitions,
        [hashtable] $policyRoleIds
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy Set JSON files in folder '$definitionsRootFolder'"
    Write-Information "==================================================================================================="

    # Calculate roleDefinitionIds for built-in and inherited PolicySets
    $readOnlyPolicySetDefinitions = $deployedDefinitions.readOnly
    foreach ($id in $readOnlyPolicySetDefinitions.Keys) {
        $policySetProperties = Get-PolicyResourceProperties -policyResource $readOnlyPolicySetDefinitions.$id
        $roleIds = @{}
        foreach ($policyDefinition in $policySetProperties.policyDefinitions) {
            $policyId = $policyDefinition.policyDefinitionId
            if ($policyRoleIds.ContainsKey($policyId)) {
                $addRoleDefinitionIds = $policyRoleIds.$policyId
                foreach ($roleDefinitionId in $addRoleDefinitionIds) {
                    $roleIds[$roleDefinitionId] = "added"
                }
            }
        }
        if ($roleIds.psbase.Count -gt 0) {
            $null = $policyRoleIds.Add($id, $roleIds.Keys)
        }
    }


    # Populate allDefinitions with deployed definitions
    $managedDefinitions = $deployedDefinitions.managed
    $deleteCandidates = Get-HashtableShallowClone $deployedDefinitions.managed
    $allDeployedDefinitions = $deployedDefinitions.all
    foreach ($id in $allDeployedDefinitions.Keys) {
        $allDefinitions.policysetdefinitions[$id] = $allDeployedDefinitions.$id
    }
    $deploymentRootScope = $pacEnvironment.deploymentRootScope
    $policyDefinitionsScopes = $pacEnvironment.policyDefinitionsScopes
    $duplicateDefinitionTracking = @{}
    $thisPacOwnerId = $pacEnvironment.pacOwnerId

    # Process Policy Set JSON files if any
    if (!(Test-Path $definitionsRootFolder -PathType Container)) {
        Write-Warning "Policy Set definitions 'policySetDefinitions' folder not found. Policy Set definitions not managed by this EPAC instance."
    }
    else {

        $definitionFiles = @()
        $definitionFiles += Get-ChildItem -Path $definitionsRootFolder -Recurse -File -Filter "*.json"
        $definitionFiles += Get-ChildItem -Path $definitionsRootFolder -Recurse -File -Filter "*.jsonc"
        if ($definitionFiles.Length -gt 0) {
            Write-Information "Number of Policy Set files = $($definitionFiles.Length)"
        }
        else {
            Write-Warning "No Policy Set files found! Deleting any custom Policy Set definitions."
        }


        foreach ($file in $definitionFiles) {
            $Json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            if (!(Test-Json $Json)) {
                Write-Error "Policy Set JSON file '$($file.Name)' is not valid = $Json" -ErrorAction Stop
            }
            $definitionObject = $Json | ConvertFrom-Json -Depth 100

            $definitionProperties = Get-PolicyResourceProperties -policyResource $definitionObject
            $name = $definitionObject.name
            $id = "$deploymentRootScope/providers/Microsoft.Authorization/policySetDefinitions/$name"
            $displayName = $definitionProperties.displayName
            $description = $definitionProperties.description
            $metadata = Get-DeepClone $definitionProperties.metadata -AsHashTable
            $version = $definitionProperties.version
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

            # Core syntax error checking
            if ($null -eq $name) {
                Write-Error "Policy Set from file '$($file.Name)' requires a name" -ErrorAction Stop
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
                -displayName $displayName `
                -policyDefinitions $policyDefinitions `
                -policyDefinitionsScopes $policyDefinitionsScopes `
                -allDefinitions $allDefinitions.policydefinitions `
                -policyRoleIds $policyRoleIds
            $policyDefinitions = $policyDefinitionsFinal.ToArray()
            if ($policyRoleIdsInSet.psbase.Count -gt 0) {
                $null = $policyRoleIds.Add($id, $policyRoleIdsInSet.Keys)
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
                    if (!($deployedDefinitions.readOnly.ContainsKey($importPolicySetId))) {
                        Write-Error "$($displayName): Policy Set '$importPolicySetId' for group name import not found." -ErrorAction Stop
                    }
                    $importedPolicySetDefinition = $deployedDefinitions.readOnly[$importPolicySetId]
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
            $allDefinitions.policysetdefinitions[$id] = $definition

            if ($managedDefinitions.ContainsKey($id)) {
                # Update or replace scenarios
                $deployedDefinition = $managedDefinitions[$id]
                $deployedDefinition = Get-PolicyResourceProperties -policyResource $deployedDefinition

                # Remove defined Policy Set entry from deleted hashtable (the hashtable originally contains all custom Policy Sets in the scope)
                $null = $deleteCandidates.Remove($id)

                # Check if Policy Set in Azure is the same as in the JSON file
                $displayNameMatches = $deployedDefinition.displayName -eq $displayName
                $descriptionMatches = $deployedDefinition.description -eq $description
                $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                    -existingMetadataObj $deployedDefinition.metadata `
                    -definedMetadataObj $metadata
                # $versionMatches = $version -eq $deployedDefinition.version
                $versionMatches = $true
                $parametersMatch, $incompatible = Confirm-ParametersMatch `
                    -existingParametersObj $deployedDefinition.parameters `
                    -definedParametersObj $parameters
                $policyDefinitionsMatch = Confirm-PolicyDefinitionsMatch `
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
                    if ($replaceDefinitions.ContainsKey($policyId)) {
                        $containsReplacedPolicy = $true
                        break
                    }
                }
                if (!$containsReplacedPolicy -and $displayNameMatches -and $descriptionMatches -and $metadataMatches -and $versionMatches -and !$changePacOwnerId -and $parametersMatch -and $policyDefinitionsMatch -and $policyDefinitionGroupsMatch) {
                    # Write-Information "Unchanged '$($displayName)'"
                    $definitions.numberUnchanged++
                }
                else {
                    $definitions.numberOfChanges++
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
                        $null = $definitions.replace.Add($id, $definition)
                        $null = $replaceDefinitions.Add($id, $definition)
                    }
                    else {
                        Write-Information "Update ($changesString) '$($displayName)'"
                        $null = $definitions.update.Add($id, $definition)
                    }
                }
            }
            else {
                Write-Information "New '$($displayName)'"
                $null = $definitions.new.Add($id, $definition)
                $definitions.numberOfChanges++

            }
        }

        $strategy = $pacEnvironment.desiredState.strategy
        foreach ($id in $deleteCandidates.Keys) {
            $deleteCandidate = $deleteCandidates.$id
            $deleteCandidateProperties = Get-PolicyResourceProperties $deleteCandidate
            $displayName = $deleteCandidateProperties.displayName
            $pacOwner = $deleteCandidate.pacOwner
            $shallDelete = Confirm-DeleteForStrategy -pacOwner $pacOwner -strategy $strategy
            if ($shallDelete) {
                # always delete if owned by this Policy as Code solution
                # never delete if owned by another Policy as Code solution
                # if strategy is "full", delete with unknown owner (missing pacOwnerId)
                Write-Information "Delete '$($displayName)'"
                $splat = @{
                    id          = $id
                    name        = $deleteCandidate.name
                    scopeId     = $deploymentRootScope
                    displayName = $displayName
                }
                $null = $definitions.delete.Add($id, $splat)
                $definitions.numberOfChanges++
                if ($allDefinitions.policydefinitions.ContainsKey($id)) {
                    # should always be true
                    $null = $allDefinitions.policydefinitions.Remove($id)
                }
            }
            else {
                # Write-Information "No delete($pacOwner,$strategy) '$($displayName)'"
            }
        }

        Write-Information "Number of unchanged Policy SetPolicy Sets definition = $($definitions.numberUnchanged)"
    }
    Write-Information ""
}