function Build-PolicyPlan {
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
    Write-Information "Processing Policy JSON files in folder '$definitionsRootFolder'"
    Write-Information "==================================================================================================="

    # Calculate roleDefinitionIds for built-in and inherited Policies
    $readOnlyPolicyDefinitions = $deployedDefinitions.readOnly
    foreach ($id in $readOnlyPolicyDefinitions.Keys) {
        $deployedDefinitionProperties = Get-PolicyResourceProperties -policyResource $readOnlyPolicyDefinitions.$id
        if ($deployedDefinitionProperties.policyRule.then.details -and $deployedDefinitionProperties.policyRule.then.details.roleDefinitionIds) {
            $roleIds = $deployedDefinitionProperties.policyRule.then.details.roleDefinitionIds
            $null = $policyRoleIds.Add($id, $roleIds)
        }
    }

    # Populate allDefinitions with all deployed definitions
    $managedDefinitions = $deployedDefinitions.managed
    $deleteCandidates = Get-HashtableShallowClone $managedDefinitions
    $allDeployedDefinitions = $deployedDefinitions.all
    foreach ($id in $allDeployedDefinitions.Keys) {
        $allDefinitions.policydefinitions[$id] = $allDeployedDefinitions.$id
    }
    $deploymentRootScope = $pacEnvironment.deploymentRootScope
    $duplicateDefinitionTracking = @{}
    $thisPacOwnerId = $pacEnvironment.pacOwnerId

    # Process Policy definitions JSON files, if any
    if (!(Test-Path $definitionsRootFolder -PathType Container)) {
        Write-Warning "Policy definitions 'policyDefinitions' folder not found. Policy definitions not managed by this EPAC instance."
    }
    else {

        $definitionFiles = @()
        $definitionFiles += Get-ChildItem -Path $definitionsRootFolder -Recurse -File -Filter "*.json"
        $definitionFiles += Get-ChildItem -Path $definitionsRootFolder -Recurse -File -Filter "*.jsonc"
        if ($definitionFiles.Length -gt 0) {
            Write-Information "Number of Policy files = $($definitionFiles.Length)"
        }
        else {
            Write-Warning "No Policy files found! Deleting any custom Policy definitions."
        }


        foreach ($file in $definitionFiles) {
            $Json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            if (!(Test-Json $Json)) {
                Write-Error "Policy JSON file '$($file.FullName)' is not valid." -ErrorAction Stop
            }
            $definitionObject = $Json | ConvertFrom-Json

            $definitionProperties = Get-PolicyResourceProperties -policyResource $definitionObject
            $name = $definitionObject.name
            $id = "$deploymentRootScope/providers/Microsoft.Authorization/policyDefinitions/$name"
            $displayName = $definitionProperties.displayName
            $description = $definitionProperties.description
            $metadata = Get-DeepClone $definitionProperties.metadata -AsHashTable
            $version = $definitionProperties.version
            $mode = $definitionProperties.mode
            $parameters = $definitionProperties.parameters
            $policyRule = $definitionProperties.policyRule
            if ($metadata) {
                $metadata.pacOwnerId = $thisPacOwnerId
            }
            else {
                $metadata = @{ pacOwnerId = $thisPacOwnerId }
            }

            # Core syntax error checking
            if ($null -eq $name) {
                Write-Error "Policy from file '$($file.Name)' requires a name" -ErrorAction Stop
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
            if ($definitionProperties.policyRule.then.details -and $definitionProperties.policyRule.then.details.roleDefinitionIds) {
                $roleDefinitionIdsInPolicy = $definitionProperties.policyRule.then.details.roleDefinitionIds
                $null = $policyRoleIds.Add($id, $roleDefinitionIdsInPolicy)
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
                # version     = $version
                parameters  = $parameters
                policyRule  = $policyRule
            }
            # Remove-NullFields $definition
            $allDefinitions.policydefinitions[$id] = $definition


            if ($managedDefinitions.ContainsKey($id)) {
                # Update and replace scenarios
                $deployedDefinition = $managedDefinitions[$id]
                $deployedDefinition = Get-PolicyResourceProperties -policyResource $deployedDefinition

                # Remove defined Policy entry from deleted hashtable (the hashtable originally contains all custom Policy in the scope)
                $null = $deleteCandidates.Remove($id)

                # Check if Policy in Azure is the same as in the JSON file
                $displayNameMatches = $deployedDefinition.displayName -eq $displayName
                $descriptionMatches = $deployedDefinition.description -eq $description
                $modeMatches = $deployedDefinition.mode -eq $definition.Mode
                $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                    -existingMetadataObj $deployedDefinition.metadata `
                    -definedMetadataObj $metadata
                # $versionMatches = $version -eq $deployedDefinition.version
                $versionMatches = $true
                $parametersMatch, $incompatible = Confirm-ParametersMatch `
                    -existingParametersObj $deployedDefinition.parameters `
                    -definedParametersObj $parameters
                $policyRuleMatches = Confirm-ObjectValueEqualityDeep `
                    $deployedDefinition.policyRule `
                    $policyRule

                # Update Policy in Azure if necessary
                if ($displayNameMatches -and $descriptionMatches -and $modeMatches -and $metadataMatches -and !$changePacOwnerId -and $versionMatches -and $parametersMatch -and $policyRuleMatches) {
                    # Write-Information "Unchanged '$($displayName)'"
                    $definitions.numberUnchanged++
                }
                else {
                    $definitions.numberOfChanges++
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
                    if (!$versionMatches) {
                        $changesStrings += "version"
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
                $null = $definitions.new.Add($id, $definition)
                $definitions.numberOfChanges++
                Write-Information "New '$($displayName)'"
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
                    DisplayName = $displayName
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

        Write-Information "Number of unchanged Policies = $($definitions.numberUnchanged)"
    }
    Write-Information ""
}