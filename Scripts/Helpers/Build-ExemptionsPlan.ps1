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
                    try {
                        $jsonObj = ConvertFrom-Json $content -AsHashTable -Depth 100
                    }
                    catch {
                        Write-Error "Assignment JSON file '$($fullName)' is not valid." -ErrorAction Stop
                    }
                    Write-Information ""
                    if ($null -ne $jsonObj) {
                        $jsonExemptions = $jsonObj.exemptions
                        if ($null -ne $jsonExemptions -and $jsonExemptions.Count -gt 0) {
                            $exemptionsArray += $jsonExemptions
                        }
                    }

                }
                elseif ($extension -eq ".csv") {
                    $isXls = $true
                    $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                    $xlsExemptions = ($content | ConvertFrom-Csv -ErrorAction Stop)
                    if ($xlsExemptions.Count -gt 0) {
                        $exemptionsArray += $xlsExemptions
                    }
                }

                $exemptionsNamesArray = @()
                foreach ($item in $exemptionsArray) {
                    $exemptionsNamesArray += $item.name
                }

                #endregion read each file

                #region validate file contents

                if ($errorInfo.hasErrors) {
                    continue
                }
                    
                $entryNumber = $isXls ? 1 : 0
                foreach ($row in $exemptionsArray) {

                    #region read and validate each row

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
                    if (-not (Confirm-ValidPolicyResourceName -Name $name)) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "name '$name' contains invalid charachters <>*%&:?.+/ or ends with a space." -EntryNumber $entryNumber
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
                    #Should add a check that name does not contain & or potentially any special characters.
                    if ([string]::IsNullOrWhitespace($assignmentScopeValidation)) {
                        $assignmentScopeValidation = "Default"
                    }
                    else {
                        if ($assignmentScopeValidation -ne "Default" -and $assignmentScopeValidation -ne "DoNotValidate") {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid assignmentScopeValidation '$assignmentScopeValidation' (must be 'Default' or 'DoNotValidate')" -EntryNumber $entryNumber
                        }
                    }

                    #endregion read and validate each row

                    #region Convert complex fields from CSV

                    if ($isXls) {
                        # Convert referenceIds into array (if cell empty, set to empty array)
                        $final = @()
                        $step1 = $policyDefinitionReferenceIds
                        if (-not [string]::IsNullOrWhiteSpace($step1)) {
                            $step2 = $step1.Trim()
                            $step3 = $step2 -split ","
                            foreach ($item in $step3) {
                                $step4 = $item.Trim()
                                if ($step4.Length -gt 0) {
                                    $final += $step4
                                }
                            }
                        }
                        $policyDefinitionReferenceIds = $final

                        # Convert resourceSelectors into array (if cell empty, set to Snull)
                        $resourceSelectors = $null
                        $step1 = $row.resourceSelectors
                        if (-not [string]::IsNullOrWhiteSpace($step1)) {
                            $step2 = $step1.Trim()      
                            if ($step2.StartsWith("{")) {
                                try {
                                    $step3 = ConvertFrom-Json $step2 -AsHashTable -Depth 100 -NoEnumerate
                                }
                                catch {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid resourceSelectors format, must be empty or legal JSON: '$step2'" -EntryNumber $entryNumber
                                }
                                if ($step3 -ne @{}) {
                                    $resourceSelectors = $step3
                                }
                            }
                        }

                        # Convert metadata JSON to object
                        $metadata = $null
                        $step1 = $row.metadata
                        if (-not [string]::IsNullOrWhiteSpace($step1)) {
                            $step2 = $step1.Trim()
                            if ($step2.StartsWith("{")) {
                                try {
                                    $step3 = ConvertFrom-Json $step2 -AsHashTable -Depth 100
                                }
                                catch {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid metadata format, must be empty or legal JSON: '$step2'" -EntryNumber $entryNumber
                                }
                                if ($step3 -ne @{}) {
                                    $metadata = $step3
                                }
                            }
                        }
                        else {
                            $metadata = $null
                        }
                    }

                    #endregion Convert complex fields from CSV

                    #region calculate expiresOn

                    $expiresOn = $null
                    $expired = $false
                    $expiresOnRaw = $row.expiresOn
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
                        if ($expiresOn) {
                            $expired = $expiresOn -lt $now
                        }
                    }

                    #endregion calculate expiresOn

                    #region create $exemption

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
                    
                    if ($metadata) {
                        $metadata.pacOwnerId = $PacEnvironment.pacOwnerId
                    }
                    else {
                        $metadata = @{
                            pacOwnerId = $PacEnvironment.pacOwnerId
                        }
                    }
                    $exemption = [PSCustomObject]@{
                        id                           = $id
                        name                         = $name
                        displayName                  = $displayName
                        description                  = $description
                        exemptionCategory            = $exemptionCategory
                        expiresOn                    = $expiresOn
                        scope                        = $scope
                        policyAssignmentId           = $policyAssignmentId
                        assignmentScopeValidation    = $assignmentScopeValidation
                        policyDefinitionReferenceIds = $policyDefinitionReferenceIds
                        resourceSelectors            = $resourceSelectors
                        metadata                     = $metadata
                    }

                    #endregion create $exemption

                    #region expired and orphaned in definitions

                    $deleteExpired = $PacEnvironment.desiredState.deleteExpiredExemptions
                    $deleteOrphaned = $PacEnvironment.desiredState.deleteOrphanedExemptions
                    $deployedManagedExemption = $null
                    if ($deployedManagedExemptions.ContainsKey($id)) {
                        $deployedManagedExemption = $deployedManagedExemptions.$id
                        # Filter orphaned and expired Exemptions in definitions; deleteCandidates will delete it from environment if it is still deployed
                        if (!$AllAssignments.ContainsKey($policyAssignmentId) -and $deleteOrphaned -eq $false) {
                            Write-Warning "Orphaned exemption (name=$name, scope=$scope) in definitions"
                            $deployedManagedExemption.pacOwner = "thisPac"
                            $deployedManagedExemptions.status = "orphaned"
                            continue
                        }
                        if ($expired -and $deleteExpired -eq $false) {
                            Write-Warning "Expired exemption (name=$name, scope=$scope) in definitions"
                            if ($deployedManagedExemption.status -ne "orphaned") {
                                $deployedManagedExemption.pacOwner = "thisPac"
                                $deployedManagedExemption.status = "expired"
                            }
                            continue
                        }
                        if (($deleteExpired -and $expired ) -or ($deleteOrphaned -and !$AllAssignments.ContainsKey($policyAssignmentId))) {
                            continue
                        }
                    }
                    else {
                        if (!$AllAssignments.ContainsKey($policyAssignmentId) -and $deleteOrphaned) {
                            Write-Warning "Orphaned exemption (name=$name, scope=$scope) in definitions"
                            continue
                        }
                        if ($expired -and $deleteExpired) {
                            Write-Warning "Expired exemption (name=$name, scope=$scope) in definitions"
                            continue
                        }
                        if (($DeleteExpired -eq $false -and $expired ) -or ($DeleteOrphaned -eq $false -and !$AllAssignments.ContainsKey($policyAssignmentId))) {
                            continue
                        }
                    }

                    #endregion expired and orphaned in definitions

                    #region calculate desired state mandated changes

                    if ($deployedManagedExemption) {
                        $deleteCandidates.Remove($id)
                        if ($deployedManagedExemption.policyAssignmentId -ne $policyAssignmentId) {
                            # Replaced Assignment
                            Write-Information "Replace(assignmentId changed) '$($name)', '$($scope)'"
                            $null = $Exemptions.replace.Add($id, $exemption)
                            $Exemptions.numberOfChanges++
                        }
                        elseif ($replacedAssignments.ContainsKey($policyAssignmentId)) {
                            # Replaced Assignment
                            Write-Information "Replace(replaced assignment) '$($name)', '$($scope)'"
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
                                    $exemption.clearExpiration = $true
                                    $clearExpiration = $true
                                }
                            }
                            $policyDefinitionReferenceIdsMatches = Confirm-ObjectValueEqualityDeep $deployedManagedExemption.policyDefinitionReferenceIds $policyDefinitionReferenceIds
                            $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                                -ExistingMetadataObj $deployedManagedExemption.metadata `
                                -DefinedMetadataObj $metadata
                            $assignmentScopeValidationMatches = ($deployedManagedExemption.assignmentScopeValidation -eq $assignmentScopeValidation) `
                                -or ($null -eq $deployedManagedExemption.assignmentScopeValidation -and ($assignmentScopeValidation -eq "Default"))
                            $resourceSelectorsMatches = Confirm-ObjectValueEqualityDeep $deployedManagedExemption.resourceSelectors $resourceSelectors
                            # Update Exemption in Azure if necessary
                            if ($displayNameMatches -and $descriptionMatches -and $exemptionCategoryMatches -and $expiresOnMatches `
                                    -and $policyDefinitionReferenceIdsMatches -and $metadataMatches -and !$changePacOwnerId -and !$clearExpiration `
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
                                    $changesStrings += "policyDefinitionReferenceIds" 
                                }
                                if ($changePacOwnerId) {
                                    $changesStrings += "owner"
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

                    #endregion calculate desired state mandated changes
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

            #region delete removed, orphaned and expired exemptions
                
            $strategy = $PacEnvironment.desiredState.strategy
            foreach ($id in $deleteCandidates.Keys) {
                $exemption = $deleteCandidates.$id
                $pacOwner = $exemption.pacOwner
                $status = $exemption.status
                if ($deleteExpired -eq $false -or $deleteOrphaned -eq $false) {
                    $currentExemptionName = $exemption.name
                    $removed = $false
                    if ($currentExemptionName -notin $exemptionsNamesArray -and ($status -ne "orphaned" -and $status -ne "expired")) {
                        $removed = $true
                    }
                }
                if ($null -eq $exemption.metadata.pacOwnerId -and $PacEnvironment.desiredState.strategy -eq "ownedOnly") {
                    $shallDelete = $false
                }
                else {
                    $shallDelete = Confirm-DeleteForStrategy -PacOwner $pacOwner `
                        -Strategy $strategy `
                        -Status $status `
                        -DeleteExpired $deleteExpired `
                        -DeleteOrphaned $deleteOrphaned `
                        -Removed $removed
                }

                if ($shallDelete) {
                    switch ($status) {
                        orphaned { 
                            $Exemptions.numberOfOrphans++
                        }
                        expired { 
                            $Exemptions.numberOfExpired++
                        }
                    }
                    Write-Information "Delete '$($exemption.name)', '$($exemption.scope)'"
                    $null = $Exemptions.delete[$exemption.id] = $exemption
                    $Exemptions.numberOfChanges++
                }
                else {
                    Write-Verbose "No delete($pacOwner,$strategy) '$($exemption.name)', '$($exemption.scope)'"
                }
            }

            #endregion delete removed, orphaned and expired exemptions

            Write-Information ""
            if ($Exemptions.numberUnchanged -gt 0) {
                Write-Information "$($Exemptions.numberUnchanged) unchanged Exemptions"
            }
        }
        Write-Information ""
    }
}
