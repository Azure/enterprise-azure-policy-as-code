BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-DeepCloneAsOrderedHashtable.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Confirm-ObjectValueEqualityDeep.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Confirm-MetadataMatches.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Confirm-DeleteForStrategy.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Confirm-ValidPolicyResourceName.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Remove-NullFields.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Build-PolicyEnrollmentPlan.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-AzPolicyEnrollments.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/RestMethods/Set-AzPolicyAssignmentRestMethod.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/RestMethods/Set-AzPolicyEnrollmentRestMethod.ps1')

    function Write-ModernSection {}
    function Write-ModernStatus {}
    function Invoke-AzRestMethod {
        param($Path, $Method, $Payload)
        $script:lastRestCall = @{ Path = $Path; Method = $Method; Payload = $Payload }
        @{ StatusCode = 200; Content = '{}' }
    }
    function Search-AzGraphAllItems {
        param($Query, $ProgressItemName)
        $script:lastGraphQuery = $Query
        @()
    }

    function New-EnrollmentPlan {
        @{
            new             = @{}
            update          = @{}
            delete          = @{}
            numberOfChanges = 0
            numberUnchanged = 0
        }
    }

    $script:scope = '/subscriptions/00000000-0000-0000-0000-000000000000'
    $script:assignmentId = "$script:scope/providers/Microsoft.Authorization/policyAssignments/enrollable"
    $script:enrollmentId = "$script:scope/providers/Microsoft.Authorization/policyEnrollments/test-enrollment"
    $script:pacEnvironment = @{
        pacOwnerId  = 'epac-test'
        desiredState = @{
            strategy = 'ownedOnly'
        }
    }
}

Describe 'Build-PolicyEnrollmentPlan' {
    BeforeEach {
        $script:enrollmentsFolder = Join-Path $TestDrive 'policyEnrollments'
        Remove-Item -Path $script:enrollmentsFolder -Recurse -Force -ErrorAction SilentlyContinue
        $null = New-Item -Path $script:enrollmentsFolder -ItemType Directory
    }

    It 'plans a new enrollment and injects EPAC ownership metadata' {
        @{
            name               = 'test-enrollment'
            scope              = $script:scope
            displayName        = 'Test enrollment'
            policyAssignmentId = $script:assignmentId
        } | ConvertTo-Json | Set-Content (Join-Path $script:enrollmentsFolder 'enrollment.json')
        $plan = New-EnrollmentPlan

        Build-PolicyEnrollmentPlan -EnrollmentsRootFolder $script:enrollmentsFolder -PacEnvironment $script:pacEnvironment -DeployedEnrollments @{ managed = @{} } -Enrollments $plan

        $plan.new.Count | Should -Be 1
        $plan.new[$script:enrollmentId].metadata.pacOwnerId | Should -Be 'epac-test'
        $plan.new[$script:enrollmentId].assignmentScopeValidation | Should -Be 'Default'
    }

    It 'compares every field and plans an update when one changes' {
        @{
            name                         = 'test-enrollment'
            scope                        = $script:scope
            displayName                  = 'Test enrollment'
            description                  = 'new description'
            policyAssignmentId           = $script:assignmentId
            policyDefinitionReferenceIds = @('reference-1')
            resourceSelectors            = @(@{ name = 'locations'; selectors = @(@{ kind = 'resourceLocation'; in = @('eastus') }) })
        } | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $script:enrollmentsFolder 'enrollment.json')
        $deployed = @{
            id                           = $script:enrollmentId
            name                         = 'test-enrollment'
            scope                        = $script:scope
            displayName                  = 'Test enrollment'
            description                  = 'old description'
            metadata                     = @{ pacOwnerId = 'epac-test' }
            policyAssignmentId           = $script:assignmentId
            policyDefinitionReferenceIds = @('reference-1')
            resourceSelectors            = @(@{ name = 'locations'; selectors = @(@{ kind = 'resourceLocation'; in = @('eastus') }) })
            assignmentScopeValidation    = 'Default'
            pacOwner                     = 'thisPaC'
        }
        $plan = New-EnrollmentPlan

        Build-PolicyEnrollmentPlan -EnrollmentsRootFolder $script:enrollmentsFolder -PacEnvironment $script:pacEnvironment -DeployedEnrollments @{ managed = @{ $script:enrollmentId = $deployed } } -Enrollments $plan

        $plan.update.Count | Should -Be 1
        $plan.numberOfChanges | Should -Be 1
    }

    It 'does not update an unchanged enrollment' {
        @{
            name               = 'test-enrollment'
            scope              = $script:scope
            displayName        = 'Test enrollment'
            policyAssignmentId = $script:assignmentId
        } | ConvertTo-Json | Set-Content (Join-Path $script:enrollmentsFolder 'enrollment.json')
        $deployed = @{
            id                           = $script:enrollmentId
            name                         = 'test-enrollment'
            scope                        = $script:scope
            displayName                  = 'Test enrollment'
            description                  = $null
            metadata                     = @{ pacOwnerId = 'epac-test' }
            policyAssignmentId           = $script:assignmentId
            policyDefinitionReferenceIds = $null
            resourceSelectors            = $null
            assignmentScopeValidation    = 'Default'
            pacOwner                     = 'thisPaC'
        }
        $plan = New-EnrollmentPlan

        Build-PolicyEnrollmentPlan -EnrollmentsRootFolder $script:enrollmentsFolder -PacEnvironment $script:pacEnvironment -DeployedEnrollments @{ managed = @{ $script:enrollmentId = $deployed } } -Enrollments $plan

        $plan.numberUnchanged | Should -Be 1
        $plan.numberOfChanges | Should -Be 0
    }

    It 'deletes an owned enrollment missing from the files' {
        $deployed = @{ id = $script:enrollmentId; pacOwner = 'thisPaC'; name = 'test-enrollment' }
        $plan = New-EnrollmentPlan

        Build-PolicyEnrollmentPlan -EnrollmentsRootFolder $script:enrollmentsFolder -PacEnvironment $script:pacEnvironment -DeployedEnrollments @{ managed = @{ $script:enrollmentId = $deployed } } -Enrollments $plan

        $plan.delete.Count | Should -Be 1
    }
}

