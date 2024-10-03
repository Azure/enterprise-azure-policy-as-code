function Build-ExemptionsPlan {
    [CmdletBinding()]
    param (
        [string] $ExemptionsRootFolder,
        [string] $ExemptionsAreNotManagedMessage,
        $PacEnvironment,
        $ScopeTable,
        $AllDefinitions,
        $AllAssignments,
        $CombinedPolicyDetails,
        $Assignments,
        $DeployedExemptions,
        $Exemptions,
        [switch]$SkipNotScopedExemptions
    )

    Write-Information "==================================================================================================="
    Write-Information "Processing Policy Exemption files in folder '$ExemptionsRootFolder'"
    Write-Information "==================================================================================================="

    #region read files and cache data structures
    [array] $exemptionFiles = @()
    $exemptionFiles += Get-ChildItem -Path $ExemptionsRootFolder -Recurse -File -Filter "*.json"
    $exemptionFiles += Get-ChildItem -Path $ExemptionsRootFolder -Recurse -File -Filter "*.jsonc"
    $exemptionFiles += Get-ChildItem -Path $ExemptionsRootFolder -Recurse -File -Filter "*.csv"

    $uniqueIds = @{}
    $deployedManagedExemptions = $DeployedExemptions.managed
    $deleteCandidates = $deployedManagedExemptions.Clone()
    $replacedAssignments = $Assignments.replace
    $numberOfFilesWithErrors = 0
    $desiredState = $PacEnvironment.desiredState
    $desiredStateStrategy = $desiredState.strategy
    $resourceIdsBySubscriptionId = @{}
    $validateResources = -not $PacEnvironment.skipResourceValidationForExemptions

    $now = Get-Date -AsUTC
    #endregion read files and cache data structures

    if ($exemptionFiles.Length -eq 0) {
        Write-Warning "No Policy Exemption files found."
        Write-Warning "All exemptions will be deleted!"
        Write-Information ""
    }
    else {
        Write-Information "Number of Policy Exemption files = $($exemptionFiles.Length)"

        #region pre-calculate assignments
        $sortedAssignments = $AllAssignments.Values | Sort-Object -Property id # for a stable order
        $calculatedResult = Get-CalculatedPolicyAssignmentsAndReferenceIds `
            -Assignments $sortedAssignments `
            -CombinedPolicyDetails $CombinedPolicyDetails
        $byAssignmentIdCalculatedAssignments = $calculatedResult.byAssignmentIdCalculatedAssignments
        $byPolicySetIdCalculatedAssignments = $calculatedResult.byPolicySetIdCalculatedAssignments
        $byPolicyIdCalculatedAssignments = $calculatedResult.byPolicyIdCalculatedAssignments
        #endregion pre-calculate assignments
        
        #region process each file
        foreach ($file  in $exemptionFiles) {

            #region read each file
            $extension = $file.Extension
            $fullName = $file.FullName
            # $fileName = $file.Name
            Write-Information ""
            Write-Information "---------------------------------------------------------------------------------------------------"
            Write-Information "Processing file '$($fullName)'"
            Write-Information "---------------------------------------------------------------------------------------------------"
            $errorInfo = New-ErrorInfo -FileName $fullName
            $exemptionsArray = [System.Collections.ArrayList]::new()
            $isCsvFile = $false
            if ($extension -eq ".json" -or $extension -eq ".jsonc") {
                $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                try {
                    $jsonObj = ConvertFrom-Json $content -AsHashTable -Depth 100
                }
                catch {
                    throw "Assignment JSON file '$($fullName)' is not valid."
                }
                Write-Information ""
                if ($null -ne $jsonObj) {
                    $jsonExemptions = $jsonObj.exemptions
                    if ($null -ne $jsonExemptions -and $jsonExemptions.Count -gt 0) {
                        $null = $exemptionsArray.AddRange($jsonExemptions)
                    }
                }
            }
            elseif ($extension -eq ".csv") {
                $isCsvFile = $true
                $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                $xlsExemptions = ($content | ConvertFrom-Csv -ErrorAction Stop)
                if ($null -ne $xlsExemptions) {
                    if ($xlsExemptions -isnot [array]) {
                        $xlsExemptions = @($xlsExemptions)
                    }
                    if ($xlsExemptions.Count -gt 0) {
                        $null = $exemptionsArray.AddRange($xlsExemptions)
                    }
                }
            }
            #endregion read each file

            #region process each row
            $entryNumber = $isCsvFile ? 1 : -1
            foreach ($row in $exemptionsArray) {
                $errorInfo.hasLocalErrors = $false
                $entryNumber++

                #region read row values and skip empty rows on CSV files
                $name = $row.name
                $displayName = $row.displayName
                $exemptionCategory = $row.exemptionCategory
                $scope = $row.scope
                $scopes = $row.scopes
                $expiresOnRaw = $row.expiresOn
                $policyAssignmentId = $row.policyAssignmentId
                $policyDefinitionName = $row.policyDefinitionName
                $policyDefinitionId = $row.policyDefinitionId
                $policySetDefinitionName = $row.policySetDefinitionName
                $policySetDefinitionId = $row.policySetDefinitionId
                $assignmentReferenceId = $row.assignmentReferenceId
                $description = $row.description
                $assignmentScopeValidation = $row.assignmentScopeValidation
                $resourceSelectors = $row.resourceSelectors
                $policyDefinitionReferenceIds = $row.policyDefinitionReferenceIds
                $metadata = @{}
                if ($isCsvFile) {
                    if ([string]::IsNullOrWhitespace($name) `
                            -and [string]::IsNullOrWhitespace($displayName) `
                            -and [string]::IsNullOrWhitespace($exemptionCategory) `
                            -and [string]::IsNullOrWhitespace($scope) `
                            -and [string]::IsNullOrWhitespace($policyAssignmentId) `
                            -and [string]::IsNullOrWhitespace($assignmentReferenceId) `
                            -and [string]::IsNullOrWhitespace($description) `
                            -and [string]::IsNullOrWhitespace($assignmentScopeValidation) `
                            -and [string]::IsNullOrWhitespace($resourceSelectors) `
                            -and [string]::IsNullOrWhitespace($policyDefinitionReferenceIds) `
                            -and [string]::IsNullOrWhitespace($metadata)) {
                        #ignore empty lines from CSV
                        # Write-Warning "Ignoring empty row $entryNumber"
                        continue
                    }
                }
                #endregion read row values and skip empty rows on CSV files

                if ($isCsvFile) {

                    #region CSV files can define the assignment with assignmentReferenceId or the legacy policyAssignmentId
                    if ([string]::IsNullOrWhitespace($assignmentReferenceId) -xor [string]::IsNullOrWhitespace($policyAssignmentId)) {
                        if (-not [string]::IsNullOrWhitespace($assignmentReferenceId)) {
                            if ($assignmentReferenceId.StartsWith("policyDefinitions/")) {
                                $splits = $assignmentReferenceId -split "/"
                                $policyDefinitionName = $splits[1]
                            }
                            elseif ($assignmentReferenceId.Contains("/providers/Microsoft.Authorization/policyDefinitions/")) {
                                $policyDefinitionId = $assignmentReferenceId
                            }
                            elseif ($assignmentReferenceId.StartsWith("policySetDefinitions/")) {
                                $splits = $assignmentReferenceId -split "/"
                                $policySetDefinitionName = $splits[1]
                            }
                            elseif ($assignmentReferenceId.Contains("/providers/Microsoft.Authorization/policySetDefinitions/")) {
                                $policySetDefinitionId = $assignmentReferenceId
                            }
                            elseif ($assignmentReferenceId.Contains("/providers/Microsoft.Authorization/policyAssignments/")) {
                                $policyAssignmentId = $assignmentReferenceId
                            }
                            else {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "assignmentReferenceId '$assignmentReferenceId' of unknown type" -EntryNumber $entryNumber
                            }
                        }
                    }
                    else {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "exactly one of the columns policyAssignmentId or assignmentReferenceId must have a non-empty cell" -EntryNumber $entryNumber
                    }
                    #endregion CSV files can define the assignment with assignmentReferenceId or the legacy policyAssignmentId

                    #region Convert referenceIds into array (if cell empty, set to empty array)
                    $final = @()
                    $step1 = $policyDefinitionReferenceIds
                    if (-not [string]::IsNullOrWhiteSpace($step1)) {
                        $step2 = $step1.Trim()
                        $step3 = $step2 -split "&"
                        foreach ($item in $step3) {
                            $step4 = $item.Trim()
                            if ($step4.Length -gt 0) {
                                $final += $step4
                            }
                        }
                    }
                    $policyDefinitionReferenceIds = $final
                    #endregion Convert referenceIds into array (if cell empty, set to empty array)

                    #region table must contain scope or scopes column
                    if (([string]::IsNullOrWhitespace($scope) -xor [string]::IsNullOrWhitespace($scopes))) {
                        if ([string]::IsNullOrWhitespace($scope)) {
                            $scopes = $scopes -split "&"
                        }
                    }
                    else {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "exactly one of the columns scope or scopes is required" -EntryNumber $entryNumber
                    }
                    #endregion table must contain scope or scopes column

                    #region Convert resourceSelectors into array (if cell empty, set to $null)
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
                    #endregion Convert resourceSelectors into array (if cell empty, set to $null)

                    #region convert metadata JSON to object
                    $step1 = $row.metadata
                    if (-not [string]::IsNullOrWhiteSpace($step1)) {
                        $step2 = $step1.Trim()
                        if ($step2.StartsWith("{") -and $step2.EndsWith("}")) {
                            $maybeEmpty = ($step2 -replace "[\s{}]", "")
                            if ($maybeEmpty.Length -gt 0) {
                                try {
                                    $step3 = ConvertFrom-Json $step2 -AsHashTable -Depth 100
                                    if ($step3 -ne @{}) {
                                        $metadata = $step3
                                    }
                                }
                                catch {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid metadata format, must be empty or legal JSON: '$step2'" -EntryNumber $entryNumber
                                }
                            }
                        }
                        else {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid metadata format, must be empty or legal JSON: '$step2'" -EntryNumber $entryNumber
                        }
                    }
                    #endregion convert metadata JSON to object
                }
                else {

                    #region JSON files require exactly one field from set @(policyAssignmentId,policyDefinitionName,policyDefinitionId)
                    $numberOfDefinedfields = 0
                    $allowedFields = @("policyAssignmentId", "policyDefinitionName", "policyDefinitionId", "policySetDefinitionName", "policySetDefinitionId")
                    foreach ($field in $allowedFields) {
                        if ($null -ne $row.$field) {
                            $numberOfDefinedfields++
                        }
                    }
                    if ($numberOfDefinedfields -ne 1) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "exactly one of the fields policyAssignmentId, policyDefinitionName, policyDefinitionId, policySetDefinitionName, policySetDefinitionId is required" -EntryNumber $entryNumber
                    }
                    if (-not ([string]::IsNullOrWhitespace($scope) -xor [string]::IsNullOrWhitespace($scopes))) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "exactly one of the fields scope or scopes is required" -EntryNumber $entryNumber
                    }
                    elseif ([string]::IsNullOrWhitespace($scope)) {
                        if ($scopes -isnot [array]) {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "scopes must be an array of strings" -EntryNumber $entryNumber
                        }
                        else {
                            foreach ($currentScope in $scopes) {
                                if ($currentScope -isnot [string]) {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "scopes must be an array of strings" -EntryNumber $entryNumber
                                    break
                                }
                            }
                        }
                    }
                    else {
                        if ($scope -isnot [string]) {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "scope must be a string" -EntryNumber $entryNumber
                        }
                    }

                    if ($null -ne $row.metadata) {
                        if ($row.metadata -isnot [hashtable]) {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "metadata must be a hashtable" -EntryNumber $entryNumber
                        }
                        else {
                            $metadata = $row.metadata
                        }
                    }
                    #endregion JSON files require exactly one field from set @(policyAssignmentId,policyDefinitionName,policyDefinitionId,policySetDefinitionName,policySetDefinitionId)
                }

                #region retrieve pre-calculated Assignments
                if ([string]::IsNullOrWhitespace($assignmentScopeValidation)) {
                    $assignmentScopeValidation = "Default"
                }
                else {
                    if ($assignmentScopeValidation -ne "Default" -and $assignmentScopeValidation -ne "DoNotValidate") {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid assignmentScopeValidation '$assignmentScopeValidation' (must be 'Default' or 'DoNotValidate')" -EntryNumber $entryNumber
                    }
                }
                $validateScope = $assignmentScopeValidation -eq "Default"
                $unValidatedPolicyAssignment = $false
                $calculatedPolicyAssignments = @()
                $epacMetadataDefinitionSpecification = @{}
                if (!$validateScope) {
                    if ($null -eq $policyAssignmentId) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "DoNotValidate (assignmentScopeValidation) is only valid when policyAssignmentId is specified." -EntryNumber $entryNumber
                    }
                    else {
                        $epacMetadataDefinitionSpecification.policyAssignmentId = $policyAssignmentId
                        $calculatedPolicyAssignments = $byAssignmentIdCalculatedAssignments.$policyAssignmentId
                        if ($null -eq $calculatedPolicyAssignments -or $calculatedPolicyAssignments.Count -eq 0) {
                            $unValidatedPolicyAssignment = $true
                            $calculatedPolicyAssignment = @{
                                id                           = $policyAssignmentId
                                name                         = $policyAssignmentId
                                scope                        = ""
                                notScopes                    = @()
                                policyDefinitionReferenceIds = @()
                                perPolicyReferenceIdTable    = @{}
                                allowReferenceIdsInRow       = $true
                                isPolicyAssignment           = $true
                        
                            }
                            $calculatedPolicyAssignments = @($calculatedPolicyAssignment)
                        }
                    }
                }
                else {
                    if ($null -ne $policyAssignmentId) {
                        $epacMetadataDefinitionSpecification.policyAssignmentId = $policyAssignmentId
                        if ($AllAssignments.ContainsKey($policyAssignmentId)) {
                            $calculatedPolicyAssignments = $byAssignmentIdCalculatedAssignments.$policyAssignmentId
                            if ($null -eq $calculatedPolicyAssignments -or $calculatedPolicyAssignments.Count -eq 0) {
                                $calculatedPolicyAssignments = @()
                                Write-Warning "Row $($entryNumber): No assignment found for policyAssignmentId '$policyAssignmentId', skipping row"
                            }
                        }
                        else {
                            Write-Warning "Row $($entryNumber): policyAssignmentId '$policyAssignmentId' not found in current root scope $($PacEnvironment.deploymentRootScope), skipping row"
                        }
                    }
                    elseif ($null -ne $policyDefinitionName) {
                        $epacMetadataDefinitionSpecification.policyDefinitionName = $policyDefinitionName
                        $policyDefinitionId = Confirm-PolicyDefinitionUsedExists `
                            -Name $policyDefinitionName `
                            -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                            -AllDefinitions $AllDefinitions.policydefinitions
                        if ($null -eq $policyDefinitionId) {
                            Write-Warning "Row $($entryNumber): policyDefinitionName '$policyDefinitionName' not found in current root scope $($PacEnvironment.deploymentRootScope), skipping row"
                        }
                        else {
                            $calculatedPolicyAssignments = $byPolicyIdCalculatedAssignments.$policyDefinitionId
                            if ($null -eq $calculatedPolicyAssignments -or $calculatedPolicyAssignments.Count -eq 0) {
                                $calculatedPolicyAssignments = @()
                                Write-Warning "Row $($entryNumber): No assignments found for policyDefinitionName '$policyDefinitionName', skipping row"
                            }
                        }
                    }
                    elseif ($null -ne $policyDefinitionId) {
                        $epacMetadataDefinitionSpecification.policyDefinitionId = $policyDefinitionId
                        $policyDefinitionId = Confirm-PolicyDefinitionUsedExists `
                            -Id $policyDefinitionId `
                            -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                            -AllDefinitions $AllDefinitions.policydefinitions
                        if ($null -eq $policyDefinitionId) {
                            $calculatedPolicyAssignments = @()
                            Write-Warning "Row $($entryNumber): policyDefinitionId '$($epacMetadataDefinitionSpecification.policyDefinitionId)' not found in current root scope $($PacEnvironment.deploymentRootScope), skipping row"
                        }
                        else {
                            $calculatedPolicyAssignments = $byPolicyIdCalculatedAssignments.$policyDefinitionId
                            if ($null -eq $calculatedPolicyAssignments -or $calculatedPolicyAssignments.Count -eq 0) {
                                $calculatedPolicyAssignments = @()
                                Write-Warning "Row $($entryNumber): No assignments found for policyDefinitionId '$($epacMetadataDefinitionSpecification.policyDefinitionId)', skipping row"
                            }
                        }
                    }
                    elseif ($null -ne $policySetDefinitionName) {
                        $epacMetadataDefinitionSpecification.policySetDefinitionName = $policySetDefinitionName
                        $policySetDefinitionId = Confirm-PolicySetDefinitionUsedExists `
                            -Name $policySetDefinitionName `
                            -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                            -AllPolicySetDefinitions $AllDefinitions.policysetdefinitions
                        if ($null -eq $policySetDefinitionId) {
                            Write-Warning "Row $($entryNumber): policySetDefinitionName '$policySetDefinitionName' not found in current root scope $($PacEnvironment.deploymentRootScope), skipping row"
                        }
                        else {
                            $calculatedPolicyAssignments = $byPolicySetIdCalculatedAssignments.$policySetDefinitionId
                            if ($null -eq $calculatedPolicyAssignments -or $calculatedPolicyAssignments.Count -eq 0) {
                                $calculatedPolicyAssignments = @()
                                Write-Warning "Row $($entryNumber): No assignments found for policySetDefinitionName '$policySetDefinitionName', skipping row"
                            }
                        }
                    }
                    elseif ($null -ne $policySetDefinitionId) {
                        $epacMetadataDefinitionSpecification.policySetDefinitionId = $policySetDefinitionId
                        $policySetDefinitionId = Confirm-PolicySetDefinitionUsedExists `
                            -Id $policySetDefinitionId `
                            -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                            -AllPolicySetDefinitions $AllDefinitions.policysetdefinitions
                        if ($null -eq $policySetDefinitionId) {
                            Write-Warning "Row $($entryNumber): policySetDefinitionId '$($epacMetadataDefinitionSpecification.policySetDefinitionId)' not found in current root scope $($PacEnvironment.deploymentRootScope), skipping row"
                        }
                        else {
                            $calculatedPolicyAssignments = $byPolicySetIdCalculatedAssignments.$policySetDefinitionId
                            if ($null -eq $calculatedPolicyAssignments -or $calculatedPolicyAssignments.Count -eq 0) {
                                $calculatedPolicyAssignments = @()
                                Write-Warning "Row $($entryNumber): No assignments found for policySetDefinitionId '$($epacMetadataDefinitionSpecification.policySetDefinitionId)', skipping row"
                            }
                        }
                    }
                }
                #endregion retrieve pre-calculated Assignments

                #region check required fields and allowed values
                if ([string]::IsNullOrWhitespace($name)) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "required name missing" -EntryNumber $entryNumber
                }
                else {
                    if (-not (Confirm-ValidPolicyResourceName -Name $name)) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "name '$($name.Substring(0, 32))...' contains invalid characters <>*%&:?.+/ or ends with a space." -EntryNumber $entryNumber
                    }
                    elseif ($name.Length -gt 64) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "name too long (max 64 characters)" -EntryNumber $entryNumber
                    }
                }
                if ([string]::IsNullOrWhitespace($displayName)) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "required displayName missing" -EntryNumber $entryNumber
                }
                else {
                    if ($displayName.Length -gt 128) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "displayName '$($displayName.Substring(0, 32))...' too long (max 128 characters)" -EntryNumber $entryNumber
                    }
                }
                if ([string]::IsNullOrWhitespace($exemptionCategory)) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "required exemptionCategory missing" -EntryNumber $entryNumber
                }
                else {
                    if ($exemptionCategory -ne "Waiver" -and $exemptionCategory -ne "Mitigated") {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid exemptionCategory '$exemptionCategory' (must be 'Waiver' or 'Mitigated')" -EntryNumber $entryNumber
                    }
                }
                if (-not [string]::IsNullOrWhitespace($description)) {
                    if ($description.Length -gt 512) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "description '$($description.Substring(0, 32))...' too long (max 512 characters)" -EntryNumber $entryNumber
                    }
                }
                #endregion check required fields and allowed values

                #region pre-process scope or scopes array
                $scopesList = [System.Collections.ArrayList]::new()
                if ([string]::IsNullOrWhitespace($scope)) {
                    # scopes array
                    $requiresPostfix = $scopes.Length -gt 1
                    foreach ($currentScope in $scopes) {
                        $currentScope = $currentScope.Trim()
                        $scopeParts = $currentScope -split ":"
                        $scopePostfix = ""
                        $numberOfScopeParts = $scopeParts.Length
                        switch ($numberOfScopeParts) {
                            1 {
                                # no ':' separator, use the last part of the scope as the postfix (default)
                                $currentScope = $scopeParts[0]
                                $scopePostfix = ($currentScope -split "/")[-1]
                            }
                            2 {
                                # has a ':' separator, either indicating no postfix if starts with ':', or a postfix contained before the ':'
                                $currentScope = $scopeParts[1]
                                if ($requiresPostfix -and $scopeParts[0] -eq "") {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid scope format - missing postfix: '$currentScope'" -EntryNumber $entryNumber
                                }
                                $scopePostfix = $scopeParts[0]
                            }
                            default {
                                # more than one ':' separator
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "invalid scope format - too many ':' separators: '$currentScope'" -EntryNumber $entryNumber
                            }
                        }
                        $scopeInformation = @{
                            scope        = $currentScope
                            scopePostfix = $scopePostfix
                        }
                        $null = $scopesList.Add($scopeInformation)
                    }
                }
                else {
                    # single scope
                    $currentScope = $scope.Trim()
                    $scopeInformation = @{
                        scope        = $currentScope
                        scopePostfix = ""
                    }
                    $null = $scopesList.Add($scopeInformation)
                }
                #endregion pre-process scope or scopes array
                                
                #region calculate expiresOn
                $expired = $false
                $expiresOn = $null
                $daysUntilExpired = 0
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
                    if ($null -ne $expiresOn) {
                        $expired = $expiresOn -lt $now
                        $daysUntilExpired = (New-TimeSpan -Start $now -End $expiresOn).Days
                        if ($expired) {
                            if ($daysUntilExpired -eq 0) {
                                Write-Warning "Exemption entry $($entryNumber): Exemption '$name' in definitions expired today."
                            }
                            else {
                                Write-Warning "Exemption entry $($entryNumber): Exemption '$name' in definitions expired $( - $daysUntilExpired) days ago."
                            }
                            $Exemptions.numberOfExpired++
                        }
                        elseif ($daysUntilExpired -le 15) {
                            Write-Warning "Exemption entry $($entryNumber): Exemption '$name' in definitions expires in $daysUntilExpired days."
                        }
                    }
                }
                #endregion calculate expiresOn

                if ($errorInfo.hasLocalErrors) {
                    continue
                }

                #region process each scope
                foreach ($scopeInformation in $scopesList) {
                    $currentScope = $scopeInformation.scope
                    $scopePostfix = $scopeInformation.scopePostfix
                    $trimmedScope = $currentScope.Trim()
                    $subscriptionId = ""
                    $scopeIsValid = $true
                    $resourceStatus = "notAnIndividualResource"
                    $splits = $currentScope -split "/"
                    if ($currentScope.StartsWith("/subscriptions/")) {
                        $subscriptionId = $splits[2]
                        if ($currentScope.Contains("/providers/")) {
                            # an actual resource, keep just the "/subscriptions/.../resourceGroups/..." part
                            $trimmedScope = $splits[0..4] -join "/"
                            if ($validateScope -and $validateResources) {
                                $resourceStatus = "individualResourceDoesNotExists"
                                if ($resourceIdsBySubscriptionId.ContainsKey($subscriptionId)) {
                                    $resourceIds = $resourceIdsBySubscriptionId.$subscriptionId
                                    if ($resourceIds.ContainsKey($currentScope)) {
                                        $resourceStatus = "individualResourceExists"
                                    }
                                }
                                else {
                                    $resources = Get-AzResourceListRestMethod -SubscriptionId $subscriptionId
                                    $resourceIds = @{}
                                    foreach ($resource in $resources) {
                                        $resourceId = $resource.id
                                        if (!$resourceIds.ContainsKey($resourceId)) {
                                            $resourceIds.Add($resourceId, $resource)
                                        }
                                        else {
                                            Write-Debug -Message "Resource '$resourceId' already exists in the resourceIds hashtable."
                                        }
                                        if ($resourceId -eq $currentScope) {
                                            $resourceStatus = "individualResourceExists"
                                        }
                                    }
                                    $resourceIdsBySubscriptionId.Add($subscriptionId, $resourceIds)
                                }
                                if ($resourceStatus -eq "individualResourceDoesNotExists") {
                                    Write-Warning "Row $($entryNumber): Resource '$currentScope' does not exist, skipping entry."
                                    $Exemptions.numberOfOrphans++
                                }
                            }
                            else {
                                $resourceStatus = "individualResourceExists"
                            }
                        }
                    }
                    if ($ScopeTable.ContainsKey($trimmedScope)) {
                        $exemptionScopeDetails = $ScopeTable.$trimmedScope
                    }
                    elseif ($validateScope) {
                        Write-Warning "Exemption entry $($entryNumber): Exemption scope $($currentScope) not found in current scope tree for root $($PacEnvironment.deploymentRootScope), skipping entry."
                        $scopeIsValid = $false
                    }
                    else {
                        $exemptionScopeDetails = @{
                            isExcluded  = $false
                            parentTable = @{}
                        }
                        Write-Verbose "Exemption entry $($entryNumber): Unvalidated Exemption scope $($currentScope) not found in current scope tree for root $($PacEnvironment.deploymentRootScope)."
                    }

                    #region filter assignments in the current scope tree or are not in excluded scopes
                    $filteredPolicyAssignments = [System.Collections.ArrayList]::new()
                    $uniqueAssignmentNames = @{}
                    if ($unValidatedPolicyAssignment) {
                        $calculatedPolicyAssignment = $calculatedPolicyAssignments[0]
                        $clonedCalculatedPolicyAssignment = $calculatedPolicyAssignment.Clone()
                        $null = $filteredPolicyAssignments.Add($clonedCalculatedPolicyAssignment)
                    }
                    elseif ($null -ne $calculatedPolicyAssignments -and $calculatedPolicyAssignments.Count -gt 0) {
                        foreach ($calculatedPolicyAssignment in $calculatedPolicyAssignments) {
                            $policyAssignmentScope = $calculatedPolicyAssignment.scope
                            $assignmentScopeDetails = $ScopeTable.$policyAssignmentScope
                            if ($null -eq $assignmentScopeDetails) {
                                Write-Verbose "Assignment scope = '$($policyAssignmentScope)' not found in current scope tree for root $($PacEnvironment.deploymentRootScope), skipping assignment."
                            }
                            elseif ($assignmentScopeDetails.isExcluded) {
                                Write-Verbose "Assignment scope = '$($policyAssignmentScope)' is in a globally excluded scope"
                            }
                            elseif ($scopeIsValid) {
                                $parentTable = $exemptionScopeDetails.parentTable
                                $includeAssignment = $trimmedScope -eq $policyAssignmentScope -or $parentTable.ContainsKey($policyAssignmentScope)
                                if ($includeAssignment) {
                                    foreach ($notScope in $calculatedPolicyAssignment.notScopes) {
                                        if ($trimmedScope -eq $notScope -or $parentTable.ContainsKey($notScope)) {
                                            if ($SkipNotScopedExemptions) {
                                                $includeAssignment = $true
                                                break
                                            }
                                            else {
                                                $includeAssignment = $false
                                                break
                                            }
                                            
                                        }
                                    }
                                    if ($includeAssignment) {
                                        $calculatedName = $calculatedPolicyAssignment.name
                                        $listOfAssignmentsWithSameName = $null
                                        if ($uniqueAssignmentNames.ContainsKey($calculatedName)) {
                                            $listOfAssignmentsWithSameName = $uniqueAssignmentNames.$calculatedName
                                        }
                                        else {
                                            $listOfAssignmentsWithSameName = [System.Collections.ArrayList]::new()
                                            $null = $uniqueAssignmentNames.Add($calculatedPolicyAssignment.name, $listOfAssignmentsWithSameName)
                                        }
                                        $clonedCalculatedPolicyAssignment = $calculatedPolicyAssignment.Clone()
                                        $null = $listOfAssignmentsWithSameName.Add($clonedCalculatedPolicyAssignment)
                                        $null = $filteredPolicyAssignments.Add($clonedCalculatedPolicyAssignment)
                                    }
                                    else {
                                        Write-Verbose "Exemption scope = '$($currentScope)' is in the notScopes list for Assignment '$($calculatedPolicyAssignment.id)'."
                                    }
                                }
                                else {
                                    Write-Verbose "Assignment scope = '$($policyAssignmentScope)' is not in the current scope tree for root $($PacEnvironment.deploymentRootScope), skipping assignment."
                                }
                            }
                        }
                        foreach ($uniqueAssignmentName in $uniqueAssignmentNames.Keys) {
                            $listOfAssignmentsWithSameName = $uniqueAssignmentNames.$uniqueAssignmentName
                            if ($listOfAssignmentsWithSameName.Count -gt 1) {
                                Write-Warning "Exemption entry $($entryNumber): Multiple assignments with the same name '$uniqueAssignmentName' found; using ordinals to disambiguate."
                                $ordinal = 0
                                foreach ($calculatedPolicyAssignment in $listOfAssignmentsWithSameName) {
                                    $ordinalString = $ordinal.ToString("[00]")
                                    $calculatedPolicyAssignment.ordinalString = $ordinalString
                                    $ordinal++
                                }
                            }
                        }
                        if ($filteredPolicyAssignments.Count -eq 0) {
                            Write-Warning "Exemption entry $($entryNumber): No assignments found for exemption scope $($currentScope), skipping entry."
                            $Exemptions.numberOfOrphans++
                            continue
                        }
                    }
                    else {
                        # warning was already displayed
                        continue
                    }
                    #endregion filter assignments in the current scope tree or are not in excluded scopes

                    #region process each assignment (or multiple assignments)
                    $isPolicyDefinitionSpecified = $null -ne $policyDefinitionId
                    foreach ($calculatedPolicyAssignment in $filteredPolicyAssignments) {
                        $policyAssignmentId = $calculatedPolicyAssignment.id
                        $policyAssignmentName = $calculatedPolicyAssignment.name
                        $policyAssignmentReferenceIds = $calculatedPolicyAssignment.policyDefinitionReferenceIds
                        $policyAssignmentPerPolicyReferenceIdTable = $calculatedPolicyAssignment.perPolicyReferenceIdTable
                        $policyAssignmentByPolicyReferenceIds = $calculatedPolicyAssignment.policyDefinitionReferenceIds
                        $allowReferenceIdsInRow = $calculatedPolicyAssignment.allowReferenceIdsInRow
                        $isPolicyAssignment = $calculatedPolicyAssignment.isPolicyAssignment

                        #region multiple assignments require unique names and displayNames
                        $exemptionName = $name
                        $exemptionDisplayName = $displayName
                        $descriptionExists = -not [string]::IsNullOrWhitespace($description)
                        $exemptionDescription = $null
                        if ($descriptionExists) {
                            $exemptionDescription = $description
                        }
                        $ordinalString = $calculatedPolicyAssignment.ordinalString
                        if ($isPolicyDefinitionSpecified -or $scopePostfix -ne "") {
                            if ($scopePostfix -ne "") {
                                $exemptionDisplayName = "$($exemptionDisplayName) - $($scopePostfix)"
                                if ($descriptionExists) {
                                    $exemptionDescription = "$($exemptionDescription) - $($scopePostfix)"
                                }
                            }
                            if ($isPolicyDefinitionSpecified) {
                                $exemptionName = "$($exemptionName)-$($policyAssignmentName)"
                                $exemptionDisplayName = "$($exemptionDisplayName) - $($policyAssignmentName)"
                                if ($descriptionExists) {
                                    $exemptionDescription = "$($exemptionDescription) - $($policyAssignmentName)"
                                }
                                if ($null -ne $ordinalString) {
                                    $exemptionName = "$($exemptionName)$($ordinalString)"
                                    $exemptionDisplayName = "$($exemptionDisplayName)$($ordinalString)"
                                    if ($descriptionExists) {
                                        $exemptionDescription = "$($exemptionDescription)$($ordinalString)"
                                    }
                                }
                            }
                            if ($exemptionName.Length -gt 64) {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Concatenated Exemption name for multiple Assignments is too long ($($exemptionName.Length) - max 64 characters): '$exemptionName'." -EntryNumber $entryNumber
                            }
                            if ($exemptionDisplayName.Length -gt 128) {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Concatenated Exemption displayName for multiple Assignments or scopes is too long ($($exemptionDisplayName.Length) - max 128 characters): '$exemptionDisplayName'." -EntryNumber $entryNumber
                            }
                            if ($exemptionDescription.Length -gt 512) {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Concatenated Exemption description for multiple Assignments or scopes is too long ($($exemptionDescription.Length) - max 512 characters): '$exemptionDescription'." -EntryNumber $entryNumber
                            }
                        }
                        $exemptionId = "$currentScope/providers/Microsoft.Authorization/policyExemptions/$exemptionName"
                        if ($uniqueIds.ContainsKey($exemptionId)) {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Duplicate Exemption id '$exemptionId' for name '$name'." -EntryNumber $entryNumber
                        }
                        else {
                            $null = $uniqueIds.Add($exemptionId, $true)
                        }
                        #endregion multiple assignments require unique names and displayNames

                        #region validate or create referenceIds
                        $policyDefinitionReferenceIdsAugmented = [System.Collections.ArrayList]::new()
                        if ($allowReferenceIdsInRow) {
                            if ($null -ne $policyDefinitionReferenceIds -and $policyDefinitionReferenceIds.Count -gt 0) {
                                if ($unValidatedPolicyAssignment) {
                                    $null = $policyDefinitionReferenceIdsAugmented.AddRange($policyDefinitionReferenceIds)
                                }
                                else {
                                    $epacMetadataDefinitionSpecification.policyDefinitionReferenceIds = ConvertTo-Json $policyDefinitionReferenceIds
                                    foreach ($referenceId in $policyDefinitionReferenceIds) {
                                        if ($policyAssignmentReferenceIds -contains $referenceId) {
                                            $null = $policyDefinitionReferenceIdsAugmented.Add($referenceId)
                                        }
                                        elseif ($referenceId.StartsWith("policyDefinitions/")) {
                                            $referenceIdTrimmed = $referenceId.Substring(18)
                                            $policyDefinitionId = Confirm-PolicyDefinitionUsedExists `
                                                -Name $referenceIdTrimmed `
                                                -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                                                -AllDefinitions $AllDefinitions
                                            if ($null -eq $policyDefinitionId) {
                                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "policyDefinitionReference '$referenceId' not resolved for policyAssignment '$policyAssignmentName'" -EntryNumber $entryNumber
                                            }
                                            else {
                                                if ($policyAssignmentPerPolicyReferenceIdTable.ContainsKey($policyDefinitionId)) {
                                                    $referenceIds = $policyAssignmentPerPolicyReferenceIdTable.$policyDefinitionId
                                                    $null = $policyDefinitionReferenceIdsAugmented.AddRange($referenceIds)
                                                }
                                                else {
                                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "policyDefinitionReference '$referenceId' not resolved for policyAssignment '$policyAssignmentName'" -EntryNumber $entryNumber
                                                }
                                            }
                                        }
                                        elseif ($referenceId -contains "/providers/Microsoft.Authorization/policyDefinitions/") {
                                            if ($policyAssignmentPerPolicyReferenceIdTable.ContainsKey($referenceId)) {
                                                $referenceIds = $policyAssignmentPerPolicyReferenceIdTable.$referenceId
                                                $null = $policyDefinitionReferenceIdsAugmented.AddRange($referenceIds)
                                            }
                                            else {
                                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "policyDefinitionReference '$referenceId' not resolved for policyAssignment '$policyAssignmentName'" -EntryNumber $entryNumber
                                            }
                                        }
                                        else {
                                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "policyDefinitionReferenceId '$referenceId' not found in policyAssignment '$policyAssignmentName'." -EntryNumber $entryNumber
                                        }
                                    }
                                }
                            }
                        }
                        elseif (-not $isPolicyAssignment) {
                            $null = $policyDefinitionReferenceIdsAugmented.AddRange($policyAssignmentByPolicyReferenceIds)
                        }
                        #endregion validate or create referenceIds

                        #region metadata
                        $epacMetadata = @{
                            pacSelector          = $PacEnvironment.pacSelector
                            originalName         = $name
                            originalDisplayName  = $displayName
                            originalDescription  = $description
                            policyAssignmentName = $policyAssignmentName
                            scopePostfix         = $scopePostfix
                            ordinalString        = $ordinalString
                        }
                        $epacMetadata += $epacMetadataDefinitionSpecification

                        # Create a new ordered hash table
                        $orderedEpacMetadata = [ordered]@{}

                        # Get the properties of the original object and sort them alphabetically
                        $sortedKeys = $epacMetadata.Keys | Sort-Object

                        # Add the sorted properties to the new ordered hash table
                        foreach ($key in $sortedKeys) {
                            $orderedEpacMetadata[$key] = $epacMetadata[$key]
                        }

                        $clonedMetadata = Get-DeepCloneAsOrderedHashtable $metadata
                        $clonedMetadata.pacOwnerId = $PacEnvironment.pacOwnerId
                        $clonedMetadata.epacMetadata = $orderedEpacMetadata
                        if (!$clonedMetadata.ContainsKey("deployedBy")) {
                            $clonedMetadata.deployedBy = $PacEnvironment.deployedBy
                        }

                        # Create a new ordered hash table
                        $orderedClonedMetadata = [ordered]@{}

                        # Get the properties of the original object and sort them alphabetically
                        $clonedSortedKeys = $clonedMetadata.Keys | Sort-Object
                        
                        # Add the sorted properties to the new ordered hash table
                        foreach ($key in $clonedSortedKeys) {
                            $orderedClonedMetadata[$key] = $clonedMetadata[$key]
                        }
                        #endregion metadata

                        # bail if we encountered errors
                        if ($errorInfo.hasLocalErrors) {
                            continue
                        }

                        $exemption = [ordered]@{
                            id                           = $exemptionId
                            name                         = $exemptionName
                            displayName                  = $exemptionDisplayName
                            description                  = $exemptionDescription
                            exemptionCategory            = $exemptionCategory
                            expiresOn                    = $expiresOn
                            scope                        = $currentScope
                            policyAssignmentId           = $policyAssignmentId
                            assignmentScopeValidation    = $assignmentScopeValidation
                            policyDefinitionReferenceIds = $policyDefinitionReferenceIdsAugmented
                            resourceSelectors            = $resourceSelectors
                            metadata                     = $orderedClonedMetadata
                            expired                      = $expired
                            scopeIsValid                 = $scopeIsValid
                        }

                    
                        $reasonStrings = [System.Collections.ArrayList]::new()
                        if ($expired) {
                            $null = $reasonStrings.Add("expired")
                        }
                        if (!$scopeIsValid) {
                            $null = $reasonStrings.Add("invalid scope")
                        }
                        if ($resourceStatus -eq "individualResourceDoesNotExists") {
                            $null = $reasonStrings.Add("resource does not exist")
                        }
                        if ($deployedManagedExemptions.ContainsKey($exemptionId)) {
                            $deployedManagedExemption = $deployedManagedExemptions.$exemptionId
                            $deleteCandidates.Remove($exemptionId)
                            if ($deployedManagedExemption.policyAssignmentId -ne $policyAssignmentId) {
                                # Replaced Assignment
                                if ($reasonStrings.Count -gt 0) {
                                    $reasonString = "assignmentId changed, $($reasonStrings -join ", ")"
                                    Write-Verbose "Skip replace ($reasonString): '$($exemptionDisplayName)' at scope '$($currentScope)'"
                                    $Exemptions.numberUnchanged += 1
                                }
                                else {
                                    Write-Information "Replace (assignmentId changed) '$($exemptionDisplayName)' at scope '$($currentScope)'"
                                    Write-Information "    assignmentId '$($deployedManagedExemption.policyAssignmentId)' to '$($policyAssignmentId)'"
                                    Write-Verbose "    $exemptionId"
                                    $null = $Exemptions.replace.Add($exemptionId, $exemption)
                                    $Exemptions.numberOfChanges++
                                }
                            }
                            elseif ($replacedAssignments.ContainsKey($policyAssignmentId)) {
                                # Replaced Assignment
                                if ($reasonStrings.Count -gt 0) {
                                    $reasonString = "replaced assignment, $($reasonStrings -join ", ")"
                                    Write-Verbose "Skip replace ($reasonString): '$($exemptionDisplayName)' at scope '$($currentScope)'"
                                    $Exemptions.numberUnchanged += 1
                                }
                                else {
                                    Write-Information "Replace (replaced assignment) '$($exemptionDisplayName)' ($($exemptionName)) at scope '$($currentScope)'"
                                    Write-Information "    assignmentId '$($policyAssignmentId)'"
                                    Write-Verbose "    $exemptionId"
                                    $null = $Exemptions.replace.Add($exemptionId, $exemption)
                                    $Exemptions.numberOfChanges++
                                }
                            }
                            else {
                                # Maybe update existing Exemption
                                $displayNameMatches = $deployedManagedExemption.displayName -eq $exemptionDisplayName
                                $descriptionMatches = ($deployedManagedExemption.description -eq $exemptionDescription) `
                                    -or ([string]::IsNullOrWhiteSpace($deployedManagedExemption.description) -and [string]::IsNullOrWhiteSpace($exemptionDescription))
                                $exemptionCategoryMatches = $deployedManagedExemption.exemptionCategory -eq $exemptionCategory
                                $expiresOnMatches = $deployedManagedExemption.expiresOn -eq $expiresOn
                                $clearExpiration = !$expiresOnMatches -and $null -eq $expiresOn
                                $deployedPolicyDefinitionReferenceIdsArray = $deployedManagedExemption.policyDefinitionReferenceIds
                                if ($null -ne $deployedPolicyDefinitionReferenceIdsArray -and $deployedPolicyDefinitionReferenceIdsArray -isnot [array]) {
                                    $deployedPolicyDefinitionReferenceIdsArray = @($deployedPolicyDefinitionReferenceIdsArray)
                                }
                                $policyDefinitionReferenceIdsMatches = Confirm-ObjectValueEqualityDeep $deployedPolicyDefinitionReferenceIdsArray $policyDefinitionReferenceIdsAugmented
                                $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                                    -ExistingMetadataObj $deployedManagedExemption.metadata `
                                    -DefinedMetadataObj $clonedMetadata
                                $assignmentScopeValidationMatches = ($deployedManagedExemption.assignmentScopeValidation -eq $assignmentScopeValidation) `
                                    -or ($null -eq $deployedManagedExemption.assignmentScopeValidation -and ($validateScope))
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
                                    $changesString = $changesStrings -join ", "
                                    if ($reasonStrings.Count -gt 0) {
                                        $reasonString = "$($reasonStrings -join ", "), $changesString"
                                        Write-Verbose "Skip update ($reasonString): '$($exemptionDisplayName)' at scope '$($currentScope)'"
                                        $Exemptions.numberUnchanged += 1
                                    }
                                    else {
                                        $Exemptions.numberOfChanges++
                                        Write-Information "Update ($changesString): '$($exemptionDisplayName)' at scope '$($currentScope)'"
                                        Write-Verbose "    $exemptionId"
                                        $null = $Exemptions.update.Add($exemptionId, $exemption)
                                    }
                                }
                            }
                        }
                        else {
                            if ($reasonStrings.Count -gt 0) {
                                $reasonString = $reasonStrings -join ", "
                                Write-Information "Skip new exemption ($reasonString): '$($exemptionDisplayName)' at scope '$($currentScope)'"
                                Write-Verbose "    $exemptionId"
                            }
                            else {
                                # Create Exemption
                                Write-Information "New '$($exemptionDisplayName)' at scope '$($currentScope)'"
                                Write-Verbose "    $exemptionId"
                                $null = $Exemptions.new.Add($exemptionId, $exemption)
                                $Exemptions.numberOfChanges++
                            }
                        }
                    }
                    #endregion process each assignment (or multiple assignments)

                }
                #endregion process each scope
            }
            #endregion process each row
            
            if ($errorInfo.hasErrors) {
                Write-ErrorsFromErrorInfo -ErrorInfo $errorInfo -ErrorAction Continue
                $numberOfFilesWithErrors++
                continue
            }
        }
        #endregion process each file

        if ($numberOfFilesWithErrors -gt 0) {
            Write-Information ""
            throw "There were errors in $numberOfFilesWithErrors file(s)."
        }
    }

    #region delete removed, orphaned and expired exemptions
    foreach ($exemptionId in $deleteCandidates.Keys) {
        $exemption = $deleteCandidates.$exemptionId
        $pacOwner = $exemption.pacOwner
        $status = $exemption.status

        $reason = "unknown"
        $shallDelete = $false
        switch ($pacOwner) {
            thisPaC {
                $shallDelete = $true
                $reason = "thisOwner"
            }
            otherPac { 
                $shallDelete = $false
                $reason = "otherPac"
            }
            unknownOwner {
                if ($desiredStateStrategy -eq "full") {
                    $shallDelete = $true
                    $reason = "unknownOwner, strategy=full, status=$status"
                }
                else {
                    $shallDelete = $false
                    $reason = "unknownOwner, strategy=ownedOnly, status=$status"
                }
            }
            Default {
                throw "Code bug: pacOwner must be one of @('thisPac', 'otherPac', 'unknownOwner')"
            }
        }
        if ($shallDelete) {
            # check fo special Exemption cases
            Write-Information "Delete '$($exemption.displayName)' at scope '$($exemption.scope)', $reason"
            Write-Verbose "    $exemptionId"
            $null = $Exemptions.delete[$exemptionId] = $exemption
            $Exemptions.numberOfChanges++
        }
        else {
            Write-Verbose "Keep: '$($exemption.displayName)'($($exemption.name)), '$($exemption.scope)' $reason"
            Write-Verbose "    $exemptionId"
        }
    }
    #endregion delete removed, orphaned and expired exemptions

    if ($Exemptions.numberUnchanged -gt 0) {
        Write-Information "$($Exemptions.numberUnchanged) unchanged Exemptions"
    }
    Write-Information ""
}
