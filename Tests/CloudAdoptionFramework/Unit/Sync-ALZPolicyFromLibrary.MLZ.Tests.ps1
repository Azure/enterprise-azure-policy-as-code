BeforeAll {
    $script:SyncScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/Sync-ALZPolicyFromLibrary.ps1')).Path

    # Builds a minimal Definitions tree plus a fake missionlz checkout so the sync never needs the
    # network. Returns the paths the tests assert against.
    function New-MlzFixture {
        param(
            [Parameter(Mandatory = $true)]
            [string] $Root,

            [Parameter(Mandatory = $true)]
            [string] $Cloud,

            [Parameter(Mandatory = $true)]
            [string] $PacEnvironmentSelector,

            [string] $LogAnalyticsResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/law',

            [string] $Scope = '/subscriptions/22222222-2222-2222-2222-222222222222'
        )

        $definitionsRoot = Join-Path $Root 'Definitions'
        $libraryRoot = Join-Path $Root 'missionlz'

        foreach ($path in @(
                (Join-Path $definitionsRoot 'policyStructures')
                (Join-Path $definitionsRoot 'policyAssignments')
                (Join-Path $libraryRoot 'src/policies')
            )) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        Set-Content -Path (Join-Path $definitionsRoot 'global-settings.jsonc') -Value @"
{
  "telemetryOptOut": true,
  "pacEnvironments": [
    {
      "pacSelector": "$PacEnvironmentSelector",
      "cloud": "$Cloud",
      "tenantId": "00000000-0000-0000-0000-000000000000",
      "deploymentRootScope": "$Scope"
    }
  ]
}
"@

        # missionlz stores parameters as { "name": { "value": x } }.
        Set-Content -Path (Join-Path $libraryRoot 'src/policies/CMMC-policyAssignmentParameters.json') -Value '{ "cmmcOnly": { "value": "cmmc" }, "IncludeArcMachines": { "value": false } }'
        Set-Content -Path (Join-Path $libraryRoot 'src/policies/IL5-policyAssignmentParameters.json') -Value '{ "il5Only": { "value": 5 } }'
        Set-Content -Path (Join-Path $libraryRoot 'src/policies/NISTRev4-policyAssignmentParameters.json') -Value '{ "nist4Only": { "value": true } }'
        Set-Content -Path (Join-Path $libraryRoot 'src/policies/NISTRev5-policyAssignmentParameters.json') -Value '{ "nist5Only": { "value": ["a", "b"] } }'

        Set-Content -Path (Join-Path $definitionsRoot "policyStructures/mlz.policy_default_structure.$PacEnvironmentSelector.jsonc") -Value @"
{
  "managementGroupNameMappings": {
    "mlz": {
      "management_group_function": "Mission Landing Zone",
      "value": "$Scope"
    }
  },
  "enforcementMode": "DoNotEnforce",
  "defaultParameterValues": {
    "log_analytics_workspace_resource_id": [
      {
        "policy_assignment_name": "NISTRev4",
        "parameters": { "parameter_name": "logAnalyticsWorkspaceIdforVMReporting", "value": "$LogAnalyticsResourceId" }
      },
      {
        "policy_assignment_name": "IL5",
        "parameters": { "parameter_name": "logAnalyticsWorkspaceIDForVMAgents", "value": "$LogAnalyticsResourceId" }
      },
      {
        "policy_assignment_name": ["Deploy-VMSS-Agents", "Deploy-VM-Agents"],
        "parameters": { "parameter_name": "logAnalytics_1", "value": "$LogAnalyticsResourceId" }
      }
    ],
    "log_analytics_workspace_customer_id": [
      {
        "policy_assignment_name": "CMMC",
        "parameters": { "parameter_name": "logAnalyticsWorkspaceId-f47b5582-33ec-4c5c-87c0-b010a6b2e917", "value": "33333333-3333-3333-3333-333333333333" }
      }
    ],
    "windows_administrators_group_membership": [
      {
        "policy_assignment_name": "NISTRev4",
        "parameters": { "parameter_name": "listOfMembersToIncludeInWindowsVMAdministratorsGroup", "value": "contoso-admins" }
      },
      {
        "policy_assignment_name": "IL5",
        "parameters": { "parameter_name": "membersToIncludeInLocalAdministratorsGroup", "value": "contoso-admins" }
      },
      {
        "policy_assignment_name": "CMMC",
        "parameters": { "parameter_name": "MembersToInclude-30f71ea1-ac77-4f26-9fc5-2d926bbd4ba7", "value": "contoso-admins" }
      }
    ],
    "windows_administrators_group_exclusions": [
      {
        "policy_assignment_name": "CMMC",
        "parameters": { "parameter_name": "MembersToExclude-69bf4abd-ca1e-4cf6-8b5a-762d42e61d4f", "value": "admin" }
      }
    ]
  },
  "enforceGuardrails": {
    "deployments": []
  }
}
"@

        [pscustomobject]@{
            DefinitionsRoot = $definitionsRoot
            LibraryRoot     = $libraryRoot
            AssignmentRoot  = Join-Path $definitionsRoot "policyAssignments/MLZ/$PacEnvironmentSelector/Mission Landing Zone"
        }
    }

    function Invoke-MlzSync {
        param(
            [Parameter(Mandatory = $true)]
            [string] $Root,

            [Parameter(Mandatory = $true)]
            [string] $DefinitionsRoot,

            [Parameter(Mandatory = $true)]
            [string] $LibraryRoot,

            [Parameter(Mandatory = $true)]
            [string] $PacEnvironmentSelector
        )

        $helperScriptPath = Join-Path $Root 'run-mlz-sync.ps1'
        Set-Content -Path $helperScriptPath -Value @"
& '$($script:SyncScriptPath.Replace("'", "''"))' -DefinitionsRootFolder '$($DefinitionsRoot.Replace("'", "''"))' -LibraryPath '$($LibraryRoot.Replace("'", "''"))' -Type MLZ -PacEnvironmentSelector '$PacEnvironmentSelector'
# Propagate the sync script's exit code so the caller can assert on failures.
if (`$LASTEXITCODE) { exit `$LASTEXITCODE }
"@

        & pwsh -NoLogo -NoProfile -File $helperScriptPath | Out-Null
        return $LASTEXITCODE
    }
}

