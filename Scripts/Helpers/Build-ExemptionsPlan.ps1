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

    if ($ExemptionsAreNotManagedMessage -ne "") {
        Write-Warning $ExemptionsAreNotManagedMessage
    }
    else {

        [array] $ExemptionFiles = @()
        # Do not manage exemptions if directory does not exist
        $ExemptionFiles += Get-ChildItem -Path $ExemptionsRootFolder -Recurse -File -Filter "*.json"
        $ExemptionFiles += Get-ChildItem -Path $ExemptionsRootFolder -Recurse -File -Filter "*.jsonc"
        $ExemptionFiles += Get-ChildItem -Path $ExemptionsRootFolder -Recurse -File -Filter "*.csv"

        $allExemptions = @{}
        $deployedManagedExemptions = $DeployedExemptions.managed
        $deleteCandidates = Get-HashtableShallowClone $deployedManagedExemptions
        $ReplacedAssignments = $Assignments.replace
        if ($ExemptionFiles.Length -eq 0) {
            Write-Warning "No Policy Exemption files found."
            Write-Warning "All exemptions will be deleted!"
            Write-Information ""
        }
        else {
            Write-Information "Number of Policy Exemption files = $($ExemptionFiles.Length)"
            $now = Get-Date -AsUTC

            [System.Collections.ArrayList] $exemptionArrayList = [System.Collections.ArrayList]::new()
            foreach ($file  in $ExemptionFiles) {
                $extension = $file.Extension
                $fullName = $file.FullName
                Write-Information "Processing file '$($fullName)'"
                if ($extension -eq ".json" -or $extension -eq ".jsonc") {
                    $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                    if (!(Test-Json $content)) {
                        Write-Error "Invalid JSON in file $($AssignmentFile.FullName)'" -ErrorAction Stop
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
                        $PolicyDefinitionReferenceIds = @()
                        $step1 = $row.policyDefinitionReferenceIds
                        if ($null -ne $step1 -and $step1 -ne "") {
                            $step2 = $step1.Trim()
                            $step3 = $step2 -split ","
                            foreach ($item in $step3) {
                                $step4 = $item.Trim()
                                if ($step4.Length -gt 0) {
                                    $PolicyDefinitionReferenceIds += $step4
                                }
                            }
                        }
                        $Metadata = $null
                        $step1 = $row.metadata
                        if ($null -ne $step1 -and $step1 -ne "") {
                            $step2 = $step1.Trim()
                            if ($step2.StartsWith("{") -and (Test-Json $step2)) {
                                $step3 = ConvertFrom-Json $step2 -AsHashtable -Depth 100
                                if ($step3 -ne @{}) {
                                    $Metadata = $step3
                                }
                            }
                            else {
                                Write-Error "  Invalid metadata format, must be empty or legal JSON: '$step2'"
                            }
                        }
                        $AssignmentscopeValidation = "Default"
                        if ($null -ne $row.assignmentScopeValidation) {
                            if ($row.assignmentScopeValidation -in ("Default", "DoNotValidate")) {
                                $AssignmentscopeValidation = $row.assignmentScopeValidation
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
                            policyDefinitionReferenceIds = $PolicyDefinitionReferenceIds
                            metadata                     = $Metadata
                            assignmentScopeValidation    = $AssignmentscopeValidation
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
                $Name = $exemptionRaw.name
                $DisplayName = $exemptionRaw.displayName
                $description = $exemptionRaw.description
                $exemptionCategory = $exemptionRaw.exemptionCategory
                $Scope = $exemptionRaw.scope
                $PolicyAssignmentId = $exemptionRaw.policyAssignmentId
                $PolicyDefinitionReferenceIds = $exemptionRaw.policyDefinitionReferenceIds
                $Metadata = $exemptionRaw.metadata
                $AssignmentscopeValidation = $exemptionRaw.assignmentScopeValidation
                if ($null -eq $AssignmentscopeValidation) {
                    $AssignmentscopeValidation = "Default"
                }
                $resourceSelectors = $exemptionRaw.resourceSelectors
                if (($null -eq $Name -or $Name -eq '') -or ($null -eq $exemptionCategory -or $exemptionCategory -eq '') -or ($null -eq $Scope -or $Scope -eq '') -or ($null -eq $PolicyAssignmentId -or $PolicyAssignmentId -eq '')) {
                    if (-not (($null -eq $Name -or $Name -eq '') -and ($null -eq $exemptionCategory -or $exemptionCategory -eq '') `
                                -and ($null -eq $Scope -or $Scope -eq '') -and ($null -eq $PolicyAssignmentId -or $PolicyAssignmentId -eq '') `
                                -and ($null -eq $DisplayName -or $DisplayName -eq "") -and ($null -eq $description -or $description -eq "") `
                                -and ($null -eq $expiresOnRaw -or $expiresOnRaw -eq "") -and ($null -eq $Metadata) `
                                -and ($null -eq $PolicyDefinitionReferenceIds -or $PolicyDefinitionReferenceIds.Count -eq 0))) {
                        #ignore empty lines from CSV
                        Write-Error "  Exemption is missing one or more of required fields name($Name), scope($Scope) and policyAssignmentId($PolicyAssignmentId)" -ErrorAction Stop
                    }
                }
                $Id = "$Scope/providers/Microsoft.Authorization/policyExemptions/$Name"
                if ($allExemptions.ContainsKey($Id)) {
                    Write-Error "  Duplicate exemption id (name=$Name, scope=$Scope)" -ErrorAction Stop
                }

                $exemption = @{
                    id                        = $Id
                    name                      = $Name
                    scope                     = $Scope
                    policyAssignmentId        = $PolicyAssignmentId
                    exemptionCategory         = $exemptionCategory
                    assignmentScopeValidation = $AssignmentscopeValidation
                }
                if ($DisplayName -and $DisplayName -ne "") {
                    $null = $exemption.Add("displayName", $DisplayName)
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

                if ($PolicyDefinitionReferenceIds -and $PolicyDefinitionReferenceIds.Count -gt 0) {
                    $null = $exemption.Add("policyDefinitionReferenceIds", $PolicyDefinitionReferenceIds)
                }
                else {
                    $PolicyDefinitionReferenceIds = $null
                }
                if ($Metadata -and $Metadata -ne @{} -and $Metadata -ne "") {
                    $null = $exemption.Add("metadata", $Metadata)
                }
                else {
                    $Metadata = $null
                }

                # Filter orphaned and expired Exemptions in definitions; deleteCandidates will delete it from environment if it is still deployed
                if ($expired) {
                    Write-Warning "Expired exemption (name=$Name, scope=$Scope) in definitions"
                    continue
                }
                if (!$AllAssignments.ContainsKey($PolicyAssignmentId)) {
                    Write-Warning "Orphaned exemption (name=$Name, scope=$Scope) in definitions"
                    continue
                }

                # Calculate desired state mandated changes
                $null = $allExemptions.Add($Id, $exemption)
                if ($deployedManagedExemptions.ContainsKey($Id)) {
                    $deleteCandidates.Remove($Id)
                    $deployedManagedExemption = $deployedManagedExemptions.$Id
                    if ($deployedManagedExemption.policyAssignmentId -ne $PolicyAssignmentId) {
                        # Replaced Assignment
                        Write-Information "Replace(assignment) '$($Name)', '$($Scope)'"
                        $null = $Exemptions.replace.Add($Id, $exemption)
                        $Exemptions.numberOfChanges++
                    }
                    elseif ($ReplacedAssignments.ContainsKey($PolicyAssignmentId)) {
                        # Replaced Assignment
                        Write-Information "Replace(reference) '$($Name)', '$($Scope)'"
                        $null = $Exemptions.replace.Add($Id, $exemption)
                        $Exemptions.numberOfChanges++
                    }
                    else {
                        # Maybe update existing Exemption
                        $DisplayNameMatches = $deployedManagedExemption.displayName -eq $DisplayName
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
                        $PolicyDefinitionReferenceIdsMatches = Confirm-ObjectValueEqualityDeep $deployedManagedExemption.policyDefinitionReferenceIds $PolicyDefinitionReferenceIds
                        $MetadataMatches = Confirm-MetadataMatches `
                            -ExistingMetadataObj $deployedManagedExemption.metadata `
                            -DefinedMetadataObj $Metadata
                        $AssignmentscopeValidationMatches = ($deployedManagedExemption.assignmentScopeValidation -eq $AssignmentscopeValidation) `
                            -or ($null -eq $deployedManagedExemption.assignmentScopeValidation -and ($AssignmentscopeValidation -eq "Default" -or $null -eq $AssignmentscopeValidation))
                        $resourceSelectorsMatches = Confirm-ObjectValueEqualityDeep $deployedManagedExemption.resourceSelectors $resourceSelectors
                        # Update Exemption in Azure if necessary
                        if ($DisplayNameMatches -and $descriptionMatches -and $exemptionCategoryMatches -and $expiresOnMatches `
                                -and $PolicyDefinitionReferenceIdsMatches -and $MetadataMatches -and (-not $clearExpiration) `
                                -and $AssignmentscopeValidationMatches -and $resourceSelectorsMatches) {
                            $Exemptions.numberUnchanged += 1
                        }
                        else {
                            # One or more properties have changed
                            if (!$DisplayNameMatches) { 
                                $changesStrings += "displayName"
                            } 
                            if (!$descriptionMatches) { 
                                $changesStrings += "description" 
                            } 
                            if (!$PolicyDefinitionReferenceIdsMatches) {
                                $changesStrings += "referenceIds" 
                            } 
                            if (!$MetadataMatches) {
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
                            if (!$AssignmentscopeValidationMatches) {
                                $changesStrings += "assignmentScopeValidation"
                            }
                            if (!$resourceSelectorsMatches) {
                                $changesStrings += "resourceSelectors"
                            }
                            $changesString = $changesStrings -join ","
                            $Exemptions.numberOfChanges++
                            $null = $Exemptions.update.Add($Id, $exemption)
                            Write-Information "Update($changesString) '$($Name)', '$($Scope)'"
                        }
                    }
                }
                else {
                    # Create Exemption
                    Write-Information "New '$($Name)', '$($Scope)'"
                    $null = $Exemptions.new.Add($Id, $exemption)
                    $Exemptions.numberOfChanges++
                }
            }
        }

        $Exemptions.numberOfOrphans = $DeployedExemptions.orphaned.psbase.Count
        foreach ($exemption in $DeployedExemptions.orphaned.Values) {
            # delete all orphaned exemptions
            Write-Warning "Delete(orphaned) '$($exemption.name)', '$($exemption.scope)'"
            $null = $Exemptions.delete[$exemption.id] = $exemption
            $Exemptions.numberOfChanges++
        }
        $Strategy = $PacEnvironment.desiredState.strategy
        foreach ($Id in $deleteCandidates.Keys) {
            $exemption = $DeployedExemptions.managed[$Id]
            $PacOwner = $exemption.pacOwner
            $shallDelete = Confirm-DeleteForStrategy -PacOwner $PacOwner -Strategy $Strategy

            if ($shallDelete) {
                Write-Information "Delete '$($exemption.name)', '$($exemption.scope)'"
                $null = $Exemptions.delete[$exemption.id] = $exemption
                $Exemptions.numberOfChanges++
            }
            else {
                # Write-Information "No delete($PacOwner,$Strategy) '$($exemption.name)', '$($exemption.scope)'"
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
