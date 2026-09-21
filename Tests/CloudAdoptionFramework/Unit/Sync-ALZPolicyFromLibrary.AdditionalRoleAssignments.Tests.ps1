BeforeAll {
    $script:SyncScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/Sync-ALZPolicyFromLibrary.ps1'
}

Describe 'Sync-ALZPolicyFromLibrary additional role assignments' {
    It 'generates Managed Identity Operator / Monitoring Reader additionalRoleAssignments for the ALZ VM Insights assignments that bring their own cross-subscription identity' {
        $definitionsRoot = Join-Path $TestDrive 'alz-definitions'
        $libraryRoot = Join-Path $TestDrive 'alz-library'

        foreach ($path in @(
                $definitionsRoot
                (Join-Path $definitionsRoot 'policyStructures')
                (Join-Path $definitionsRoot 'policyAssignments')
                (Join-Path $libraryRoot 'platform/alz/archetype_definitions')
                (Join-Path $libraryRoot 'platform/alz/policy_assignments')
            )) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        Set-Content -Path (Join-Path $definitionsRoot 'global-settings.jsonc') -Value @'
{
  "telemetryOptOut": true,
  "pacEnvironments": ["epac-dev"]
}
'@

        Set-Content -Path (Join-Path $definitionsRoot 'policyStructures/alz.policy_default_structure.epac-dev.jsonc') -Value @'
{
  "enforcementMode": "Default",
  "managementGroupNameMappings": {
    "platform": {
      "management_group_function": "Platform",
      "value": "/providers/Microsoft.Management/managementGroups/platform"
    }
  },
  "defaultParameterValues": {}
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/alz/archetype_definitions/platform.alz_archetype_definition.json') -Value @'
{
  "name": "platform",
  "policy_assignments": ["Deploy-VM-Monitoring", "Deploy-VM-ChangeTrack", "Deploy-VMSS-Monitoring", "Deploy-vmHybr-Monitoring", "Enforce-ACSB"]
}
'@

        # Deploy-VM-Monitoring / Deploy-VM-ChangeTrack / Deploy-VMSS-Monitoring bring their own user-assigned
        # managed identity that is allowed to live outside the assignment's own subscription/scope.
        foreach ($assignmentName in @('Deploy-VM-Monitoring', 'Deploy-VM-ChangeTrack', 'Deploy-VMSS-Monitoring')) {
            Set-Content -Path (Join-Path $libraryRoot "platform/alz/policy_assignments/$assignmentName.alz_policy_assignment.json") -Value @"
{
  "name": "$assignmentName",
  "properties": {
    "displayName": "Test $assignmentName",
    "description": "Test $assignmentName assignment",
    "policyDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/$assignmentName",
    "parameters": {
      "dcrResourceId": {
        "value": "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-monitoring/providers/Microsoft.Insights/dataCollectionRules/dcr-vminsights"
      },
      "bringYourOwnUserAssignedManagedIdentity": {
        "value": true
      },
      "restrictBringYourOwnUserAssignedIdentityToSubscription": {
        "value": false
      },
      "userAssignedIdentityResourceId": {
        "value": "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-ama"
      }
    }
  }
}
"@
        }

        # Deploy-vmHybr-Monitoring uses a system-assigned identity, so it only has the DCR parameter.
        Set-Content -Path (Join-Path $libraryRoot 'platform/alz/policy_assignments/Deploy-vmHybr-Monitoring.alz_policy_assignment.json') -Value @'
{
  "name": "Deploy-vmHybr-Monitoring",
  "properties": {
    "displayName": "Test Deploy-vmHybr-Monitoring",
    "description": "Test Deploy-vmHybr-Monitoring assignment",
    "policyDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/Deploy-vmHybr-Monitoring",
    "parameters": {
      "dcrResourceId": {
        "value": "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-monitoring/providers/Microsoft.Insights/dataCollectionRules/dcr-vminsights"
      }
    }
  }
}
'@

        # Control assignment with no identity/DCR parameters - must not get an additionalRoleAssignments block.
        Set-Content -Path (Join-Path $libraryRoot 'platform/alz/policy_assignments/Enforce-ACSB.alz_policy_assignment.json') -Value @'
{
  "name": "Enforce-ACSB",
  "properties": {
    "displayName": "Test Enforce-ACSB",
    "description": "Test Enforce-ACSB assignment",
    "policyDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/Enforce-ACSB",
    "parameters": {}
  }
}
'@

        & pwsh -NoLogo -NoProfile -File $script:SyncScriptPath `
            -DefinitionsRootFolder $definitionsRoot `
            -LibraryPath $libraryRoot `
            -Type ALZ `
            -PacEnvironmentSelector 'epac-dev' `
            -SyncAssignmentsOnly | Out-Null
        $LASTEXITCODE | Should -Be 0

        foreach ($assignmentName in @('Deploy-VM-Monitoring', 'Deploy-VM-ChangeTrack', 'Deploy-VMSS-Monitoring')) {
            $assignmentFile = Join-Path $definitionsRoot "policyAssignments/ALZ/epac-dev/Platform/$assignmentName.jsonc"
            Test-Path $assignmentFile | Should -BeTrue

            $assignment = Get-Content -Path $assignmentFile -Raw | ConvertFrom-Json
            $roleAssignments = $assignment.additionalRoleAssignments.'epac-dev'
            $roleAssignments.Count | Should -Be 2
            ($roleAssignments | Where-Object { $_.roleDefinitionId -eq '/providers/microsoft.authorization/roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830' }).scope |
                Should -Be '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-ama'
            ($roleAssignments | Where-Object { $_.roleDefinitionId -eq '/providers/microsoft.authorization/roleDefinitions/43d0d8ad-25c7-4714-9337-8ba259a9fe05' }).scope |
                Should -Be '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-monitoring/providers/Microsoft.Insights/dataCollectionRules/dcr-vminsights'
        }

        $hybrAssignmentFile = Join-Path $definitionsRoot 'policyAssignments/ALZ/epac-dev/Platform/Deploy-vmHybr-Monitoring.jsonc'
        $hybrAssignment = Get-Content -Path $hybrAssignmentFile -Raw | ConvertFrom-Json
        $hybrRoleAssignments = $hybrAssignment.additionalRoleAssignments.'epac-dev'
        $hybrRoleAssignments.Count | Should -Be 1
        $hybrRoleAssignments[0].roleDefinitionId | Should -Be '/providers/microsoft.authorization/roleDefinitions/43d0d8ad-25c7-4714-9337-8ba259a9fe05'

        $controlAssignmentFile = Join-Path $definitionsRoot 'policyAssignments/ALZ/epac-dev/Platform/Enforce-ACSB.jsonc'
        $controlAssignment = Get-Content -Path $controlAssignmentFile -Raw | ConvertFrom-Json
        ($controlAssignment.PSObject.Properties.Name -contains 'additionalRoleAssignments') | Should -BeFalse
    }

    It 'does not add a redundant additionalRoleAssignments entry when the AMBA-Management assignment is already scoped to the management management group' {
        $definitionsRoot = Join-Path $TestDrive 'amba-definitions'
        $libraryRoot = Join-Path $TestDrive 'amba-library'

        foreach ($path in @(
                $definitionsRoot
                (Join-Path $definitionsRoot 'policyStructures')
                (Join-Path $definitionsRoot 'policyAssignments')
                (Join-Path $libraryRoot 'platform/amba/archetype_definitions')
                (Join-Path $libraryRoot 'platform/amba/policy_assignments')
            )) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        Set-Content -Path (Join-Path $definitionsRoot 'global-settings.jsonc') -Value @'
{
  "telemetryOptOut": true,
  "pacEnvironments": ["epac-dev"]
}
'@

        Set-Content -Path (Join-Path $definitionsRoot 'policyStructures/amba.policy_default_structure.epac-dev.jsonc') -Value @'
{
  "enforcementMode": "Default",
  "managementGroupNameMappings": {
    "management": {
      "management_group_function": "Management",
      "value": "/providers/Microsoft.Management/managementGroups/management"
    }
  },
  "defaultParameterValues": {}
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/amba/archetype_definitions/amba_management.alz_archetype_definition.json') -Value @'
{
  "name": "amba_management",
  "policy_assignments": ["Deploy-AMBA-Management"]
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/amba/policy_assignments/Deploy-AMBA-Management.alz_policy_assignment.json') -Value @'
{
  "name": "Deploy-AMBA-Management",
  "properties": {
    "displayName": "Test Deploy-AMBA-Management",
    "description": "Test Deploy-AMBA-Management assignment",
    "policyDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/Deploy-AMBA-Management",
    "parameters": {}
  }
}
'@

        & pwsh -NoLogo -NoProfile -File $script:SyncScriptPath `
            -DefinitionsRootFolder $definitionsRoot `
            -LibraryPath $libraryRoot `
            -Type AMBA `
            -PacEnvironmentSelector 'epac-dev' `
            -SyncAssignmentsOnly | Out-Null
        $LASTEXITCODE | Should -Be 0

        $assignmentFile = Join-Path $definitionsRoot 'policyAssignments/AMBA/epac-dev/Management/Deploy-AMBA-Management.jsonc'
        Test-Path $assignmentFile | Should -BeTrue

        $assignment = Get-Content -Path $assignmentFile -Raw | ConvertFrom-Json
        ($assignment.PSObject.Properties.Name -contains 'additionalRoleAssignments') | Should -BeFalse
    }
}
