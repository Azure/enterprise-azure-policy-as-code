#Requires -PSEdition Core

function Build-AzInitiativeDefinitionsPlan {
    [CmdletBinding()]
    param (
        [string] $initiativeDefinitionsRootFolder,
        [bool] $noDelete,
        [hashtable] $rootScope,
        [string] $rootScopeId,
        [hashtable] $existingCustomInitiativeDefinitions,
        [hashtable] $builtInInitiativeDefinitions,
        [hashtable] $allPolicyDefinitions,
        [hashtable] $allInitiativeDefinitions,
        [hashtable] $newInitiativeDefinitions,
        [hashtable] $updatedInitiativeDefinitions,
        [hashtable] $replacedInitiativeDefinitions,
        [hashtable] $deletedInitiativeDefinitions,
        [hashtable] $unchangedInitiativeDefinitions,
        [hashtable] $customInitiativeDefinitions
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Initiative definitions JSON files in folder '$initiativeDefinitionsRootFolder'"
    Write-Information "==================================================================================================="
    $initiativeFiles = @()
    $initiativeFiles += Get-ChildItem -Path $initiativeDefinitionsRootFolder -Recurse -File -Filter "*.json"
    $initiativeFiles += Get-ChildItem -Path $initiativeDefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
    if ($initiativeFiles.Length -gt 0) {
        Write-Information "Number of Initiative files = $($initiativeFiles.Length)"
    }
    else {
        Write-Information "There aren't any Initiative files in the folder provided!"
    }

    # Getting Initiative definitions from the JSON files
    $obsoleteInitiativeDefinitions = $existingCustomInitiativeDefinitions.Clone()
    foreach ($initiativeFile in $initiativeFiles) {
        $Json = Get-Content -Path $initiativeFile.FullName -Raw -ErrorAction Stop
        if (!(Test-Json $Json)) {
            Write-Error "Initiative JSON file '$($initiativeFile.Name)' is not valid = $Json" -ErrorAction Stop
        }
        $initiativeObject = $Json | ConvertFrom-Json -Depth 100
        
        $name = $initiativeObject.name
        $displayName = $initiativeObject.properties.displayName
        if ($null -eq $name) {
            Write-Error "Initiative JSON file '$($policyFile.FullName)' is missing an Initiative name" -ErrorAction Stop
        }
        elseif ($null -eq $displayName) {
            Write-Error "Initiative JSON file '$($policyFile.FullName)' is missing a Initiative displayName" -ErrorAction Stop
        }
        if ($customInitiativeDefinitions.ContainsKey($name)) {
            Write-Error "Duplicate Initiative definition '$($name)' in '$($customInitiativeDefinitions[$name].FullName)' and '$($initiativeFile.FullName)'" -ErrorAction Stop
        }
        else {
            $customInitiativeDefinitions.Add($name, $policyFile)
        }

        # Prep additional fields
        [hashtable] $mergedParameters = @{}
        if ($null -ne $initiativeObject.properties.parameters) {
            $mergedParameters = ConvertTo-HashTable $initiativeObject.properties.parameters
        }

        [System.Collections.ArrayList] $mergedPolicyDefinitions = [System.Collections.ArrayList]::new()
        if ($null -ne $initiativeObject.properties.PolicyDefinitions) {
            $result = Build-AzPolicyDefinitionsForInitiative `
                -allPolicyDefinitions $allPolicyDefinitions `
                -replacedPolicyDefinitions $replacedPolicyDefinitions `
                -policyDefinitionsInJson $initiativeObject.properties.PolicyDefinitions `
                -definitionScope $rootScopeId
            $mergedPolicyDefinitions.AddRange($result.policyDefinitions)
        }

        [hashtable] $mergedGroupDefinitions = @{}
        if ($null -ne $initiativeObject.properties.policyDefinitionGroups) {
            $null = ($initiativeObject.properties.policyDefinitionGroups) | ForEach-Object { 
                $mergedGroupDefinitions.Add($_.name, $_)
            }
        }

        # if ($null -ne $initiativeObject.merge) {
        #     $mergeHt = ConvertTo-HashTable $initiativeObject.merge
        #     Merge-Initiatives `
        #         -initiativeDisplayName $displayName `
        #         -merge $mergeHt `
        #         -builtInInitiativeDefinitions $builtInInitiativeDefinitions `
        #         -allPolicyDefinitions $allPolicyDefinitions `
        #         -mergedParameters $mergedParameters `
        #         -mergedPolicyDefinitions $mergedPolicyDefinitions `
        #         -mergedGroupDefinitions $mergedGroupDefinitions
        # }

        if ($result.usingUndefinedReference) {
            Write-Error "Undefined Policy referenced in '$($name)' from $($initiativeFile.Name)" -ErrorAction Stop
        }
        elseif ($mergedPolicyDefinitions.Count -eq 0) {
            Write-Error "Initiative must contain at least one Policy Defintion" -ErrorAction Stop
        }
        else {
            # Constructing Initiative definitions parameters for splatting
            $initiativeDefinitionConfig = @{
                Name             = $name
                DisplayName      = $displayName
                Description      = "no description"
                Parameter        = $mergedParameters
                PolicyDefinition = $mergedPolicyDefinitions
                GroupDefinition  = $mergedGroupDefinitions.Values
            }

            # Adding SubscriptionId or ManagementGroupName value and optional fields to the splat
            $initiativeDefinitionConfig += $rootScope
            # Add Initiative description if it's present in the definition file
            if ($initiativeObject.properties.description) {
                $initiativeDefinitionConfig.Description = $initiativeObject.properties.description
            }
            #Add Initiative metadata if it's present in the definition file
            if ($initiativeObject.properties.metadata) {
                $initiativeDefinitionConfig.Add("Metadata", $initiativeObject.properties.metadata)
            }

            $allInitiativeDefinitions.Add($initiativeDefinitionConfig.Name, $initiativeDefinitionConfig)
            if ($existingCustomInitiativeDefinitions.ContainsKey($initiativeDefinitionConfig.Name)) {
                # Update scenarios

                # Remove defined Initative definition entry from deleted hashtable (the hastable originall contains all custom Initiative definition in the scope)
                $matchingCustomDefinition = $existingCustomInitiativeDefinitions[$initiativeDefinitionConfig.Name]
                $obsoleteInitiativeDefinitions.Remove($initiativeDefinitionConfig.Name)
                $initiativeDefinitionConfig.Add("id", $matchingCustomDefinition.id)

                if ($result.usingReplacedReference) {
                    Write-Information "Replace(ref) '$($name)' - '$($displayName)'"
                    $replacedInitiativeDefinitions.Add($name, $initiativeDefinitionConfig)
                }
                else {
                    # Check if policy definition in Azure is the same as in the JSON file
                    $displayNameMatches = $matchingCustomDefinition.displayName -eq $initiativeDefinitionConfig.DisplayName
                    $descriptionMatches = $matchingCustomDefinition.description -eq $initiativeDefinitionConfig.Description
                    $metadataMatches = Confirm-MetadataMatches `
                        -existingMetadataObj $matchingCustomDefinition.metadata `
                        -definedMetadataObj $initiativeObject.properties.metadata
                    $parameterMatchResults = Confirm-ParametersMatch `
                        -existingParametersObj $matchingCustomDefinition.parameters `
                        -definedParametersObj  $initiativeObject.properties.parameters
                    $groupDefinitionMatches = Confirm-ObjectValueEqualityDeep `
                        -existingObj $matchingCustomDefinition.policyDefinitionGroups `
                        -definedObj $initiativeDefinitionConfig.GroupDefinition
                    $policyDefinitionsMatch = Confirm-ObjectValueEqualityDeep `
                        -existingObj $matchingCustomDefinition.policyDefinitions `
                        -definedObj $initiativeDefinitionConfig.PolicyDefinition

                    # Update policy definition in Azure if necessary
                    if ($displayNameMatches -and $groupDefinitionMatches -and $parameterMatchResults.match -and $metadataMatches -and $policyDefinitionsMatch -and $descriptionMatches) {
                        # Write-Information "Unchanged '$($name)' - '$($displayName)'"
                        $unchangedInitiativeDefinitions.Add($name, $displayName)
                    }
                    else {
                        if ($parameterMatchResults.incompatible) {
                            # check if parameters are compatible with an update. Otherwise the Policy will need to be deleted (and any Initiatives and Assignments referencing the Policy)
                            Write-Information "Replace(par) '$($name)' - '$($displayName)'"
                            $replacedInitiativeDefinitions.Add($name, $initiativeDefinitionConfig)
                        }
                        else {
                            $changesString = ($displayNameMatches ? "-" : "n") `
                                + ($descriptionMatches ? "-" : "d") `
                                + ($metadataMatches ? "-": "m") `
                                + ($parameterMatchResults.match ? "-": "p") `
                                + ($policyDefinitionsMatch ? "-": "P") `
                                + ($groupDefinitionMatches ? "-": "G")

                            Write-Information "Update($changesString) '$($name)' - '$($displayName)'"
                            $updatedInitiativeDefinitions.Add($name, $initiativeDefinitionConfig)
                        }
                
                    }
                }
            }
            else {
                Write-Information "New '$($name)' - '$($displayName)'"
                $newInitiativeDefinitions.Add($name, $initiativeDefinitionConfig)
            }
        }
    }
    foreach ($deletedName in $obsoleteInitiativeDefinitions.Keys) {
        $deleted = $obsoleteInitiativeDefinitions[$deletedName]
        if ($SuppressDeletes.IsPresent) {
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
            $deletedInitiativeDefinitions.Add($deletedName, $splat)
        }
    }

    Write-Information "Number of unchanged Initiatives =  $($unchangedInitiativeDefinitions.Count)"
    Write-Information  ""
    Write-Information  ""
}