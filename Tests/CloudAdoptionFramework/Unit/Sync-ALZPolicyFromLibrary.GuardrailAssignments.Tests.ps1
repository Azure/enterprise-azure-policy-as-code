BeforeAll {
    $script:SyncScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/Sync-ALZPolicyFromLibrary.ps1'
    $script:Tag = 'platform/alz/2026.04.2'

    # Scaffolds a minimal ALZ library + Definitions folder used to exercise guardrail assignment
    # syncing. The structure file content is supplied by the caller so each test can describe its own
    # archetypes / overrides while sharing the policy assignment fixtures.
    function New-GuardrailTestEnvironment {
        param(
            [Parameter(Mandatory = $true)] [string] $Root,
            [Parameter(Mandatory = $true)] [string] $StructureFileContent,
            [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [hashtable[]] $ArchetypeDefinitions
        )

        $definitionsRoot = Join-Path $Root 'Definitions'
        $libraryRoot = Join-Path $Root 'library'

        foreach ($path in @(
                $definitionsRoot
                (Join-Path $definitionsRoot 'policyStructures')
                (Join-Path $definitionsRoot 'policyAssignments')
                (Join-Path $libraryRoot 'platform/alz/archetype_definitions')
                (Join-Path $libraryRoot 'platform/alz/policy_assignments')
                (Join-Path $libraryRoot 'platform/alz/policy_definitions')
            )) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        Set-Content -Path (Join-Path $definitionsRoot 'global-settings.jsonc') -Value @'
{
  "telemetryOptOut": true,
  "pacEnvironments": ["epac-dev"]
}
'@

        Set-Content -Path (Join-Path $definitionsRoot 'policyStructures/alz.policy_default_structure.epac-dev.jsonc') -Value $StructureFileContent

        foreach ($archetype in $ArchetypeDefinitions) {
            $archetypeJson = [ordered]@{
                name               = $archetype.name
                policy_assignments = @($archetype.policy_assignments)
            } | ConvertTo-Json -Depth 10
            Set-Content -Path (Join-Path $libraryRoot "platform/alz/archetype_definitions/$($archetype.name).alz_archetype_definition.json") -Value $archetypeJson
        }

        # A normal (non-guardrail) initiative assignment.
        Set-Content -Path (Join-Path $libraryRoot 'platform/alz/policy_assignments/Audit-AppGW-WAF.alz_policy_assignment.json') -Value @'
{
  "type": "Microsoft.Authorization/policyAssignments",
  "apiVersion": "2022-06-01",
  "name": "Audit-AppGW-WAF",
  "properties": {
    "description": "Audit Application Gateway WAF.",
    "displayName": "Audit Application Gateway WAF",
    "policyDefinitionId": "/providers/Microsoft.Management/managementGroups/placeholder/providers/Microsoft.Authorization/policyDefinitions/Audit-AppGW-WAF",
    "enforcementMode": "Default",
    "scope": "/providers/Microsoft.Management/managementGroups/placeholder",
    "notScopes": [],
    "parameters": {}
  }
}
'@

        # Guardrail initiative assignments. Their names match ^Enforce-(GR|Encrypt)-\w+0 so they are
        # only synced when -CreateGuardrailAssignments is supplied.
        foreach ($guardrail in @(
                @{ name = 'Enforce-GR-Storage0'; set = 'Enforce-Guardrails-Storage'; displayName = 'Enforce recommended guardrails for Storage Accounts' }
                @{ name = 'Enforce-GR-KeyVaultSup0'; set = 'Enforce-Guardrails-KeyVault-Sup'; displayName = 'Enforce recommended guardrails for Key Vault Supplementary' }
            )) {
            $guardrailContent = @"
{
  "type": "Microsoft.Authorization/policyAssignments",
  "apiVersion": "2022-06-01",
  "name": "$($guardrail.name)",
  "properties": {
    "description": "This initiative assignment enables additional ALZ guardrails.",
    "displayName": "$($guardrail.displayName)",
    "policyDefinitionId": "/providers/Microsoft.Management/managementGroups/placeholder/providers/Microsoft.Authorization/policySetDefinitions/$($guardrail.set)",
    "enforcementMode": "DoNotEnforce",
    "scope": "/providers/Microsoft.Management/managementGroups/placeholder",
    "notScopes": [],
    "parameters": {}
  }
}
"@
            Set-Content -Path (Join-Path $libraryRoot "platform/alz/policy_assignments/$($guardrail.name).alz_policy_assignment.json") -Value $guardrailContent
        }

        [pscustomobject]@{
            DefinitionsRoot = $definitionsRoot
            LibraryRoot     = $libraryRoot
        }
    }

    # Runs Sync-ALZPolicyFromLibrary against the scaffolded environment, stubbing the GitHub tag
    # validation call so no network access is required.
    function Invoke-SyncScript {
        param(
            [Parameter(Mandatory = $true)] [string] $Root,
            [Parameter(Mandatory = $true)] [string] $DefinitionsRoot,
            [Parameter(Mandatory = $true)] [string] $LibraryRoot,
            [switch] $CreateGuardrailAssignments,
            [switch] $EnableOverrides
        )

        $helperScriptPath = Join-Path $Root 'run-sync.ps1'
        $switches = ''
        if ($CreateGuardrailAssignments) { $switches += ' -CreateGuardrailAssignments' }
        if ($EnableOverrides) { $switches += ' -EnableOverrides' }

        Set-Content -Path $helperScriptPath -Value @"
function Invoke-RestMethod {
    param(
        [string] `$Uri
    )

    [pscustomobject]@{
        ref = @('refs/tags/$($script:Tag)')
    }
}

& '$($script:SyncScriptPath.Replace("'", "''"))' -DefinitionsRootFolder '$($DefinitionsRoot.Replace("'", "''"))' -LibraryPath '$($LibraryRoot.Replace("'", "''"))' -Type ALZ -PacEnvironmentSelector 'epac-dev' -Tag '$($script:Tag)' -SyncAssignmentsOnly$switches
"@

        & pwsh -NoLogo -NoProfile -File $helperScriptPath 2>&1 | Out-String
    }
}

Describe 'Sync-ALZPolicyFromLibrary guardrail assignments' {
    It 'only creates guardrail assignments when -CreateGuardrailAssignments is supplied' {
        $root = Join-Path $TestDrive 'GuardrailDefault'
        $structure = @'
{
  "enforcementMode": "Default",
  "managementGroupNameMappings": {
    "landingzones": {
      "management_group_function": "Landing Zones",
      "value": "/providers/Microsoft.Management/managementGroups/landingzones"
    }
  },
  "defaultParameterValues": {},
  "archetypes": []
}
'@
        $env = New-GuardrailTestEnvironment -Root $root -StructureFileContent $structure -ArchetypeDefinitions @(
            @{ name = 'landing_zones'; policy_assignments = @('Audit-AppGW-WAF', 'Enforce-GR-Storage0') }
        )

        $guardrailFile = Join-Path $env.DefinitionsRoot 'policyAssignments/ALZ/epac-dev/Landing Zones/Enforce-GR-Storage0.jsonc'
        $normalFile = Join-Path $env.DefinitionsRoot 'policyAssignments/ALZ/epac-dev/Landing Zones/Audit-AppGW-WAF.jsonc'

        # Without the switch the guardrail assignment is filtered out, while normal assignments sync.
        Invoke-SyncScript -Root $root -DefinitionsRoot $env.DefinitionsRoot -LibraryRoot $env.LibraryRoot | Out-Null
        Test-Path $normalFile | Should -BeTrue
        Test-Path $guardrailFile | Should -BeFalse

        # With the switch the guardrail assignment is created and scoped to its archetype.
        Invoke-SyncScript -Root $root -DefinitionsRoot $env.DefinitionsRoot -LibraryRoot $env.LibraryRoot -CreateGuardrailAssignments | Out-Null
        Test-Path $guardrailFile | Should -BeTrue

        $guardrailContent = Get-Content -Path $guardrailFile -Raw | ConvertFrom-Json
        $guardrailContent.assignment.name | Should -Be 'Enforce-GR-Storage0'
        $guardrailContent.nodeName | Should -Be 'landing_zones/Enforce-GR-Storage0'
        $guardrailContent.definitionEntry.policySetName | Should -Be 'Enforce-Guardrails-Storage'
        $guardrailContent.scope.'epac-dev' | Should -Be '/providers/Microsoft.Management/managementGroups/landingzones'
    }

    It 'adds a guardrail assignment to a different archetype using policy_assignments_to_add' {
        $root = Join-Path $TestDrive 'GuardrailToAdd'
        $structure = @'
{
  "enforcementMode": "Default",
  "managementGroupNameMappings": {
    "alz": {
      "management_group_function": "Intermediate Root",
      "value": "/providers/Microsoft.Management/managementGroups/alz"
    }
  },
  "defaultParameterValues": {},
  "overrides": {
    "archetypes": {
      "ignore": [],
      "custom": [
        {
          "name": "alz",
          "type": "existing",
          "policy_assignments_to_add": [
            "Enforce-GR-KeyVaultSup0"
          ]
        }
      ]
    },
    "parameters": {},
    "enforcementMode": {}
  }
}
'@
        $env = New-GuardrailTestEnvironment -Root $root -StructureFileContent $structure -ArchetypeDefinitions @()

        $guardrailFile = Join-Path $env.DefinitionsRoot 'policyAssignments/ALZ/epac-dev/Intermediate Root/Enforce-GR-KeyVaultSup0.jsonc'

        # The guardrail added to the root archetype is still gated behind -CreateGuardrailAssignments.
        Invoke-SyncScript -Root $root -DefinitionsRoot $env.DefinitionsRoot -LibraryRoot $env.LibraryRoot -EnableOverrides | Out-Null
        Test-Path $guardrailFile | Should -BeFalse

        # With the switch the guardrail is created under the target (root) archetype scope.
        Invoke-SyncScript -Root $root -DefinitionsRoot $env.DefinitionsRoot -LibraryRoot $env.LibraryRoot -EnableOverrides -CreateGuardrailAssignments | Out-Null
        Test-Path $guardrailFile | Should -BeTrue

        $guardrailContent = Get-Content -Path $guardrailFile -Raw | ConvertFrom-Json
        $guardrailContent.assignment.name | Should -Be 'Enforce-GR-KeyVaultSup0'
        $guardrailContent.nodeName | Should -Be 'root/Enforce-GR-KeyVaultSup0'
        $guardrailContent.definitionEntry.policySetName | Should -Be 'Enforce-Guardrails-KeyVault-Sup'
        $guardrailContent.scope.'epac-dev' | Should -Be '/providers/Microsoft.Management/managementGroups/alz'
    }
}
