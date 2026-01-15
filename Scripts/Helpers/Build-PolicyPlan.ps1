function Build-PolicyPlan {
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

    Write-ModernSection -Title "Processing Policy Definitions" -Color Blue
    Write-ModernStatus -Message "Source folder: $DefinitionsRootFolder" -Status "info" -Indent 2

    # Process Policy definitions JSON files, if any
    $definitionFiles = @()
    $definitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.json"
    $definitionFiles += Get-ChildItem -Path $DefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
    if ($definitionFiles.Length -gt 0) {
        Write-ModernStatus -Message "Found $($definitionFiles.Length) policy files" -Status "success" -Indent 2
    }
    else {
        Write-ModernStatus -Message "No policy files found - all custom definitions will be deleted" -Status "warning" -Indent 2
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
        $version = $definitionProperties.version
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
        if ($null -eq $displayName -and $definitionProperties.mode -ne "Microsoft.Network.Data") {
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
            version     = $version
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
                -DefinedMetadataObj $metadata `
                -SuppressPacOwnerIdMessage:$DetailedOutput
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
                    Write-ModernStatus -Message "Replace ($changesString): $($displayName)" -Status "warning" -Indent 4
                    $null = $definitionsReplace.Add($id, $definition)
                    $null = $ReplaceDefinitions.Add($id, $definition)
                    
                    # Show detailed diff if requested
                    if ($DetailedOutput) {
                        Write-Host ""
                        Write-ModernStatus -Message "[Policy Definition] Detailed Changes for: $displayName" -Status "info" -Indent 6
                        foreach ($change in $changesStrings) {
                            switch ($change) {
                                "display" {
                                    Write-SimplePropertyDiff -PropertyName "Display Name" -OldValue $deployedDefinitionProperties.displayName -NewValue $displayName -Indent 8
                                }
                                "description" {
                                    Write-SimplePropertyDiff -PropertyName "Description" -OldValue $deployedDefinitionProperties.description -NewValue $description -Indent 8
                                }
                                "mode" {
                                    Write-SimplePropertyDiff -PropertyName "Mode" -OldValue $deployedDefinitionProperties.mode -NewValue $mode -Indent 8
                                }
                                "metadata" {
                                    # Filter Azure system-managed properties and EPAC-managed pacOwnerId from metadata display
                                    $systemManagedProperties = @("createdBy", "createdOn", "updatedBy", "updatedOn", "lastSyncedToArgOn")
                                    $filteredDeployedMetadata = @{}
                                    $filteredDesiredMetadata = @{}
                                    
                                    if ($deployedDefinitionProperties.metadata) {
                                        foreach ($key in $deployedDefinitionProperties.metadata.Keys) {
                                            if ($key -notin $systemManagedProperties -and $key -ne "pacOwnerId") {
                                                $filteredDeployedMetadata[$key] = $deployedDefinitionProperties.metadata[$key]
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
                                    Write-DetailedDiff -DeployedObject $deployedDefinitionProperties.parameters -DesiredObject $parameters -PropertyName "Parameters" -Indent 8
                                }
                                "param-incompat" {
                                    Write-DetailedDiff -DeployedObject $deployedDefinitionProperties.parameters -DesiredObject $parameters -PropertyName "Parameters (Incompatible)" -Indent 8
                                }
                                "rule" {
                                    Write-DetailedDiff -DeployedObject $deployedDefinitionProperties.policyRule -DesiredObject $policyRule -PropertyName "Policy Rule" -Indent 8
                                }
                            }
                        }
                        Write-Host ""
                    }
                }
                else {
                    Write-ModernStatus -Message "Update ($changesString): $($displayName)" -Status "update" -Indent 4
                    $null = $definitionsUpdate.Add($id, $definition)
                    
                    # Show detailed diff if requested
                    if ($DetailedOutput) {
                        Write-Host ""
                        Write-ModernStatus -Message "[Policy Definition] Detailed Changes for: $displayName" -Status "info" -Indent 6
                        foreach ($change in $changesStrings) {
                            switch ($change) {
                                "display" {
                                    Write-SimplePropertyDiff -PropertyName "Display Name" -OldValue $deployedDefinitionProperties.displayName -NewValue $displayName -Indent 8
                                }
                                "description" {
                                    Write-SimplePropertyDiff -PropertyName "Description" -OldValue $deployedDefinitionProperties.description -NewValue $description -Indent 8
                                }
                                "mode" {
                                    Write-SimplePropertyDiff -PropertyName "Mode" -OldValue $deployedDefinitionProperties.mode -NewValue $mode -Indent 8
                                }
                                "metadata" {
                                    # Filter Azure system-managed properties and EPAC-managed pacOwnerId from metadata display
                                    $systemManagedProperties = @("createdBy", "createdOn", "updatedBy", "updatedOn", "lastSyncedToArgOn")
                                    $filteredDeployedMetadata = @{}
                                    $filteredDesiredMetadata = @{}
                                    
                                    if ($deployedDefinitionProperties.metadata) {
                                        foreach ($key in $deployedDefinitionProperties.metadata.Keys) {
                                            if ($key -notin $systemManagedProperties -and $key -ne "pacOwnerId") {
                                                $filteredDeployedMetadata[$key] = $deployedDefinitionProperties.metadata[$key]
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
                                    Write-DetailedDiff -DeployedObject $deployedDefinitionProperties.parameters -DesiredObject $parameters -PropertyName "Parameters" -Indent 8
                                }
                                "rule" {
                                    Write-DetailedDiff -DeployedObject $deployedDefinitionProperties.policyRule -DesiredObject $policyRule -PropertyName "Policy Rule" -Indent 8
                                }
                            }
                        }
                        Write-Host ""
                    }
                }
            }
        }
        else {
            $null = $definitionsNew.Add($id, $definition)
            Write-ModernStatus -Message "New: $($displayName)" -Status "success" -Indent 4
            
            # Show detailed content for new policies if requested
            if ($DetailedOutput) {
                Write-Host ""
                Write-ModernStatus -Message "[Policy Definition] Details for New Policy:" -Status "info" -Indent 6
                
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
                
                # Mode - display current value (already defaulted to "All" earlier if null)
                Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                Write-ColoredOutput -Message "Mode: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "`"$mode`"" -ForegroundColor Green
                if ([string]::IsNullOrWhiteSpace($definitionObject.properties.mode)) {
                    Write-ColoredOutput -Message " (default)" -ForegroundColor DarkGray
                }
                
                # Policy Rule - show the actual rule
                if ($policyRule) {
                    Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                    Write-ColoredOutput -Message "Policy Rule:" -ForegroundColor Gray
                    $ruleJson = $policyRule | ConvertTo-Json -Depth 100 -Compress:$false
                    $ruleLines = $ruleJson -split "`n" | ForEach-Object { $_.TrimEnd("`r") }
                    foreach ($line in $ruleLines) {
                        Write-ColoredOutput -Message "            $line" -ForegroundColor Green
                    }
                }
                
                # Parameters if any
                if ($parameters) {
                    $paramCount = ($parameters.PSObject.Properties | Measure-Object).Count
                    Write-ColoredOutput -Message "        + " -NoNewline -ForegroundColor Green
                    Write-ColoredOutput -Message "Parameters: " -NoNewline -ForegroundColor Gray
                    Write-ColoredOutput -Message "$paramCount parameter(s)" -ForegroundColor Green
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
                Write-ModernStatus -Message "[Policy Definition] Details for Deleted Policy:" -Status "info" -Indent 6
                
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
                
                # Mode - show actual value or default
                $deletedMode = if ([string]::IsNullOrWhiteSpace($deleteCandidateProperties.mode)) { "All" } else { $deleteCandidateProperties.mode }
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "Mode: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message "`"$deletedMode`"" -ForegroundColor Red
                if ([string]::IsNullOrWhiteSpace($deleteCandidateProperties.mode)) {
                    Write-ColoredOutput -Message " (default)" -ForegroundColor DarkGray
                }
                
                # ID
                Write-ColoredOutput -Message "        - " -NoNewline -ForegroundColor Red
                Write-ColoredOutput -Message "ID: " -NoNewline -ForegroundColor Gray
                Write-ColoredOutput -Message $id -ForegroundColor Red
                
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
                Write-ModernStatus -Message "Skip delete ($pacOwner,$strategy): $($displayName)" -Status "skip" -Indent 4
            }
        }
    }

    $Definitions.numberUnchanged = $definitionsUnchanged
    $Definitions.numberOfChanges = $Definitions.new.Count + $Definitions.update.Count + $Definitions.replace.Count + $Definitions.delete.Count

    Write-ModernStatus -Message "Unchanged Policy Definitions: $($Definitions.numberUnchanged)" -Status "status" -Indent 2
    Write-Information ""
}