Describe 'Sync-ALZPolicyFromLibrary MLZ' {
    It 'creates every baseline assignment for a non commercial cloud' {
        $root = Join-Path $TestDrive 'gov'
        $fixture = New-MlzFixture -Root $root -Cloud 'AzureUSGovernment' -PacEnvironmentSelector 'epac-dev'

        Invoke-MlzSync -Root $root -DefinitionsRoot $fixture.DefinitionsRoot -LibraryRoot $fixture.LibraryRoot -PacEnvironmentSelector 'epac-dev' | Should -Be 0

        @(Get-ChildItem -Path $fixture.AssignmentRoot -File | Select-Object -ExpandProperty Name | Sort-Object) | Should -Be @(
            'CMMC.jsonc'
            'Deploy-VM-Agents.jsonc'
            'Deploy-VMSS-Agents.jsonc'
            'IL5.jsonc'
            'NISTRev4.jsonc'
            'NISTRev5.jsonc'
        )

        $nist5 = Get-Content -Path (Join-Path $fixture.AssignmentRoot 'NISTRev5.jsonc') -Raw | ConvertFrom-Json
        $nist5.assignment.name | Should -Be 'NISTRev5'
        $nist5.definitionEntry.policySetId | Should -Be '/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f'
        # enforcementMode comes from the structure file, and the missionlz {"value":x} wrapper is flattened.
        $nist5.enforcementMode | Should -Be 'DoNotEnforce'
        $nist5.parameters.nist5Only | Should -Be @('a', 'b')
        $nist5.scope.'epac-dev' | Should -Be '/subscriptions/22222222-2222-2222-2222-222222222222'
    }

    It 'applies the structure file stubs to the assignments that need them' {
        $root = Join-Path $TestDrive 'stubs'
        $fixture = New-MlzFixture -Root $root -Cloud 'AzureUSGovernment' -PacEnvironmentSelector 'epac-dev'

        Invoke-MlzSync -Root $root -DefinitionsRoot $fixture.DefinitionsRoot -LibraryRoot $fixture.LibraryRoot -PacEnvironmentSelector 'epac-dev' | Should -Be 0

        $lawResourceId = '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/law'

        $nist4 = Get-Content -Path (Join-Path $fixture.AssignmentRoot 'NISTRev4.jsonc') -Raw | ConvertFrom-Json
        $nist4.parameters.logAnalyticsWorkspaceIdforVMReporting | Should -Be $lawResourceId
        $nist4.parameters.listOfMembersToIncludeInWindowsVMAdministratorsGroup | Should -Be 'contoso-admins'
        $nist4.parameters.nist4Only | Should -BeTrue

        $il5 = Get-Content -Path (Join-Path $fixture.AssignmentRoot 'IL5.jsonc') -Raw | ConvertFrom-Json
        $il5.parameters.logAnalyticsWorkspaceIDForVMAgents | Should -Be $lawResourceId
        $il5.parameters.membersToIncludeInLocalAdministratorsGroup | Should -Be 'contoso-admins'

        # A single stub fans out to both agent assignments.
        foreach ($agentAssignment in @('Deploy-VM-Agents', 'Deploy-VMSS-Agents')) {
            $agent = Get-Content -Path (Join-Path $fixture.AssignmentRoot "$agentAssignment.jsonc") -Raw | ConvertFrom-Json
            $agent.parameters.logAnalytics_1 | Should -Be $lawResourceId
            @($agent.parameters.PSObject.Properties).Count | Should -Be 1
        }

        # The CMMC workspace parameter takes the customer id, not the resource id.
        $cmmc = Get-Content -Path (Join-Path $fixture.AssignmentRoot 'CMMC.jsonc') -Raw | ConvertFrom-Json
        $cmmc.parameters.'logAnalyticsWorkspaceId-f47b5582-33ec-4c5c-87c0-b010a6b2e917' | Should -Be '33333333-3333-3333-3333-333333333333'
    }

    It 'omits the commercial only CMMC parameters outside of Azure commercial' {
        $root = Join-Path $TestDrive 'gov-cmmc'
        $fixture = New-MlzFixture -Root $root -Cloud 'AzureUSGovernment' -PacEnvironmentSelector 'epac-dev'

        Invoke-MlzSync -Root $root -DefinitionsRoot $fixture.DefinitionsRoot -LibraryRoot $fixture.LibraryRoot -PacEnvironmentSelector 'epac-dev' | Should -Be 0

        $cmmc = Get-Content -Path (Join-Path $fixture.AssignmentRoot 'CMMC.jsonc') -Raw | ConvertFrom-Json
        $cmmc.parameters.PSObject.Properties.Name | Should -Not -Contain 'MembersToExclude-69bf4abd-ca1e-4cf6-8b5a-762d42e61d4f'
        $cmmc.parameters.PSObject.Properties.Name | Should -Not -Contain 'MembersToInclude-30f71ea1-ac77-4f26-9fc5-2d926bbd4ba7'
    }

    It 'skips IL5 and adds the CMMC administrators group parameters in Azure commercial' {
        $root = Join-Path $TestDrive 'com'
        $fixture = New-MlzFixture -Root $root -Cloud 'AzureCloud' -PacEnvironmentSelector 'epac-dev'

        Invoke-MlzSync -Root $root -DefinitionsRoot $fixture.DefinitionsRoot -LibraryRoot $fixture.LibraryRoot -PacEnvironmentSelector 'epac-dev' | Should -Be 0

        # The deployment maps IL5 to NISTRev4 in commercial, which is already generated in its own right.
        @(Get-ChildItem -Path $fixture.AssignmentRoot -File | Select-Object -ExpandProperty Name | Sort-Object) | Should -Be @(
            'CMMC.jsonc'
            'Deploy-VM-Agents.jsonc'
            'Deploy-VMSS-Agents.jsonc'
            'NISTRev4.jsonc'
            'NISTRev5.jsonc'
        )

        $cmmc = Get-Content -Path (Join-Path $fixture.AssignmentRoot 'CMMC.jsonc') -Raw | ConvertFrom-Json
        $cmmc.parameters.'MembersToExclude-69bf4abd-ca1e-4cf6-8b5a-762d42e61d4f' | Should -Be 'admin'
        $cmmc.parameters.'MembersToInclude-30f71ea1-ac77-4f26-9fc5-2d926bbd4ba7' | Should -Be 'contoso-admins'
    }

    It 'removes assignments that are no longer generated when the cloud changes' {
        $root = Join-Path $TestDrive 'cleanup'
        $fixture = New-MlzFixture -Root $root -Cloud 'AzureUSGovernment' -PacEnvironmentSelector 'epac-dev'

        Invoke-MlzSync -Root $root -DefinitionsRoot $fixture.DefinitionsRoot -LibraryRoot $fixture.LibraryRoot -PacEnvironmentSelector 'epac-dev' | Should -Be 0
        Test-Path (Join-Path $fixture.AssignmentRoot 'IL5.jsonc') | Should -BeTrue

        $globalSettingsPath = Join-Path $fixture.DefinitionsRoot 'global-settings.jsonc'
        (Get-Content -Path $globalSettingsPath -Raw).Replace('AzureUSGovernment', 'AzureCloud') | Set-Content -Path $globalSettingsPath

        Invoke-MlzSync -Root $root -DefinitionsRoot $fixture.DefinitionsRoot -LibraryRoot $fixture.LibraryRoot -PacEnvironmentSelector 'epac-dev' | Should -Be 0
        Test-Path (Join-Path $fixture.AssignmentRoot 'IL5.jsonc') | Should -BeFalse
        Test-Path (Join-Path $fixture.AssignmentRoot 'NISTRev4.jsonc') | Should -BeTrue
    }

    It 'produces assignments that validate against the policy assignment schema' {
        $root = Join-Path $TestDrive 'schema'
        $fixture = New-MlzFixture -Root $root -Cloud 'AzureUSGovernment' -PacEnvironmentSelector 'epac-dev'
        $schemaPath = (Resolve-Path (Join-Path $PSScriptRoot '../../../Schemas/policy-assignment-schema.json')).Path

        Invoke-MlzSync -Root $root -DefinitionsRoot $fixture.DefinitionsRoot -LibraryRoot $fixture.LibraryRoot -PacEnvironmentSelector 'epac-dev' | Should -Be 0

        foreach ($assignmentFile in Get-ChildItem -Path $fixture.AssignmentRoot -File) {
            (Get-Content -Path $assignmentFile.FullName -Raw | Test-Json -SchemaFile $schemaPath) | Should -BeTrue -Because "$($assignmentFile.Name) must be a valid EPAC policy assignment"
        }
    }

    It 'falls back to Azure commercial when the PAC environment cannot be resolved' {
        $root = Join-Path $TestDrive 'fallback'
        $fixture = New-MlzFixture -Root $root -Cloud 'AzureUSGovernment' -PacEnvironmentSelector 'epac-dev'

        # The structure file selector still matches, but no PAC environment does.
        $globalSettingsPath = Join-Path $fixture.DefinitionsRoot 'global-settings.jsonc'
        (Get-Content -Path $globalSettingsPath -Raw).Replace('"pacSelector": "epac-dev"', '"pacSelector": "something-else"') | Set-Content -Path $globalSettingsPath

        Invoke-MlzSync -Root $root -DefinitionsRoot $fixture.DefinitionsRoot -LibraryRoot $fixture.LibraryRoot -PacEnvironmentSelector 'epac-dev' | Should -Be 0

        Test-Path (Join-Path $fixture.AssignmentRoot 'IL5.jsonc') | Should -BeFalse
    }

    It 'fails when the library path is not a missionlz repository' {
        $root = Join-Path $TestDrive 'bad-library'
        $fixture = New-MlzFixture -Root $root -Cloud 'AzureUSGovernment' -PacEnvironmentSelector 'epac-dev'
        Remove-Item -Path (Join-Path $fixture.LibraryRoot 'src/policies') -Recurse -Force

        Invoke-MlzSync -Root $root -DefinitionsRoot $fixture.DefinitionsRoot -LibraryRoot $fixture.LibraryRoot -PacEnvironmentSelector 'epac-dev' | Should -Be 1
    }
}
