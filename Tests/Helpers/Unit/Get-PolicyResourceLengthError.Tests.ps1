BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Confirm-ValidPolicyResourceName.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-DeepCloneAsOrderedHashtable.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Build-AssignmentParameterObject.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Build-AssignmentDefinitionAtLeaf.ps1')

    function New-TestAssignmentDefinition {
        param (
            [string] $DisplayName = "Test Assignment",
            [string] $Description = "",
            [string] $EntryDisplayName = "",
            [string] $EntryDescription = ""
        )

        return @{
            nodeName            = "/root/test"
            assignment          = @{
                name        = "test-assignment"
                displayName = $DisplayName
                description = $Description
            }
            definitionEntryList = @(
                @{
                    policyDefinitionId = "/providers/Microsoft.Authorization/policyDefinitions/test-policy"
                    isPolicySet        = $false
                    assignment         = @{
                        append      = $true
                        name        = ""
                        displayName = $EntryDisplayName
                        description = $EntryDescription
                    }
                }
            )
            scopeCollection     = @(
                @{
                    scope = "/providers/Microsoft.Management/managementGroups/test-mg"
                }
            )
            metadata            = @{}
            parameters          = @{}
            enforcementMode     = "Default"
        }
    }

    function Invoke-TestLeaf {
        param (
            [hashtable] $AssignmentDefinition
        )

        return Build-AssignmentDefinitionAtLeaf `
            -PacEnvironment @{ pacOwnerId = "test-pac-owner" } `
            -AssignmentDefinition $AssignmentDefinition `
            -CombinedPolicyDetails @{
            policies   = @{
                "/providers/Microsoft.Authorization/policyDefinitions/test-policy" = @{
                    name       = "test-policy"
                    parameters = @{}
                }
            }
            policySets = @{}
        } `
            -PolicyRoleIds @{} `
            -RoleDefinitions @{}
    }
}

Describe 'Get-PolicyResourceLengthError' {
    It 'returns no errors at the limits' {
        $lengthErrors = Get-PolicyResourceLengthError -Name ('n' * 64) -DisplayName ('d' * 128) -Description ('x' * 512)

        $lengthErrors.Count | Should -Be 0
    }

    It 'returns no errors for null displayName and description' {
        $lengthErrors = Get-PolicyResourceLengthError -Name "test" -DisplayName $null -Description $null

        $lengthErrors.Count | Should -Be 0
    }

    It 'returns an error for each field over its limit' {
        $lengthErrors = Get-PolicyResourceLengthError -Name ('n' * 65) -DisplayName ('d' * 129) -Description ('x' * 552)

        $lengthErrors.Count | Should -Be 3
        $lengthErrors[0] | Should -Match "65 characters long \(max 64\)"
        $lengthErrors[1] | Should -Match "129 characters long \(max 128\)"
        $lengthErrors[2] | Should -Match "552 characters long \(max 512\)"
    }

    It 'uses MaxNameLength for the name' {
        $lengthErrors = Get-PolicyResourceLengthError -Name ('n' * 25) -MaxNameLength 24

        $lengthErrors.Count | Should -Be 1
        $lengthErrors[0] | Should -Match "max 24"
    }
}

Describe 'Build-AssignmentDefinitionAtLeaf displayName and description length' {
    It 'succeeds when the concatenated displayName and description are at the limits' {
        $assignmentDefinition = New-TestAssignmentDefinition `
            -DisplayName ('d' * 100) -EntryDisplayName ('d' * 28) `
            -Description ('x' * 500) -EntryDescription ('x' * 12)

        $hasErrors, $assignmentsList = Invoke-TestLeaf -AssignmentDefinition $assignmentDefinition

        $hasErrors | Should -BeFalse
        $assignmentsList.Count | Should -Be 1
    }

    It 'fails when the concatenated displayName is longer than 128 characters' {
        $assignmentDefinition = New-TestAssignmentDefinition -DisplayName ('d' * 100) -EntryDisplayName ('d' * 29)

        $Error.Clear()
        $hasErrors, $null = Invoke-TestLeaf -AssignmentDefinition $assignmentDefinition 2>$null

        $hasErrors | Should -BeTrue
        ($Error.Exception.Message -join "`n") | Should -Match "displayName .* is 129 characters long \(max 128\)"
    }

    It 'fails when the concatenated description is longer than 512 characters' {
        $assignmentDefinition = New-TestAssignmentDefinition -Description ('x' * 500) -EntryDescription ('x' * 13)

        $Error.Clear()
        $hasErrors, $null = Invoke-TestLeaf -AssignmentDefinition $assignmentDefinition 2>$null

        $hasErrors | Should -BeTrue
        ($Error.Exception.Message -join "`n") | Should -Match "description .* is 513 characters long \(max 512\)"
    }
}
