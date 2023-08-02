function Build-ExemptionsPlan {
    [CmdletBinding()]
    param (
        [string] $ExemptionsRootFolder,
        [string] $ExemptionsAreNotManagedMessage,
        [hashtable] $PacEnvironment,
        [hashtable] $AllAssignments,
        [hashtable] $Assignments,
        [hashtable] $DeployedExemptions,
        [hashtable] $Exemptions
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy Exemption files in folder '$ExemptionsRootFolder'"
    Write-Information "==================================================================================================="

    if ($ExemptionsAreNotManagedMessage -eq "") {

        [array] $exemptionFiles = @()
        # Do not manage exemptions if directory does not exist
        $exemptionFiles += Get-ChildItem -Path $ExemptionsRootFolder -Recurse -File -Filter "*.json"
        $exemptionFiles += Get-ChildItem -Path $ExemptionsRootFolder -Recurse -File -Filter "*.jsonc"
        $exemptionFiles += Get-ChildItem -Path $ExemptionsRootFolder -Recurse -File -Filter "*.csv"

        $allExemptions = @{}
        $deployedManagedExemptions = $DeployedExemptions.managed
        $deleteCandidates = Get-HashtableShallowClone $deployedManagedExemptions
        $replacedAssignments = $Assignments.replace
        if ($exemptionFiles.Length -eq 0) {
            Write-Warning "No Policy Exemption files found."
            Write-Warning "All exemptions will be deleted!"
            Write-Information ""
        }
        else {
            Write-Information "Number of Policy Exemption files = $($exemptionFiles.Length)"
            $now = Get-Date -AsUTC
            $numberOfFilesWithErrors = 0
            foreach ($file  in $exemptionFiles) {

                #region read each file

                $extension = $file.Extension
                $fullName = $file.FullName
                Write-Information "Processing file '$($fullName)'"
                $errorInfo = New-ErrorInfo -FileName $fullName
                $exemptionsArray = @()
                $isXls = $false
                if ($extension -eq ".json" -or $extension -eq ".jsonc") {
                    $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                    if (!(Test-Json $content)) {
                        Build-ErrorString -ErrorInfo $errorInfo -ErrorText "Invalid JSON"
                    }
                    else {
                        $jsonObj = ConvertFrom-Json $content -AsHashTable -Depth 100
                        Write-Information ""
                        if ($null -ne $jsonObj) {
                            $jsonExemptions = $jsonObj.exemptions
                            if ($null -ne $jsonExemptions -and $jsonExemptions.Count -gt 0) {
                                $exemptionsArray += $jsonExemptions
                            }
                        }
                    }
                }
                elseif ($extension -eq ".csv") {
                    $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                    $xlsExemptions = ($content | ConvertFrom-Csv -ErrorAction Stop)
                    if ($xlsExemptions.Count -gt 0) {
                        $exemptionsArray += $xlsExemptions
                    }
                }

                #endregion read each file

                #region validate file contents

                if ($errorInfo.hasErrors) {
                    Confirm-PolicyDefinitionUsedExists
                }
                    
                $entryNumber = $isXls ? 1 : 0
                foreach ($row in $emptionsArray) {
                    $name = $row.name
                    $displayName = $row.displayName
                    $exemptionCategory = $row.exemptionCategory
                    $scope = $row.scope
                    $policyAssignmentId = $row.policyAssignmentId
                    $description = $row.description
                    $assignmentScopeValidation = $row.assignmentScopeValidation
                    $resourceSelectors = $row.resourceSelectors
                    $policyDefinitionReferenceIds = $row.policyDefinitionReferenceIds
                    $metadata = $row.metadata
                    if ($isXls) {
                        if ([string]::IsNullOrWhitespace($name) `
                                -and [string]::IsNullOrWhitespace($displayName) `
                                -and [string]::IsNullOrWhitespace($exemptionCategory) `
                                -and [string]::IsNullOrWhitespace($scope) `
                                -and [string]::IsNullOrWhitespace($policyAssignmentId) `
                                -and [string]::IsNullOrWhitespace($description) `
                                -and [string]::IsNullOrWhitespace($assignmentScopeValidation) `
                                -and [string]::IsNullOrWhitespace($resourceSelectors) `
                                -and [string]::IsNullOrWhitespace($policyDefinitionReferenceIds) `
                                -and [string]::IsNullOrWhitespace($metadata)) {
                            #ignore empty lines from CSV
                            # Write-Warning "Ignoring empty line in file"
                            continue
                        }
                    }
                    if ([string]::IsNullOrWhitespace($name)) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "required name missing" -EntryNumber $entryNumber
                    }
                    if ([string]::IsNullOrWhitespace($displayName)) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "required displayName missing" -EntryNumber $entryNumber
                    }
                    if ([string]::IsNullOrWhitespace($exemptionCategory)) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "required exemptionCategory missing" -EntryNumber $entryNumber
                    }
                    else {
                        if ($exemptionCategory -ne "Waiver" -and $exemptionCategory -ne "Mitigated") {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid exemptionCategory '$exemptionCategory' (must be 'Waiver' or 'Mitigated')" -EntryNumber $entryNumber
                        }
                    }
                    if ([string]::IsNullOrWhitespace($scope)) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "required scope missing" -EntryNumber $entryNumber
                    }
                    if ([string]::IsNullOrWhitespace($policyAssignmentId)) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "required policyAssignmentId missing" -EntryNumber $entryNumber
                    }
                    if (-not [string]::IsNullOrWhitespace($description)) {
                        if ($description.Length -gt 1024) {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "description too long (max 1024 characters)" -EntryNumber $entryNumber
                        }
                    }
                    if ([string]::IsNullOrWhitespace($assignmentScopeValidation)) {
                        $assignmentScopeValidation = "Default"
                    }
                    else {
                        if ($assignmentScopeValidation -ne "Default" -and $assignmentScopeValidation -ne "DoNotValidate") {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid assignmentScopeValidation '$assignmentScopeValidation' (must be 'Default' or 'DoNotValidate')" -EntryNumber $entryNumber
                        }
                    }

                    #region Convert complex fields from CSV

                    if ($isXls) {
                        # Convert referenceIds into array (if cell empty, set to empty array)
                        $policyDefinitionReferenceIds = @()
                        $step1 = $row.policyDefinitionReferenceIds
                        if (-not [string]::IsNullOrWhiteSpace($step1)) {
                            $step2 = $step1.Trim()
                            $step3 = $step2 -split ","

                            foreach ($item in $step3) {
                                $step4 = $item.Trim()
                                if ($step4.Length -gt 0) {
                                    $policyDefinitionReferenceIds += $step4
                                }
                            }
                        }

                        # Convert resourceSelectors into array (if cell empty, set to Snull)
                        $resourceSelectors = $null
                        $step1 = $row.resourceSelectors
                        if (-not [string]::IsNullOrWhiteSpace($step1)) {
                            $step2 = $step1.Trim()
                            if ($step2.StartsWith("{") -and (Test-Json $step2)) {
                                $step3 = ConvertFrom-Json $step2 -AsHashTable -Depth 100
                                if ($step3 -ne @{}) {
                                    $resourceSelectors = $step3
                                }
                            }
                            else {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid resourceSelectors format, must be empty or legal JSON: '$step2'" -EntryNumber $entryNumber
                            }
                        }

                        # Convert metadata JSON to object
                        $metadata = $null
                        $step1 = $row.metadata
                        if (-not [string]::IsNullOrWhiteSpace($step1)) {
                            $step2 = $step1.Trim()
                            if ($step2.StartsWith("{") -and (Test-Json $step2)) {
                                $step3 = ConvertFrom-Json $step2 -AsHashTable -Depth 100
                                if ($step3 -ne @{}) {
                                    $metadata = $step3
                                }
                            }
                            else {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid metadata format, must be empty or legal JSON: '$step2'" -EntryNumber $entryNumber
                            }
                        }
                    }

                    $expiresOn = $null
                    $expiresOnRaw = $exemptionRaw.expiresOn
                    if (-not [string]::IsNullOrWhitespace($expiresOnRaw)) {
                        if ($expiresOnRaw -is [datetime]) {
                            $expiresOn = $expiresOnRaw
                        }
                        elseif ($expiresOnRaw -is [string]) {
                            try {
                                $expiresOn = [datetime]::Parse($expiresOnRaw, $null, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                            }
                            catch {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString $_ -EntryNumber $entryNumber
                            }
                        }
                        else {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid expiresOn format, must be empty or a valid date/time: '$expiresOnRaw'" -EntryNumber $entryNumber
                        }
                    }

                    $id = "$scope/providers/Microsoft.Authorization/policyExemptions/$name"
                    if ($allExemptions.ContainsKey($id)) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "duplicate exemption id (name=$name, scope=$scope)" -EntryNumber $entryNumber
                    }
                    else {
                        $allExemptions.Add($id, $true)
                    }

                    if ($errorInfo.hasErrors) {
                        continue
                    }
                    
                    $exemption = [PSCustomObject]@{
                        name                         = $name
                        displayName                  = $displayName
                        description                  = $description
                        exemptionCategory            = $exemptionCategory
                        expiresOn                    = $expiresOn
                        scope                        = $scope
                        policyAssignmentId           = $policyAssignmentId
                        assignmentScopeValidation    = $assignmentScopeValidation
                        resourceSelectors            = $resourceSelectors
                        policyDefinitionReferenceIds = $policyDefinitionReferenceIds
                        metadata                     = $metadata
                    }


                    #region expiresOn

                    $expired = $false
                    $expiresOn = $exemptionRaw.expiresOn
                    if ($null -ne $expiresOn) {
                        $expired = $expiresOn -lt $now
                        $null = $exemption.Add("expiresOn", $expiresOn)
                    }

                    #endregion expiresOn

                    # Filter orphaned and expired Exemptions in definitions; deleteCandidates will delete it from environment if it is still deployed
                    if ($expired) {
                        Write-Warning "Expired exemption (name=$name, scope=$scope) in definitions"
                        continue
                    }
                    if (!$AllAssignments.ContainsKey($policyAssignmentId)) {
                        Write-Warning "Orphaned exemption (name=$name, scope=$scope) in definitions"
                        continue
                    }

                    # Calculate desired state mandated changes
                    if ($deployedManagedExemptions.ContainsKey($id)) {
                        $deleteCandidates.Remove($id)
                        $deployedManagedExemption = $deployedManagedExemptions.$id
                        if ($deployedManagedExemption.policyAssignmentId -ne $policyAssignmentId) {
                            # Replaced Assignment
                            Write-Information "Replace(assignment) '$($name)', '$($scope)'"
                            $null = $Exemptions.replace.Add($id, $exemption)
                            $Exemptions.numberOfChanges++
                        }
                        elseif ($replacedAssignments.ContainsKey($policyAssignmentId)) {
                            # Replaced Assignment
                            Write-Information "Replace(reference) '$($name)', '$($scope)'"
                            $null = $Exemptions.replace.Add($id, $exemption)
                            $Exemptions.numberOfChanges++
                        }
                        else {
                            # Maybe update existing Exemption
                            $displayNameMatches = $deployedManagedExemption.displayName -eq $displayName
                            $descriptionMatches = ($deployedManagedExemption.description -eq $description) `
                                -or ([string]::IsNullOrWhiteSpace($deployedManagedExemption.description) -and [string]::IsNullOrWhiteSpace($description))
                            $exemptionCategoryMatches = $deployedManagedExemption.exemptionCategory -eq $exemptionCategory
                            $expiresOnMatches = $deployedManagedExemption.expiresOn -eq $expiresOn
                            $clearExpiration = $false
                            if (-not $expiresOnMatches) {
                                if ($null -eq $expiresOn) {
                                    $null = $exemption.Add("clearExpiration", $true)
                                    $clearExpiration = $true
                                }
                            }
                            $policyDefinitionReferenceIdsMatches = Confirm-ObjectValueEqualityDeep $deployedManagedExemption.policyDefinitionReferenceIds $policyDefinitionReferenceIds
                            $metadataMatches = Confirm-MetadataMatches `
                                -ExistingMetadataObj $deployedManagedExemption.metadata `
                                -DefinedMetadataObj $metadata
                            $assignmentScopeValidationMatches = ($deployedManagedExemption.assignmentScopeValidation -eq $assignmentScopeValidation) `
                                -or ($null -eq $deployedManagedExemption.assignmentScopeValidation -and ($assignmentScopeValidation -eq "Default" -or $null -eq $assignmentScopeValidation))
                            $resourceSelectorsMatches = Confirm-ObjectValueEqualityDeep $deployedManagedExemption.resourceSelectors $resourceSelectors
                            # Update Exemption in Azure if necessary
                            if ($displayNameMatches -and $descriptionMatches -and $exemptionCategoryMatches -and $expiresOnMatches `
                                    -and $policyDefinitionReferenceIdsMatches -and $metadataMatches -and (-not $clearExpiration) `
                                    -and $assignmentScopeValidationMatches -and $resourceSelectorsMatches) {
                                $Exemptions.numberUnchanged += 1
                            }
                            else {
                                # One or more properties have changed
                                $changesStrings = @()
                                if (!$displayNameMatches) { 
                                    $changesStrings += "displayName"
                                } 
                                if (!$descriptionMatches) { 
                                    $changesStrings += "description" 
                                } 
                                if (!$policyDefinitionReferenceIdsMatches) {
                                    $changesStrings += "referenceIds" 
                                } 
                                if (!$metadataMatches) {
                                    $changesStrings += "metadata" 
                                } 
                                if (!$exemptionCategoryMatches) {
                                    $changesStrings += "exemptionCategory" 
                                } 
                                if ($clearExpiration) { 
                                    $changesStrings += "clearExpiration"
                                } 
                                elseif (!$expiresOnMatches) {
                                    $changesStrings += "expiresOn"
                                }
                                if (!$assignmentScopeValidationMatches) {
                                    $changesStrings += "assignmentScopeValidation"
                                }
                                if (!$resourceSelectorsMatches) {
                                    $changesStrings += "resourceSelectors"
                                }
                                $changesString = $changesStrings -join ","
                                $Exemptions.numberOfChanges++
                                $null = $Exemptions.update.Add($id, $exemption)
                                Write-Information "Update($changesString) '$($name)', '$($scope)'"
                            }
                        }
                    }
                    else {
                        # Create Exemption
                        Write-Information "New '$($name)', '$($scope)'"
                        $null = $Exemptions.new.Add($id, $exemption)
                        $Exemptions.numberOfChanges++
                    }
                }
                if ($errorInfo.hasErrors) {
                    $errorText = Get-ErrorTextFromInfo -ErrorInfo $errorInfo
                    Write-Error $errorText -ErrorAction Continue
                    $numberOfFilesWithErrors++
                    continue
                }

            }
            if ($numberOfFilesWithErrors -gt 0) {
                Write-Error "There were errors in $numberOfFilesWithErrors file(s)." -ErrorAction Stop
            }

            $Exemptions.numberOfOrphans = $DeployedExemptions.orphaned.psbase.Count
            foreach ($exemption in $DeployedExemptions.orphaned.Values) {
                # delete all orphaned exemptions
                Write-Warning "Delete(orphaned) '$($exemption.name)', '$($exemption.scope)'"
                $null = $Exemptions.delete[$exemption.id] = $exemption
                $Exemptions.numberOfChanges++
            }
            $strategy = $PacEnvironment.desiredState.strategy
            foreach ($id in $deleteCandidates.Keys) {
                $exemption = $DeployedExemptions.managed[$id]
                $pacOwner = $exemption.pacOwner
                $shallDelete = Confirm-DeleteForStrategy -PacOwner $pacOwner -Strategy $strategy

                if ($shallDelete) {
                    Write-Information "Delete '$($exemption.name)', '$($exemption.scope)'"
                    $null = $Exemptions.delete[$exemption.id] = $exemption
                    $Exemptions.numberOfChanges++
                }
                else {
                    # Write-Information "No delete($pacOwner,$strategy) '$($exemption.name)', '$($exemption.scope)'"
                }
            }

            Write-Information ""
            if ($Exemptions.numberUnchanged -gt 0) {
                Write-Information "$($Exemptions.numberUnchanged) unchanged Exemptions"
            }
            if ($Exemptions.numberOfOrphans -gt 0) {
                Write-Information "$($Exemptions.numberOfOrphans) orphaned Exemptions"
            }
        }
        Write-Information ""
    }
}