Describe 'Get-AzPolicyEnrollments' {
    It 'uses the policy enrollments ARG query' {
        $script:lastGraphQuery = $null
        $resources = @{ policyenrollments = @{ managed = @{}; counters = @{ managedBy = @{ thisPaC = 0; otherPaC = 0; unknown = 0 } } } }
        $environment = @{ tenantId = 'tenant'; pacOwnerId = 'owner'; desiredState = @{ excludedPolicyAssignments = @() } }
        $scopeTable = @{ root = @{ excludedScopesTable = @{} } }

        Get-AzPolicyEnrollments -DeployedPolicyResources $resources -PacEnvironment $environment -ScopeTable $scopeTable

        $script:lastGraphQuery | Should -Be "policyresources | where type =~ 'microsoft.authorization/policyenrollments'"
    }
}

Describe 'Set-AzPolicyEnrollmentRestMethod' {
    It 'puts all enrollment properties to the resource id' {
        $script:lastRestCall = $null
        $enrollment = @{
            id                           = $script:enrollmentId
            displayName                  = 'Test enrollment'
            description                  = 'Description'
            metadata                     = @{ pacOwnerId = 'epac-test' }
            policyAssignmentId           = $script:assignmentId
            policyDefinitionReferenceIds = @('reference-1')
            resourceSelectors            = @()
            assignmentScopeValidation    = 'Default'
        }

        Set-AzPolicyEnrollmentRestMethod -EnrollmentObj $enrollment -ApiVersion '2026-01-01-preview'

        $script:lastRestCall.Path | Should -Be "$script:enrollmentId`?api-version=2026-01-01-preview"
        $script:lastRestCall.Method | Should -Be 'PUT'
        ($script:lastRestCall.Payload | ConvertFrom-Json).properties.policyAssignmentId | Should -Be $script:assignmentId
    }
}

Describe 'Set-AzPolicyAssignmentRestMethod enrollment mode' {
    It 'uses API version 2026-01-01-preview for an Enroll assignment' {
        $script:lastRestCall = $null
        $assignment = @{
            id                 = $script:assignmentId
            displayName        = 'Enrollable assignment'
            description        = 'Description'
            metadata           = @{}
            policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/test'
            enforcementMode    = 'Enroll'
            parameters         = @{}
            notScopes          = @()
            identityRequired   = $false
        }

        Set-AzPolicyAssignmentRestMethod -AssignmentObj $assignment -ApiVersion '2023-04-01'

        $script:lastRestCall.Path | Should -Be "$script:assignmentId`?api-version=2026-01-01-preview"
    }
}