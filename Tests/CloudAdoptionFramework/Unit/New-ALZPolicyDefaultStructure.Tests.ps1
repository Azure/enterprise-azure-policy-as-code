BeforeAll {
    . (Join-Path $PSScriptRoot '..\Helpers\CloudAdoptionFrameworkTestHelpers.ps1')
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $script:NewScript = Join-Path $script:RepoRoot 'Scripts\CloudAdoptionFramework\New-ALZPolicyDefaultStructure.ps1'
}

Describe 'New-ALZPolicyDefaultStructure' {
    It 'creates ALZ structure output with selector suffix and ALZ-only defaults' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library') -Types @('ALZ')

        & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot

        $structurePath = Join-Path $definitionsRoot 'policyStructures\alz.policy_default_structure.epac-dev.jsonc'
        (Test-Path -Path $structurePath) | Should -BeTrue

        $structure = Get-TestJsonFile -Path $structurePath
        $structure.managementGroupNameMappings.alz.value | Should -Be '/providers/Microsoft.Management/managementGroups/alz'
        $structure.defaultParameterValues.base_effect[0].parameters.value | Should -Be 'Audit'
        $structure.defaultParameterValues.ama_mdfc_sql_workspace_id[0].parameters.value | Should -Be '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/monitoring-rg/providers/Microsoft.OperationalInsights/workspaces/sql-law'
        @($structure.PSObject.Properties.Name) | Should -Not -Contain 'archetypeScopeMappings'
    }

    It 'creates AMBA structure output and resolves underscore assignment filenames for defaults' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library') -Types @('AMBA')

        & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type AMBA -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot

        $structurePath = Join-Path $definitionsRoot 'policyStructures\amba.policy_default_structure.epac-dev.jsonc'
        (Test-Path -Path $structurePath) | Should -BeTrue

        $structure = Get-TestJsonFile -Path $structurePath
        $structure.defaultParameterValues.log_analytics_workspace_id_0[0].parameters.value | Should -Be '/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/amba-rg/providers/Microsoft.OperationalInsights/workspaces/amba-law'
        @($structure.PSObject.Properties.Name) | Should -Not -Contain 'archetypeScopeMappings'
    }

    It 'creates SLZ structure output with archetype scope mappings' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library') -Types @('SLZ')

        & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type SLZ -PacEnvironmentSelector 'epac-dev' -LibraryPath $libraryRoot

        $structurePath = Join-Path $definitionsRoot 'policyStructures\slz.policy_default_structure.epac-dev.jsonc'
        (Test-Path -Path $structurePath) | Should -BeTrue

        $structure = Get-TestJsonFile -Path $structurePath
        @($structure.archetypeScopeMappings.sovereign_l2_controls) | Should -Contain '/providers/Microsoft.Management/managementGroups/l2'
        @($structure.archetypeScopeMappings.sovereign_shared) | Should -Contain '/providers/Microsoft.Management/managementGroups/l2'
    }

    It 'supports tag-based generation when tag lookup and git clone are mocked' {
        $workspace = Join-Path $TestDrive 'Workspace'
        $definitionsRoot = Join-Path $workspace 'Definitions'
        $null = New-Item -Path $workspace -ItemType Directory -Force
        New-TestDefinitionsRoot -DefinitionsRootFolder $definitionsRoot | Out-Null

        $fixtureLibrary = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'SourceLibrary') -Types @('ALZ')
        $existingFunction = if (Test-Path Function:\Invoke-RestMethod) {
            (Get-Item Function:\Invoke-RestMethod).ScriptBlock
        }
        else {
            $null
        }

        Set-Item -Path Function:\Invoke-RestMethod -Value {
            param([string] $Uri)
            [PSCustomObject]@{
                ref = @('refs/tags/platform/alz/test-tag')
            }
        }

        Push-Location $workspace
        try {
            Invoke-WithMockedGitClone -CloneMap @{
                'https://github.com/Azure/Azure-Landing-Zones-Library.git' = $fixtureLibrary
            } -ScriptBlock {
                & $script:NewScript -DefinitionsRootFolder $definitionsRoot -Type ALZ -PacEnvironmentSelector 'epac-dev' -Tag 'platform/alz/test-tag'
            }
        }
        finally {
            Pop-Location
            if ($null -eq $existingFunction) {
                Remove-Item -Path Function:\Invoke-RestMethod -ErrorAction SilentlyContinue
            }
            else {
                Set-Item -Path Function:\Invoke-RestMethod -Value $existingFunction
            }
        }

        (Test-Path -Path (Join-Path $definitionsRoot 'policyStructures\alz.policy_default_structure.epac-dev.jsonc')) | Should -BeTrue
    }
}
