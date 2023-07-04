function Build-ExemptionsPlan {
    [CmdletBinding()]
    param (
        [string] $exemptionsRootFolder,
        [string] $exemptionsAreNotManagedMessage,
        [hashtable] $pacEnvironment,
        [hashtable] $allAssignments,
        [hashtable] $assignments,
        [hashtable] $deployedExemptions,
        [hashtable] $exemptions
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy Exemption files in folder '$exemptionsRootFolder'"
    Write-Information "==================================================================================================="

    if ($exemptionsAreNotManagedMessage -ne "") {
        Write-Warning $exemptionsAreNotManagedMessage
    }
    else {

        [array] $exemptionFiles = @()
        # Do not manage exemptions if directory does not exist
        $exemptionFiles += Get-ChildItem -Path $exemptionsRootFolder -Recurse -File -Filter "*.json"
        $exemptionFiles += Get-ChildItem -Path $exemptionsRootFolder -Recurse -File -Filter "*.jsonc"
        $exemptionFiles += Get-ChildItem -Path $exemptionsRootFolder -Recurse -File -Filter "*.csv"

        $allExemptions = @{}
        $deployedManagedExemptions = $deployedExemptions.managed
        $deleteCandidates = Get-HashtableShallowClone $deployedManagedExemptions
        $replacedAssignments = $assignments.replace
        if ($exemptionFiles.Length -eq 0) {
            Write-Warning "No Policy Exemption files found."
            Write-Warning "All exemptions will be deleted!"
            Write-Information ""
        }
        else {
            Write-Information "Number of Policy Exemption files = $($exemptionFiles.Length)"
            $now = Get-Date -AsUTC

            [System.Collections.ArrayList] $exemptionArrayList = [System.Collections.ArrayList]::new()
            foreach ($file  in $exemptionFiles) {
                $extension = $file.Extension
                $fullName = $file.FullName
                Write-Information "Processing file '$($fullName)'"
                if ($extension -eq ".json" -or $extension -eq ".jsonc") {
                    $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                    if (!(Test-Json $content)) {
                        Write-Error "Invalid JSON in file $($assignmentFile.FullName)'" -ErrorAction Stop
                    }
                    $jsonObj = ConvertFrom-Json $content -AsHashtable -Depth 100
                    Write-Information ""
                    if ($null -ne $jsonObj) {
                        $jsonExemptions = $jsonObj.exemptions
                        if ($null -ne $jsonExemptions -and $jsonExemptions.Count -gt 0) {
                            $null = $exemptionArrayList.AddRange($jsonExemptions)
                        }
                    }
                }
                elseif ($extension -eq ".csv") {
                    $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                    $xlsExemptionArray = @() + ($content | ConvertFrom-Csv -ErrorAction Stop)
                    # Adjust flat structure from spreadsheets to the almost flat structure in JSON
                    foreach ($row in $xlsExemptionArray) {
                        $policyDefinitionReferenceIds = @()
                        $step1 = $row.policyDefinitionReferenceIds
                        if ($null -ne $step1 -and $step1 -ne "") {
                            $step2 = $step1.Trim()
                            $step3 = $step2 -split ","
                            foreach ($item in $step3) {
                                $step4 = $item.Trim()
                                if ($step4.Length -gt 0) {
                                    $policyDefinitionReferenceIds += $step4
                                }
                            }
                        }
                        $metadata = $null
                        $step1 = $row.metadata
                        if ($null -ne $step1 -and $step1 -ne "") {
                            $step2 = $step1.Trim()
                            if ($step2.StartsWith("{") -and (Test-Json $step2)) {
                                $step3 = ConvertFrom-Json $step2 -AsHashtable -Depth 100
                                if ($step3 -ne @{}) {
                                    $metadata = $step3
                                }
                            }
                            else {
                                Write-Error "  Invalid metadata format, must be empty or legal JSON: '$step2'"
                            }
                        }
                        $assignmentScopeValidation = "Default"
                        if ($null -ne $row.assignmentScopeValidation) {
                            if ($row.assignmentScopeValidation -in ("Default", "DoNotValidate")) {
                                $assignmentScopeValidation = $row.assignmentScopeValidation
                            }
                            else {
                                Write-Error "  Invalid assignmentScopeValidation value, must be 'Default' or 'DoNotValidate': '$($row.assignmentScopeValidation)'"
                            }
                        }
                        $exemption = @{
                            name                         = $row.name
                            displayName                  = $row.displayName
                            description                  = $row.description
                            exemptionCategory            = $row.exemptionCategory
                            expiresOn                    = $row.expiresOn
                            scope                        = $row.scope
                            policyAssignmentId           = $row.policyAssignmentId
                            policyDefinitionReferenceIds = $policyDefinitionReferenceIds
                            metadata                     = $metadata
                            assignmentScopeValidation    = $assignmentScopeValidation
                        }
                        if ($null -ne $row.resourceSelectors) {
                            $exemption.resourceSelectors = $row.resourceSelectors
                        }
                        $null = $exemptionArrayList.Add($exemption)
                    }
                }
            }

            foreach ($exemptionRaw in $exemptionArrayList) {

                # Validate the content,  remove extraneous columns
                $name = $exemptionRaw.name
                $displayName = $exemptionRaw.displayName
                $description = $exemptionRaw.description
                $exemptionCategory = $exemptionRaw.exemptionCategory
                $scope = $exemptionRaw.scope
                $policyAssignmentId = $exemptionRaw.policyAssignmentId
                $policyDefinitionReferenceIds = $exemptionRaw.policyDefinitionReferenceIds
                $metadata = $exemptionRaw.metadata
                $assignmentScopeValidation = $exemptionRaw.assignmentScopeValidation
                if ($null -eq $assignmentScopeValidation) {
                    $assignmentScopeValidation = "Default"
                }
                $resourceSelectors = $exemptionRaw.resourceSelectors
                if (($null -eq $name -or $name -eq '') -or ($null -eq $exemptionCategory -or $exemptionCategory -eq '') -or ($null -eq $scope -or $scope -eq '') -or ($null -eq $policyAssignmentId -or $policyAssignmentId -eq '')) {
                    if (-not (($null -eq $name -or $name -eq '') -and ($null -eq $exemptionCategory -or $exemptionCategory -eq '') `
                                -and ($null -eq $scope -or $scope -eq '') -and ($null -eq $policyAssignmentId -or $policyAssignmentId -eq '') `
                                -and ($null -eq $displayName -or $displayName -eq "") -and ($null -eq $description -or $description -eq "") `
                                -and ($null -eq $expiresOnRaw -or $expiresOnRaw -eq "") -and ($null -eq $metadata) `
                                -and ($null -eq $policyDefinitionReferenceIds -or $policyDefinitionReferenceIds.Count -eq 0))) {
                        #ignore empty lines from CSV
                        Write-Error "  Exemption is missing one or more of required fields name($name), scope($scope) and policyAssignmentId($policyAssignmentId)" -ErrorAction Stop
                    }
                }
                $id = "$scope/providers/Microsoft.Authorization/policyExemptions/$name"
                if ($allExemptions.ContainsKey($id)) {
                    Write-Error "  Duplicate exemption id (name=$name, scope=$scope)" -ErrorAction Stop
                }

                $exemption = @{
                    id                        = $id
                    name                      = $name
                    scope                     = $scope
                    policyAssignmentId        = $policyAssignmentId
                    exemptionCategory         = $exemptionCategory
                    assignmentScopeValidation = $assignmentScopeValidation
                }
                if ($displayName -and $displayName -ne "") {
                    $null = $exemption.Add("displayName", $displayName)
                }
                if ($description -and $description -ne "") {
                    $null = $exemption.Add("description", $description)
                }
                if ($resourceSelectors) {
                    $null = $exemption.Add("resourceSelectors", $resourceSelectors)
                }

                $expiresOn = $null
                $expired = $false
                $expiresOnRaw = $exemptionRaw.expiresOn
                if ($null -ne $expiresOnRaw) {
                    if ($expiresOnRaw -is [datetime]) {
                        $expiresOn = $expiresOnRaw
                    }
                    elseif ($expiresOnRaw -is [string]) {
                        if ($expiresOnRaw -ne "") {
                            try {
                                $expiresOn = [datetime]::Parse($expiresOnRaw, $null, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                            }
                            catch {
                                Write-Error "$_" -ErrorAction Stop
                            }
                        }
                    }
                    else {
                        Write-Error "expiresOn field '$($expiresOnRaw)' is not a recognized type $($expiresOnRaw.GetType().Name)" -ErrorAction Stop
                    }
                }
                if ($null -ne $expiresOn) {
                    $expired = $expiresOn -lt $now
                    $null = $exemption.Add("expiresOn", $expiresOn)
                }

                if ($policyDefinitionReferenceIds -and $policyDefinitionReferenceIds.Count -gt 0) {
                    $null = $exemption.Add("policyDefinitionReferenceIds", $policyDefinitionReferenceIds)
                }
                else {
                    $policyDefinitionReferenceIds = $null
                }
                if ($metadata -and $metadata -ne @{} -and $metadata -ne "") {
                    $null = $exemption.Add("metadata", $metadata)
                }
                else {
                    $metadata = $null
                }

                # Filter orphaned and expired Exemptions in definitions; deleteCandidates will delete it from environment if it is still deployed
                if ($expired) {
                    Write-Warning "Expired exemption (name=$name, scope=$scope) in definitions"
                    continue
                }
                if (!$allAssignments.ContainsKey($policyAssignmentId)) {
                    Write-Warning "Orphaned exemption (name=$name, scope=$scope) in definitions"
                    continue
                }

                # Calculate desired state mandated changes
                $null = $allExemptions.Add($id, $exemption)
                if ($deployedManagedExemptions.ContainsKey($id)) {
                    $deleteCandidates.Remove($id)
                    $deployedManagedExemption = $deployedManagedExemptions.$id
                    if ($deployedManagedExemption.policyAssignmentId -ne $policyAssignmentId) {
                        # Replaced Assignment
                        Write-Information "Replace(assignment) '$($name)', '$($scope)'"
                        $null = $exemptions.replace.Add($id, $exemption)
                        $exemptions.numberOfChanges++
                    }
                    elseif ($replacedAssignments.ContainsKey($policyAssignmentId)) {
                        # Replaced Assignment
                        Write-Information "Replace(reference) '$($name)', '$($scope)'"
                        $null = $exemptions.replace.Add($id, $exemption)
                        $exemptions.numberOfChanges++
                    }
                    else {
                        # Maybe update existing Exemption
                        $displayNameMatches = $deployedManagedExemption.displayName -eq $displayName
                        $descriptionMatches = $deployedManagedExemption.description -eq $description
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
                            -existingMetadataObj $deployedManagedExemption.metadata `
                            -definedMetadataObj $metadata
                        $assignmentScopeValidationMatches = ($deployedManagedExemption.assignmentScopeValidation -eq $assignmentScopeValidation) `
                            -or ($null -eq $deployedManagedExemption.assignmentScopeValidation -and ($assignmentScopeValidation -eq "Default" -or $null -eq $assignmentScopeValidation))
                        $resourceSelectorsMatches = Confirm-ObjectValueEqualityDeep $deployedManagedExemption.resourceSelectors $resourceSelectors
                        # Update Exemption in Azure if necessary
                        if ($displayNameMatches -and $descriptionMatches -and $exemptionCategoryMatches -and $expiresOnMatches `
                                -and $policyDefinitionReferenceIdsMatches -and $metadataMatches -and (-not $clearExpiration) `
                                -and $assignmentScopeValidationMatches -and $resourceSelectorsMatches) {
                            $exemptions.numberUnchanged += 1
                        }
                        else {
                            # One or more properties have changed
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
                            $exemptions.numberOfChanges++
                            $null = $exemptions.update.Add($id, $exemption)
                            Write-Information "Update($changesString) '$($name)', '$($scope)'"
                        }
                    }
                }
                else {
                    # Create Exemption
                    Write-Information "New '$($name)', '$($scope)'"
                    $null = $exemptions.new.Add($id, $exemption)
                    $exemptions.numberOfChanges++
                }
            }
        }

        $exemptions.numberOfOrphans = $deployedExemptions.orphaned.psbase.Count
        foreach ($exemption in $deployedExemptions.orphaned.Values) {
            # delete all orphaned exemptions
            Write-Warning "Delete(orphaned) '$($exemption.name)', '$($exemption.scope)'"
            $null = $exemptions.delete[$exemption.id] = $exemption
            $exemptions.numberOfChanges++
        }
        $strategy = $pacEnvironment.desiredState.strategy
        foreach ($id in $deleteCandidates.Keys) {
            $exemption = $deployedExemptions.managed[$id]
            $pacOwner = $exemption.pacOwner
            $shallDelete = Confirm-DeleteForStrategy -pacOwner $pacOwner -strategy $strategy

            if ($shallDelete) {
                Write-Information "Delete '$($exemption.name)', '$($exemption.scope)'"
                $null = $exemptions.delete[$exemption.id] = $exemption
                $exemptions.numberOfChanges++
            }
            else {
                # Write-Information "No delete($pacOwner,$strategy) '$($exemption.name)', '$($exemption.scope)'"
            }
        }

        Write-Information ""
        if ($exemptions.numberUnchanged -gt 0) {
            Write-Information "$($exemptions.numberUnchanged) unchanged Exemptions"
        }
        if ($exemptions.numberOfOrphans -gt 0) {
            Write-Information "$($exemptions.numberOfOrphans) orphaned Exemptions"
        }
    }
    Write-Information ""
}
