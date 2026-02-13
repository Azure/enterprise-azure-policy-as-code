function Build-PolicySetPlan {
    [CmdletBinding()]
    param (
        [string] $DefinitionsRootFolder,
        [hashtable] $PacEnvironment,
        [hashtable] $DeployedDefinitions,
        [hashtable] $Definitions,
        [hashtable] $AllDefinitions,
        [hashtable] $ReplaceDefinitions,
        [hashtable] $PolicyRoleIds,
        [switch] $DetailedOutput
    )

    Write-ModernSection -Title "Processing Policy Set Definitions" -Color Blue
    Write-ModernStatus -Message "Source folder: $DefinitionsRootFolder" -Status "info" -Indent 2

    # Process Policy Set JSON files if any
    $definitionFiles = @()
    $definitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.json"
    $definitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
    if ($definitionFiles.Length -gt 0) {
        Write-ModernStatus -Message "Found $($definitionFiles.Length) policy set files" -Status "success" -Indent 2
    }
    else {
        Write-ModernStatus -Message "No policy set files found - all custom definitions will be deleted" -Status "warning" -Indent 2
    }

    $managedDefinitions = $DeployedDefinitions.managed
    $deleteCandidates = $managedDefinitions.Clone()
    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    $policyDefinitionsScopes = $PacEnvironment.policyDefinitionsScopes
    $duplicateDefinitionTracking = @{}
    $definitionsIgnored = 0
    $thisPacOwnerId = $PacEnvironment.pacOwnerId

    foreach ($file in $definitionFiles) {
        if ($file.Name -in $PacEnvironment.desiredState.excludedPolicySetDefinitionFiles) {
            Write-ModernStatus -Message "Excluded by configuration: $($file.FullName)" -Status "skip" -Indent 4
            $definitionsIgnored++
            continue
        }
        $Json = Get-Content -Path $file.FullName -Raw -ErrorAction Stop

        $definitionObject = $null
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
        $metadata = Get-DeepCloneAsOrderedHashtable $definitionProperties.metadata
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
            version                = $version
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
                -DefinedMetadataObj $metadata `
                -SuppressPacOwnerIdMessage:$DetailedOutput
            $parametersMatch, $incompatible = Confirm-ParametersDefinitionMatch `
                -ExistingParametersObj $deployedDefinition.parameters `
                -DefinedParametersObj $parameters
            $policyDefinitionsMatch = Confirm-PolicyDefinitionsInPolicySetMatch `
                $deployedDefinition.policyDefinitions `
                $policyDefinitionsFinal `
                $AllDefinitions.policydefinitions
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
                    Write-ModernStatus -Message "Replace ($changesString): $($displayName)" -Status "warning" -Indent 4
                    $null = $Definitions.replace.Add($id, $definition)
                    $null = $ReplaceDefinitions.Add($id, $definition)
                    
                    # Show detailed diff if requested
                    if ($DetailedOutput) {
                        Write-Host ""
                        Write-ModernStatus -Message "[Policy Set Definition] Detailed Changes for: $displayName" -Status "info" -Indent 6
                        foreach ($change in $changesStrings) {
                            switch ($change) {
                                "display" {
                                    Write-SimplePropertyDiff -PropertyName "Display Name" -OldValue $deployedDefinition.displayName -NewValue $displayName -Indent 8
                                }
                                "description" {
                                    Write-SimplePropertyDiff -PropertyName "Description" -OldValue $deployedDefinition.description -NewValue $description -Indent 8
                                }
                                "metadata" {
                                    # Filter Azure system-managed properties and EPAC-managed pacOwnerId from metadata display
                                    $systemManagedProperties = @("createdBy", "createdOn", "updatedBy", "updatedOn", "lastSyncedToArgOn")
                                    $filteredDeployedMetadata = @{}
                                    $filteredDesiredMetadata = @{}
                                    
                                    if ($deployedDefinition.metadata) {
                                        foreach ($key in $deployedDefinition.metadata.Keys) {
                                            if ($key -notin $systemManagedProperties -and $key -ne "pacOwnerId") {
                                                $filteredDeployedMetadata[$key] = $deployedDefinition.metadata[$key]
                                            }
                                        }
                                    }
                                    
                                    if ($metadata) {
                                        foreach ($key in $metadata.Keys) {
                                            if ($key -ne "pacOwnerId") {
                                                $filteredDesiredMetadata[$key] = $metadata[$key]
                                            }
                                        }
                                    }
                                    
                                    Write-DetailedDiff -DeployedObject $filteredDeployedMetadata -DesiredObject $filteredDesiredMetadata -PropertyName "Metadata" -Indent 8
                                }
                                "param" {
                                    Write-DetailedDiff -DeployedObject $deployedDefinition.parameters -DesiredObject $parameters -PropertyName "Parameters" -Indent 8
                                }
                                "param-incompat" {
                                    Write-DetailedDiff -DeployedObject $deployedDefinition.parameters -DesiredObject $parameters -PropertyName "Parameters (Incompatible)" -Indent 8
                                }
                                "policies" {
                                    Write-DetailedDiff -DeployedObject $deployedDefinition.policyDefinitions -DesiredObject $policyDefinitions -PropertyName "Policy Definitions" -Indent 8
                                }
                                "groups" {
                                    Write-DetailedDiff -DeployedObject $deployedDefinition.policyDefinitionGroups -DesiredObject $policyDefinitionGroups -PropertyName "Policy Definition Groups" -Indent 8
                                }
                            }
                        }
                        Write-Host ""
                    }
                }
                else {
                    Write-ModernStatus -Message "Update ($changesString): $($displayName)" -Status "update" -Indent 4
                    $null = $Definitions.update.Add($id, $definition)
                    
                    # Show detailed diff if requested
                    if ($DetailedOutput) {
                        Write-Host ""
                        Write-ModernStatus -Message "[Policy Set Definition] Detailed Changes for: $displayName" -Status "info" -Indent 6
                        foreach ($change in $changesStrings) {
                            switch ($change) {
                                "display" {
                                    Write-SimplePropertyDiff -PropertyName "Display Name" -OldValue $deployedDefinition.displayName -NewValue $displayName -Indent 8
                                }
                                "description" {
                                    Write-SimplePropertyDiff -PropertyName "Description" -OldValue $deployedDefinition.description -NewValue $description -Indent 8
                                }
                                "metadata" {
                                    # Filter Azure system-managed properties and EPAC-managed pacOwnerId from metadata display
                                    $systemManagedProperties = @("createdBy", "createdOn", "updatedBy", "updatedOn", "lastSyncedToArgOn")
                                    $filteredDeployedMetadata = @{}
                                    $filteredDesiredMetadata = @{}
                                    
                                    if ($deployedDefinition.metadata) {
                                        foreach ($key in $deployedDefinition.metadata.Keys) {
                                            if ($key -notin $systemManagedProperties -and $key -ne "pacOwnerId") {
                                                $filteredDeployedMetadata[$key] = $deployedDefinition.metadata[$key]
                                            }
                                        }
                                    }
                                    
                                    if ($metadata) {
                                        foreach ($key in $metadata.Keys) {
                                            if ($key -ne "pacOwnerId") {
                                                $filteredDesiredMetadata[$key] = $metadata[$key]
                                            }
                                        }
                                    }
                                    
                                    Write-DetailedDiff -DeployedObject $filteredDeployedMetadata -DesiredObject $filteredDesiredMetadata -PropertyName "Metadata" -Indent 8
                                }
                                "param" {
                                    Write-DetailedDiff -DeployedObject $deployedDefinition.parameters -DesiredObject $parameters -PropertyName "Parameters" -Indent 8
                                }
                                "policies" {
                                    Write-DetailedDiff -DeployedObject $deployedDefinition.policyDefinitions -DesiredObject $policyDefinitions -PropertyName "Policy Definitions" -Indent 8
                                }
                                "groups" {
                                    Write-DetailedDiff -DeployedObject $deployedDefinition.policyDefinitionGroups -DesiredObject $policyDefinitionGroups -PropertyName "Policy Definition Groups" -Indent 8
                                }
                            }
                        }
                        Write-Host ""
                    }
                }
            }
        }
        else {
            Write-ModernStatus -Message "New: $($displayName)" -Status "success" -Indent 4
            $null = $Definitions.new.Add($id, $definition)
            $Definitions.numberOfChanges++
            
            # Show detailed content for new policy sets if requested
            if ($DetailedOutput) {
                Write-Host ""
                Write-ModernStatus -Message "[Policy Set Definition] Details for New Policy Set:" -Status "info" -Indent 6
                
                # Display Name
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Display Name: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "`"$displayName`"" -ForegroundColor Green
                
                # Description
                if ($description) {
                    Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                    Write-ColoredOutput -Message "Description: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "`"$description`"" -ForegroundColor Green
                }
                
                # Policy Definitions - show detailed list
                if ($policyDefinitionsFinal -and $policyDefinitionsFinal.Count -gt 0) {
                    Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                    Write-ColoredOutput -Message "Policy Definitions: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "$($policyDefinitionsFinal.Count) policy/policies" -ForegroundColor Green
                    foreach ($policyDef in $policyDefinitionsFinal) {
                        Write-ColoredOutput -Message "            - " -NoNewline -ForegroundColor Green
                        Write-ColoredOutput -Message "Policy ID: " -NoNewline -ForegroundColor Gray
                        Write-ColoredOutput -Message "$($policyDef.policyDefinitionId)" -ForegroundColor Green
                        if ($policyDef.policyDefinitionReferenceId) {
                            Write-ColoredOutput -Message "              Reference ID: " -NoNewline -ForegroundColor Gray
                            Write-ColoredOutput -Message "$($policyDef.policyDefinitionReferenceId)" -ForegroundColor Green
                        }
                        if ($policyDef.groupNames -and $policyDef.groupNames.Count -gt 0) {
                            Write-ColoredOutput -Message "              Groups: " -NoNewline -ForegroundColor Gray
                            Write-ColoredOutput -Message "$($policyDef.groupNames -join ', ')" -ForegroundColor Green
                        }
                        if ($policyDef.parameters) {
                            $paramCount = ($policyDef.parameters.PSObject.Properties | Measure-Object).Count
                            Write-ColoredOutput -Message "              Parameters: " -NoNewline -ForegroundColor Gray
                            Write-ColoredOutput -Message "$paramCount parameter(s) passed" -ForegroundColor Green
                        }
                    }
                }
                
                # Policy Definition Groups if any - show detailed list
                if ($policyDefinitionGroupsFinal -and $policyDefinitionGroupsFinal.Count -gt 0) {
                    Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                    Write-ColoredOutput -Message "Policy Definition Groups: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "$($policyDefinitionGroupsFinal.Count) group(s)" -ForegroundColor Green
                    foreach ($group in $policyDefinitionGroupsFinal) {
                        Write-ColoredOutput -Message "            - " -NoNewline -ForegroundColor Green
                        Write-ColoredOutput -Message "Name: " -NoNewline -ForegroundColor Gray
                        Write-ColoredOutput -Message "$($group.name)" -ForegroundColor Green
                        if ($group.displayName) {
                            Write-ColoredOutput -Message "              Display Name: " -NoNewline -ForegroundColor Gray
                            Write-ColoredOutput -Message "`"$($group.displayName)`"" -ForegroundColor Green
                        }
                        if ($group.category) {
                            Write-ColoredOutput -Message "              Category: " -NoNewline -ForegroundColor Gray
                            Write-ColoredOutput -Message "`"$($group.category)`"" -ForegroundColor Green
                        }
                    }
                }
                
                # Parameters if any - show detailed list
                if ($parameters) {
                    $paramKeys = $parameters.PSObject.Properties.Name
                    if ($paramKeys.Count -gt 0) {
                        Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                        Write-ColoredOutput -Message "Parameters: " -NoNewline -ForegroundColor Gray
                        Write-ColoredOutput -Message "$($paramKeys.Count) parameter(s)" -ForegroundColor Green
                        foreach ($paramName in ($paramKeys | Sort-Object)) {
                            $param = $parameters.$paramName
                            Write-ColoredOutput -Message "            - " -NoNewline -ForegroundColor Green
                            Write-ColoredOutput -Message "Name: " -NoNewline -ForegroundColor Gray
                            Write-ColoredOutput -Message "$paramName" -ForegroundColor Green
                            
                            if ($param.type) {
                                Write-ColoredOutput -Message "              Type: " -NoNewline -ForegroundColor Gray
                                Write-ColoredOutput -Message "$($param.type)" -ForegroundColor Green
                            }
                            if ($param.defaultValue) {
                                Write-ColoredOutput -Message "              Default: " -NoNewline -ForegroundColor Gray
                                $defaultJson = $param.defaultValue | ConvertTo-Json -Depth 100 -Compress
                                Write-ColoredOutput -Message "$defaultJson" -ForegroundColor Green
                            }
                            if ($param.allowedValues) {
                                Write-ColoredOutput -Message "              Allowed Values: " -NoNewline -ForegroundColor Gray
                                $allowedJson = $param.allowedValues | ConvertTo-Json -Depth 100 -Compress
                                Write-ColoredOutput -Message "$allowedJson" -ForegroundColor Green
                            }
                            if ($param.metadata -and $param.metadata.description) {
                                Write-ColoredOutput -Message "              Description: " -NoNewline -ForegroundColor Gray
                                Write-ColoredOutput -Message "`"$($param.metadata.description)`"" -ForegroundColor Green
                            }
                        }
                    }
                }
                
                # Metadata if any (excluding system properties)
                if ($metadata) {
                    $systemManagedProperties = @("createdBy", "createdOn", "updatedBy", "updatedOn", "lastSyncedToArgOn")
                    $filteredMetadata = @{}
                    foreach ($key in $metadata.Keys) {
                        if ($key -notin $systemManagedProperties) {
                            $filteredMetadata[$key] = $metadata[$key]
                        }
                    }
                    if ($filteredMetadata.Count -gt 0) {
                        Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                        Write-ColoredOutput -Message "Metadata:" -ForegroundColor Gray
                        foreach ($key in ($filteredMetadata.Keys | Sort-Object)) {
                            Write-ColoredOutput -Message "            + " -NoNewline -ForegroundColor Green
                            Write-ColoredOutput -Message "$key" -NoNewline -ForegroundColor White
                            Write-ColoredOutput -Message " = " -NoNewline -ForegroundColor Gray
                            Write-ColoredOutput -Message "`"$($filteredMetadata[$key])`"" -ForegroundColor Green
                        }
                    }
                }
                
                Write-Host ""
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
            Write-ModernStatus -Message "Delete: $($deleteCandidateProperties.displayName)" -Status "error" -Indent 4
            
            # Show detailed context for deletions if requested
            if ($DetailedOutput) {
                Write-Host ""
                Write-ModernStatus -Message "[Policy Set Definition] Details for Deleted Policy Set:" -Status "info" -Indent 6
                
                # Display Name
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "Display Name: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "`"$($deleteCandidateProperties.displayName)`"" -ForegroundColor Red
                
                # Description
                if ($deleteCandidateProperties.description) {
                    Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                    Write-ColoredOutput -Message "Description: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "`"$($deleteCandidateProperties.description)`"" -ForegroundColor Red
                }
                
                # ID
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "ID: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message $id -ForegroundColor Red
                
                # Number of policies in the set
                if ($deleteCandidateProperties.policyDefinitions) {
                    $policyCount = $deleteCandidateProperties.policyDefinitions.Count
                    Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                    Write-ColoredOutput -Message "Policy Definitions: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "$policyCount policy/policies" -ForegroundColor Red
                }
                
                # Category from metadata if available
                if ($deleteCandidateProperties.metadata -and $deleteCandidateProperties.metadata.category) {
                    Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                    Write-ColoredOutput -Message "Category: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "`"$($deleteCandidateProperties.metadata.category)`"" -ForegroundColor Red
                }
                
                # Version from metadata if available
                if ($deleteCandidateProperties.metadata -and $deleteCandidateProperties.metadata.version) {
                    Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                    Write-ColoredOutput -Message "Version: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "`"$($deleteCandidateProperties.metadata.version)`"" -ForegroundColor Red
                }
                
                Write-Host ""
            }
            
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
            if ($VerbosePreference -eq "Continue") {
                Write-ModernStatus -Message "Skip delete ($pacOwner,$strategy): $($displayName)" -Status "skip" -Indent 4
            }
        }
    }

    Write-ModernStatus -Message "Unchanged Policy Set Definitions: $($Definitions.numberUnchanged)" -Status "status" -Indent 2
    # Write-ModernCountSummary -Operation "Policy Set Definitions" -Unchanged $Definitions.numberUnchanged
    Write-Information ""
}


