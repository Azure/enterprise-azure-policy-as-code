function Build-ExemptionsPlan {
    [CmdletBinding()]
    param (
        [string] $ExemptionsRootFolder,
        [string] $ExemptionsAreNotManagedMessage,
        [hashtable] $PacEnvironment,
        $ScopeTable,
        [hashtable] $AllDefinitions,
        [hashtable] $AllAssignments,
        [hashtable] $CombinedPolicyDetails,
        [hashtable] $Assignments,
        [hashtable] $DeployedExemptions,
        [hashtable] $Exemptions
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
    $deleteCandidates = Get-ClonedObject $deployedManagedExemptions -AsHashTable -AsShallowClone
    $replacedAssignments = $Assignments.replace
    $xlsUsesPolicyMethod = "unknown"
    $numberOfFilesWithErrors = 0
    $desiredState = $PacEnvironment.desiredState
    $desiredStateStrategy = $desiredState.strategy

    $now = Get-Date -AsUTC
    #endregion read files and cache data structures

    if ($exemptionFiles.Length -eq 0) {
        Write-Warning "No Policy Exemption files found."
        Write-Warning "All exemptions will be deleted!"
        Write-Information ""
    }
    else {
        Write-Information "Number of Policy Exemption files = $($exemptionFiles.Length)"
        $resourceIdsExist = @{}

        #region pre-calculate assignments
        $sortedAssignments = $AllAssignments.Values | Sort-Object -Property id # for a stable order
        $calculatedResult = Get-CalculatedPolicyAssignmentsAndReferenceIds `
            -Assignments $sortedAssignments `
            -CombinedPolicyDetails $CombinedPolicyDetails
        $byAssignmentIdCalculatedAssignments = $calculatedResult.byAssignmentIdCalculatedAssignments
        $byPolicySetIdCalculatedAssignments = $calculatedResult.byPolicySetIdCalculatedAssignments
        $byPolicyIdCalculatedAssignments = $calculatedResult.byPolicyIdCalculatedAssignments
        #endregion pre-calculate assignments
            
        foreach ($file  in $exemptionFiles) {

            #region read each file
            $extension = $file.Extension
            $fullName = $file.FullName
            Write-Information "Processing file '$($fullName)'"
            $errorInfo = New-ErrorInfo -FileName $fullName
            $exemptionsArray = @()
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
                        $exemptionsArray += $jsonExemptions
                    }
                }

            }
            elseif ($extension -eq ".csv") {
                $isCsvFile = $true
                $content = Get-Content -Path $fullName -Raw -ErrorAction Stop
                $xlsExemptions = ($content | ConvertFrom-Csv -ErrorAction Stop)
                if ($xlsExemptions.Count -gt 0) {
                    $exemptionsArray += $xlsExemptions
                }
            }
            #endregion read each file

            $entryNumber = $isCsvFile ? 1 : -1
            foreach ($row in $exemptionsArray) {
                $errorInfo.hasLocalErrors = $false
                $entryNumber++

                #region read row values andd skip empty rows on CSV files
                $name = $row.name
                $displayName = $row.displayName
                $exemptionCategory = $row.exemptionCategory
                $scope = $row.scope
                $policyAssignmentId = $row.policyAssignmentId
                $policyDefinitionId = $null
                $policySetDefinitionId = $null
                $assignmentReferenceId = $row.assignmentReferenceId
                $description = $row.description
                $assignmentScopeValidation = $row.assignmentScopeValidation
                $resourceSelectors = $row.resourceSelectors
                $policyDefinitionReferenceIds = $row.policyDefinitionReferenceIds
                $metadata = $row.metadata
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
                        Write-Warning "Ignoring empty row $entryNumber"
                        continue
                    }
                }
                #endregion read row values andd skip empty rows on CSV files

                #region check if scope defined
                if ([string]::IsNullOrWhitespace($scope)) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "required Exemption scope missing" -EntryNumber $entryNumber
                    continue
                }
                $trimmedScope = $scope
                if ($scope.StartsWith("/subscriptions/")) {
                    if ($scope.Contains("/providers/")) {
                        # an actual resource, keep just the "/subscriptions/.../resourceGroups/..." part
                        $splits = $scope -split "/"
                        $trimmedScope = $splits[0..4] -join "/"
                    }
                }
                $exemptionScopeDetails = $ScopeTable.$trimmedScope
                #endregion check if scope defined


                #region Convert complex fields from CSV
                if ($isCsvFile) {

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
                }
                #endregion Convert complex fields from CSV

                if ($isCsvFile) {

                    #region CSV files can define the assignment with assignmentReferenceId or the leagcy policyAssignmentId
                    if ([string]::IsNullOrWhitespace($assignmentReferenceId) -xor [string]::IsNullOrWhitespace($policyAssignmentId)) {
                        if (-not [string]::IsNullOrWhitespace($assignmentReferenceId)) {
                            $xlsUsesPolicyMethod = "assignmentReferenceId"
                            if ($assignmentReferenceId.StartsWith("policyDefinitions/")) {
                                $splits = $assignmentReferenceId -split "/"
                                $name = $splits[1]
                                $policyDefinitionId = Confirm-PolicyDefinitionUsedExists `
                                    -Name $name `
                                    -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                                    -AllDefinitions $AllDefinitions.policydefinitions `
                                    -SuppressErrorMessage
                                if ($null -eq $policyDefinitionId) {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "assignmentReferenceId '$assignmentReferenceId' not found in current EPAC environment '$($PacEnvironment.pacSelector)'" -EntryNumber $entryNumber
                                }
                            }
                            elseif ($assignmentReferenceId.StartsWith("policySetDefinitions/")) {
                                $splits = $assignmentReferenceId -split "/"
                                $name = $splits[1]
                                $policySetDefinitionId = Confirm-PolicySetDefinitionUsedExists `
                                    -Name $name `
                                    -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                                    -AllPolicySetDefinitions $AllDefinitions.policysetdefinitions
                                if ($null -eq $policySetDefinitionId) {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "assignmentReferenceId '$assignmentReferenceId' not found in current EPAC environment '$($PacEnvironment.pacSelector)'" -EntryNumber $entryNumber
                                }
                            }
                            elseif ($assignmentReferenceId.Contains("/providers/Microsoft.Authorization/policyDefinitions/")) {
                                $policyDefinitionId = Confirm-PolicyDefinitionUsedExists `
                                    -Id $assignmentReferenceId `
                                    -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                                    -AllDefinitions $AllDefinitions.policydefinitions `
                                    -SuppressErrorMessage
                                if ($null -eq $policyDefinitionId) {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "assignmentReferenceId '$assignmentReferenceId' not found in current EPAC environment '$($PacEnvironment.pacSelector)'" -EntryNumber $entryNumber
                                }
                            }
                            elseif ($assignmentReferenceId.Contains("/providers/Microsoft.Authorization/policySetDefinitions/")) {
                                $policySetDefinitionId = Confirm-PolicySetDefinitionUsedExists `
                                    -Id $assignmentReferenceId `
                                    -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                                    -AllPolicySetDefinitions $AllDefinitions.policysetdefinitions
                                if ($null -eq $policySetDefinitionId) {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "assignmentReferenceId '$assignmentReferenceId' not found in current EPAC environment '$($PacEnvironment.pacSelector)'" -EntryNumber $entryNumber
                                }
                            }
                            elseif ($assignmentReferenceId.Contains("/providers/Microsoft.Authorization/policyAssignments/")) {
                                $policyAssignmentId = $assignmentReferenceId
                                if ($AllAssignments.ContainsKey($policyAssignmentId)) {
                                    $policyAssignmentId = $assignmentReferenceId
                                }
                                else {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "assignmentReferenceId '$assignmentReferenceId' not found in current root scope $($PacEnvironment.deploymentRootScope)" -EntryNumber $entryNumber
                                }
                            }
                            else {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "assignmentReferenceId '$assignmentReferenceId' of unknown type" -EntryNumber $entryNumber
                            }
                        }
                        else {
                            $xlsUsesPolicyMethod = "policyAssignmentId"
                            if (-not $AllAssignments.ContainsKey($policyAssignmentId)) {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "assignmentReferenceId '$policyAssignmentId' not found in current root scope $($PacEnvironment.deploymentRootScope)" -EntryNumber $entryNumber
                            }
                        }
                    }
                    elseif ([string]::IsNullOrWhitespace($assignmentReferenceId) -and [string]::IsNullOrWhitespace($policyAssignmentId)) {
                        if ($xlsUsesPolicyMethod -eq "unknown") {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "exactly one of the columns policyAssignmentId or assignmentReferenceId is required" -EntryNumber $entryNumber
                        }
                        else {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "cell in $xlsUsesPolicyMethod column is empty" -EntryNumber $entryNumber
                        }
                    }
                    else {
                        throw "$($fullName): exactly one of the columns policyAssignmentId or assignmentReferenceId is allowed"
                    }                            
                    #endregion policyAssignmentId

                }
                else {

                    #region JSON files require exactly one field from set @(policyAssignmentId,policyDefinitionName,policyDefinitionId,policySetDefinitionName,policySetDefinitionId)
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
                    else {
                        if ($null -ne $row.policyAssignmentId) {
                            $policyAssignmentId = $row.policyAssignmentId
                            if (-not $AllAssignments.ContainsKey($policyAssignmentId)) {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "policyAssignmentId '$assignmentReferenceId' not found in current root scope $($PacEnvironment.deploymentRootScope)" -EntryNumber $entryNumber
                            }
                        }
                        elseif ($null -ne $row.policyDefinitionName) {
                            $policyDefinitionId = Confirm-PolicyDefinitionUsedExists `
                                -Name $row.policyDefinitionName `
                                -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                                -AllDefinitions $AllDefinitions.policydefinitions
                            if ($null -eq $policyDefinitionId) {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "policyDefinitionName '$($row.policyDefinitionName)' not found in current EPAC environment '$($PacEnvironment.pacSelector)'" -EntryNumber $entryNumber
                            }
                        }
                        elseif ($null -ne $row.policyDefinitionId) {
                            $policyDefinitionId = Confirm-PolicyDefinitionUsedExists `
                                -Id $row.policyDefinitionId `
                                -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                                -AllDefinitions $AllDefinitions.policydefinitions
                            if ($null -eq $policyDefinitionId) {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "policyDefinitionId '$($row.policyDefinitionId)' not found in current EPAC environment '$($PacEnvironment.pacSelector)'" -EntryNumber $entryNumber
                            }
                        }
                        elseif ($null -ne $row.policySetDefinitionName) {
                            $policySetDefinitionId = Confirm-PolicySetDefinitionUsedExists `
                                -Name $row.policySetDefinitionName `
                                -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                                -AllPolicySetDefinitions $AllDefinitions.policysetdefinitions
                            if ($null -eq $policySetDefinitionId) {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "policySetDefinitionName '$($row.policySetDefinitionName)' not found in current EPAC environment '$($PacEnvironment.pacSelector)'" -EntryNumber $entryNumber
                            }
                        }
                        elseif ($null -ne $row.policySetDefinitionId) {
                            $policySetDefinitionId = Confirm-PolicySetDefinitionUsedExists `
                                -Id $row.policySetDefinitionId `
                                -PolicyDefinitionsScopes $PacEnvironment.policyDefinitionsScopes `
                                -AllPolicySetDefinitions $AllDefinitions.policysetdefinitions
                            if ($null -eq $policySetDefinitionId) {
                                $policySetDefinitionId = $row.policySetDefinitionId
                            }
                            else {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "policySetDefinitionId '$($row.policySetDefinitionId)' not found in current EPAC environment '$($PacEnvironment.pacSelector)'" -EntryNumber $entryNumber
                            }
                        }
                    }
                    #endregion JSON files require exactly one field from set @(policyAssignmentId,policyDefinitionName,policyDefinitionId,policySetDefinitionName,policySetDefinitionId)
                }

                #region check required fields
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
                #endregion check required fields

                #region validate scope
                if ($null -eq $exemptionScopeDetails) {
                    Write-Warning "Exemption entry $($entryNumber): Exemption '$($displayName)'($($name)) scope $($scope) is not in current scope tree for root $($PacEnvironment.deploymentRootScope), skipping row."
                    continue
                }
                if ($assignmentScopeValidation -eq "Default") {
                    if ($exemptionScopeDetails.isInGlobalNotScope) {
                        Write-Warning "Exemption entry $($entryNumber): Exemption '$($displayName)'($($name)) scope $($scope) is in a global not scope, skipping row."
                        continue
                    }
                }
                #endregion validate scope

                $warning = $false

                #region calculate expiresOn
                $expiresOn = $null
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
                        $daysUntilExpired = (New-TimeSpan -Start $now -End $expiresOn).Days
                        if ($expired) {
                            $daysExpired = - $daysUntilExpired
                            if ($daysExpired -eq 0) {
                                Write-Warning "Exemption entry $($entryNumber): Exemption '$name' in definitions expired today, skipping row."
                                $warning = $true
                            }
                            else {
                                Write-Warning "Exemption entry $($entryNumber): Exemption '$name' in definitions expired $daysExpired days ago, skipping row."
                                $warning = $true
                            }
                            $warning = $true
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

                #region check if resource still exists; $scope indicating a resource container (resourceGroups, subscriptions, managementGroups) or an actual resource
                $isIndividualResource = $true
                if ($scope.StartsWith("/providers/Microsoft.Management/management")) {
                    $isIndividualResource = $false
                }
                elseif ($scope.Contains("/providers/")) {
                    $isIndividualResource = $true
                }
                else {
                    # subscription, resourceGroup
                    $isIndividualResource = $false
                }

                if ($isIndividualResource) {
                    $thisResourceIdExists = $false
                    if ($resourceIdsExist.ContainsKey($scope)) {
                        $thisResourceIdExists = $resourceIdsExist.$scope
                    }
                    else {
                        $resource = Get-AzResource -ResourceId $scope -ErrorAction SilentlyContinue
                        $thisResourceIdExists = $null -ne $resource
                        $resourceIdsExist[$scope] = $thisResourceIdExists
                    }
                    if (-not $thisResourceIdExists) {
                        Write-Warning "Row $($entryNumber): Resource '$scope' does not exist, skipping row."
                        $warning = $true
                    }
                }
                #endregion check if resource still exists; $scope indicating a resource container (resourceGroups, subscriptions, managementGroups)

                #region retrieve pre-calculated assignments for this row
                $calculatedPolicyAssignments = $null
                if ($null -ne $policyDefinitionId) {
                    $calculatedPolicyAssignments = $byPolicyIdCalculatedAssignments.$policyDefinitionId
                    if ($null -eq $calculatedPolicyAssignments -or $calculatedPolicyAssignments.Count -eq 0) {
                        Write-Warning "Row $($entryNumber): No assignments found for policyDefinitionId '$policyDefinitionId', skipping row"
                        $warning = $true
                    }
                }
                elseif ($null -ne $policySetDefinitionId) {
                    $calculatedPolicyAssignments = $byPolicySetIdCalculatedAssignments.$policySetDefinitionId
                    if ($null -eq $calculatedPolicyAssignments -or $calculatedPolicyAssignments.Count -eq 0) {
                        Write-Warning "Row $($entryNumber): No assignments found for policySetDefinitionId '$policySetDefinitionId', skipping row"
                        $warning = $true
                    }
                }
                elseif ($null -ne $policyAssignmentId) {
                    $calculatedPolicyAssignments = $byAssignmentIdCalculatedAssignments.$policyAssignmentId
                    if ($null -eq $calculatedPolicyAssignments -or $calculatedPolicyAssignments.Count -eq 0) {
                        Write-Warning "Row $($entryNumber): No assignment found for policyAssignmentId '$policyAssignmentId', skipping row"
                        $warning = $true
                    }
                }
                else {
                    throw "Code bug: policyDefinitionId, policySetDefinitionId, or policyAssignmentId must be defined"
                }
                #endregion retrieve pre-calculated assignments for this row

                if ($warning) {
                    foreach ($deployedManagedExemption in $deployedManagedExemptions.Values) {
                        $deployedId = $deployedManagedExemption.id
                        $deployedName = $deployedManagedExemption.name
                        if ($deployedName -eq $name -or $deployedName -like "$($name)___*") {
                            # do not delete the deployed exemption
                            $null = $deleteCandidates.Remove($deployedId)
                            break
                        }
                    }
                    continue
                }

                #region filter out assignments that are not in the current scope tree or are in excluded scopes
                $filteredPolicyAssignments = [System.Collections.ArrayList]::new()
                foreach ($calculatedPolicyAssignment in $calculatedPolicyAssignments) {
                    $policyAssignmentScope = $calculatedPolicyAssignment.scope
                    if ($ScopeTable.ContainsKey($policyAssignmentScope)) {
                        $assignmentScopeDetails = $ScopeTable.$policyAssignmentScope
                        if (-not $assignmentScopeDetails.isExcluded) {
                            $exemptionScopeDetails = $ScopeTable.$trimmedScope
                            $parentTable = $exemptionScopeDetails.parentTable
                            #region validate that the Assignment scope is at or above the Exemption scope
                            $isAssignmentScopeValid = ($assignmentScopeValidation -ne "Default") -or ($trimmedScope -eq $policyAssignmentScope) -or $parentTable.ContainsKey($policyAssignmentScope)
                            if (-not $isAssignmentScopeValid) {
                                Write-Verbose "Exemption entry $($entryNumber): Exemption scope = '$scope' is NOT in a child scope for assignment $($calculatedPolicyAssignment.displayName)($($calculatedPolicyAssignment.id)), skipping assignment."
                                continue
                            }
                            #endregion validate that the Assignment scope is at or above the Exemption scope

                            #region validate scope against the assignment's notScopes
                            if ($assignmentScopeValidation -eq "Default") {
                                foreach ($notScope in $calculatedPolicyAssignment.notScopes) {
                                    if ($trimmedScope -eq $notScope -or $parentTable.ContainsKey($notScope)) {
                                        Write-Warning "Exemption entry $($entryNumber): Exemption scope = '$scope' is in a not scope for assignment $($calculatedPolicyAssignment.displayName)($($calculatedPolicyAssignment.id)), skipping assignment."
                                        $warning = $true
                                        break
                                    }
                                }
                            }
                            #endregion validate scope against the assignment's notScopes

                            if (-not $warning) {
                                $null = $filteredPolicyAssignments.Add($calculatedPolicyAssignment)
                            }
                        }
                        else {
                            Write-Verbose "Assignment scope = '$($policyAssignmentScope)' is in a globally excluded scope"
                        }
                    }
                    else {
                        Write-Verbose "Assignment scope = '$($policyAssignmentScope)' not found in current scope tree for root $($PacEnvironment.deploymentRootScope)"
                    }
                }
                #endregion filter out assignments that are not in the current scope tree or are in excluded scopes

                $isMultipleAssignments = $filteredPolicyAssignments.Count -gt 1
                $ordinal = 1
                foreach ($calculatedPolicyAssignment in $filteredPolicyAssignments) {
                    $policyAssignmentId = $calculatedPolicyAssignment.id
                    $policyAssignmentName = $calculatedPolicyAssignment.name
                    $policyAssignmentReferenceIds = $calculatedPolicyAssignment.policyDefinitionReferenceIds
                    $policyAssignmentPerPolicyReferenceIdTable = $calculatedPolicyAssignment.perPolicyReferenceIdTable
                    $policyAssignmentByPolicyReferenceIds = $calculatedPolicyAssignment.policyDefinitionReferenceIds
                    $allowReferenceIdsInRow = $calculatedPolicyAssignment.allowReferenceIdsInRow
                    $isPolicyAssignment = $calculatedPolicyAssignment.isPolicyAssignment

                    #region multiple assignments require unique names and displayNames
                    $tryName = $null
                    $tryId = $null
                    $tryDisplayName = $null
                    if ($isMultipleAssignments) {
                        $ordinalString = '{0:d2}' -f $ordinal
                        $possibleName = "$($name)-$($policyAssignmentName)"
                        $possibleDisplayName = "$($displayName) - $($policyAssignmentName)"
                        if ($possibleName.Length -gt 64) {
                            Write-Warning "Exemption entry $($entryNumber): Concatenated Exemption name for multiple assignments too long ($($possibleName.Length) - max 60 characters, truncating."
                            $possibleName = $possibleName.Substring(0, 60)
                        }
                        if ($possibleDisplayName.Length -gt 125) {
                            Write-Warning "Exemption entry $($entryNumber): Concatenated Exemption displayName for multiple assignments too long ($($possibleDisplayName.Length) - max 125 characters, truncating."
                            $possibleDisplayName = $possibleDisplayName.Substring(0, 125)
                        }
                        $tryName = $possibleName
                        $tryId = "$scope/providers/Microsoft.Authorization/policyExemptions/$tryName"
                        $tryDisplayName = $possibleDisplayName
                        if ($uniqueIds.ContainsKey($tryId)) {
                            # append ordinal string to name and displayName; last resort fallback
                            $tryName = "$($possibleName)-$($ordinalString)"
                            $tryId = "$scope/providers/Microsoft.Authorization/policyExemptions/$tryName"
                            $tryDisplayName = "$($possibleDisplayName);$($ordinalString)"
                            if ($uniqueIds.ContainsKey($tryId)) {
                                $tryName = $null
                                $tryId = $null
                                $tryDisplayName = $null
                            }
                            else {
                                $ordinal++
                            }
                        }
                        else {
                            $null = $null
                        }
                        if ($null -eq $tryName) {
                            # ultimate fall back, use the original name and displayName and an ordinal
                            do {
                                $tryName = "$($name)-$($ordinalString)"
                                if ($tryName.Length -gt 64) {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Exemption name for multiple assignments too long ($($tryName.Length) - max 60 characters), please shorten the Exemption name." -EntryNumber $entryNumber
                                    break
                                }
                                if ($ordinal -gt 99) {
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Exemption has too many assignments ($($ordinal), swich back to specifying the assignment" -EntryNumber $entryNumber
                                    break
                                }
                                $tryId = "$scope/providers/Microsoft.Authorization/policyExemptions/$tryName"
                                $tryDisplayName = "$($displayName);$($ordinalString)"
                                $ordinal++
                            } while ($uniqueIds.ContainsKey($tryId))
                            if ($errorInfo.hasLocalErrors) {
                                continue
                            }
                        }
                        if ($displayNameAugmented.Length -gt 128) {
                            Write-Warning "Exemption entry $($entryNumber): Exemption displayName (for multiple assignments) too long ($($displayNameAugmented.Length) - max 128 characters), truncating."
                            $displayNameAugmented = $displayNameAugmented.Substring(0, 128)
                        }
                    }
                    else {
                        $tryName = $name
                        $tryId = "$scope/providers/Microsoft.Authorization/policyExemptions/$tryName"
                        $tryDisplayName = $displayName
                        if ($uniqueIds.ContainsKey($tryId)) {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Duplicate Exemption id '$tryId'." -EntryNumber $entryNumber
                            continue
                        }
                    }
                    $null = $uniqueIds.Add($tryId, $true)
                    $nameAugmented = $tryName
                    $displayNameAugmented = $tryDisplayName
                    $id = $tryId
                    #endregion multiple assignments require unique names and displayNames

                    #region validate or create referenceIds
                    $policyDefinitionReferenceIdsAugmented = [System.Collections.ArrayList]::new()
                    if ($allowReferenceIdsInRow) {
                        if ($null -ne $policyDefinitionReferenceIds -and $policyDefinitionReferenceIds.Count -gt 0) {
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
                                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "policyDefinitionReference '$referenceId' not resolved for policyAssignment '$policyAssignmentName'" -EntryNumber $entryNumber
                                }
                            }
                        }
                    }
                    elseif (-not $isPolicyAssignment) {
                        $null = $policyDefinitionReferenceIdsAugmented.AddRange($policyAssignmentByPolicyReferenceIds)
                    }
                    #endregion validate or create referenceIds

                    if ($metadata) {
                        $metadata.pacOwnerId = $PacEnvironment.pacOwnerId
                    }
                    else {
                        $metadata = @{
                            pacOwnerId = $PacEnvironment.pacOwnerId
                        }
                    }
                    if (!$metadata.ContainsKey("deployedBy")) {
                        $metadata.deployedBy = $PacEnvironment.deployedBy
                    }

                    # bail if we encountered errors
                    if ($errorInfo.hasLocalErrors) {
                        continue
                    }
                    
                    #region check if the exemption already exists in Azure
                    $deployedManagedExemption = $null
                    if ($deployedManagedExemptions.ContainsKey($id)) {
                        $deployedManagedExemption = $deployedManagedExemptions.$id
                    }
                    else {
                        # try to find a matching deployed exemption
                        foreach ($possibleId in $deployedManagedExemptions.Keys) {
                            $deployedManagedExemption = $deployedManagedExemptions.$possibleId
                            $deployedName = $deployedManagedExemption.name
                            $deployedDisplayName = $deployedManagedExemption.displayName
                            $deployedPolicyAssignmentId = $deployedManagedExemption.policyAssignmentId
                            if ($deployedName.StartsWith($name) -and $deployedDisplayName.StartsWith($displayName) `
                                    -and $deployedPolicyAssignmentId -eq $policyAssignmentId) {
                                $oldFormat = $deployedName -match "^$($name)___\d{3}$"
                                if (-not $oldFormat) {
                                    $null = $uniqueIds.Remove($nameAugmented)
                                    $null = $uniqueIds.Add($deployedName, $true)
                                    $id = $possibleId
                                    $nameAugmented = $deployedName
                                    $displayNameAugmented = $deployedManagedExemption.displayName
                                    break
                                }
                                else {
                                    $deployedManagedExemption = $null
                                }
                            }
                            else {
                                $deployedManagedExemption = $null
                            }
                        }
                    }
                    #endregion check if the exemption already exists in Azure

                    #region create exemption object
                    $policyDefinitionReferenceIdsAugmentedArray = $policyDefinitionReferenceIdsAugmented.ToArray()
                    $exemption = [ordered]@{
                        id                           = $id
                        name                         = $nameAugmented
                        displayName                  = $displayNameAugmented
                        description                  = $description
                        exemptionCategory            = $exemptionCategory
                        expiresOn                    = $expiresOn
                        scope                        = $scope
                        policyAssignmentId           = $policyAssignmentId
                        assignmentScopeValidation    = $assignmentScopeValidation
                        policyDefinitionReferenceIds = $policyDefinitionReferenceIdsAugmentedArray
                        resourceSelectors            = $resourceSelectors
                        metadata                     = $metadata
                    }
                    #endregion create exemption object

                    #region calculate desired state mandated changes
                    if ($null -ne $deployedManagedExemption) {
                        $deleteCandidates.Remove($id)
                        if ($deployedManagedExemption.policyAssignmentId -ne $policyAssignmentId) {
                            # Replaced Assignment
                            if ($isMultipleAssignments) {
                                Write-Information "Replace(ordinal) '$($nameAugmented)', '$($scope)' from '$($deployedManagedExemption.policyAssignmentId)' to '$($policyAssignmentId)"
                            }
                            else {
                                Write-Information "Replace(assignmentId) '$($nameAugmented)', '$($scope)' from '$($deployedManagedExemption.policyAssignmentId)' to '$($policyAssignmentId)'"
                            }
                            $null = $Exemptions.replace.Add($id, $exemption)
                            $Exemptions.numberOfChanges++
                        }
                        elseif ($replacedAssignments.ContainsKey($policyAssignmentId)) {
                            # Replaced Assignment
                            Write-Information "Replace(replaced assignment) '$($nameAugmented)', '$($scope)', assignmentId '$($deployedManagedExemption.policyAssignmentId)'"
                            $null = $Exemptions.replace.Add($id, $exemption)
                            $Exemptions.numberOfChanges++
                        }
                        else {
                            # Maybe update existing Exemption
                            $displayNameMatches = $deployedManagedExemption.displayName -eq $displayNameAugmented
                            $descriptionMatches = ($deployedManagedExemption.description -eq $description) `
                                -or ([string]::IsNullOrWhiteSpace($deployedManagedExemption.description) -and [string]::IsNullOrWhiteSpace($description))
                            $exemptionCategoryMatches = $deployedManagedExemption.exemptionCategory -eq $exemptionCategory
                            $expiresOnMatches = $deployedManagedExemption.expiresOn -eq $expiresOn
                            $clearExpiration = !$expiresOnMatches -and $null -eq $expiresOn
                            $deployedPolicyDefinitionReferenceIdsArray = $deployedManagedExemption.policyDefinitionReferenceIds
                            if ($null -ne $deployedPolicyDefinitionReferenceIdsArray -and $deployedPolicyDefinitionReferenceIdsArray -isnot [array]) {
                                $deployedPolicyDefinitionReferenceIdsArray = @($deployedPolicyDefinitionReferenceIdsArray)
                            }
                            $policyDefinitionReferenceIdsMatches = Confirm-ObjectValueEqualityDeep $deployedPolicyDefinitionReferenceIdsArray $policyDefinitionReferenceIdsAugmentedArray
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
                                Write-Information "Update($changesString) '$($displayNameAugmented)'($($nameAugmented)), '$($scope)'"
                            }
                        }
                    }
                    else {
                        # Create Exemption
                        Write-Information "New '$($displayNameAugmented)'($($nameAugmented)), '$($scope)'"
                        $null = $Exemptions.new.Add($id, $exemption)
                        $Exemptions.numberOfChanges++
                    }

                    #endregion calculate desired state mandated changes
                }
            }    

            if ($errorInfo.hasErrors) {
                Write-ErrorsFromErrorInfo -ErrorInfo $errorInfo
                $numberOfFilesWithErrors++
                continue
            }
        }
            
        if ($numberOfFilesWithErrors -gt 0) {
            Write-Information ""
            throw "There were errors in $numberOfFilesWithErrors file(s)."
        }
    }

    #region delete removed, orphaned and expired exemptions
    foreach ($id in $deleteCandidates.Keys) {
        $exemption = $deleteCandidates.$id
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
                    $reason = "unknownOwner, strategy=owwnedOnly, status=$status"
                }
            }
            Default {
                throw "Code bug: pacOwner must be one of @('thisPac','otherPac','unknownOwner')"
            }
        }
        if ($shallDelete) {
            # check fo special Exemption cases
            Write-Information "Delete '$($exemption.displayName)'($($exemption.name)), '$($exemption.scope)', $reason"
            $null = $Exemptions.delete[$id] = $exemption
            $Exemptions.numberOfChanges++
        }
        else {
            Write-Verbose "Keep $($reason): '$($exemption.displayName)'($($exemption.name)), '$($exemption.scope)' $reason"
        }
    }
    #endregion delete removed, orphaned and expired exemptions

    if ($Exemptions.numberUnchanged -gt 0) {
        Write-Information "$($Exemptions.numberUnchanged) unchanged Exemptions"
    }
    Write-Information ""
}
