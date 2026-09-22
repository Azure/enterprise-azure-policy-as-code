BeforeAll {
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Confirm-ValidPolicyResourceName.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Get-DeepCloneAsOrderedHashtable.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Build-AssignmentParameterObject.ps1')
    . (Join-Path $PSScriptRoot '../../../Scripts/Helpers/Build-AssignmentDefinitionAtLeaf.ps1')

    function New-TestAssignmentDefinition {
        param (
            [string] $Name,
            [string] $Scope = "/providers/Microsoft.Management/managementGroups/test-mg"
        )

        return @{
            nodeName            = "/root/test"
            assignment          = @{
                name        = $Name
                displayName = "Test Assignment"
                description = ""
            }
            definitionEntryList = @(
                @{
                    policyDefinitionId = "/providers/Microsoft.Authorization/policyDefinitions/test-policy"
                    isPolicySet        = $false
                    assignment         = @{
                        append      = $false
                        name        = ""
                        displayName = ""
                        description = ""
                    }
                }
            )
            scopeCollection     = @(
                @{
                    scope = $Scope
                }
            )
            metadata            = @{}
            parameters          = @{}
            enforcementMode     = "Default"
        }
    }

    $script:pacEnvironment = @{
        pacOwnerId = "test-pac-owner"
    }

    $script:combinedPolicyDetails = @{
        policies   = @{
            "/providers/Microsoft.Authorization/policyDefinitions/test-policy" = @{
                name       = "test-policy"
                parameters = @{}
            }
        }
        policySets = @{}
    }
}

Describe 'Build-AssignmentDefinitionAtLeaf assignment name length' {
    It 'fails when the assignment name is longer than 24 characters at Management Group scope' {
        $assignmentDefinition = New-TestAssignmentDefinition -Name "this-assignment-name-is-way-too-long"

        $Error.Clear()
        $hasErrors, $null = Build-AssignmentDefinitionAtLeaf `
            -PacEnvironment $script:pacEnvironment `
            -AssignmentDefinition $assignmentDefinition `
            -CombinedPolicyDetails $script:combinedPolicyDetails `
            -PolicyRoleIds @{} `
            -RoleDefinitions @{} 2>$null

        $hasErrors | Should -BeTrue
        ($Error | Out-String) | Should -Match "24 characters"
    }

    It 'succeeds when the assignment name is 24 characters or shorter at Management Group scope' {
        $assignmentDefinition = New-TestAssignmentDefinition -Name "short-assignment-name"

        $hasErrors, $assignmentsList = Build-AssignmentDefinitionAtLeaf `
            -PacEnvironment $script:pacEnvironment `
            -AssignmentDefinition $assignmentDefinition `
            -CombinedPolicyDetails $script:combinedPolicyDetails `
            -PolicyRoleIds @{} `
            -RoleDefinitions @{}

        $hasErrors | Should -BeFalse
        $assignmentsList.Count | Should -Be 1
    }

    It 'succeeds when the assignment name is longer than 24 but at most 64 characters at Subscription scope' {
        $assignmentDefinition = New-TestAssignmentDefinition `
            -Name "this-assignment-name-is-way-too-long-for-a-management-group" `
            -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"

        $hasErrors, $assignmentsList = Build-AssignmentDefinitionAtLeaf `
            -PacEnvironment $script:pacEnvironment `
            -AssignmentDefinition $assignmentDefinition `
            -CombinedPolicyDetails $script:combinedPolicyDetails `
            -PolicyRoleIds @{} `
            -RoleDefinitions @{}

        $hasErrors | Should -BeFalse
        $assignmentsList.Count | Should -Be 1
    }

    It 'succeeds when the assignment name is longer than 24 but at most 64 characters at Resource Group scope' {
        $assignmentDefinition = New-TestAssignmentDefinition `
            -Name "this-assignment-name-is-way-too-long-for-a-management-group" `
            -Scope "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test-rg"

        $hasErrors, $assignmentsList = Build-AssignmentDefinitionAtLeaf `
            -PacEnvironment $script:pacEnvironment `
            -AssignmentDefinition $assignmentDefinition `
            -CombinedPolicyDetails $script:combinedPolicyDetails `
            -PolicyRoleIds @{} `
            -RoleDefinitions @{}

        $hasErrors | Should -BeFalse
        $assignmentsList.Count | Should -Be 1
    }

    It 'fails when the assignment name is longer than 64 characters at Subscription scope' {
        $assignmentDefinition = New-TestAssignmentDefinition `
            -Name "this-assignment-name-is-way-too-long-for-a-subscription-scope-assignment-too" `
            -Scope "/subscriptions/00000000-0000-0000-0000-000000000000"

        $Error.Clear()
        $hasErrors, $null = Build-AssignmentDefinitionAtLeaf `
            -PacEnvironment $script:pacEnvironment `
            -AssignmentDefinition $assignmentDefinition `
            -CombinedPolicyDetails $script:combinedPolicyDetails `
            -PolicyRoleIds @{} `
            -RoleDefinitions @{} 2>$null

        $hasErrors | Should -BeTrue
        ($Error | Out-String) | Should -Match "64 characters"
    }
}
