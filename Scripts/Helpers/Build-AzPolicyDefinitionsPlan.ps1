#Requires -PSEdition Core

function Build-AzPolicyDefinitionsPlan {
    [CmdletBinding()]
    param (
        [string] $policyDefinitionsRootFolder,
        [bool] $noDelete,
        [hashtable] $rootScope,
        [hashtable] $existingCustomPolicyDefinitions,
        [hashtable] $builtInPolicyDefinitions,
        [hashtable] $allPolicyDefinitions,
        [hashtable] $newPolicyDefinitions,
        [hashtable] $updatedPolicyDefinitions,
        [hashtable] $replacedPolicyDefinitions,
        [hashtable] $deletedPolicyDefinitions,
        [hashtable] $unchangedPolicyDefinitions,
        [hashtable] $customPolicyDefinitions,
        [hashtable] $policyNeededRoleDefinitionIds
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy definitions JSON files in folder '$policyDefinitionsRootFolder'"
    Write-Information "==================================================================================================="
    $policyFiles = @()
    $policyFiles += Get-ChildItem -Path $policyDefinitionsRootFolder -Recurse -File -Filter "*.json"
    $policyFiles += Get-ChildItem -Path $policyDefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
    if ($policyFiles.Length -gt 0) {
        Write-Information "Number of Policy files = $($policyFiles.Length)"
    }
    else {
        Write-Information "There aren't any Policy files in the folder provided!"
    }

    # Calculate roleDefinitionIds for built-in Policies
    foreach ($policyName in $builtInPolicyDefinitions.Keys) {
        $policy = $builtInPolicyDefinitions.$policyName
        if ($policy.policyRule.then.details -and $policy.policyRule.then.details.roleDefinitionIds) {
            $roleDefinitionIdsInPolicy = $policy.policyRule.then.details.roleDefinitionIds
            $policyNeededRoleDefinitionIds.Add($policyName, $roleDefinitionIdsInPolicy)
        }
    }

    $obsoletePolicyDefinitions = $existingCustomPolicyDefinitions.Clone()
    foreach ($policyFile in $policyFiles) {
        $Json = Get-Content -Path $policyFile.FullName -Raw -ErrorAction Stop
        if (!(Test-Json $Json)) {
            Write-Error "Policy JSON file '$($policyFile.FullName)' is not valid = $Json" -ErrorAction Stop
        }
        $policyObject = $Json | ConvertFrom-Json

        $name = $policyObject.name
        $displayName = $policyObject.properties.displayName
        if ($null -eq $name) {
            Write-Error "Policy JSON file '$($policyFile.FullName)' is missing a Policy name" -ErrorAction Stop
        }
        elseif ($null -eq $displayName) {
            Write-Error "Policy JSON file '$($policyFile.FullName)' is missing a Policy displayName" -ErrorAction Stop
        }
        if ($customPolicyDefinitions.ContainsKey($name)) {
            Write-Error "Duplicate Policy definition '$($name)' in '$($customPolicyDefinitions[$name].FullName)' and '$($policyFile.FullName)'" -ErrorAction Stop
        }
        else {
            $customPolicyDefinitions.Add($name, $policyFile)
        }

        # If policy mode was not defined, it should be defaulted to "All"
        if (-not $policyObject.properties.mode) {
            $Mode = "All"
        }
        else {
            $Mode = $policyObject.properties.mode
        }



        # Constructing policy definitions parameters for splatting
        $policyDefinitionConfig = @{
            Name        = $name
            DisplayName = $displayName
            Policy      = $policyObject.properties.policyRule
            Parameter   = $policyObject.properties.parameters
            Mode        = $Mode
        }
        if ($null -ne $policyObject.properties.metadata) {
            $null = $policyDefinitionConfig.Add("Metadata", $policyObject.properties.metadata)
        }

        # Calculate roleDefinitionIds for this Policy
        if ($policyObject.properties.policyRule.then.details -and $policyObject.properties.policyRule.then.details.roleDefinitionIds) {
            $roleDefinitionIdsInPolicy = $policyObject.properties.policyRule.then.details.roleDefinitionIds
            $null = $policyNeededRoleDefinitionIds.Add($name, $roleDefinitionIdsInPolicy)
        }

        # Adding SubscriptionId or ManagementGroupName value (depending on the parameter set in use)
        $policyDefinitionConfig += $rootScope

        # Add policy description if it's present in the definition file
        if ($policyObject.properties.description) {
            $policyDefinitionConfig.Description = $policyObject.properties.description
        }

        Write-Verbose "    Processing: '$($name)' from $($policyFile.Name)"
        $allPolicyDefinitions.Add($name, $policyDefinitionConfig)
        if ($existingCustomPolicyDefinitions.ContainsKey($name)) {
            # Update scenarios

            # Remove defined Policy definition entry from deleted hashtable (the hastable originally contains all custom Policy definition in the scope)
            $matchingCustomDefinition = $existingCustomPolicyDefinitions[$name]
            $obsoletePolicyDefinitions.Remove($name)
            $policyDefinitionConfig.Add("id", $matchingCustomDefinition.id)


            # Check if policy definition in Azure is the same as in the JSON file
            $displayNameMatches = $matchingCustomDefinition.displayName -eq $displayName
            $descriptionMatches = $matchingCustomDefinition.description -eq $policyDefinitionConfig.Description
            $modeMatches = $matchingCustomDefinition.mode -eq $policyDefinitionConfig.Mode
            $metadataMatches = Confirm-MetadataMatches -existingMetadataObj $matchingCustomDefinition.metadata -definedMetadataObj $policyObject.properties.metadata
            $parameterMatchResults = Confirm-ParametersMatch -existingParametersObj $matchingCustomDefinition.parameters -definedParametersObj $policyObject.properties.parameters
            $policyRuleMatches = Confirm-ObjectValueEqualityDeep -existingObj $matchingCustomDefinition.policyRule -definedObj $policyObject.properties.policyRule

            # Update policy definition in Azure if necessary
            if ($displayNameMatches -and $policyRuleMatches -and $parameterMatchResults.match -and $metadataMatches -and $modeMatches -and $descriptionMatches) {
                # Write-Information "Unchanged '$($name)' - '$($displayName)'"
                $unchangedPolicyDefinitions.Add($name, $displayName)
            }
            else {
                if ($parameterMatchResults.incompatible) {
                    # check if parameters are compatible with an update. Otherwise the Policy will need to be deleted (and any Initiatives and Assignments referencing the Policy)
                    Write-Information "Replace(par) '$($name)' - '$($displayName)'"
                    $replacedPolicyDefinitions.Add($name, $policyDefinitionConfig)
                }
                else {
                    $changesString = ($displayNameMatches ? "-" : "n") `
                        + ($descriptionMatches ? "-" : "d") `
                        + ($modeMatches ? "-": "a") `
                        + ($metadataMatches ? "-": "m") `
                        + ($parameterMatchResults.match ? "-": "p") `
                        + ($policyRuleMatches ? "-": "R")
                    Write-Information "Update($changesString) '$($name)' - '$($displayName)'"
                    $updatedPolicyDefinitions.Add($name, $policyDefinitionConfig)
                }
            }
        }
        else {
            $newPolicyDefinitions.Add($name, $policyDefinitionConfig)
            Write-Information "New '$($name)' - '$($displayName)'"
        }
    }

    foreach ($deletedName in $obsoletePolicyDefinitions.Keys) {
        $deleted = $obsoletePolicyDefinitions[$deletedName]
        if ($noDelete) {
            Write-Information "Suppressing Delete '$($deletedName)' - '$($deleted.displayName)'"
        }
        else {
            Write-Information "Delete '$($deletedName)' - '$($deleted.displayName)'"
            $splat = @{
                Name        = $deletedName
                DisplayName = $deleted.displayName
                id          = $deleted.id
            }
            $splat += $rootScope
            $deletedPolicyDefinitions.Add($deletedName, $splat)
        }
    }

    Write-Information "Number of unchanged Policies = $($unchangedPolicyDefinitions.Count)"
    Write-Information ""
    Write-Information ""

}