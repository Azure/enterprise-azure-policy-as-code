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
    foreach ($Id in $readOnlyPolicySetDefinitions.Keys) {
        $PolicySetProperties = Get-PolicyResourceProperties -PolicyResource $readOnlyPolicySetDefinitions.$Id
        $roleIds = @{}
        foreach ($PolicyDefinition in $PolicySetProperties.policyDefinitions) {
            $PolicyId = $PolicyDefinition.policyDefinitionId
            if ($PolicyRoleIds.ContainsKey($PolicyId)) {
                $addRoleDefinitionIds = $PolicyRoleIds.$PolicyId
                foreach ($roleDefinitionId in $addRoleDefinitionIds) {
                    $roleIds[$roleDefinitionId] = "added"
                }
            }
        }
        if ($roleIds.psbase.Count -gt 0) {
            $null = $PolicyRoleIds.Add($Id, $roleIds.Keys)
        }
    }


    # Populate allDefinitions with deployed definitions
    $managedDefinitions = $DeployedDefinitions.managed
    $deleteCandidates = Get-HashtableShallowClone $DeployedDefinitions.managed
    $allDeployedDefinitions = $DeployedDefinitions.all
    foreach ($Id in $allDeployedDefinitions.Keys) {
        $AllDefinitions.policysetdefinitions[$Id] = $allDeployedDefinitions.$Id
    }
    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    $PolicyDefinitionsScopes = $PacEnvironment.policyDefinitionsScopes
    $duplicateDefinitionTracking = @{}
    $ThisPacOwnerId = $PacEnvironment.pacOwnerId

    # Process Policy Set JSON files if any
    if (!(Test-Path $DefinitionsRootFolder -PathType Container)) {
        Write-Warning "Policy Set definitions 'policySetDefinitions' folder not found. Policy Set definitions not managed by this EPAC instance."
    }
    else {

        $DefinitionFiles = @()
        $DefinitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.json"
        $DefinitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
        if ($DefinitionFiles.Length -gt 0) {
            Write-Information "Number of Policy Set files = $($DefinitionFiles.Length)"
        }
        else {
            Write-Warning "No Policy Set files found! Deleting any custom Policy Set definitions."
        }


        foreach ($file in $DefinitionFiles) {
            $Json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            if (!(Test-Json $Json)) {
                Write-Error "Policy Set JSON file '$($file.Name)' is not valid = $Json" -ErrorAction Stop
            }
            $DefinitionObject = $Json | ConvertFrom-Json -Depth 100

            $DefinitionProperties = Get-PolicyResourceProperties -PolicyResource $DefinitionObject
            $Name = $DefinitionObject.name
            $Id = "$deploymentRootScope/providers/Microsoft.Authorization/policySetDefinitions/$Name"
            $DisplayName = $DefinitionProperties.displayName
            $description = $DefinitionProperties.description
            $Metadata = Get-DeepClone $DefinitionProperties.metadata -AsHashtable
            $version = $DefinitionProperties.version
            $Parameters = $DefinitionProperties.parameters
            $PolicyDefinitions = $DefinitionProperties.policyDefinitions
            $PolicyDefinitionGroups = $DefinitionProperties.policyDefinitionGroups
            $importPolicyDefinitionGroups = $DefinitionProperties.importPolicyDefinitionGroups
            if ($Metadata) {
                $Metadata.pacOwnerId = $ThisPacOwnerId
            }
            else {
                $Metadata = @{ pacOwnerId = $ThisPacOwnerId }
            }

            # Core syntax error checking
            if ($null -eq $Name) {
                Write-Error "Policy Set from file '$($file.Name)' requires a name" -ErrorAction Stop
            }
            if ($null -eq $DisplayName) {
                Write-Error "Policy Set '$Name' from file '$($file.Name)' requires a displayName" -ErrorAction Stop
            }
            if ($null -eq $PolicyDefinitions -or $PolicyDefinitions.Count -eq 0) {
                Write-Error "Policy Set '$DisplayName' from file '$($file.Name)' requires a policyDefinitions array with at least one entry" -ErrorAction Stop
            }
            if ($duplicateDefinitionTracking.ContainsKey($Id)) {
                Write-Error "Duplicate Policy Set '$($Name)' in '$(($duplicateDefinitionTracking[$Id]).FullName)' and '$($file.FullName)'" -ErrorAction Stop
            }
            else {
                $null = $duplicateDefinitionTracking.Add($Id, $PolicyFile)
            }

            # Calculate included policyDefinitions
            $validPolicyDefinitions, $PolicyDefinitionsFinal, $PolicyRoleIdsInSet, $usedPolicyGroupDefinitions = Build-PolicySetPolicyDefinitionIds `
                -DisplayName $DisplayName `
                -PolicyDefinitions $PolicyDefinitions `
                -PolicyDefinitionsScopes $PolicyDefinitionsScopes `
                -AllDefinitions $AllDefinitions.policydefinitions `
                -PolicyRoleIds $PolicyRoleIds
            $PolicyDefinitions = $PolicyDefinitionsFinal.ToArray()
            if ($PolicyRoleIdsInSet.psbase.Count -gt 0) {
                $null = $PolicyRoleIds.Add($Id, $PolicyRoleIdsInSet.Keys)
            }


            # Process policyDefinitionGroups
            $PolicyDefinitionGroupsHashTable = @{}
            if ($null -ne $PolicyDefinitionGroups) {
                # Explicitly defined policyDefinitionGroups
                $null = $PolicyDefinitionGroups | ForEach-Object {
                    $groupName = $_.name
                    if ($usedPolicyGroupDefinitions.ContainsKey($groupName)) {
                        # Covered this use of a group name
                        $usedPolicyGroupDefinitions.Remove($groupName)
                    }
                    if (!$PolicyDefinitionGroupsHashTable.ContainsKey($groupName)) {
                        # Ignore duplicates
                        $PolicyDefinitionGroupsHashTable.Add($groupName, $_)
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
                        Write-Error "$($DisplayName): Policy Set '$importPolicySetId' for group name import not found." -ErrorAction Stop
                    }
                    $importedPolicySetDefinition = $DeployedDefinitions.readOnly[$importPolicySetId]
                    $importedPolicyDefinitionGroups = $importedPolicySetDefinition.properties.policyDefinitionGroups
                    if ($null -ne $importedPolicyDefinitionGroups -and $importedPolicyDefinitionGroups.Count -gt 0) {
                        # Write-Information "$($DisplayName): Importing PolicyDefinitionGroups from '$($importedPolicySetDefinition.displayName)'"
                        foreach ($importedPolicyDefinitionGroup in $importedPolicyDefinitionGroups) {
                            $groupName = $importedPolicyDefinitionGroup.name
                            if ($usedPolicyGroupDefinitions.ContainsKey($groupName)) {
                                $usedPolicyGroupDefinitions.Remove($groupName)
                                $PolicyDefinitionGroupsHashTable.Add($groupName, $importedPolicyDefinitionGroup)
                                if ($PolicyDefinitionGroupsHashTable.psbase.Count -ge 1000) {
                                    $limitReachedPolicyDefinitionGroups = $true
                                    if ($usedPolicyGroupDefinitions.psbase.Count -gt 0) {
                                        Write-Warning "$($DisplayName): Too many PolicyDefinitionGroups (1000+) - ignore remaining imports."
                                    }
                                    break
                                }
                            }
                        }
                        # Write-Information "$($DisplayName): Imported $($PolicyDefinitionGroupsHashTable.psbase.psbase.Count) PolicyDefinitionGroups from '$($importedPolicySetDefinition.displayName)'."
                    }
                    else {
                        Write-Error "$($DisplayName): Policy Set $($importedPolicySet.displayName) does not contain PolicyDefinitionGroups to import." -ErrorAction Stop
                    }
                }
            }
            $PolicyDefinitionGroupsFinal = $null
            if ($PolicyDefinitionGroupsHashTable.Count -gt 0) {
                $PolicyDefinitionGroupsFinal = @() + ($PolicyDefinitionGroupsHashTable.Values | Sort-Object -Property "name")
            }

            if (!$validPolicyDefinitions) {
                Write-Error "$($DisplayName): One or more invalid Policy entries referenced in Policy Set '$($DisplayName)' from '$($file.Name)'." -ErrorAction Stop
            }

            # Constructing Policy Set parameters for splatting
            $Definition = @{
                id                     = $Id
                name                   = $Name
                scopeId                = $deploymentRootScope
                displayName            = $DisplayName
                description            = $description
                metadata               = $Metadata
                # version                = $version
                parameters             = $Parameters
                policyDefinitions      = $PolicyDefinitionsFinal
                policyDefinitionGroups = $PolicyDefinitionGroupsFinal
            }
            # Remove-NullFields $Definition
            $AllDefinitions.policysetdefinitions[$Id] = $Definition

            if ($managedDefinitions.ContainsKey($Id)) {
                # Update or replace scenarios
                $deployedDefinition = $managedDefinitions[$Id]
                $deployedDefinition = Get-PolicyResourceProperties -PolicyResource $deployedDefinition

                # Remove defined Policy Set entry from deleted hashtable (the hashtable originally contains all custom Policy Sets in the scope)
                $null = $deleteCandidates.Remove($Id)

                # Check if Policy Set in Azure is the same as in the JSON file
                $DisplayNameMatches = $deployedDefinition.displayName -eq $DisplayName
                $descriptionMatches = $deployedDefinition.description -eq $description
                $MetadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                    -ExistingMetadataObj $deployedDefinition.metadata `
                    -DefinedMetadataObj $Metadata
                # $versionMatches = $version -eq $deployedDefinition.version
                $versionMatches = $true
                $ParametersMatch, $incompatible = Confirm-ParametersMatch `
                    -ExistingParametersObj $deployedDefinition.parameters `
                    -DefinedParametersObj $Parameters
                $PolicyDefinitionsMatch = Confirm-PolicyDefinitionsMatch `
                    $deployedDefinition.policyDefinitions `
                    $PolicyDefinitionsFinal
                $PolicyDefinitionGroupsMatch = Confirm-ObjectValueEqualityDeep `
                    $deployedDefinition.policyDefinitionGroups `
                    $PolicyDefinitionGroupsFinal
                $deletedPolicyDefinitionGroups = !$PolicyDefinitionGroupsMatch -and ($null -eq $PolicyDefinitionGroupsFinal -or $PolicyDefinitionGroupsFinal.Length -eq 0)

                # Update Policy Set in Azure if necessary
                $containsReplacedPolicy = $false
                foreach ($PolicyDefinitionEntry in $PolicyDefinitionsFinal) {
                    $PolicyId = $PolicyDefinitionEntry.policyDefinitionId
                    if ($ReplaceDefinitions.ContainsKey($PolicyId)) {
                        $containsReplacedPolicy = $true
                        break
                    }
                }
                if (!$containsReplacedPolicy -and $DisplayNameMatches -and $descriptionMatches -and $MetadataMatches -and $versionMatches -and !$changePacOwnerId -and $ParametersMatch -and $PolicyDefinitionsMatch -and $PolicyDefinitionGroupsMatch) {
                    # Write-Information "Unchanged '$($DisplayName)'"
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
                    if (!$DisplayNameMatches) {
                        $changesStrings += "displayName"
                    }
                    if (!$descriptionMatches) {
                        $changesStrings += "description"
                    }
                    if ($changePacOwnerId) {
                        $changesStrings += "owner"
                    }
                    if (!$MetadataMatches) {
                        $changesStrings += "metadata"
                    }
                    if (!$versionMatches) {
                        $changesStrings += "version"
                    }
                    if (!$ParametersMatch -and !$incompatible) {
                        $changesStrings += "param"
                    }
                    if (!$PolicyDefinitionsMatch) {
                        $changesStrings += "policies"
                    }
                    if (!$PolicyDefinitionGroupsMatch) {
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
                        Write-Information "Replace ($changesString) '$($DisplayName)'"
                        $null = $Definitions.replace.Add($Id, $Definition)
                        $null = $ReplaceDefinitions.Add($Id, $Definition)
                    }
                    else {
                        Write-Information "Update ($changesString) '$($DisplayName)'"
                        $null = $Definitions.update.Add($Id, $Definition)
                    }
                }
            }
            else {
                Write-Information "New '$($DisplayName)'"
                $null = $Definitions.new.Add($Id, $Definition)
                $Definitions.numberOfChanges++

            }
        }

        $Strategy = $PacEnvironment.desiredState.strategy
        foreach ($Id in $deleteCandidates.Keys) {
            $deleteCandidate = $deleteCandidates.$Id
            $deleteCandidateProperties = Get-PolicyResourceProperties $deleteCandidate
            $DisplayName = $deleteCandidateProperties.displayName
            $PacOwner = $deleteCandidate.pacOwner
            $shallDelete = Confirm-DeleteForStrategy -PacOwner $PacOwner -Strategy $Strategy
            if ($shallDelete) {
                # always delete if owned by this Policy as Code solution
                # never delete if owned by another Policy as Code solution
                # if strategy is "full", delete with unknown owner (missing pacOwnerId)
                Write-Information "Delete '$($DisplayName)'"
                $Splat = @{
                    id          = $Id
                    name        = $deleteCandidate.name
                    scopeId     = $deploymentRootScope
                    displayName = $DisplayName
                }
                $null = $Definitions.delete.Add($Id, $Splat)
                $Definitions.numberOfChanges++
                if ($AllDefinitions.policydefinitions.ContainsKey($Id)) {
                    # should always be true
                    $null = $AllDefinitions.policydefinitions.Remove($Id)
                }
            }
            else {
                # Write-Information "No delete($PacOwner,$Strategy) '$($DisplayName)'"
            }
        }

        Write-Information "Number of unchanged Policy SetPolicy Sets definition = $($Definitions.numberUnchanged)"
    }
    Write-Information ""
}
