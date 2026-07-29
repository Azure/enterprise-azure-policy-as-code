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

    $deployedManagedEnrollments = $DeployedEnrollments.managed
    $deleteCandidates = $deployedManagedEnrollments.Clone()
    $desiredStateStrategy = $PacEnvironment.desiredState.strategy
    $uniqueIds = @{}

    foreach ($enrollmentFile in $enrollmentFiles) {
        $content = Get-Content -Path $enrollmentFile.FullName -Raw -ErrorAction Stop
        try {
            $definedEnrollment = ConvertFrom-Json $content -AsHashTable -Depth 100
        }
        catch {
            throw "Policy Enrollment JSON file '$($enrollmentFile.FullName)' is not valid."
        }

        $name = $definedEnrollment.name
        $scope = $definedEnrollment.scope
        $policyAssignmentId = $definedEnrollment.policyAssignmentId
        if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($scope) -or [string]::IsNullOrWhiteSpace($policyAssignmentId)) {
            throw "Policy Enrollment file '$($enrollmentFile.FullName)' must define name, scope, and policyAssignmentId."
        }
        if (-not (Confirm-ValidPolicyResourceName -Name $name)) {
            throw "Policy Enrollment name '$name' in '$($enrollmentFile.FullName)' contains invalid characters or ends with a space."
        }

        $assignmentScopeValidation = $definedEnrollment.assignmentScopeValidation
        if ([string]::IsNullOrWhiteSpace($assignmentScopeValidation)) {
            $assignmentScopeValidation = "Default"
        }
        elseif ($assignmentScopeValidation -notin @("Default", "DoNotValidate")) {
            throw "Policy Enrollment assignmentScopeValidation '$assignmentScopeValidation' in '$($enrollmentFile.FullName)' must be Default or DoNotValidate."
        }

        $id = "$scope/providers/Microsoft.Authorization/policyEnrollments/$name"
        if ($uniqueIds.ContainsKey($id)) {
            throw "Duplicate Policy Enrollment id '$id' in '$($enrollmentFile.FullName)' and '$($uniqueIds[$id])'."
        }
        $uniqueIds[$id] = $enrollmentFile.FullName

        $metadata = @{}
        if ($null -ne $definedEnrollment.metadata) {
            $metadata = Get-DeepCloneAsOrderedHashtable $definedEnrollment.metadata
        }
        if ($metadata.ContainsKey("pacOwnerId")) {
            throw "Policy Enrollment metadata.pacOwnerId is reserved for EPAC usage in '$($enrollmentFile.FullName)'."
        }
        $metadata.pacOwnerId = $PacEnvironment.pacOwnerId

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

            $matches = `
                $deployedEnrollment.displayName -eq $enrollment.displayName `
                -and $deployedEnrollment.description -eq $enrollment.description `
                -and $deployedEnrollment.policyAssignmentId -eq $enrollment.policyAssignmentId `
                -and $deployedEnrollment.assignmentScopeValidation -eq $enrollment.assignmentScopeValidation `
                -and (Confirm-ObjectValueEqualityDeep $deployedEnrollment.policyDefinitionReferenceIds $enrollment.policyDefinitionReferenceIds) `
                -and (Confirm-ObjectValueEqualityDeep $deployedEnrollment.resourceSelectors $enrollment.resourceSelectors) `
                -and $metadataMatches `
                -and -not $changePacOwnerId

            if ($matches) {
                $Enrollments.numberUnchanged++
            }
            else {
                $Enrollments.update[$id] = $enrollment
                $Enrollments.numberOfChanges++
            }
        }
        else {
            $Enrollments.new[$id] = $enrollment
            $Enrollments.numberOfChanges++
        }
    }

    foreach ($id in $deleteCandidates.Keys) {
        $deployedEnrollment = $deleteCandidates[$id]
        if (Confirm-DeleteForStrategy -PacOwner $deployedEnrollment.pacOwner -Strategy $desiredStateStrategy) {
            $Enrollments.delete[$id] = $deployedEnrollment
            $Enrollments.numberOfChanges++
        }
    }
}