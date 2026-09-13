BeforeAll {
    $script:SyncScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/Sync-ALZPolicyFromLibrary.ps1'
    $script:Tag = 'platform/amba/2026.06.2'
}

Describe 'Sync-ALZPolicyFromLibrary AMBA Web defaults' {
    It 'applies shared structure values while retaining the additional role assignment' {
        $definitionsRoot = Join-Path $TestDrive 'Definitions'
        $libraryRoot = Join-Path $TestDrive 'library'

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
    "landingzones": {
      "management_group_function": "Landing Zones",
      "value": "/providers/Microsoft.Management/managementGroups/landingzones"
    },
    "management": {
      "management_group_function": "Management",
      "value": "/providers/Microsoft.Management/managementGroups/management"
    }
  },
  "defaultParameterValues": {
    "amba_alz_resource_group_name": [
      {
        "policy_assignment_name": ["Deploy-AMBA-Web", "Deploy-AMBA-VM", "Deploy-AMBA-HybridVM", "Deploy-AMBA-VMSS", "Deploy-AMBA-Management"],
        "parameters": {
          "parameter_name": "ALZMonitorResourceGroupName",
          "value": "rg-from-structure"
        }
      }
    ]
  }
}
'@

        Set-Content -Path (Join-Path $libraryRoot 'platform/amba/archetype_definitions/amba_landing_zones.alz_archetype_definition.json') -Value @'
{
  "name": "amba_landing_zones",
 "policy_assignments": ["Deploy-AMBA-Web", "Deploy-AMBA-VM", "Deploy-AMBA-HybridVM", "Deploy-AMBA-VMSS", "Deploy-AMBA-Management"]
}
'@

       foreach ($assignmentName in @('Deploy-AMBA-Web','Deploy-AMBA-VM','Deploy-AMBA-HybridVM','Deploy-AMBA-VMSS','Deploy-AMBA-Management')) {
           Set-Content -Path (Join-Path $libraryRoot "platform/amba/policy_assignments/$assignmentName.alz_policy_assignment.json") -Value @"
{
 "name": "$assignmentName",
 "properties": {
   "displayName": "Deploy $assignmentName",
   "description": "Test $assignmentName assignment",
   "policyDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/$assignmentName",
   "parameters": {
     "ALZMonitorResourceGroupName": {
       "value": "rg-from-library"
     }
   }
 }
}
"@
       }

       $helperScriptPath = Join-Path $TestDrive 'run-sync.ps1'
       Set-Content -Path $helperScriptPath -Value @"
function Invoke-RestMethod {
    param([string] `$Uri)
 
    [pscustomobject]@{
        ref = @('refs/tags/$($script:Tag)')
    }
}
 
& '$($script:SyncScriptPath.Replace("'", "''"))' -DefinitionsRootFolder '$($definitionsRoot.Replace("'", "''"))' -LibraryPath '$($libraryRoot.Replace("'", "''"))' -Type AMBA -PacEnvironmentSelector 'epac-dev' -Tag '$($script:Tag)' -SyncAssignmentsOnly
"@

       & pwsh -NoLogo -NoProfile -File $helperScriptPath | Out-Null
       $LASTEXITCODE | Should -Be 0

       foreach ($assignmentName in @('Deploy-AMBA-Web','Deploy-AMBA-VM','Deploy-AMBA-HybridVM','Deploy-AMBA-VMSS','Deploy-AMBA-Management')) {
           $assignmentFile = Join-Path $definitionsRoot "policyAssignments/AMBA/epac-dev/Landing Zones/$assignmentName.jsonc"
           Test-Path $assignmentFile | Should -BeTrue

           $assignment = Get-Content -Path $assignmentFile -Raw | ConvertFrom-Json
           $assignment.parameters.ALZMonitorResourceGroupName | Should -Be 'rg-from-structure'
           $assignment.additionalRoleAssignments.'epac-dev'[0].scope | Should -Be '/providers/Microsoft.Management/managementGroups/management'
           $assignment.additionalRoleAssignments.'epac-dev'[0].roleDefinitionId | Should -Be '/providers/microsoft.authorization/roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830'
       }
   }
}
