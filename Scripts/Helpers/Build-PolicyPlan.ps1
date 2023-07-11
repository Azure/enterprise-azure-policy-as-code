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

    # Calculate roleDefinitionIds for built-in and inherited Policies
    $readOnlyPolicyDefinitions = $DeployedDefinitions.readOnly
    foreach ($Id in $readOnlyPolicyDefinitions.Keys) {
        $deployedDefinitionProperties = Get-PolicyResourceProperties -PolicyResource $readOnlyPolicyDefinitions.$Id
        if ($deployedDefinitionProperties.policyRule.then.details -and $deployedDefinitionProperties.policyRule.then.details.roleDefinitionIds) {
            $roleIds = $deployedDefinitionProperties.policyRule.then.details.roleDefinitionIds
            $null = $PolicyRoleIds.Add($Id, $roleIds)
        }
    }

    # Populate allDefinitions with all deployed definitions
    $managedDefinitions = $DeployedDefinitions.managed
    $deleteCandidates = Get-HashtableShallowClone $managedDefinitions
    $allDeployedDefinitions = $DeployedDefinitions.all
    foreach ($Id in $allDeployedDefinitions.Keys) {
        $AllDefinitions.policydefinitions[$Id] = $allDeployedDefinitions.$Id
    }
    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    $duplicateDefinitionTracking = @{}
    $ThisPacOwnerId = $PacEnvironment.pacOwnerId

    # Process Policy definitions JSON files, if any
    if (!(Test-Path $DefinitionsRootFolder -PathType Container)) {
        Write-Warning "Policy definitions 'policyDefinitions' folder not found. Policy definitions not managed by this EPAC instance."
    }
    else {

        $DefinitionFiles = @()
        $DefinitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.json"
        $DefinitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
        if ($DefinitionFiles.Length -gt 0) {
            Write-Information "Number of Policy files = $($DefinitionFiles.Length)"
        }
        else {
            Write-Warning "No Policy files found! Deleting any custom Policy definitions."
        }


        foreach ($file in $DefinitionFiles) {
            $Json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            if (!(Test-Json $Json)) {
                Write-Error "Policy JSON file '$($file.FullName)' is not valid." -ErrorAction Stop
            }
            $DefinitionObject = $Json | ConvertFrom-Json

            $DefinitionProperties = Get-PolicyResourceProperties -PolicyResource $DefinitionObject
            $Name = $DefinitionObject.name
            $Id = "$deploymentRootScope/providers/Microsoft.Authorization/policyDefinitions/$Name"
            $DisplayName = $DefinitionProperties.displayName
            $description = $DefinitionProperties.description
            $Metadata = Get-DeepClone $DefinitionProperties.metadata -AsHashtable
            $version = $DefinitionProperties.version
            $Mode = $DefinitionProperties.mode
            $Parameters = $DefinitionProperties.parameters
            $PolicyRule = $DefinitionProperties.policyRule
            if ($Metadata) {
                $Metadata.pacOwnerId = $ThisPacOwnerId
            }
            else {
                $Metadata = @{ pacOwnerId = $ThisPacOwnerId }
            }

            # Core syntax error checking
            if ($null -eq $Name) {
                Write-Error "Policy from file '$($file.Name)' requires a name" -ErrorAction Stop
            }
            if ($null -eq $DisplayName) {
                Write-Error "Policy '$Name' from file '$($file.Name)' requires a displayName" -ErrorAction Stop
            }
            if ($null -eq $Mode) {
                $Mode = "All" # Default
            }
            if ($null -eq $PolicyRule) {
                Write-Error "Policy '$DisplayName' from file '$($file.Name)' requires a policyRule" -ErrorAction Stop
            }
            if ($duplicateDefinitionTracking.ContainsKey($Id)) {
                Write-Error "Duplicate Policy '$($Name)' in '$(($duplicateDefinitionTracking[$Id]).FullName)' and '$($file.FullName)'" -ErrorAction Stop
            }
            else {
                $null = $duplicateDefinitionTracking.Add($Id, $file)
            }

            # Calculate roleDefinitionIds for this Policy
            if ($DefinitionProperties.policyRule.then.details -and $DefinitionProperties.policyRule.then.details.roleDefinitionIds) {
                $roleDefinitionIdsInPolicy = $DefinitionProperties.policyRule.then.details.roleDefinitionIds
                $null = $PolicyRoleIds.Add($Id, $roleDefinitionIdsInPolicy)
            }

            # Constructing Policy parameters for splatting
            $Definition = @{
                id          = $Id
                name        = $Name
                scopeId     = $deploymentRootScope
                displayName = $DisplayName
                description = $description
                mode        = $Mode
                metadata    = $Metadata
                # version     = $version
                parameters  = $Parameters
                policyRule  = $PolicyRule
            }
            # Remove-NullFields $Definition
            $AllDefinitions.policydefinitions[$Id] = $Definition


            if ($managedDefinitions.ContainsKey($Id)) {
                # Update and replace scenarios
                $deployedDefinition = $managedDefinitions[$Id]
                $deployedDefinition = Get-PolicyResourceProperties -PolicyResource $deployedDefinition

                # Remove defined Policy entry from deleted hashtable (the hashtable originally contains all custom Policy in the scope)
                $null = $deleteCandidates.Remove($Id)

                # Check if Policy in Azure is the same as in the JSON file
                $DisplayNameMatches = $deployedDefinition.displayName -eq $DisplayName
                $descriptionMatches = $deployedDefinition.description -eq $description
                $ModeMatches = $deployedDefinition.mode -eq $Definition.Mode
                $MetadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                    -ExistingMetadataObj $deployedDefinition.metadata `
                    -DefinedMetadataObj $Metadata
                # $versionMatches = $version -eq $deployedDefinition.version
                $versionMatches = $true
                $ParametersMatch, $incompatible = Confirm-ParametersMatch `
                    -ExistingParametersObj $deployedDefinition.parameters `
                    -DefinedParametersObj $Parameters
                $PolicyRuleMatches = Confirm-ObjectValueEqualityDeep `
                    $deployedDefinition.policyRule `
                    $PolicyRule

                # Update Policy in Azure if necessary
                if ($DisplayNameMatches -and $descriptionMatches -and $ModeMatches -and $MetadataMatches -and !$changePacOwnerId -and $versionMatches -and $ParametersMatch -and $PolicyRuleMatches) {
                    # Write-Information "Unchanged '$($DisplayName)'"
                    $Definitions.numberUnchanged++
                }
                else {
                    $Definitions.numberOfChanges++
                    $changesStrings = @()
                    if ($incompatible) {
                        $changesStrings += "param-incompat"
                    }
                    if (!$DisplayNameMatches) {
                        $changesStrings += "display"
                    }
                    if (!$descriptionMatches) {
                        $changesStrings += "description"
                    }
                    if (!$ModeMatches) {
                        $changesStrings += "mode"
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
                    if (!$PolicyRuleMatches) {
                        $changesStrings += "rule"
                    }
                    $changesString = $changesStrings -join ","

                    if ($incompatible) {
                        # check if parameters are compatible with an update. Otherwise the Policy will need to be deleted (and any PolicySets and Assignments referencing the Policy)
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
                $null = $Definitions.new.Add($Id, $Definition)
                $Definitions.numberOfChanges++
                Write-Information "New '$($DisplayName)'"
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
                    DisplayName = $DisplayName
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

        Write-Information "Number of unchanged Policies = $($Definitions.numberUnchanged)"
    }
    Write-Information ""
}
