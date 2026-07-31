function Build-PolicyEnrollmentPlan {
    [CmdletBinding()]
    param (
        [string] $EnrollmentsRootFolder,
        $PacEnvironment,
        $DeployedEnrollments,
        $Enrollments
    )

    Write-ModernSection -Title "Processing Policy Enrollments (Preview)" -Color Blue
    Write-ModernStatus -Message "Source folder: $EnrollmentsRootFolder" -Status "info" -Indent 2

    [array] $enrollmentFiles = @()
    $enrollmentFiles += Get-ChildItem -Path $EnrollmentsRootFolder -Recurse -File -Filter "*.json"
    $enrollmentFiles += Get-ChildItem -Path $EnrollmentsRootFolder -Recurse -File -Filter "*.jsonc"
    if ($enrollmentFiles.Length -gt 0) {
        Write-ModernStatus -Message "Found $($enrollmentFiles.Length) policy enrollment files" -Status "success" -Indent 2
    }
    else {
        Write-ModernStatus -Message "No policy enrollment files found - managed enrollments may be deleted" -Status "warning" -Indent 2
    }

    $deployedManagedEnrollments = $DeployedEnrollments.managed
    $deleteCandidates = $deployedManagedEnrollments.Clone()
    $desiredStateStrategy = $PacEnvironment.desiredState.strategy
    $uniqueIds = @{}

    foreach ($enrollmentFile in $enrollmentFiles) {
        Write-ModernStatus -Message "Processing policy enrollment file '$($enrollmentFile.FullName)'" -Status "info" -Indent 2
        $content = Get-Content -Path $enrollmentFile.FullName -Raw -ErrorAction Stop
        try {
            $definedEnrollment = ConvertFrom-Json $content -AsHashTable -Depth 100
        }
        catch {
            throw "Policy Enrollment JSON file '$($enrollmentFile.FullName)' is not valid."
        }

        $name = $definedEnrollment.name
        $policyAssignmentId = $definedEnrollment.policyAssignmentId
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($policyAssignmentId)) {
            throw "Policy Enrollment file '$($enrollmentFile.FullName)' must define name and policyAssignmentId."
        }
        if (-not (Confirm-ValidPolicyResourceName -Name $name)) {
            throw "Policy Enrollment name '$name' in '$($enrollmentFile.FullName)' contains invalid characters or ends with a space."
        }

        $hasScope = -not [string]::IsNullOrWhiteSpace($definedEnrollment.scope)
        $hasScopes = $null -ne $definedEnrollment.scopes
        if ($hasScope -eq $hasScopes) {
            throw "Policy Enrollment file '$($enrollmentFile.FullName)' must define exactly one of scope or scopes."
        }
        if ($hasScope) {
            $scopes = @($definedEnrollment.scope)
        }
        else {
            $scopes = $definedEnrollment.scopes
            if ($scopes -isnot [array] -or $scopes.Count -eq 0) {
                throw "Policy Enrollment scopes in '$($enrollmentFile.FullName)' must be a non-empty array of strings."
            }
            foreach ($scope in $scopes) {
                if ($scope -isnot [string] -or [string]::IsNullOrWhiteSpace($scope)) {
                    throw "Policy Enrollment scopes in '$($enrollmentFile.FullName)' must be a non-empty array of strings."
                }
            }
        }

        $assignmentScopeValidation = $definedEnrollment.assignmentScopeValidation
        if ([string]::IsNullOrWhiteSpace($assignmentScopeValidation)) {
            $assignmentScopeValidation = "Default"
        }
        elseif ($assignmentScopeValidation -notin @("Default", "DoNotValidate")) {
            throw "Policy Enrollment assignmentScopeValidation '$assignmentScopeValidation' in '$($enrollmentFile.FullName)' must be Default or DoNotValidate."
        }

        $metadata = @{}
        if ($null -ne $definedEnrollment.metadata) {
            $metadata = Get-DeepCloneAsOrderedHashtable $definedEnrollment.metadata
        }
        if ($metadata.ContainsKey("pacOwnerId")) {
            throw "Policy Enrollment metadata.pacOwnerId is reserved for EPAC usage in '$($enrollmentFile.FullName)'."
        }
        $metadata.pacOwnerId = $PacEnvironment.pacOwnerId

        foreach ($scope in $scopes) {
            $id = "$scope/providers/Microsoft.Authorization/policyEnrollments/$name"
            if ($uniqueIds.ContainsKey($id)) {
                throw "Duplicate Policy Enrollment id '$id' in '$($enrollmentFile.FullName)' and '$($uniqueIds[$id])'."
            }
            $uniqueIds[$id] = $enrollmentFile.FullName
            $displayLabel = if ([string]::IsNullOrWhiteSpace($definedEnrollment.displayName)) { $name } else { $definedEnrollment.displayName }

            $enrollment = [ordered]@{
                id                           = $id
                name                         = $name
                scope                        = $scope
                displayName                  = $definedEnrollment.displayName
                description                  = $definedEnrollment.description
                metadata                     = $metadata
                policyAssignmentId           = $policyAssignmentId
                policyDefinitionReferenceIds = $definedEnrollment.policyDefinitionReferenceIds
                resourceSelectors            = $definedEnrollment.resourceSelectors
                assignmentScopeValidation    = $assignmentScopeValidation
            }

            if ($deployedManagedEnrollments.ContainsKey($id)) {
                $deleteCandidates.Remove($id)
                $deployedEnrollment = $deployedManagedEnrollments[$id]
                $metadataMatches, $changePacOwnerId = Confirm-MetadataMatches `
                    -ExistingMetadataObj $deployedEnrollment.metadata `
                    -DefinedMetadataObj $metadata

                $displayNameMatches = $deployedEnrollment.displayName -eq $enrollment.displayName
                $descriptionMatches = $deployedEnrollment.description -eq $enrollment.description
                $policyAssignmentIdMatches = $deployedEnrollment.policyAssignmentId -eq $enrollment.policyAssignmentId
                $assignmentScopeValidationMatches = $deployedEnrollment.assignmentScopeValidation -eq $enrollment.assignmentScopeValidation
                $policyDefinitionReferenceIdsMatch = Confirm-ObjectValueEqualityDeep $deployedEnrollment.policyDefinitionReferenceIds $enrollment.policyDefinitionReferenceIds
                $resourceSelectorsMatch = Confirm-ObjectValueEqualityDeep $deployedEnrollment.resourceSelectors $enrollment.resourceSelectors
                $matches = `
                    $displayNameMatches `
                    -and $descriptionMatches `
                    -and $policyAssignmentIdMatches `
                    -and $assignmentScopeValidationMatches `
                    -and $policyDefinitionReferenceIdsMatch `
                    -and $resourceSelectorsMatch `
                    -and $metadataMatches `
                    -and -not $changePacOwnerId

                if ($matches) {
                    $Enrollments.numberUnchanged++
                }
                else {
                    $changes = [System.Collections.ArrayList]::new()
                    if (-not $displayNameMatches) { $null = $changes.Add("displayName") }
                    if (-not $descriptionMatches) { $null = $changes.Add("description") }
                    if (-not $policyAssignmentIdMatches) { $null = $changes.Add("policyAssignmentId") }
                    if (-not $assignmentScopeValidationMatches) { $null = $changes.Add("assignmentScopeValidation") }
                    if (-not $policyDefinitionReferenceIdsMatch) { $null = $changes.Add("policyDefinitionReferenceIds") }
                    if (-not $resourceSelectorsMatch) { $null = $changes.Add("resourceSelectors") }
                    if (-not $metadataMatches -or $changePacOwnerId) { $null = $changes.Add("metadata") }
                    Write-ModernStatus -Message "Update ($($changes -join ', ')): '$displayLabel' at scope '$scope'" -Status "update" -Indent 4
                    $Enrollments.update[$id] = $enrollment
                    $Enrollments.numberOfChanges++
                }
            }
            else {
                Write-ModernStatus -Message "New: '$displayLabel' at scope '$scope'" -Status "success" -Indent 4
                $Enrollments.new[$id] = $enrollment
                $Enrollments.numberOfChanges++
            }
        }
    }

    foreach ($id in $deleteCandidates.Keys) {
        $deployedEnrollment = $deleteCandidates[$id]
        if (Confirm-DeleteForStrategy -PacOwner $deployedEnrollment.pacOwner -Strategy $desiredStateStrategy) {
            $displayLabel = if ([string]::IsNullOrWhiteSpace($deployedEnrollment.displayName)) { $deployedEnrollment.name } else { $deployedEnrollment.displayName }
            Write-ModernStatus -Message "Delete: '$displayLabel' at scope '$($deployedEnrollment.scope)'" -Status "error" -Indent 4
            $Enrollments.delete[$id] = $deployedEnrollment
            $Enrollments.numberOfChanges++
        }
        else {
            Write-ModernStatus -Message "Skip delete ($($deployedEnrollment.pacOwner),$desiredStateStrategy): '$($deployedEnrollment.name)' at scope '$($deployedEnrollment.scope)'" -Status "skip" -Indent 4
        }
    }

    if ($Enrollments.numberUnchanged -gt 0) {
        Write-ModernStatus -Message "Unchanged Policy Enrollments: $($Enrollments.numberUnchanged)" -Status "status" -Indent 2
    }
}