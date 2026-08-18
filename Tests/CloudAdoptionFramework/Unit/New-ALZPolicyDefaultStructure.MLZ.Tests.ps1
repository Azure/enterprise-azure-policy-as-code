BeforeAll {
    $script:StructureScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/New-ALZPolicyDefaultStructure.ps1'
    $script:SchemaPath = Join-Path $PSScriptRoot '../../../Schemas/policy-structure-schema.json'

    function Invoke-MlzStructureScript {
        param(
            [Parameter(Mandatory = $true)]
            [string] $DefinitionsRoot,

            [string] $PacEnvironmentSelector = 'epac-dev',

            [Parameter(Mandatory = $true)]
            [string] $WorkingDirectory
        )

        $runnerPath = Join-Path $WorkingDirectory 'run-structure.ps1'
        Set-Content -Path $runnerPath -Value @"
Set-Location '$($WorkingDirectory.Replace("'", "''"))'
& '$($script:StructureScriptPath.Replace("'", "''"))' -DefinitionsRootFolder '$($DefinitionsRoot.Replace("'", "''"))' -Type MLZ -PacEnvironmentSelector '$($PacEnvironmentSelector.Replace("'", "''"))'
"@

        & pwsh -NoLogo -NoProfile -File $runnerPath | Out-Null
        return $LASTEXITCODE
    }
}

Describe 'New-ALZPolicyDefaultStructure MLZ' {
    It 'creates a Mission Landing Zone structure file with a subscription scope placeholder' {
        $definitionsRoot = Join-Path $TestDrive 'Definitions'
        $workingDirectory = Join-Path $TestDrive 'work'
        New-Item -ItemType Directory -Path $definitionsRoot, $workingDirectory -Force | Out-Null

        Invoke-MlzStructureScript -DefinitionsRoot $definitionsRoot -WorkingDirectory $workingDirectory | Should -Be 0

        $structureFile = Join-Path $definitionsRoot 'policyStructures/mlz.policy_default_structure.epac-dev.jsonc'
        Test-Path $structureFile | Should -BeTrue

        $structure = Get-Content -Path $structureFile -Raw | ConvertFrom-Json

        $structure.'$schema' | Should -Be 'https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-structure-schema.json'
        $structure.enforcementMode | Should -Be 'Default'

        @($structure.managementGroupNameMappings.PSObject.Properties.Name) | Should -Be @('mlz')
        $structure.managementGroupNameMappings.mlz.management_group_function | Should -Be 'Mission Landing Zone'
        $structure.managementGroupNameMappings.mlz.value | Should -Be '/subscriptions/00000000-0000-0000-0000-000000000000'
    }

    It 'stubs defaultParameterValues so they are populated during the sync step' {
        $definitionsRoot = Join-Path $TestDrive 'Definitions-defaults'
        $workingDirectory = Join-Path $TestDrive 'work-defaults'
        New-Item -ItemType Directory -Path $definitionsRoot, $workingDirectory -Force | Out-Null

        Invoke-MlzStructureScript -DefinitionsRoot $definitionsRoot -WorkingDirectory $workingDirectory | Should -Be 0

        $structure = Get-Content -Path (Join-Path $definitionsRoot 'policyStructures/mlz.policy_default_structure.epac-dev.jsonc') -Raw | ConvertFrom-Json

        @($structure.defaultParameterValues.PSObject.Properties).Count | Should -Be 0
        @($structure.enforceGuardrails.deployments).Count | Should -Be 0
        $structure.PSObject.Properties.Name | Should -Not -Contain 'archetypeScopeMappings'
    }

    It 'produces a structure file that validates against the policy structure schema' {
        $definitionsRoot = Join-Path $TestDrive 'Definitions-schema'
        $workingDirectory = Join-Path $TestDrive 'work-schema'
        New-Item -ItemType Directory -Path $definitionsRoot, $workingDirectory -Force | Out-Null

        Invoke-MlzStructureScript -DefinitionsRoot $definitionsRoot -WorkingDirectory $workingDirectory | Should -Be 0

        $structureContent = Get-Content -Path (Join-Path $definitionsRoot 'policyStructures/mlz.policy_default_structure.epac-dev.jsonc') -Raw
        $structureContent | Test-Json -SchemaFile $script:SchemaPath | Should -BeTrue
    }

    It 'does not clone a library repository because MLZ needs no library content' {
        $definitionsRoot = Join-Path $TestDrive 'Definitions-noclone'
        $workingDirectory = Join-Path $TestDrive 'work-noclone'
        New-Item -ItemType Directory -Path $definitionsRoot, $workingDirectory -Force | Out-Null

        Invoke-MlzStructureScript -DefinitionsRoot $definitionsRoot -WorkingDirectory $workingDirectory | Should -Be 0

        Test-Path (Join-Path $workingDirectory 'temp') | Should -BeFalse
    }

    It 'honours the PAC environment selector in the output file name' {
        $definitionsRoot = Join-Path $TestDrive 'Definitions-env'
        $workingDirectory = Join-Path $TestDrive 'work-env'
        New-Item -ItemType Directory -Path $definitionsRoot, $workingDirectory -Force | Out-Null

        Invoke-MlzStructureScript -DefinitionsRoot $definitionsRoot -PacEnvironmentSelector 'tenant1' -WorkingDirectory $workingDirectory | Should -Be 0

        Test-Path (Join-Path $definitionsRoot 'policyStructures/mlz.policy_default_structure.tenant1.jsonc') | Should -BeTrue
    }
}
