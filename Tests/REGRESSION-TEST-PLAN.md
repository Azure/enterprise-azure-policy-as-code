# EPAC Regression Testing Plan

This document outlines a comprehensive regression testing strategy for Enterprise Policy as Code (EPAC). The tests focus on validating how Azure Policy objects are deployed, changed, and deleted through the EPAC deployment scripts.

## Overview

### Testing Objectives

1. Validate the complete lifecycle of Azure Policy resources (create → update → delete)
2. Ensure the deployment plan accurately reflects intended changes
3. Verify role assignments are correctly managed for policy remediation
4. Test desired state strategies (`full` vs `ownedOnly`)
5. Validate exemption handling across various scenarios
6. Test parameter handling including CSV parameters and overrides

### Testing Approach

Tests are executed using EPAC's native functionality rather than external testing frameworks:

1. **Modify Policy Files** - Each test starts by modifying or creating policy definition files in the test definitions folder
2. **Build Deployment Plan** - Run `Build-DeploymentPlans` to generate the plan and validate expected changes
3. **Deploy Policy Plan** - Run `Deploy-PolicyPlan` to apply policy changes to Azure
4. **Deploy Roles Plan** - Run `Deploy-RolesPlan` if role assignments are required
5. **Validate Results** - Query Azure to confirm resources match expected state

### Testing Prerequisites

- A dedicated Azure test environment (management group for testing)
- Service Principal with sufficient permissions for policy management
- PowerShell Core with the `EnterprisePolicyAsCode` module installed
- Az PowerShell module installed and authenticated
- **Pester v5.0+** for Azure state validation assertions (`Install-Module -Name Pester -MinimumVersion 5.0`)
- Isolated test `pacEnvironment` in the test `global-settings.jsonc`

### Test Environment Structure

```
Tests/
├── Definitions/                        # Test-specific definitions folder
│   ├── global-settings.jsonc          # Test environment configuration
│   ├── policyDefinitions/             # Test policy definitions
│   │   ├── Baseline/                  # Initial baseline policies
│   │   └── TestCases/                 # Policies for specific test cases
│   ├── policySetDefinitions/          # Test policy set definitions
│   │   ├── Baseline/                  # Initial baseline policy sets
│   │   └── TestCases/                 # Policy sets for specific tests
│   ├── policyAssignments/             # Test policy assignments
│   │   ├── Baseline/                  # Initial baseline assignments
│   │   └── TestCases/                 # Assignments for specific tests
│   └── policyExemptions/              # Test policy exemptions
│       ├── Baseline/                  # Initial baseline exemptions
│       └── TestCases/                 # Exemptions for specific tests
├── Output/                            # Plan files output folder
├── Scripts/                           # Test orchestration scripts
│   ├── Initialize-TestEnvironment.ps1
│   ├── Invoke-TestStage.ps1
│   ├── Test-DeploymentPlan.ps1
│   ├── Assert-AzureState.ps1
│   └── Cleanup-TestEnvironment.ps1
├── TestCases/                         # Test case definitions
│   ├── Stage1-Create/
│   ├── Stage2-Update/
│   ├── Stage3-Replace/
│   ├── Stage4-Delete/
│   ├── Stage5-DesiredState/
│   ├── Stage6-SpecialScenarios/
│   └── Stage7-CICD/
└── Results/                           # Test execution results and logs
```

### Test Execution Workflow

Each test follows this workflow:

```powershell
# 1. Setup: Copy/modify test files into Definitions folder
Copy-TestCaseFiles -TestCaseId "PD-001" -TargetFolder "./Tests/Definitions"

# 2. Build: Generate deployment plan
Build-DeploymentPlans -PacEnvironmentSelector "epac-test" `
    -DefinitionsRootFolder "./Tests/Definitions" `
    -OutputFolder "./Tests/Output"

# 3. Validate Plan: Check plan contains expected changes
$plan = Get-Content "./Tests/Output/plans-epac-test/policy-plan.json" | ConvertFrom-Json
Assert-PlanContains -Plan $plan -ExpectedNew 1 -ExpectedUpdate 0 -ExpectedDelete 0

# 4. Deploy: Apply the changes
Deploy-PolicyPlan -PacEnvironmentSelector "epac-test" `
    -DefinitionsRootFolder "./Tests/Definitions" `
    -InputFolder "./Tests/Output"

# 5. Deploy Roles (if needed)
Deploy-RolesPlan -PacEnvironmentSelector "epac-test" `
    -DefinitionsRootFolder "./Tests/Definitions" `
    -InputFolder "./Tests/Output"

# 6. Verify: Confirm Azure state matches expectations
$policy = Get-AzPolicyDefinition -Name "test-policy-pd001" -ManagementGroupName "epac-test-mg"
Assert-PolicyExists -Policy $policy -ExpectedDisplayName "Test Policy PD-001"
```

---

## Sample Test Definitions

The following sample policy objects are used as the baseline for all tests. These files reside in `Tests/Definitions/` and simulate a realistic EPAC deployment.

### global-settings.jsonc

```jsonc
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json",
    "pacOwnerId": "epac-regression-test-00000000-0000-0000-0000-000000000001",
    "pacEnvironments": [
        {
            "pacSelector": "epac-test",
            "cloud": "AzureCloud",
            "tenantId": "{{TENANT_ID}}",
            "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/epac-test-mg",
            "desiredState": {
                "strategy": "full",
                "keepDfcSecurityAssignments": false
            },
            "globalNotScopes": [],
            "managedIdentityLocation": "eastus2"
        }
    ]
}
```

### Baseline Policy Definition (policyDefinitions/Baseline/audit-resource-location.jsonc)

```jsonc
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-definition-schema.json",
    "name": "test-audit-resource-location",
    "properties": {
        "displayName": "Test - Audit Resource Location",
        "policyType": "Custom",
        "mode": "Indexed",
        "description": "Audits resources deployed outside allowed locations. Used for EPAC regression testing.",
        "metadata": {
            "version": "1.0.0",
            "category": "EPAC-Test"
        },
        "parameters": {
            "effect": {
                "type": "String",
                "metadata": {
                    "displayName": "Effect",
                    "description": "Enable or disable the execution of the policy"
                },
                "allowedValues": ["Audit", "Deny", "Disabled"],
                "defaultValue": "Audit"
            },
            "allowedLocations": {
                "type": "Array",
                "metadata": {
                    "displayName": "Allowed Locations",
                    "description": "The list of allowed locations for resources"
                },
                "defaultValue": ["eastus", "eastus2", "westus", "westus2"]
            }
        },
        "policyRule": {
            "if": {
                "allOf": [
                    {
                        "field": "location",
                        "notIn": "[parameters('allowedLocations')]"
                    },
                    {
                        "field": "location",
                        "notEquals": "global"
                    }
                ]
            },
            "then": {
                "effect": "[parameters('effect')]"
            }
        }
    }
}
```

### Baseline Policy Definition with DINE Effect (policyDefinitions/Baseline/deploy-diagnostic-settings.jsonc)

```jsonc
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-definition-schema.json",
    "name": "test-deploy-diag-settings",
    "properties": {
        "displayName": "Test - Deploy Diagnostic Settings",
        "policyType": "Custom",
        "mode": "Indexed",
        "description": "Deploys diagnostic settings for storage accounts. Used for EPAC regression testing.",
        "metadata": {
            "version": "1.0.0",
            "category": "EPAC-Test"
        },
        "parameters": {
            "effect": {
                "type": "String",
                "allowedValues": ["DeployIfNotExists", "Disabled"],
                "defaultValue": "DeployIfNotExists"
            },
            "logAnalyticsWorkspaceId": {
                "type": "String",
                "metadata": {
                    "displayName": "Log Analytics Workspace ID",
                    "description": "The resource ID of the Log Analytics workspace"
                }
            }
        },
        "policyRule": {
            "if": {
                "field": "type",
                "equals": "Microsoft.Storage/storageAccounts"
            },
            "then": {
                "effect": "[parameters('effect')]",
                "details": {
                    "type": "Microsoft.Insights/diagnosticSettings",
                    "roleDefinitionIds": [
                        "/providers/Microsoft.Authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa",
                        "/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293"
                    ],
                    "existenceCondition": {
                        "field": "Microsoft.Insights/diagnosticSettings/workspaceId",
                        "equals": "[parameters('logAnalyticsWorkspaceId')]"
                    },
                    "deployment": {
                        "properties": {
                            "mode": "incremental",
                            "template": {
                                "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
                                "contentVersion": "1.0.0.0",
                                "parameters": {},
                                "resources": []
                            }
                        }
                    }
                }
            }
        }
    }
}
```

### Baseline Policy Set Definition (policySetDefinitions/Baseline/test-governance-initiative.jsonc)

```jsonc
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-set-definition-schema.json",
    "name": "test-governance-initiative",
    "properties": {
        "displayName": "Test - Governance Initiative",
        "description": "Initiative containing governance policies for EPAC regression testing.",
        "metadata": {
            "version": "1.0.0",
            "category": "EPAC-Test"
        },
        "parameters": {
            "allowedLocations": {
                "type": "Array",
                "defaultValue": ["eastus", "eastus2"]
            },
            "locationEffect": {
                "type": "String",
                "defaultValue": "Audit"
            }
        },
        "policyDefinitions": [
            {
                "policyDefinitionReferenceId": "audit-resource-location",
                "policyDefinitionName": "test-audit-resource-location",
                "parameters": {
                    "effect": {
                        "value": "[parameters('locationEffect')]"
                    },
                    "allowedLocations": {
                        "value": "[parameters('allowedLocations')]"
                    }
                }
            }
        ]
    }
}
```

### Baseline Policy Assignment (policyAssignments/Baseline/governance-assignment.jsonc)

```jsonc
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-assignment-schema.json",
    "nodeName": "/Test/",
    "assignment": {
        "name": "test-governance",
        "displayName": "Test - Governance Assignment",
        "description": "Governance policy assignment for EPAC regression testing."
    },
    "definitionEntry": {
        "policySetName": "test-governance-initiative",
        "displayName": "Test - Governance Initiative"
    },
    "parameters": {
        "allowedLocations": ["eastus", "eastus2", "westus"],
        "locationEffect": "Audit"
    },
    "scope": {
        "epac-test": [
            "/providers/Microsoft.Management/managementGroups/epac-test-mg"
        ]
    }
}
```

### Baseline Policy Exemption (policyExemptions/Baseline/sample-exemption.jsonc)

```jsonc
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-exemption-schema.json",
    "exemptions": [
        {
            "name": "test-exemption-001",
            "displayName": "Test Exemption - Legacy Resources",
            "description": "Exemption for legacy resources during EPAC regression testing.",
            "exemptionCategory": "Waiver",
            "policyAssignmentId": "/providers/Microsoft.Management/managementGroups/epac-test-mg/providers/Microsoft.Authorization/policyAssignments/test-governance",
            "scopes": [
                "/subscriptions/{{TEST_SUBSCRIPTION_ID}}/resourceGroups/epac-test-legacy-rg"
            ],
            "metadata": {
                "ticketNumber": "TEST-001",
                "approvedBy": "EPAC Test Framework"
            }
        }
    ]
}
```

---

## Stage 1: Initial Deployment (Create Operations)

**Objective:** Verify that new Policy resources are correctly created from scratch.

### 1.1 Policy Definition Deployment

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PD-001 | Deploy single policy definition | Add `simple-audit-policy.jsonc` | 1 new policy definition | Policy exists in Azure with correct displayName |
| PD-002 | Deploy policy with all parameter types | Add policy with String, Array, Integer, Boolean, Object params | 1 new policy definition | All parameter types correctly registered |
| PD-003 | Deploy multiple policy definitions | Add 3 policy definition files | 3 new policy definitions | All 3 policies exist in Azure |
| PD-004 | Deploy policy with DINE effect | Add DINE policy with roleDefinitionIds | 1 new policy definition | Policy has roleDefinitionIds, roles plan generated |
| PD-005 | Deploy policy with Modify effect | Add Modify effect policy | 1 new policy definition | Policy has roleDefinitionIds, roles plan generated |
| PD-006 | Deploy policy with mode variations | Add policies with "All", "Indexed", "Microsoft.Kubernetes.Data" modes | 3 new policy definitions | Each policy has correct mode |
| PD-007 | Deploy policy with complex policyRule | Add policy with nested conditions, count expressions | 1 new policy definition | Policy rule logic preserved in Azure |
| PD-008 | Verify metadata injection | Add policy, check deployed metadata | 1 new policy definition | Metadata contains pacOwnerId and deployedBy |

### 1.2 Policy Set Definition Deployment

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PS-001 | Deploy policy set with custom policies only | Add policy set referencing custom policies | 1 new policy set | Set deployed with correct policyDefinitionName references |
| PS-002 | Deploy policy set with built-in policies only | Add policy set with policyDefinitionId references | 1 new policy set | Set deployed with correct built-in policy IDs |
| PS-003 | Deploy policy set with mixed policies | Add policy set with both custom and built-in | 1 new policy set | All references correctly resolved |
| PS-004 | Deploy policy set with parameters | Add policy set with parameterized child policies | 1 new policy set | Parameters correctly mapped |
| PS-005 | Deploy policy set with policy groups | Add policy set with policyDefinitionGroups | 1 new policy set | Groups correctly applied |
| PS-006 | Deploy policy set with importPolicyDefinitionGroups | Add policy set importing groups from built-in | 1 new policy set | Groups imported and applied |
| PS-007 | Deploy nested policy parameters | Add policy set with value mapping | 1 new policy set | Parameter inheritance works |

### 1.3 Policy Assignment Deployment

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PA-001 | Deploy assignment to management group | Add assignment with MG scope | 1 new assignment | Assignment exists at MG scope |
| PA-002 | Deploy assignment to subscription | Add assignment with subscription scope | 1 new assignment | Assignment exists at subscription |
| PA-003 | Deploy assignment to resource group | Add assignment with RG scope | 1 new assignment | Assignment exists at RG |
| PA-004 | Deploy assignment with parameters | Add assignment with parameter values | 1 new assignment | Parameters correctly applied |
| PA-005 | Deploy assignment with notScopes | Add assignment with notScopes array | 1 new assignment | notScopes correctly configured |
| PA-006 | Deploy assignment with system-assigned identity | Add DINE policy assignment | 1 new assignment | System MI created, roles plan has entries |
| PA-007 | Deploy assignment with user-assigned identity | Add assignment with userAssignedIdentity | 1 new assignment | UAMI correctly assigned |
| PA-008 | Deploy assignment with enforcementMode DoNotEnforce | Add assignment with DoNotEnforce | 1 new assignment | EnforcementMode set correctly |
| PA-009 | Deploy assignment with overrides | Add assignment with overrides array | 1 new assignment | Overrides correctly applied |
| PA-010 | Deploy assignment with resourceSelectors | Add assignment with resourceSelectors | 1 new assignment | ResourceSelectors configured |
| PA-011 | Deploy assignment with nonComplianceMessages | Add assignment with messages | 1 new assignment | Messages attached |
| PA-012 | Deploy assignment with additionalRoleAssignments | Add assignment with cross-scope roles | 1 new assignment | Additional roles in roles plan |
| PA-013 | Deploy assignment from definitionEntryList | Add assignment with multiple entries | 2+ new assignments | All assignments created |
| PA-014 | Deploy hierarchical assignment tree | Add assignment with nested nodeNames | 1+ new assignments | Inheritance works correctly |

### 1.4 Role Assignment Deployment

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| RA-001 | Deploy role assignments for DINE policy | Deploy DINE assignment | roles-plan.json has added entries | Role assignments exist at correct scope |
| RA-002 | Deploy role assignments for Modify policy | Deploy Modify assignment | roles-plan.json has added entries | Role assignments exist |
| RA-003 | Deploy additional role assignments | Add assignment with additionalRoleAssignments | roles-plan.json has additional entries | Cross-scope roles created |
| RA-004 | Verify role assignment metadata | Deploy DINE assignment | Role created | Description contains policyAssignmentId |

### 1.5 Policy Exemption Deployment

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PE-001 | Deploy Waiver exemption | Add exemption with "Waiver" category | 1 new exemption | Exemption exists with Waiver category |
| PE-002 | Deploy Mitigated exemption | Add exemption with "Mitigated" category | 1 new exemption | Exemption exists with Mitigated category |
| PE-003 | Deploy exemption with expiration | Add exemption with expiresOn date | 1 new exemption | Expiration date set correctly |
| PE-004 | Deploy exemption with policyDefinitionReferenceIds | Add exemption with referenceIds | 1 new exemption | Only specified policies exempted |
| PE-005 | Deploy exemption using policyDefinitionName | Add exemption by policy name | 1+ new exemptions | Exemption applies to all assignments |
| PE-006 | Deploy exemption using policySetDefinitionName | Add exemption by policy set name | 1+ new exemptions | Exemption applies to set assignments |
| PE-007 | Deploy exemption using policyAssignmentId | Add exemption by assignment ID | 1 new exemption | Exemption for specific assignment |
| PE-008 | Deploy exemption to multiple scopes | Add exemption with multiple scopes | 2+ new exemptions | Exemptions at all scopes |
| PE-009 | Deploy exemption with resourceSelectors | Add exemption with resourceSelectors | 1 new exemption | ResourceSelectors applied |
| PE-010 | Deploy exemption from CSV file | Add exemptions.csv file | 1+ new exemptions | Exemptions created from CSV |

---

## Stage 2: Update Operations (Modify Existing Resources)

**Objective:** Verify that existing resources are correctly updated when definitions change.

### 2.1 Policy Definition Updates

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PD-U01 | Update policy description | Modify description in existing policy file | 1 policy definition update | Description changed in Azure |
| PD-U02 | Update policy displayName | Modify displayName | 1 policy definition update | DisplayName changed in Azure |
| PD-U03 | Update policy metadata version | Change version from 1.0.0 to 1.0.1 | 1 policy definition update | Metadata version updated |
| PD-U04 | Update policy parameter defaultValue | Change defaultValue of existing parameter | 1 policy definition update | Default value updated |
| PD-U05 | Add new parameter to policy | Add new optional parameter to policy | 1 policy definition update | New parameter available |
| PD-U06 | Update policy rule logic | Modify if/then conditions | 1 policy definition update | Policy rule updated |
| PD-U07 | Update policy effect options | Add/remove from allowedValues | 1 policy definition update | Allowed values updated |
| PD-U08 | Verify no-change detection | Run with no file modifications | 0 changes in plan | No deployment occurs |

### 2.2 Policy Set Definition Updates

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PS-U01 | Add policy to policy set | Add new policyDefinition entry | 1 policy set update | New policy in set |
| PS-U02 | Remove policy from policy set | Remove policyDefinition entry | 1 policy set update | Policy removed from set |
| PS-U03 | Update policy set parameter | Change parameter definition | 1 policy set update | Parameter updated |
| PS-U04 | Update policy reference parameters | Change parameter value mapping | 1 policy set update | Reference parameters updated |
| PS-U05 | Update policy definition groups | Modify policyDefinitionGroups | 1 policy set update | Groups updated |
| PS-U06 | Update policy set version | Change version metadata | 1 policy set update | Version updated |

### 2.3 Policy Assignment Updates

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PA-U01 | Update assignment parameters | Change parameter values | 1 assignment update | Parameters updated in Azure |
| PA-U02 | Update assignment displayName | Change displayName | 1 assignment update | DisplayName changed |
| PA-U03 | Update assignment description | Change description | 1 assignment update | Description changed |
| PA-U04 | Add notScopes to assignment | Add exclusion scope to notScopes | 1 assignment update | notScopes updated |
| PA-U05 | Remove notScopes from assignment | Remove scope from notScopes | 1 assignment update | notScopes updated |
| PA-U06 | Update enforcementMode | Toggle Default ↔ DoNotEnforce | 1 assignment update | EnforcementMode changed |
| PA-U07 | Update assignment overrides | Modify override values | 1 assignment update | Overrides updated |
| PA-U08 | Update resourceSelectors | Modify selector conditions | 1 assignment update | Selectors updated |
| PA-U09 | Update nonComplianceMessages | Change message text | 1 assignment update | Messages updated |
| PA-U10 | Change managed identity location | Different region in managedIdentityLocations | 1 assignment replace | MI recreated in new region |

### 2.4 Role Assignment Updates

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| RA-U01 | Update when policy roleDefinitionIds change | Modify policy's roleDefinitionIds | roles-plan shows removed/added | Old role removed, new role added |
| RA-U02 | Add additional role assignments | Add additionalRoleAssignments entry | roles-plan shows added | Additional role created |
| RA-U03 | Remove additional role assignments | Remove additionalRoleAssignments entry | roles-plan shows removed | Role assignment removed |

### 2.5 Policy Exemption Updates

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PE-U01 | Update exemption displayName | Change displayName | 1 exemption update | DisplayName changed |
| PE-U02 | Update exemption description | Change description | 1 exemption update | Description changed |
| PE-U03 | Update exemption category | Change Waiver ↔ Mitigated | 1 exemption update | Category changed |
| PE-U04 | Update exemption expiration | Add/change/remove expiresOn | 1 exemption update | Expiration updated |
| PE-U05 | Update policyDefinitionReferenceIds | Change exempted policy refs | 1 exemption update | References updated |
| PE-U06 | Extend exemption scope | Add additional scope | 1 new exemption | New exemption at new scope |
| PE-U07 | Update exemption metadata | Modify metadata object | 1 exemption update | Metadata updated |

---

## Stage 3: Replace Operations (Breaking Changes)

**Objective:** Verify that resources requiring replacement are correctly handled (delete + recreate).

### 3.1 Policy Definition Replacements

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PD-R01 | Change policy name | Modify `name` attribute in policy file | 1 policy delete, 1 policy new | Old policy deleted, new policy created |
| PD-R02 | Change policy mode | Change mode from "All" to "Indexed" | 1 policy replace | Policy replaced with new mode |
| PD-R03 | Remove required parameter | Remove non-optional parameter | 1 policy replace | Policy replaced without parameter |
| PD-R04 | Change parameter type | Change String → Array | 1 policy replace | Policy replaced with new param type |

### 3.2 Policy Set Definition Replacements

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PS-R01 | Change policy set name | Modify `name` attribute | 1 policy set delete, 1 new | Old set deleted, new set created |
| PS-R02 | Change parameter type | Modify parameter type | 1 policy set replace | Set replaced with new param type |

### 3.3 Policy Assignment Replacements

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PA-R01 | Change assignment scope | Move to different scope in assignment file | 1 assignment delete, 1 new | Old deleted at old scope, new at new scope |
| PA-R02 | Change assigned definition | Point to different policy/set | 1 assignment replace | Assignment recreated with new definition |
| PA-R03 | Change identity type | Switch system ↔ user assigned | 1 assignment replace | Assignment recreated with new identity |

---

## Stage 4: Delete Operations

**Objective:** Verify that resources are correctly deleted when removed from definitions.

### 4.1 Policy Definition Deletions

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PD-D01 | Delete unused policy definition | Remove policy definition file | 1 policy definition delete | Policy no longer exists in Azure |
| PD-D02 | Delete policy with dependencies | Remove policy used in set (set still exists) | Error in plan build | Clear error about dependency |
| PD-D03 | Verify orphan detection | Create policy in Azure not in EPAC files | 1 policy delete (full strategy) | Orphan policy deleted |

### 4.2 Policy Set Definition Deletions

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PS-D01 | Delete unused policy set | Remove policy set file | 1 policy set delete | Set no longer exists |
| PS-D02 | Delete policy set with assignments | Remove set that is assigned | Error in plan build | Clear error about assignment dependency |
| PS-D03 | Verify orphan detection | Create set in Azure not in EPAC files | 1 policy set delete (full strategy) | Orphan set deleted |

### 4.3 Policy Assignment Deletions

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PA-D01 | Delete assignment by removing file | Remove assignment file | 1 assignment delete | Assignment no longer exists |
| PA-D02 | Delete assignment for one scope | Remove scope from assignment file | 1 assignment delete | Assignment deleted at that scope only |
| PA-D03 | Delete assignment with exemptions | Remove assignment that has exemptions | 1 assignment delete, exemptions deleted | Both assignment and exemptions removed |
| PA-D04 | Verify orphan detection | Create assignment in Azure not in EPAC | 1 assignment delete (full strategy) | Orphan assignment deleted |

### 4.4 Role Assignment Deletions

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| RA-D01 | Delete role when assignment deleted | Remove DINE assignment file | roles-plan shows removed | Role assignments cleaned up |
| RA-D02 | Delete orphan role assignments | Manually orphan role in Azure | roles-plan shows removed | Orphan roles removed |

### 4.5 Policy Exemption Deletions

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PE-D01 | Delete exemption by removing from file | Remove exemption entry | 1 exemption delete | Exemption no longer exists |
| PE-D02 | Delete expired exemptions | Exemption with past expiresOn date | Handled per cleanupObsoleteExemptions | Expired exemption removed |
| PE-D03 | Verify orphan detection | Create exemption in Azure not in EPAC | 1 exemption delete (full strategy) | Orphan exemption deleted |

---

## Stage 5: Desired State Strategy Testing

**Objective:** Verify the behavior differences between `full` and `ownedOnly` strategies.

### 5.1 Full Strategy

| Test ID | Test Name | Setup | File Modification | Expected Plan | Validation |
|---------|-----------|-------|-------------------|---------------|------------|
| DS-F01 | Full strategy deletes unmanaged policies | Create policy directly in Azure via CLI | None (just run plan) | 1 policy delete | Unmanaged policy deleted |
| DS-F02 | Full strategy deletes unmanaged sets | Create set directly in Azure | None | 1 policy set delete | Unmanaged set deleted |
| DS-F03 | Full strategy deletes unmanaged assignments | Create assignment directly in Azure | None | 1 assignment delete | Unmanaged assignment deleted |
| DS-F04 | Full strategy deletes unmanaged exemptions | Create exemption directly in Azure | None | 1 exemption delete | Unmanaged exemption deleted |
| DS-F05 | excludedScopes respected | Create policy at excluded scope | Add scope to excludedScopes | 0 deletes for that scope | Policy preserved |
| DS-F06 | excludedPolicyDefinitions respected | Create policy matching pattern | Add pattern to excludedPolicyDefinitions | 0 deletes matching pattern | Matched policies preserved |
| DS-F07 | excludedPolicySetDefinitions respected | Create set matching pattern | Add pattern to excludedPolicySetDefinitions | 0 deletes matching pattern | Matched sets preserved |
| DS-F08 | excludedPolicyAssignments respected | Create assignment matching pattern | Add pattern to excludedPolicyAssignments | 0 deletes matching pattern | Matched assignments preserved |
| DS-F09 | keepDfcSecurityAssignments works | DFC security assignment exists | Set keepDfcSecurityAssignments: true | 0 DFC assignment deletes | DFC assignments preserved |
| DS-F10 | excludeSubscriptions works | Subscriptions under root MG | Set excludeSubscriptions: true | Subscriptions ignored | Subscription policies not managed |

### 5.2 OwnedOnly Strategy

| Test ID | Test Name | Setup | File Modification | Expected Plan | Validation |
|---------|-----------|-------|-------------------|---------------|------------|
| DS-O01 | OwnedOnly preserves unmanaged policies | Create policy directly in Azure | Change strategy to ownedOnly | 0 policy deletes | Unmanaged policy preserved |
| DS-O02 | OwnedOnly preserves unmanaged sets | Create set directly in Azure | Change strategy to ownedOnly | 0 set deletes | Unmanaged set preserved |
| DS-O03 | OwnedOnly preserves unmanaged assignments | Create assignment directly in Azure | Change strategy to ownedOnly | 0 assignment deletes | Unmanaged assignment preserved |
| DS-O04 | OwnedOnly preserves unmanaged exemptions | Create exemption directly in Azure | Change strategy to ownedOnly | 0 exemption deletes | Unmanaged exemption preserved |
| DS-O05 | OwnedOnly deletes own resources | EPAC-deployed resource, then remove from files | Remove file, ownedOnly strategy | 1 delete | Own resource deleted |
| DS-O06 | pacOwnerId identification works | Deploy with EPAC, check metadata | None | N/A | deployedBy metadata contains pacOwnerId |

---

## Stage 6: Special Scenarios

**Objective:** Test edge cases and complex scenarios.

### 6.1 CSV Parameter Handling

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| CSV-01 | Deploy assignment with CSV parameters | Add assignment + CSV file with effects | 1 new assignment | Parameters from CSV applied |
| CSV-02 | Update CSV parameters | Modify values in CSV file | 1 assignment update | Updated parameters applied |
| CSV-03 | CSV with effect overrides | Add overrides column in CSV | 1 assignment update | Effects correctly overridden |
| CSV-04 | CSV with nonComplianceMessages | Add messages in CSV | 1 assignment update | Messages attached |

### 6.2 Multi-Environment Deployment

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| ME-01 | Deploy to multiple pacEnvironments | Add second pacEnvironment to global-settings | 1 assignment per env | Each env gets correct scope |
| ME-02 | Environment-specific parameters | Different param values per env | 1 assignment update | Correct values per environment |
| ME-03 | Environment-specific scopes | Different scopes in assignment file | 1 assignment per scope | Assignments at correct scopes |
| ME-04 | Skip environment in assignment | Remove scope for one env | 0 assignments for that env | Assignment skipped for that env |

### 6.3 Definition Dependency Handling

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| DEP-01 | Policy set references new custom policy | Add both policy and set files together | 1 new policy, 1 new set | Policy deployed before set |
| DEP-02 | Assignment references new policy set | Add both set and assignment together | 1 new set, 1 new assignment | Set deployed before assignment |
| DEP-03 | Update policy used by multiple sets | Modify shared policy file | 1 policy update | All dependent sets remain valid |
| DEP-04 | Circular dependency detection | Create invalid cross-references | Error in plan build | Clear error message |

### 6.4 Plan File Validation

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| PLN-01 | Verify policy-plan.json structure | Any deployment | Valid plan file | JSON matches expected schema |
| PLN-02 | Verify roles-plan.json structure | DINE deployment | Valid roles plan file | JSON matches expected schema |
| PLN-03 | Plan counts match changes | Various changes | Counts in plan | new/update/replace/delete counts accurate |
| PLN-04 | DetailedOutput shows diffs | Any update | Use -DetailedOutput flag | Line-by-line diff in output |

### 6.5 Error Handling

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| ERR-01 | Invalid policy definition JSON | Add malformed JSON file | Error in plan build | Clear error with file location |
| ERR-02 | Missing required properties | Add assignment without name | Error in plan build | Error shows nodeName breadcrumbs |
| ERR-03 | Invalid scope format | Add malformed scope path | Error in plan build | Error identifies invalid scope |
| ERR-04 | Assignment name exceeds 24 chars | Add assignment with long name | Error in plan build | Error about 24 char limit |
| ERR-05 | Duplicate policy names | Add two policies with same name | Error in plan build | Error identifying duplicates |
| ERR-06 | Invalid parameter reference | Assignment refs non-existent param | Error in plan build | Error identifying bad reference |
| ERR-07 | Permission denied (simulated) | Deploy without permissions | Error in deployment | Clear 403 error message |

### 6.6 Global Settings Variations

| Test ID | Test Name | File Modification | Expected Plan | Validation |
|---------|-----------|-------------------|---------------|------------|
| GS-01 | Custom deployedBy value | Add deployedBy to global-settings | 1 new policy | Metadata has custom deployedBy |
| GS-02 | globalNotScopes applied | Add globalNotScopes | 1 new assignment | notScopes includes global values |
| GS-03 | managedIdentityLocation used | Set custom MI location | 1 new DINE assignment | MI in specified region |
| GS-04 | Telemetry disabled | Set telemetryEnabled: false | Any plan | No telemetry in output |
| GS-05 | Multiple pacEnvironments | Add 3+ environments | Various | Each works independently |

---

## Stage 7: CI/CD Integration Testing

**Objective:** Validate pipeline integration and DevOps-specific outputs.

### 7.1 Azure DevOps Integration

| Test ID | Test Name | Command Modification | Expected Output | Validation |
|---------|-----------|---------------------|-----------------|------------|
| ADO-01 | DevOpsType ado output | Add `-DevOpsType ado` to Build-DeploymentPlans | Pipeline variables in stdout | Variables correctly formatted |
| ADO-02 | Conditional deployment variables | Policy changes detected | deployPolicyChanges = true | Variable set correctly |
| ADO-03 | No changes detection | No policy changes | deployPolicyChanges = false | Variable set correctly |
| ADO-04 | Role changes detection | Role changes present | deployRoleChanges = true | Variable set correctly |

### 7.2 GitLab Integration

| Test ID | Test Name | Command Modification | Expected Output | Validation |
|---------|-----------|---------------------|-----------------|------------|
| GL-01 | DevOpsType gitlab output | Add `-DevOpsType gitlab` to Build-DeploymentPlans | GitLab variables in stdout | Variables correctly formatted |
| GL-02 | GitLab variable format | Any changes | GitLab CI format | Format matches GitLab expectations |

### 7.3 Pipeline Idempotency

| Test ID | Test Name | Execution | Expected Plan | Validation |
|---------|-----------|-----------|---------------|------------|
| IDP-01 | Consecutive runs with no changes | Run Build-DeploymentPlans twice | 0 changes on second run | Second run shows unchanged |
| IDP-02 | Recovery after partial failure | Fail mid-deployment, then retry | Retry completes remaining | All resources in correct state |
| IDP-03 | Parallel environment safety | Deploy to multiple envs concurrently | Each env independent | No interference between envs |

### 7.4 BuildExemptionsOnly Mode

| Test ID | Test Name | Command Modification | Expected Plan | Validation |
|---------|-----------|---------------------|---------------|------------|
| BEO-01 | BuildExemptionsOnly skips policies | Add `-BuildExemptionsOnly` flag | Only exemptions in plan | Policies/sets/assignments ignored |
| BEO-02 | Fast-track exemptions | Add exemption, use BuildExemptionsOnly | 1 exemption only | Exemption deployed quickly |

### 7.5 SkipExemptions Mode

| Test ID | Test Name | Command Modification | Expected Plan | Validation |
|---------|-----------|---------------------|---------------|------------|
| SE-01 | SkipExemptions in Build | Add `-SkipExemptions` to Build-DeploymentPlans | No exemptions in plan | Exemptions not processed |
| SE-02 | SkipExemptions in Deploy | Add `-SkipExemptions` to Deploy-PolicyPlan | No exemptions deployed | Exemptions not deployed |

---

## Test Execution Framework

### Test Orchestration Scripts

The following PowerShell scripts orchestrate test execution using EPAC's native functionality.

#### Initialize-TestEnvironment.ps1

Sets up the test environment and baseline definitions.

```powershell
<#
.SYNOPSIS
    Initializes the EPAC regression test environment.
.DESCRIPTION
    - Creates the test management group if it doesn't exist
    - Copies baseline definitions to the test Definitions folder
    - Configures global-settings.jsonc with actual tenant/subscription IDs
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $true)]
    [string]$TestManagementGroupId,
    
    [Parameter(Mandatory = $false)]
    [string]$TestSubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$TestRootFolder = "./Tests"
)

# Create test folder structure
$folders = @(
    "$TestRootFolder/Definitions/policyDefinitions/Baseline",
    "$TestRootFolder/Definitions/policyDefinitions/TestCases",
    "$TestRootFolder/Definitions/policySetDefinitions/Baseline",
    "$TestRootFolder/Definitions/policySetDefinitions/TestCases",
    "$TestRootFolder/Definitions/policyAssignments/Baseline",
    "$TestRootFolder/Definitions/policyAssignments/TestCases",
    "$TestRootFolder/Definitions/policyExemptions/Baseline",
    "$TestRootFolder/Definitions/policyExemptions/TestCases",
    "$TestRootFolder/Output",
    "$TestRootFolder/Results"
)

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
}

# Generate global-settings.jsonc with actual values
$globalSettings = @{
    '$schema' = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json"
    pacOwnerId = "epac-regression-test-$(New-Guid)"
    pacEnvironments = @(
        @{
            pacSelector = "epac-test"
            cloud = "AzureCloud"
            tenantId = $TenantId
            deploymentRootScope = "/providers/Microsoft.Management/managementGroups/$TestManagementGroupId"
            desiredState = @{
                strategy = "full"
                keepDfcSecurityAssignments = $false
            }
            globalNotScopes = @()
            managedIdentityLocation = "eastus2"
        }
    )
}

$globalSettings | ConvertTo-Json -Depth 10 | Set-Content "$TestRootFolder/Definitions/global-settings.jsonc"

Write-Host "Test environment initialized at $TestRootFolder" -ForegroundColor Green
```

#### Invoke-TestStage.ps1

Executes a specific test case by modifying files, running EPAC commands, and validating with Pester.

```powershell
<#
.SYNOPSIS
    Executes a single test case using EPAC native functionality.
.DESCRIPTION
    1. Copies test case files to the Definitions folder
    2. Runs Build-DeploymentPlans
    3. Validates the plan matches expected changes
    4. Optionally deploys the changes
    5. Validates Azure state using Pester assertions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TestCaseId,
    
    [Parameter(Mandatory = $true)]
    [string]$TestCasePath,
    
    [Parameter(Mandatory = $false)]
    [string]$DefinitionsFolder = "./Tests/Definitions",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = "./Tests/Output",
    
    [Parameter(Mandatory = $false)]
    [string]$ResultsFolder = "./Tests/Results",
    
    [Parameter(Mandatory = $false)]
    [string]$ManagementGroupId = "epac-test-mg",
    
    [Parameter(Mandatory = $false)]
    [switch]$DeployChanges,
    
    [Parameter(Mandatory = $false)]
    [hashtable]$ExpectedPlan = @{},
    
    [Parameter(Mandatory = $false)]
    [hashtable]$ExpectedAzureState = @{}
)

$testResult = @{
    TestCaseId = $TestCaseId
    StartTime = Get-Date
    Steps = @()
    PlanValidation = $null
    AzureValidation = $null
    Success = $false
    ErrorMessage = $null
}

try {
    # Step 1: Copy test case files
    Write-Host "[$TestCaseId] Step 1: Applying test case files..." -ForegroundColor Cyan
    
    if (Test-Path $TestCasePath) {
        # Copy policy files from test case to definitions folder
        $policyFolders = @("policyDefinitions", "policySetDefinitions", "policyAssignments", "policyExemptions")
        foreach ($folder in $policyFolders) {
            $sourcePath = Join-Path $TestCasePath $folder
            if (Test-Path $sourcePath) {
                $targetPath = Join-Path $DefinitionsFolder $folder
                Copy-Item -Path "$sourcePath/*" -Destination $targetPath -Recurse -Force
            }
        }
        $testResult.Steps += @{ Step = "CopyFiles"; Success = $true }
    }
    else {
        throw "Test case path not found: $TestCasePath"
    }
    
    # Step 2: Build deployment plan
    Write-Host "[$TestCaseId] Step 2: Building deployment plan..." -ForegroundColor Cyan
    
    $buildParams = @{
        PacEnvironmentSelector = "epac-test"
        DefinitionsRootFolder = $DefinitionsFolder
        OutputFolder = $OutputFolder
    }
    
    Build-DeploymentPlans @buildParams
    $testResult.Steps += @{ Step = "BuildPlan"; Success = $true }
    
    # Step 3: Validate plan
    Write-Host "[$TestCaseId] Step 3: Validating deployment plan..." -ForegroundColor Cyan
    
    $planFile = Join-Path $OutputFolder "plans-epac-test/policy-plan.json"
    if (Test-Path $planFile) {
        $plan = Get-Content $planFile | ConvertFrom-Json
        
        $planValidation = @{ Passed = @(); Failed = @() }
        
        # Helper function to count object properties
        function Get-ObjectCount($obj) {
            if ($null -eq $obj) { return 0 }
            return ($obj.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' }).Count
        }
        
        # Validate expected counts
        if ($ExpectedPlan.ContainsKey('PolicyDefinitionsNew')) {
            $actualNew = Get-ObjectCount $plan.policyDefinitions.new
            if ($actualNew -eq $ExpectedPlan.PolicyDefinitionsNew) {
                $planValidation.Passed += "PolicyDefinitionsNew: $actualNew"
            } else {
                $planValidation.Failed += "PolicyDefinitionsNew: expected $($ExpectedPlan.PolicyDefinitionsNew), got $actualNew"
            }
        }
        
        if ($ExpectedPlan.ContainsKey('PolicyDefinitionsUpdate')) {
            $actualUpdate = Get-ObjectCount $plan.policyDefinitions.update
            if ($actualUpdate -eq $ExpectedPlan.PolicyDefinitionsUpdate) {
                $planValidation.Passed += "PolicyDefinitionsUpdate: $actualUpdate"
            } else {
                $planValidation.Failed += "PolicyDefinitionsUpdate: expected $($ExpectedPlan.PolicyDefinitionsUpdate), got $actualUpdate"
            }
        }
        
        if ($ExpectedPlan.ContainsKey('PolicyDefinitionsDelete')) {
            $actualDelete = Get-ObjectCount $plan.policyDefinitions.delete
            if ($actualDelete -eq $ExpectedPlan.PolicyDefinitionsDelete) {
                $planValidation.Passed += "PolicyDefinitionsDelete: $actualDelete"
            } else {
                $planValidation.Failed += "PolicyDefinitionsDelete: expected $($ExpectedPlan.PolicyDefinitionsDelete), got $actualDelete"
            }
        }
        
        # Similar checks for policy sets
        if ($ExpectedPlan.ContainsKey('PolicySetDefinitionsNew')) {
            $actualNew = Get-ObjectCount $plan.policySetDefinitions.new
            if ($actualNew -eq $ExpectedPlan.PolicySetDefinitionsNew) {
                $planValidation.Passed += "PolicySetDefinitionsNew: $actualNew"
            } else {
                $planValidation.Failed += "PolicySetDefinitionsNew: expected $($ExpectedPlan.PolicySetDefinitionsNew), got $actualNew"
            }
        }
        
        # Similar checks for assignments
        if ($ExpectedPlan.ContainsKey('AssignmentsNew')) {
            $actualNew = Get-ObjectCount $plan.assignments.new
            if ($actualNew -eq $ExpectedPlan.AssignmentsNew) {
                $planValidation.Passed += "AssignmentsNew: $actualNew"
            } else {
                $planValidation.Failed += "AssignmentsNew: expected $($ExpectedPlan.AssignmentsNew), got $actualNew"
            }
        }
        
        $testResult.PlanValidation = $planValidation
        
        if ($planValidation.Failed.Count -gt 0) {
            throw "Plan validation failed: $($planValidation.Failed -join '; ')"
        }
        
        $testResult.Steps += @{ Step = "ValidatePlan"; Success = $true }
    }
    else {
        Write-Host "[$TestCaseId] No plan file generated (no changes detected)" -ForegroundColor Yellow
        $testResult.Steps += @{ Step = "ValidatePlan"; Success = $true; Note = "No changes" }
    }
    
    # Step 4: Deploy changes (if requested)
    if ($DeployChanges) {
        Write-Host "[$TestCaseId] Step 4: Deploying policy plan..." -ForegroundColor Cyan
        
        $deployParams = @{
            PacEnvironmentSelector = "epac-test"
            DefinitionsRootFolder = $DefinitionsFolder
            InputFolder = $OutputFolder
        }
        
        Deploy-PolicyPlan @deployParams
        $testResult.Steps += @{ Step = "DeployPolicy"; Success = $true }
        
        # Check for roles plan
        $rolesPlanFile = Join-Path $OutputFolder "plans-epac-test/roles-plan.json"
        if (Test-Path $rolesPlanFile) {
            $rolesPlan = Get-Content $rolesPlanFile | ConvertFrom-Json
            if ($rolesPlan.roleAssignments.added.Count -gt 0 -or $rolesPlan.roleAssignments.removed.Count -gt 0) {
                Write-Host "[$TestCaseId] Step 5: Deploying roles plan..." -ForegroundColor Cyan
                Deploy-RolesPlan @deployParams
                $testResult.Steps += @{ Step = "DeployRoles"; Success = $true }
            }
        }
        
        # Step 6: Validate Azure state using Pester
        if ($ExpectedAzureState.Count -gt 0) {
            Write-Host "[$TestCaseId] Step 6: Validating Azure state with Pester..." -ForegroundColor Cyan
            
            $assertParams = @{
                TestCaseId = $TestCaseId
                ManagementGroupId = $ManagementGroupId
                OutputPath = $ResultsFolder
            }
            
            if ($ExpectedAzureState.ContainsKey('policyDefinitions')) {
                $assertParams.ExpectedPolicyDefinitions = $ExpectedAzureState.policyDefinitions
            }
            if ($ExpectedAzureState.ContainsKey('policySetDefinitions')) {
                $assertParams.ExpectedPolicySetDefinitions = $ExpectedAzureState.policySetDefinitions
            }
            if ($ExpectedAzureState.ContainsKey('policyAssignments')) {
                $assertParams.ExpectedPolicyAssignments = $ExpectedAzureState.policyAssignments
            }
            if ($ExpectedAzureState.ContainsKey('notExpectedPolicyDefinitions')) {
                $assertParams.NotExpectedPolicyDefinitions = $ExpectedAzureState.notExpectedPolicyDefinitions
            }
            if ($ExpectedAzureState.ContainsKey('properties')) {
                $assertParams.ExpectedProperties = $ExpectedAzureState.properties
            }
            
            $azureValidation = & "$PSScriptRoot/Assert-AzureState.ps1" @assertParams
            $testResult.AzureValidation = $azureValidation
            
            if (-not $azureValidation.Success) {
                throw "Azure state validation failed: $($azureValidation.FailedTests) Pester tests failed"
            }
            
            $testResult.Steps += @{ Step = "ValidateAzure"; Success = $true; PesterTests = $azureValidation.TotalTests }
        }
    }
    
    $testResult.Success = $true
    Write-Host "[$TestCaseId] TEST PASSED" -ForegroundColor Green
}
catch {
    $testResult.Success = $false
    $testResult.ErrorMessage = $_.Exception.Message
    Write-Host "[$TestCaseId] TEST FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    $testResult.EndTime = Get-Date
    $testResult.Duration = $testResult.EndTime - $testResult.StartTime
}

return $testResult
```

#### Assert-AzureState.ps1

Validates that Azure Policy resources match expected state after deployment using Pester assertions.

```powershell
<#
.SYNOPSIS
    Validates Azure Policy resources match expected state using Pester.
.DESCRIPTION
    Queries Azure to verify policy definitions, sets, assignments, and exemptions
    match the expected configuration after deployment. Uses Pester for assertions
    and structured test output.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TestCaseId,
    
    [Parameter(Mandatory = $true)]
    [string]$ManagementGroupId,
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExpectedPolicyDefinitions = @(),
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExpectedPolicySetDefinitions = @(),
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExpectedPolicyAssignments = @(),
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExpectedPolicyExemptions = @(),
    
    [Parameter(Mandatory = $false)]
    [string[]]$NotExpectedPolicyDefinitions = @(),
    
    [Parameter(Mandatory = $false)]
    [string[]]$NotExpectedPolicySetDefinitions = @(),
    
    [Parameter(Mandatory = $false)]
    [string[]]$NotExpectedPolicyAssignments = @(),
    
    [Parameter(Mandatory = $false)]
    [hashtable]$ExpectedProperties = @{},
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./Tests/Results"
)

# Ensure Pester is available
if (-not (Get-Module -ListAvailable -Name Pester)) {
    throw "Pester module is required. Install with: Install-Module -Name Pester -Force"
}

Import-Module Pester -MinimumVersion 5.0

$pesterConfig = New-PesterConfiguration
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputPath = "$OutputPath/$TestCaseId-results.xml"
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'

# Define the Pester test container
$container = New-PesterContainer -ScriptBlock {
    param(
        $TestCaseId,
        $ManagementGroupId,
        $ExpectedPolicyDefinitions,
        $ExpectedPolicySetDefinitions,
        $ExpectedPolicyAssignments,
        $ExpectedPolicyExemptions,
        $NotExpectedPolicyDefinitions,
        $NotExpectedPolicySetDefinitions,
        $NotExpectedPolicyAssignments,
        $ExpectedProperties
    )
    
    Describe "Azure State Validation for $TestCaseId" {
        
        Context "Policy Definitions" {
            
            foreach ($policyName in $ExpectedPolicyDefinitions) {
                It "Policy definition '$policyName' should exist" {
                    $policy = Get-AzPolicyDefinition -Name $policyName -ManagementGroupName $ManagementGroupId -ErrorAction SilentlyContinue
                    $policy | Should -Not -BeNullOrEmpty -Because "Policy '$policyName' should be deployed"
                }
            }
            
            foreach ($policyName in $NotExpectedPolicyDefinitions) {
                It "Policy definition '$policyName' should NOT exist" {
                    $policy = Get-AzPolicyDefinition -Name $policyName -ManagementGroupName $ManagementGroupId -ErrorAction SilentlyContinue
                    $policy | Should -BeNullOrEmpty -Because "Policy '$policyName' should have been deleted"
                }
            }
            
            # Check expected properties for policy definitions
            if ($ExpectedProperties.ContainsKey('policyDefinitions')) {
                foreach ($policyCheck in $ExpectedProperties.policyDefinitions) {
                    It "Policy '$($policyCheck.name)' should have correct $($policyCheck.property)" {
                        $policy = Get-AzPolicyDefinition -Name $policyCheck.name -ManagementGroupName $ManagementGroupId
                        $actualValue = $policy.Properties.$($policyCheck.property)
                        $actualValue | Should -Be $policyCheck.expectedValue
                    }
                }
            }
        }
        
        Context "Policy Set Definitions" {
            
            foreach ($setName in $ExpectedPolicySetDefinitions) {
                It "Policy set definition '$setName' should exist" {
                    $policySet = Get-AzPolicySetDefinition -Name $setName -ManagementGroupName $ManagementGroupId -ErrorAction SilentlyContinue
                    $policySet | Should -Not -BeNullOrEmpty -Because "Policy set '$setName' should be deployed"
                }
            }
            
            foreach ($setName in $NotExpectedPolicySetDefinitions) {
                It "Policy set definition '$setName' should NOT exist" {
                    $policySet = Get-AzPolicySetDefinition -Name $setName -ManagementGroupName $ManagementGroupId -ErrorAction SilentlyContinue
                    $policySet | Should -BeNullOrEmpty -Because "Policy set '$setName' should have been deleted"
                }
            }
            
            # Check expected properties for policy sets
            if ($ExpectedProperties.ContainsKey('policySetDefinitions')) {
                foreach ($setCheck in $ExpectedProperties.policySetDefinitions) {
                    It "Policy set '$($setCheck.name)' should have correct $($setCheck.property)" {
                        $policySet = Get-AzPolicySetDefinition -Name $setCheck.name -ManagementGroupName $ManagementGroupId
                        $actualValue = $policySet.Properties.$($setCheck.property)
                        $actualValue | Should -Be $setCheck.expectedValue
                    }
                }
            }
        }
        
        Context "Policy Assignments" {
            
            $mgScope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"
            
            foreach ($assignmentName in $ExpectedPolicyAssignments) {
                It "Policy assignment '$assignmentName' should exist" {
                    $assignment = Get-AzPolicyAssignment -Name $assignmentName -Scope $mgScope -ErrorAction SilentlyContinue
                    $assignment | Should -Not -BeNullOrEmpty -Because "Assignment '$assignmentName' should be deployed"
                }
            }
            
            foreach ($assignmentName in $NotExpectedPolicyAssignments) {
                It "Policy assignment '$assignmentName' should NOT exist" {
                    $assignment = Get-AzPolicyAssignment -Name $assignmentName -Scope $mgScope -ErrorAction SilentlyContinue
                    $assignment | Should -BeNullOrEmpty -Because "Assignment '$assignmentName' should have been deleted"
                }
            }
            
            # Check expected properties for assignments
            if ($ExpectedProperties.ContainsKey('policyAssignments')) {
                foreach ($assignCheck in $ExpectedProperties.policyAssignments) {
                    It "Assignment '$($assignCheck.name)' should have correct $($assignCheck.property)" {
                        $assignment = Get-AzPolicyAssignment -Name $assignCheck.name -Scope $mgScope
                        $actualValue = $assignment.Properties.$($assignCheck.property)
                        $actualValue | Should -Be $assignCheck.expectedValue
                    }
                }
            }
        }
        
        Context "Policy Exemptions" {
            
            $mgScope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"
            
            foreach ($exemptionName in $ExpectedPolicyExemptions) {
                It "Policy exemption '$exemptionName' should exist" {
                    $exemption = Get-AzPolicyExemption -Name $exemptionName -Scope $mgScope -ErrorAction SilentlyContinue
                    $exemption | Should -Not -BeNullOrEmpty -Because "Exemption '$exemptionName' should be deployed"
                }
            }
            
            # Check expected properties for exemptions
            if ($ExpectedProperties.ContainsKey('policyExemptions')) {
                foreach ($exCheck in $ExpectedProperties.policyExemptions) {
                    It "Exemption '$($exCheck.name)' should have correct $($exCheck.property)" {
                        $exemption = Get-AzPolicyExemption -Name $exCheck.name -Scope $mgScope
                        $actualValue = $exemption.Properties.$($exCheck.property)
                        $actualValue | Should -Be $exCheck.expectedValue
                    }
                }
            }
        }
        
        Context "Metadata Validation" {
            
            if ($ExpectedProperties.ContainsKey('validateMetadata') -and $ExpectedProperties.validateMetadata) {
                foreach ($policyName in $ExpectedPolicyDefinitions) {
                    It "Policy '$policyName' should have pacOwnerId in metadata" {
                        $policy = Get-AzPolicyDefinition -Name $policyName -ManagementGroupName $ManagementGroupId
                        $policy.Properties.Metadata.pacOwnerId | Should -Not -BeNullOrEmpty
                    }
                    
                    It "Policy '$policyName' should have deployedBy in metadata" {
                        $policy = Get-AzPolicyDefinition -Name $policyName -ManagementGroupName $ManagementGroupId
                        $policy.Properties.Metadata.deployedBy | Should -Not -BeNullOrEmpty
                    }
                }
            }
        }
        
        Context "Role Assignments" {
            
            if ($ExpectedProperties.ContainsKey('roleAssignments')) {
                foreach ($roleCheck in $ExpectedProperties.roleAssignments) {
                    It "Role assignment for '$($roleCheck.principalId)' with role '$($roleCheck.roleDefinitionId)' should exist at scope '$($roleCheck.scope)'" {
                        $roleAssignment = Get-AzRoleAssignment -ObjectId $roleCheck.principalId -Scope $roleCheck.scope -RoleDefinitionId $roleCheck.roleDefinitionId -ErrorAction SilentlyContinue
                        $roleAssignment | Should -Not -BeNullOrEmpty
                    }
                }
            }
        }
    }
} -Data @{
    TestCaseId = $TestCaseId
    ManagementGroupId = $ManagementGroupId
    ExpectedPolicyDefinitions = $ExpectedPolicyDefinitions
    ExpectedPolicySetDefinitions = $ExpectedPolicySetDefinitions
    ExpectedPolicyAssignments = $ExpectedPolicyAssignments
    ExpectedPolicyExemptions = $ExpectedPolicyExemptions
    NotExpectedPolicyDefinitions = $NotExpectedPolicyDefinitions
    NotExpectedPolicySetDefinitions = $NotExpectedPolicySetDefinitions
    NotExpectedPolicyAssignments = $NotExpectedPolicyAssignments
    ExpectedProperties = $ExpectedProperties
}

$pesterConfig.Run.Container = $container

# Run the tests
$result = Invoke-Pester -Configuration $pesterConfig

# Return summary
return @{
    TestCaseId = $TestCaseId
    TotalTests = $result.TotalCount
    PassedTests = $result.PassedCount
    FailedTests = $result.FailedCount
    SkippedTests = $result.SkippedCount
    Duration = $result.Duration
    Success = ($result.FailedCount -eq 0)
    ResultFile = "$OutputPath/$TestCaseId-results.xml"
}
```

#### Example: Using Assert-AzureState.ps1 with Pester

```powershell
# After deploying test case PD-001, validate the Azure state
$validationResult = .\Tests\Scripts\Assert-AzureState.ps1 `
    -TestCaseId "PD-001" `
    -ManagementGroupId "epac-test-mg" `
    -ExpectedPolicyDefinitions @("test-simple-audit-policy") `
    -ExpectedProperties @{
        validateMetadata = $true
        policyDefinitions = @(
            @{
                name = "test-simple-audit-policy"
                property = "DisplayName"
                expectedValue = "Test - Simple Audit Policy"
            },
            @{
                name = "test-simple-audit-policy"
                property = "Mode"
                expectedValue = "Indexed"
            }
        )
    }

if ($validationResult.Success) {
    Write-Host "✓ All Pester assertions passed ($($validationResult.PassedTests) tests)" -ForegroundColor Green
} else {
    Write-Host "✗ $($validationResult.FailedTests) Pester assertions failed" -ForegroundColor Red
}
```

#### Cleanup-TestEnvironment.ps1

Removes all test resources from Azure.

```powershell
<#
.SYNOPSIS
    Cleans up all EPAC regression test resources from Azure.
.DESCRIPTION
    Removes all policy assignments, exemptions, policy sets, and policy definitions
    created during testing.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManagementGroupId,
    
    [Parameter(Mandatory = $false)]
    [string]$PolicyPrefix = "test-"
)

Write-Host "Cleaning up test resources with prefix '$PolicyPrefix'..." -ForegroundColor Yellow

# Remove assignments first (they depend on definitions)
$assignments = Get-AzPolicyAssignment -Scope "/providers/Microsoft.Management/managementGroups/$ManagementGroupId" |
    Where-Object { $_.Name -like "$PolicyPrefix*" }

foreach ($assignment in $assignments) {
    Write-Host "Removing assignment: $($assignment.Name)" -ForegroundColor Cyan
    Remove-AzPolicyAssignment -Id $assignment.PolicyAssignmentId -ErrorAction SilentlyContinue
}

# Remove policy sets
$policySets = Get-AzPolicySetDefinition -ManagementGroupName $ManagementGroupId |
    Where-Object { $_.Name -like "$PolicyPrefix*" }

foreach ($policySet in $policySets) {
    Write-Host "Removing policy set: $($policySet.Name)" -ForegroundColor Cyan
    Remove-AzPolicySetDefinition -Id $policySet.PolicySetDefinitionId -Force -ErrorAction SilentlyContinue
}

# Remove policy definitions
$policies = Get-AzPolicyDefinition -ManagementGroupName $ManagementGroupId |
    Where-Object { $_.Name -like "$PolicyPrefix*" }

foreach ($policy in $policies) {
    Write-Host "Removing policy: $($policy.Name)" -ForegroundColor Cyan
    Remove-AzPolicyDefinition -Id $policy.PolicyDefinitionId -Force -ErrorAction SilentlyContinue
}

Write-Host "Cleanup complete." -ForegroundColor Green
```

### Test Case File Structure

Each test case is defined as a folder containing the policy files to deploy and a manifest file.

```
TestCases/
├── Stage1-Create/
│   ├── PD-001-SinglePolicyDefinition/
│   │   ├── manifest.json              # Test metadata and expectations
│   │   └── policyDefinitions/
│   │       └── simple-audit-policy.jsonc
│   ├── PD-002-AllParameterTypes/
│   │   ├── manifest.json
│   │   └── policyDefinitions/
│   │       └── all-param-types-policy.jsonc
│   └── PA-001-AssignToMG/
│       ├── manifest.json
│       └── policyAssignments/
│           └── mg-assignment.jsonc
```

#### manifest.json Example

```json
{
    "testCaseId": "PD-001",
    "testName": "Deploy single policy definition",
    "description": "Verifies that a single custom policy definition can be deployed",
    "stage": 1,
    "category": "PolicyDefinition",
    "prerequisites": [],
    "expectedPlan": {
        "policyDefinitions": {
            "new": 1,
            "update": 0,
            "replace": 0,
            "delete": 0
        },
        "policySetDefinitions": {
            "new": 0,
            "update": 0,
            "replace": 0,
            "delete": 0
        },
        "assignments": {
            "new": 0,
            "update": 0,
            "replace": 0,
            "delete": 0
        }
    },
    "expectedAzureState": {
        "policyDefinitions": ["test-simple-audit-policy"],
        "policySetDefinitions": [],
        "policyAssignments": [],
        "notExpectedPolicyDefinitions": [],
        "properties": {
            "validateMetadata": true,
            "policyDefinitions": [
                {
                    "name": "test-simple-audit-policy",
                    "property": "DisplayName",
                    "expectedValue": "Test - Simple Audit Policy"
                },
                {
                    "name": "test-simple-audit-policy",
                    "property": "Mode",
                    "expectedValue": "Indexed"
                }
            ]
        }
    },
    "deploy": true
}
```

### Running the Full Test Suite

```powershell
<#
.SYNOPSIS
    Full EPAC regression test suite execution script.
.DESCRIPTION
    Runs all test stages, validates deployment plans, deploys changes,
    and uses Pester to validate Azure state after each deployment.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $true)]
    [string]$TestManagementGroupId,
    
    [Parameter(Mandatory = $false)]
    [int[]]$Stages = @(1, 2, 3, 4, 5, 6, 7),
    
    [Parameter(Mandatory = $false)]
    [string]$TestRootFolder = "./Tests"
)

$allResults = @()

# Initialize
Write-Host "=== EPAC Regression Test Suite ===" -ForegroundColor Magenta
Write-Host "Using Pester for Azure state validation" -ForegroundColor Cyan
.\Tests\Scripts\Initialize-TestEnvironment.ps1 -TenantId $TenantId -TestManagementGroupId $TestManagementGroupId

# Execute each stage
foreach ($stage in $Stages) {
    Write-Host "`n=== Stage $stage ===" -ForegroundColor Magenta
    
    $stageFolders = Get-ChildItem -Path "$TestRootFolder/TestCases" -Directory | 
        Where-Object { $_.Name -like "Stage$stage-*" }
    
    foreach ($stageFolder in $stageFolders) {
        $testCases = Get-ChildItem -Path $stageFolder.FullName -Directory
        
        foreach ($testCase in $testCases) {
            $manifestPath = Join-Path $testCase.FullName "manifest.json"
            if (-not (Test-Path $manifestPath)) {
                Write-Host "Skipping $($testCase.Name) - no manifest.json" -ForegroundColor Yellow
                continue
            }
            
            $manifest = Get-Content $manifestPath | ConvertFrom-Json
            
            # Build expected plan hashtable
            $expectedPlan = @{}
            if ($manifest.expectedPlan.policyDefinitions) {
                $expectedPlan.PolicyDefinitionsNew = $manifest.expectedPlan.policyDefinitions.new
                $expectedPlan.PolicyDefinitionsUpdate = $manifest.expectedPlan.policyDefinitions.update
                $expectedPlan.PolicyDefinitionsDelete = $manifest.expectedPlan.policyDefinitions.delete
            }
            if ($manifest.expectedPlan.policySetDefinitions) {
                $expectedPlan.PolicySetDefinitionsNew = $manifest.expectedPlan.policySetDefinitions.new
            }
            if ($manifest.expectedPlan.assignments) {
                $expectedPlan.AssignmentsNew = $manifest.expectedPlan.assignments.new
            }
            
            # Build expected Azure state hashtable for Pester validation
            $expectedAzureState = @{}
            if ($manifest.expectedAzureState) {
                if ($manifest.expectedAzureState.policyDefinitions) {
                    $expectedAzureState.policyDefinitions = $manifest.expectedAzureState.policyDefinitions
                }
                if ($manifest.expectedAzureState.policySetDefinitions) {
                    $expectedAzureState.policySetDefinitions = $manifest.expectedAzureState.policySetDefinitions
                }
                if ($manifest.expectedAzureState.policyAssignments) {
                    $expectedAzureState.policyAssignments = $manifest.expectedAzureState.policyAssignments
                }
                if ($manifest.expectedAzureState.notExpectedPolicyDefinitions) {
                    $expectedAzureState.notExpectedPolicyDefinitions = $manifest.expectedAzureState.notExpectedPolicyDefinitions
                }
                if ($manifest.expectedAzureState.properties) {
                    $expectedAzureState.properties = $manifest.expectedAzureState.properties
                }
            }
            
            $result = .\Tests\Scripts\Invoke-TestStage.ps1 `
                -TestCaseId $manifest.testCaseId `
                -TestCasePath $testCase.FullName `
                -ManagementGroupId $TestManagementGroupId `
                -DeployChanges:$manifest.deploy `
                -ExpectedPlan $expectedPlan `
                -ExpectedAzureState $expectedAzureState
            
            $allResults += $result
        }
    }
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Magenta
$passed = ($allResults | Where-Object { $_.Success }).Count
$failed = ($allResults | Where-Object { -not $_.Success }).Count
$totalPesterTests = ($allResults | Where-Object { $_.AzureValidation } | 
    ForEach-Object { $_.AzureValidation.TotalTests } | Measure-Object -Sum).Sum

Write-Host "Test Cases Passed: $passed" -ForegroundColor Green
Write-Host "Test Cases Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host "Total Pester Assertions: $totalPesterTests" -ForegroundColor Cyan

# Show failed tests
if ($failed -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $allResults | Where-Object { -not $_.Success } | ForEach-Object {
        Write-Host "  - $($_.TestCaseId): $($_.ErrorMessage)" -ForegroundColor Red
    }
}

# Cleanup
Write-Host "`n=== Cleanup ===" -ForegroundColor Magenta
.\Tests\Scripts\Cleanup-TestEnvironment.ps1 -ManagementGroupId $TestManagementGroupId

# Export results
$resultsFile = "$TestRootFolder/Results/test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$allResults | ConvertTo-Json -Depth 10 | Set-Content $resultsFile
Write-Host "Results exported to: $resultsFile" -ForegroundColor Green

# Return exit code
if ($failed -gt 0) {
    exit 1
}
exit 0
```

---

## Local Execution

### Quick Start - Running Tests Locally

```powershell
# Prerequisites check
Write-Host "Checking prerequisites..." -ForegroundColor Cyan

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw "PowerShell 7+ is required. Current version: $($PSVersionTable.PSVersion)"
}

# Check required modules
$requiredModules = @('Az.Accounts', 'Az.Resources', 'Pester', 'EnterprisePolicyAsCode')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Force -Scope CurrentUser
    }
}

# Authenticate to Azure
Connect-AzAccount -TenantId "<your-tenant-id>"

Write-Host "Prerequisites check complete!" -ForegroundColor Green
```

### Run-LocalTests.ps1

This is the main entry point for running tests locally.

```powershell
<#
.SYNOPSIS
    Runs EPAC regression tests locally.
.DESCRIPTION
    Main entry point for local test execution. Authenticates to Azure,
    runs all or selected test stages, and generates a summary report.
.EXAMPLE
    .\Tests\Scripts\Run-LocalTests.ps1 -TenantId "xxx" -TestManagementGroupId "epac-test-mg"
.EXAMPLE
    .\Tests\Scripts\Run-LocalTests.ps1 -TenantId "xxx" -TestManagementGroupId "epac-test-mg" -Stages 1,2 -SkipCleanup
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure Tenant ID for testing")]
    [string]$TenantId,
    
    [Parameter(Mandatory = $true, HelpMessage = "Management Group ID for test deployments")]
    [string]$TestManagementGroupId,
    
    [Parameter(Mandatory = $false, HelpMessage = "Test subscription ID (for RG-scoped tests)")]
    [string]$TestSubscriptionId,
    
    [Parameter(Mandatory = $false, HelpMessage = "Stages to run (1-7). Default: all stages")]
    [int[]]$Stages = @(1, 2, 3, 4, 5, 6, 7),
    
    [Parameter(Mandatory = $false, HelpMessage = "Specific test case IDs to run")]
    [string[]]$TestCaseIds,
    
    [Parameter(Mandatory = $false, HelpMessage = "Skip cleanup after tests")]
    [switch]$SkipCleanup,
    
    [Parameter(Mandatory = $false, HelpMessage = "Continue on test failure")]
    [switch]$ContinueOnError,
    
    [Parameter(Mandatory = $false, HelpMessage = "Generate HTML report")]
    [switch]$GenerateHtmlReport,
    
    [Parameter(Mandatory = $false)]
    [string]$TestRootFolder = "./Tests"
)

$ErrorActionPreference = if ($ContinueOnError) { "Continue" } else { "Stop" }

# Banner
Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║           EPAC Regression Test Suite - Local Execution        ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

$startTime = Get-Date
Write-Host "Start Time: $startTime" -ForegroundColor Cyan
Write-Host "Tenant ID: $TenantId" -ForegroundColor Cyan
Write-Host "Test Management Group: $TestManagementGroupId" -ForegroundColor Cyan
Write-Host "Stages to run: $($Stages -join ', ')" -ForegroundColor Cyan

# Verify Azure connection
Write-Host "`n[1/5] Verifying Azure connection..." -ForegroundColor Yellow
$context = Get-AzContext
if (-not $context -or $context.Tenant.Id -ne $TenantId) {
    Write-Host "Connecting to Azure tenant: $TenantId" -ForegroundColor Cyan
    Connect-AzAccount -TenantId $TenantId
}
Write-Host "✓ Connected as: $($context.Account.Id)" -ForegroundColor Green

# Initialize test environment
Write-Host "`n[2/5] Initializing test environment..." -ForegroundColor Yellow
& "$TestRootFolder/Scripts/Initialize-TestEnvironment.ps1" `
    -TenantId $TenantId `
    -TestManagementGroupId $TestManagementGroupId `
    -TestSubscriptionId $TestSubscriptionId `
    -TestRootFolder $TestRootFolder
Write-Host "✓ Test environment initialized" -ForegroundColor Green

# Run tests
Write-Host "`n[3/5] Executing test stages..." -ForegroundColor Yellow
$allResults = @()
$stageResults = @{}

foreach ($stage in $Stages) {
    Write-Host "`n━━━ Stage $stage ━━━" -ForegroundColor Magenta
    
    $stageFolders = Get-ChildItem -Path "$TestRootFolder/TestCases" -Directory | 
        Where-Object { $_.Name -like "Stage$stage-*" }
    
    $stageResults[$stage] = @{ Passed = 0; Failed = 0; Skipped = 0 }
    
    foreach ($stageFolder in $stageFolders) {
        $testCases = Get-ChildItem -Path $stageFolder.FullName -Directory
        
        foreach ($testCase in $testCases) {
            $manifestPath = Join-Path $testCase.FullName "manifest.json"
            if (-not (Test-Path $manifestPath)) { continue }
            
            $manifest = Get-Content $manifestPath | ConvertFrom-Json
            
            # Filter by specific test case IDs if provided
            if ($TestCaseIds -and $manifest.testCaseId -notin $TestCaseIds) {
                $stageResults[$stage].Skipped++
                continue
            }
            
            # Build parameters
            $expectedPlan = @{}
            if ($manifest.expectedPlan.policyDefinitions) {
                $expectedPlan.PolicyDefinitionsNew = $manifest.expectedPlan.policyDefinitions.new
                $expectedPlan.PolicyDefinitionsUpdate = $manifest.expectedPlan.policyDefinitions.update
                $expectedPlan.PolicyDefinitionsDelete = $manifest.expectedPlan.policyDefinitions.delete
            }
            
            $expectedAzureState = @{}
            if ($manifest.expectedAzureState) {
                $expectedAzureState = $manifest.expectedAzureState
            }
            
            $result = & "$TestRootFolder/Scripts/Invoke-TestStage.ps1" `
                -TestCaseId $manifest.testCaseId `
                -TestCasePath $testCase.FullName `
                -ManagementGroupId $TestManagementGroupId `
                -DefinitionsFolder "$TestRootFolder/Definitions" `
                -OutputFolder "$TestRootFolder/Output" `
                -ResultsFolder "$TestRootFolder/Results" `
                -DeployChanges:$manifest.deploy `
                -ExpectedPlan $expectedPlan `
                -ExpectedAzureState $expectedAzureState
            
            $allResults += $result
            
            if ($result.Success) {
                $stageResults[$stage].Passed++
            } else {
                $stageResults[$stage].Failed++
                if (-not $ContinueOnError) {
                    throw "Test $($manifest.testCaseId) failed: $($result.ErrorMessage)"
                }
            }
        }
    }
}

# Generate summary report
Write-Host "`n[4/5] Generating test summary..." -ForegroundColor Yellow
$summaryReport = & "$TestRootFolder/Scripts/New-TestSummaryReport.ps1" `
    -AllResults $allResults `
    -StageResults $stageResults `
    -OutputFolder "$TestRootFolder/Results" `
    -GenerateHtml:$GenerateHtmlReport

# Cleanup
if (-not $SkipCleanup) {
    Write-Host "`n[5/5] Cleaning up test resources..." -ForegroundColor Yellow
    & "$TestRootFolder/Scripts/Cleanup-TestEnvironment.ps1" -ManagementGroupId $TestManagementGroupId
    Write-Host "✓ Cleanup complete" -ForegroundColor Green
} else {
    Write-Host "`n[5/5] Skipping cleanup (--SkipCleanup specified)" -ForegroundColor Yellow
}

# Final summary
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║                    TEST EXECUTION COMPLETE                     ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor $(if ($summaryReport.OverallSuccess) { "Green" } else { "Red" })

Write-Host $summaryReport.SummaryText

Write-Host "`nDuration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
Write-Host "Results: $($summaryReport.ResultsFile)" -ForegroundColor Cyan

if (-not $summaryReport.OverallSuccess) {
    exit 1
}
exit 0
```

### New-TestSummaryReport.ps1

Generates the final pass/fail summary report.

```powershell
<#
.SYNOPSIS
    Generates a comprehensive test summary report.
.DESCRIPTION
    Creates JSON and optionally HTML reports summarizing all test results.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [array]$AllResults,
    
    [Parameter(Mandatory = $true)]
    [hashtable]$StageResults,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = "./Tests/Results",
    
    [Parameter(Mandatory = $false)]
    [switch]$GenerateHtml
)

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Calculate totals
$totalTests = $AllResults.Count
$passedTests = ($AllResults | Where-Object { $_.Success }).Count
$failedTests = ($AllResults | Where-Object { -not $_.Success }).Count
$totalPesterAssertions = ($AllResults | Where-Object { $_.AzureValidation } | 
    ForEach-Object { $_.AzureValidation.TotalTests } | Measure-Object -Sum).Sum
$passedPesterAssertions = ($AllResults | Where-Object { $_.AzureValidation } | 
    ForEach-Object { $_.AzureValidation.PassedTests } | Measure-Object -Sum).Sum

$overallSuccess = $failedTests -eq 0

# Build summary object
$summary = [ordered]@{
    timestamp = Get-Date -Format 'o'
    overallSuccess = $overallSuccess
    overallResult = if ($overallSuccess) { "PASSED" } else { "FAILED" }
    totals = [ordered]@{
        testCases = $totalTests
        passed = $passedTests
        failed = $failedTests
        passRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
        pesterAssertions = [ordered]@{
            total = $totalPesterAssertions
            passed = $passedPesterAssertions
            failed = $totalPesterAssertions - $passedPesterAssertions
        }
    }
    stageResults = [ordered]@{}
    failedTests = @()
    allResults = $AllResults
}

# Add stage breakdown
foreach ($stage in ($StageResults.Keys | Sort-Object)) {
    $sr = $StageResults[$stage]
    $summary.stageResults["Stage$stage"] = [ordered]@{
        passed = $sr.Passed
        failed = $sr.Failed
        skipped = $sr.Skipped
        total = $sr.Passed + $sr.Failed + $sr.Skipped
    }
}

# List failed tests
$summary.failedTests = $AllResults | Where-Object { -not $_.Success } | ForEach-Object {
    [ordered]@{
        testCaseId = $_.TestCaseId
        errorMessage = $_.ErrorMessage
        duration = $_.Duration.ToString()
    }
}

# Generate summary text for console output
$summaryText = @"

┌─────────────────────────────────────────────────────────────────┐
│                        TEST SUMMARY                             │
├─────────────────────────────────────────────────────────────────┤
│  Overall Result:  $(if ($overallSuccess) { "✓ PASSED" } else { "✗ FAILED" })                                        │
├─────────────────────────────────────────────────────────────────┤
│  Test Cases:      $passedTests passed / $failedTests failed / $totalTests total     │
│  Pass Rate:       $($summary.totals.passRate)%                                            │
│  Pester Tests:    $passedPesterAssertions passed / $($totalPesterAssertions - $passedPesterAssertions) failed / $totalPesterAssertions total     │
├─────────────────────────────────────────────────────────────────┤
│  Stage Breakdown:                                               │
"@

foreach ($stage in ($StageResults.Keys | Sort-Object)) {
    $sr = $StageResults[$stage]
    $stageStatus = if ($sr.Failed -eq 0) { "✓" } else { "✗" }
    $summaryText += "`n│    Stage $stage`: $stageStatus $($sr.Passed) passed, $($sr.Failed) failed                            │"
}

$summaryText += @"

└─────────────────────────────────────────────────────────────────┘
"@

if ($failedTests -gt 0) {
    $summaryText += "`n┌─────────────────────────────────────────────────────────────────┐"
    $summaryText += "`n│                      FAILED TESTS                               │"
    $summaryText += "`n├─────────────────────────────────────────────────────────────────┤"
    foreach ($failed in $summary.failedTests) {
        $summaryText += "`n│  ✗ $($failed.testCaseId): $($failed.errorMessage.Substring(0, [Math]::Min(45, $failed.errorMessage.Length)))..."
    }
    $summaryText += "`n└─────────────────────────────────────────────────────────────────┘"
}

# Save JSON report
$resultsFile = "$OutputFolder/test-summary-$timestamp.json"
$summary | ConvertTo-Json -Depth 10 | Set-Content $resultsFile

# Generate HTML report if requested
if ($GenerateHtml) {
    $htmlFile = "$OutputFolder/test-summary-$timestamp.html"
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>EPAC Regression Test Results - $timestamp</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        .summary-box { display: flex; gap: 20px; margin: 20px 0; }
        .stat-card { flex: 1; padding: 20px; border-radius: 8px; text-align: center; }
        .stat-card.passed { background: #d4edda; border: 1px solid #28a745; }
        .stat-card.failed { background: #f8d7da; border: 1px solid #dc3545; }
        .stat-card.total { background: #e7f3ff; border: 1px solid #0078d4; }
        .stat-number { font-size: 48px; font-weight: bold; }
        .stat-label { font-size: 14px; color: #666; }
        .stage-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        .stage-table th, .stage-table td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        .stage-table th { background: #f8f9fa; }
        .status-pass { color: #28a745; font-weight: bold; }
        .status-fail { color: #dc3545; font-weight: bold; }
        .failed-tests { background: #fff3cd; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .overall-result { font-size: 24px; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0; }
        .overall-result.passed { background: #28a745; color: white; }
        .overall-result.failed { background: #dc3545; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>EPAC Regression Test Results</h1>
        <p>Generated: $timestamp</p>
        
        <div class="overall-result $(if ($overallSuccess) { 'passed' } else { 'failed' })">
            $(if ($overallSuccess) { '✓ ALL TESTS PASSED' } else { '✗ SOME TESTS FAILED' })
        </div>
        
        <div class="summary-box">
            <div class="stat-card passed">
                <div class="stat-number">$passedTests</div>
                <div class="stat-label">Tests Passed</div>
            </div>
            <div class="stat-card failed">
                <div class="stat-number">$failedTests</div>
                <div class="stat-label">Tests Failed</div>
            </div>
            <div class="stat-card total">
                <div class="stat-number">$($summary.totals.passRate)%</div>
                <div class="stat-label">Pass Rate</div>
            </div>
        </div>
        
        <h2>Stage Results</h2>
        <table class="stage-table">
            <tr><th>Stage</th><th>Passed</th><th>Failed</th><th>Skipped</th><th>Status</th></tr>
            $(foreach ($stage in ($StageResults.Keys | Sort-Object)) {
                $sr = $StageResults[$stage]
                "<tr><td>Stage $stage</td><td>$($sr.Passed)</td><td>$($sr.Failed)</td><td>$($sr.Skipped)</td><td class='$(if ($sr.Failed -eq 0) { "status-pass" } else { "status-fail" })'>$(if ($sr.Failed -eq 0) { "✓ PASS" } else { "✗ FAIL" })</td></tr>"
            })
        </table>
        
        $(if ($failedTests -gt 0) {
            "<h2>Failed Tests</h2><div class='failed-tests'><ul>"
            foreach ($failed in $summary.failedTests) {
                "<li><strong>$($failed.testCaseId)</strong>: $($failed.errorMessage)</li>"
            }
            "</ul></div>"
        })
    </div>
</body>
</html>
"@
    $htmlContent | Set-Content $htmlFile
    Write-Host "HTML report: $htmlFile" -ForegroundColor Cyan
}

return @{
    OverallSuccess = $overallSuccess
    SummaryText = $summaryText
    ResultsFile = $resultsFile
    Summary = $summary
}
```

### Test Execution Order

Tests should be executed in stage order to build on previous state:

1. **Setup Phase:** Run `Initialize-TestEnvironment.ps1` to create test environment
2. **Stage 1 Tests:** Initial deployment (creates baseline resources in Azure)
3. **Stage 2 Tests:** Update operations (modifies Stage 1 resources)
4. **Stage 3 Tests:** Replace operations (recreates selected resources)
5. **Stage 4 Tests:** Delete operations (removes resources)
6. **Stage 5 Tests:** Desired state strategy (requires isolated sub-tests with setup/teardown)
7. **Stage 6 Tests:** Special scenarios (various edge cases, may require reset)
8. **Stage 7 Tests:** CI/CD integration validation
9. **Cleanup Phase:** Run `Cleanup-TestEnvironment.ps1` to remove all test resources

### Test Isolation

For tests that require a clean state or specific pre-conditions:

1. Each test case folder contains all necessary files to establish its starting state
2. Tests use unique naming prefixes (e.g., `test-st1-pd001-`, `test-st2-pa001-`)
3. The `Invoke-TestStage.ps1` script can copy files to create the required state
4. Some Stage 5 and 6 tests may require complete cleanup between runs

### Running Individual Tests

```powershell
# Run a single test case
.\Tests\Scripts\Invoke-TestStage.ps1 `
    -TestCaseId "PD-001" `
    -TestCasePath "./Tests/TestCases/Stage1-Create/PD-001-SinglePolicyDefinition" `
    -DefinitionsFolder "./Tests/Definitions" `
    -OutputFolder "./Tests/Output" `
    -DeployChanges `
    -ExpectedPlan @{
        PolicyDefinitionsNew = 1
        PolicyDefinitionsUpdate = 0
        PolicyDefinitionsDelete = 0
    }
```

### Running a Full Stage

```powershell
# Run all Stage 1 tests
$stage1Tests = Get-ChildItem -Path "./Tests/TestCases/Stage1-Create" -Directory

foreach ($testCase in $stage1Tests) {
    $manifest = Get-Content "$($testCase.FullName)/manifest.json" | ConvertFrom-Json
    
    .\Tests\Scripts\Invoke-TestStage.ps1 `
        -TestCaseId $manifest.testCaseId `
        -TestCasePath $testCase.FullName `
        -DeployChanges:$manifest.deploy `
        -ExpectedPlan @{
            PolicyDefinitionsNew = $manifest.expectedPlan.policyDefinitions.new
            PolicyDefinitionsUpdate = $manifest.expectedPlan.policyDefinitions.update
            PolicyDefinitionsDelete = $manifest.expectedPlan.policyDefinitions.delete
        }
}
```

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Test Coverage | All EPAC object types and operations covered |
| Pass Rate | 100% for release approval |
| Plan Validation | All `Build-DeploymentPlans` outputs match expected changes |
| Deployment Success | All `Deploy-PolicyPlan` and `Deploy-RolesPlan` complete without errors |
| Azure State Validation | All deployed resources match expected configuration |
| Execution Time | < 60 minutes for full suite |
| Resource Cleanup | 100% automated cleanup via `Cleanup-TestEnvironment.ps1` |

---

## Test Summary by Stage

| Stage | Category | Test Count | Focus Area |
|-------|----------|------------|------------|
| 1 | Create | 43 | Initial deployment of all object types |
| 2 | Update | 34 | Modifications to existing resources |
| 3 | Replace | 9 | Breaking changes requiring recreate |
| 4 | Delete | 14 | Resource removal and orphan detection |
| 5 | Desired State | 16 | Full vs ownedOnly strategy behavior |
| 6 | Special | 28 | Edge cases, CSV, multi-env, errors |
| 7 | CI/CD | 14 | Pipeline integration and flags |
| **Total** | | **158** | |

---

## GitHub Actions Workflow

The following GitHub Actions workflow runs the regression tests when a PR is created or updated. Place this file at `.github/workflows/regression-tests.yml`.

### .github/workflows/regression-tests.yml

```yaml
name: EPAC Regression Tests

on:
  pull_request:
    branches:
      - main
      - develop
    paths:
      - 'Module/**'
      - 'Scripts/**'
      - 'Tests/**'
  workflow_dispatch:
    inputs:
      stages:
        description: 'Stages to run (comma-separated, e.g., 1,2,3)'
        required: false
        default: '1,2,3,4,5,6,7'
      skip_cleanup:
        description: 'Skip cleanup after tests'
        required: false
        default: 'false'
        type: boolean

permissions:
  id-token: write
  contents: read
  pull-requests: write

env:
  TEST_MANAGEMENT_GROUP_ID: ${{ secrets.TEST_MANAGEMENT_GROUP_ID }}
  TEST_SUBSCRIPTION_ID: ${{ secrets.TEST_SUBSCRIPTION_ID }}
  AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}

jobs:
  # ─────────────────────────────────────────────────────────────────
  # Job 1: Setup and Initialize Test Environment
  # ─────────────────────────────────────────────────────────────────
  setup:
    name: '🔧 Setup Test Environment'
    runs-on: ubuntu-latest
    outputs:
      test-run-id: ${{ steps.setup.outputs.test-run-id }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup PowerShell
        shell: pwsh
        run: |
          $PSVersionTable
          Install-Module -Name Az.Accounts -Force -Scope CurrentUser
          Install-Module -Name Az.Resources -Force -Scope CurrentUser
          Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
          Install-Module -Name EnterprisePolicyAsCode -Force -Scope CurrentUser

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ env.AZURE_CLIENT_ID }}
          tenant-id: ${{ env.AZURE_TENANT_ID }}
          subscription-id: ${{ env.TEST_SUBSCRIPTION_ID }}
          enable-AzPSSession: true

      - name: Initialize Test Environment
        id: setup
        shell: pwsh
        run: |
          $testRunId = "run-$(Get-Date -Format 'yyyyMMddHHmmss')"
          echo "test-run-id=$testRunId" >> $env:GITHUB_OUTPUT
          
          ./Tests/Scripts/Initialize-TestEnvironment.ps1 `
            -TenantId "${{ env.AZURE_TENANT_ID }}" `
            -TestManagementGroupId "${{ env.TEST_MANAGEMENT_GROUP_ID }}" `
            -TestSubscriptionId "${{ env.TEST_SUBSCRIPTION_ID }}" `
            -TestRootFolder "./Tests"

      - name: Upload Test Definitions
        uses: actions/upload-artifact@v4
        with:
          name: test-definitions-${{ steps.setup.outputs.test-run-id }}
          path: Tests/Definitions/
          retention-days: 1

  # ─────────────────────────────────────────────────────────────────
  # Job 2: Stage 1 - Create Operations
  # ─────────────────────────────────────────────────────────────────
  stage-1-create:
    name: '📦 Stage 1: Create Operations'
    runs-on: ubuntu-latest
    needs: setup
    outputs:
      stage-passed: ${{ steps.run-tests.outputs.stage-passed }}
      tests-passed: ${{ steps.run-tests.outputs.tests-passed }}
      tests-failed: ${{ steps.run-tests.outputs.tests-failed }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup PowerShell Modules
        shell: pwsh
        run: |
          Install-Module -Name Az.Accounts -Force -Scope CurrentUser
          Install-Module -Name Az.Resources -Force -Scope CurrentUser
          Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
          Install-Module -Name EnterprisePolicyAsCode -Force -Scope CurrentUser

      - name: Download Test Definitions
        uses: actions/download-artifact@v4
        with:
          name: test-definitions-${{ needs.setup.outputs.test-run-id }}
          path: Tests/Definitions/

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ env.AZURE_CLIENT_ID }}
          tenant-id: ${{ env.AZURE_TENANT_ID }}
          subscription-id: ${{ env.TEST_SUBSCRIPTION_ID }}
          enable-AzPSSession: true

      - name: Run Stage 1 Tests
        id: run-tests
        shell: pwsh
        run: |
          $results = ./Tests/Scripts/Invoke-StageTests.ps1 `
            -Stage 1 `
            -ManagementGroupId "${{ env.TEST_MANAGEMENT_GROUP_ID }}" `
            -TestRootFolder "./Tests" `
            -OutputFormat "GitHubActions"
          
          echo "stage-passed=$($results.StagePassed)" >> $env:GITHUB_OUTPUT
          echo "tests-passed=$($results.Passed)" >> $env:GITHUB_OUTPUT
          echo "tests-failed=$($results.Failed)" >> $env:GITHUB_OUTPUT
          
          # Write to job summary
          $results.MarkdownSummary >> $env:GITHUB_STEP_SUMMARY
          
          if (-not $results.StagePassed) {
            exit 1
          }

      - name: Upload Stage 1 Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: stage-1-results-${{ needs.setup.outputs.test-run-id }}
          path: Tests/Results/Stage1/
          retention-days: 7

  # ─────────────────────────────────────────────────────────────────
  # Job 3: Stage 2 - Update Operations
  # ─────────────────────────────────────────────────────────────────
  stage-2-update:
    name: '✏️ Stage 2: Update Operations'
    runs-on: ubuntu-latest
    needs: [setup, stage-1-create]
    if: ${{ needs.stage-1-create.outputs.stage-passed == 'true' || github.event.inputs.stages != '' }}
    outputs:
      stage-passed: ${{ steps.run-tests.outputs.stage-passed }}
      tests-passed: ${{ steps.run-tests.outputs.tests-passed }}
      tests-failed: ${{ steps.run-tests.outputs.tests-failed }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup PowerShell Modules
        shell: pwsh
        run: |
          Install-Module -Name Az.Accounts -Force -Scope CurrentUser
          Install-Module -Name Az.Resources -Force -Scope CurrentUser
          Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
          Install-Module -Name EnterprisePolicyAsCode -Force -Scope CurrentUser

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ env.AZURE_CLIENT_ID }}
          tenant-id: ${{ env.AZURE_TENANT_ID }}
          subscription-id: ${{ env.TEST_SUBSCRIPTION_ID }}
          enable-AzPSSession: true

      - name: Run Stage 2 Tests
        id: run-tests
        shell: pwsh
        run: |
          $results = ./Tests/Scripts/Invoke-StageTests.ps1 `
            -Stage 2 `
            -ManagementGroupId "${{ env.TEST_MANAGEMENT_GROUP_ID }}" `
            -TestRootFolder "./Tests" `
            -OutputFormat "GitHubActions"
          
          echo "stage-passed=$($results.StagePassed)" >> $env:GITHUB_OUTPUT
          echo "tests-passed=$($results.Passed)" >> $env:GITHUB_OUTPUT
          echo "tests-failed=$($results.Failed)" >> $env:GITHUB_OUTPUT
          
          $results.MarkdownSummary >> $env:GITHUB_STEP_SUMMARY
          
          if (-not $results.StagePassed) { exit 1 }

      - name: Upload Stage 2 Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: stage-2-results-${{ needs.setup.outputs.test-run-id }}
          path: Tests/Results/Stage2/
          retention-days: 7

  # ─────────────────────────────────────────────────────────────────
  # Job 4: Stage 3 - Replace Operations
  # ─────────────────────────────────────────────────────────────────
  stage-3-replace:
    name: '🔄 Stage 3: Replace Operations'
    runs-on: ubuntu-latest
    needs: [setup, stage-2-update]
    if: ${{ needs.stage-2-update.outputs.stage-passed == 'true' || github.event.inputs.stages != '' }}
    outputs:
      stage-passed: ${{ steps.run-tests.outputs.stage-passed }}
      tests-passed: ${{ steps.run-tests.outputs.tests-passed }}
      tests-failed: ${{ steps.run-tests.outputs.tests-failed }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup PowerShell Modules
        shell: pwsh
        run: |
          Install-Module -Name Az.Accounts -Force -Scope CurrentUser
          Install-Module -Name Az.Resources -Force -Scope CurrentUser
          Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
          Install-Module -Name EnterprisePolicyAsCode -Force -Scope CurrentUser

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ env.AZURE_CLIENT_ID }}
          tenant-id: ${{ env.AZURE_TENANT_ID }}
          subscription-id: ${{ env.TEST_SUBSCRIPTION_ID }}
          enable-AzPSSession: true

      - name: Run Stage 3 Tests
        id: run-tests
        shell: pwsh
        run: |
          $results = ./Tests/Scripts/Invoke-StageTests.ps1 `
            -Stage 3 `
            -ManagementGroupId "${{ env.TEST_MANAGEMENT_GROUP_ID }}" `
            -TestRootFolder "./Tests" `
            -OutputFormat "GitHubActions"
          
          echo "stage-passed=$($results.StagePassed)" >> $env:GITHUB_OUTPUT
          echo "tests-passed=$($results.Passed)" >> $env:GITHUB_OUTPUT
          echo "tests-failed=$($results.Failed)" >> $env:GITHUB_OUTPUT
          
          $results.MarkdownSummary >> $env:GITHUB_STEP_SUMMARY
          
          if (-not $results.StagePassed) { exit 1 }

      - name: Upload Stage 3 Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: stage-3-results-${{ needs.setup.outputs.test-run-id }}
          path: Tests/Results/Stage3/
          retention-days: 7

  # ─────────────────────────────────────────────────────────────────
  # Job 5: Stage 4 - Delete Operations
  # ─────────────────────────────────────────────────────────────────
  stage-4-delete:
    name: '🗑️ Stage 4: Delete Operations'
    runs-on: ubuntu-latest
    needs: [setup, stage-3-replace]
    if: ${{ needs.stage-3-replace.outputs.stage-passed == 'true' || github.event.inputs.stages != '' }}
    outputs:
      stage-passed: ${{ steps.run-tests.outputs.stage-passed }}
      tests-passed: ${{ steps.run-tests.outputs.tests-passed }}
      tests-failed: ${{ steps.run-tests.outputs.tests-failed }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup PowerShell Modules
        shell: pwsh
        run: |
          Install-Module -Name Az.Accounts -Force -Scope CurrentUser
          Install-Module -Name Az.Resources -Force -Scope CurrentUser
          Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
          Install-Module -Name EnterprisePolicyAsCode -Force -Scope CurrentUser

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ env.AZURE_CLIENT_ID }}
          tenant-id: ${{ env.AZURE_TENANT_ID }}
          subscription-id: ${{ env.TEST_SUBSCRIPTION_ID }}
          enable-AzPSSession: true

      - name: Run Stage 4 Tests
        id: run-tests
        shell: pwsh
        run: |
          $results = ./Tests/Scripts/Invoke-StageTests.ps1 `
            -Stage 4 `
            -ManagementGroupId "${{ env.TEST_MANAGEMENT_GROUP_ID }}" `
            -TestRootFolder "./Tests" `
            -OutputFormat "GitHubActions"
          
          echo "stage-passed=$($results.StagePassed)" >> $env:GITHUB_OUTPUT
          echo "tests-passed=$($results.Passed)" >> $env:GITHUB_OUTPUT
          echo "tests-failed=$($results.Failed)" >> $env:GITHUB_OUTPUT
          
          $results.MarkdownSummary >> $env:GITHUB_STEP_SUMMARY
          
          if (-not $results.StagePassed) { exit 1 }

      - name: Upload Stage 4 Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: stage-4-results-${{ needs.setup.outputs.test-run-id }}
          path: Tests/Results/Stage4/
          retention-days: 7

  # ─────────────────────────────────────────────────────────────────
  # Job 6: Stage 5 - Desired State Strategy
  # ─────────────────────────────────────────────────────────────────
  stage-5-desired-state:
    name: '🎯 Stage 5: Desired State Strategy'
    runs-on: ubuntu-latest
    needs: [setup, stage-4-delete]
    if: ${{ needs.stage-4-delete.outputs.stage-passed == 'true' || github.event.inputs.stages != '' }}
    outputs:
      stage-passed: ${{ steps.run-tests.outputs.stage-passed }}
      tests-passed: ${{ steps.run-tests.outputs.tests-passed }}
      tests-failed: ${{ steps.run-tests.outputs.tests-failed }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup PowerShell Modules
        shell: pwsh
        run: |
          Install-Module -Name Az.Accounts -Force -Scope CurrentUser
          Install-Module -Name Az.Resources -Force -Scope CurrentUser
          Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
          Install-Module -Name EnterprisePolicyAsCode -Force -Scope CurrentUser

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ env.AZURE_CLIENT_ID }}
          tenant-id: ${{ env.AZURE_TENANT_ID }}
          subscription-id: ${{ env.TEST_SUBSCRIPTION_ID }}
          enable-AzPSSession: true

      - name: Run Stage 5 Tests
        id: run-tests
        shell: pwsh
        run: |
          $results = ./Tests/Scripts/Invoke-StageTests.ps1 `
            -Stage 5 `
            -ManagementGroupId "${{ env.TEST_MANAGEMENT_GROUP_ID }}" `
            -TestRootFolder "./Tests" `
            -OutputFormat "GitHubActions"
          
          echo "stage-passed=$($results.StagePassed)" >> $env:GITHUB_OUTPUT
          echo "tests-passed=$($results.Passed)" >> $env:GITHUB_OUTPUT
          echo "tests-failed=$($results.Failed)" >> $env:GITHUB_OUTPUT
          
          $results.MarkdownSummary >> $env:GITHUB_STEP_SUMMARY
          
          if (-not $results.StagePassed) { exit 1 }

      - name: Upload Stage 5 Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: stage-5-results-${{ needs.setup.outputs.test-run-id }}
          path: Tests/Results/Stage5/
          retention-days: 7

  # ─────────────────────────────────────────────────────────────────
  # Job 7: Stage 6 - Special Scenarios
  # ─────────────────────────────────────────────────────────────────
  stage-6-special:
    name: '⚡ Stage 6: Special Scenarios'
    runs-on: ubuntu-latest
    needs: [setup, stage-5-desired-state]
    if: ${{ needs.stage-5-desired-state.outputs.stage-passed == 'true' || github.event.inputs.stages != '' }}
    outputs:
      stage-passed: ${{ steps.run-tests.outputs.stage-passed }}
      tests-passed: ${{ steps.run-tests.outputs.tests-passed }}
      tests-failed: ${{ steps.run-tests.outputs.tests-failed }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup PowerShell Modules
        shell: pwsh
        run: |
          Install-Module -Name Az.Accounts -Force -Scope CurrentUser
          Install-Module -Name Az.Resources -Force -Scope CurrentUser
          Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
          Install-Module -Name EnterprisePolicyAsCode -Force -Scope CurrentUser

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ env.AZURE_CLIENT_ID }}
          tenant-id: ${{ env.AZURE_TENANT_ID }}
          subscription-id: ${{ env.TEST_SUBSCRIPTION_ID }}
          enable-AzPSSession: true

      - name: Run Stage 6 Tests
        id: run-tests
        shell: pwsh
        run: |
          $results = ./Tests/Scripts/Invoke-StageTests.ps1 `
            -Stage 6 `
            -ManagementGroupId "${{ env.TEST_MANAGEMENT_GROUP_ID }}" `
            -TestRootFolder "./Tests" `
            -OutputFormat "GitHubActions"
          
          echo "stage-passed=$($results.StagePassed)" >> $env:GITHUB_OUTPUT
          echo "tests-passed=$($results.Passed)" >> $env:GITHUB_OUTPUT
          echo "tests-failed=$($results.Failed)" >> $env:GITHUB_OUTPUT
          
          $results.MarkdownSummary >> $env:GITHUB_STEP_SUMMARY
          
          if (-not $results.StagePassed) { exit 1 }

      - name: Upload Stage 6 Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: stage-6-results-${{ needs.setup.outputs.test-run-id }}
          path: Tests/Results/Stage6/
          retention-days: 7

  # ─────────────────────────────────────────────────────────────────
  # Job 8: Stage 7 - CI/CD Integration
  # ─────────────────────────────────────────────────────────────────
  stage-7-cicd:
    name: '🚀 Stage 7: CI/CD Integration'
    runs-on: ubuntu-latest
    needs: [setup, stage-6-special]
    if: ${{ needs.stage-6-special.outputs.stage-passed == 'true' || github.event.inputs.stages != '' }}
    outputs:
      stage-passed: ${{ steps.run-tests.outputs.stage-passed }}
      tests-passed: ${{ steps.run-tests.outputs.tests-passed }}
      tests-failed: ${{ steps.run-tests.outputs.tests-failed }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup PowerShell Modules
        shell: pwsh
        run: |
          Install-Module -Name Az.Accounts -Force -Scope CurrentUser
          Install-Module -Name Az.Resources -Force -Scope CurrentUser
          Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
          Install-Module -Name EnterprisePolicyAsCode -Force -Scope CurrentUser

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ env.AZURE_CLIENT_ID }}
          tenant-id: ${{ env.AZURE_TENANT_ID }}
          subscription-id: ${{ env.TEST_SUBSCRIPTION_ID }}
          enable-AzPSSession: true

      - name: Run Stage 7 Tests
        id: run-tests
        shell: pwsh
        run: |
          $results = ./Tests/Scripts/Invoke-StageTests.ps1 `
            -Stage 7 `
            -ManagementGroupId "${{ env.TEST_MANAGEMENT_GROUP_ID }}" `
            -TestRootFolder "./Tests" `
            -OutputFormat "GitHubActions"
          
          echo "stage-passed=$($results.StagePassed)" >> $env:GITHUB_OUTPUT
          echo "tests-passed=$($results.Passed)" >> $env:GITHUB_OUTPUT
          echo "tests-failed=$($results.Failed)" >> $env:GITHUB_OUTPUT
          
          $results.MarkdownSummary >> $env:GITHUB_STEP_SUMMARY
          
          if (-not $results.StagePassed) { exit 1 }

      - name: Upload Stage 7 Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: stage-7-results-${{ needs.setup.outputs.test-run-id }}
          path: Tests/Results/Stage7/
          retention-days: 7

  # ─────────────────────────────────────────────────────────────────
  # Job 9: Final Summary and Cleanup
  # ─────────────────────────────────────────────────────────────────
  summary-and-cleanup:
    name: '📊 Summary & Cleanup'
    runs-on: ubuntu-latest
    needs: [setup, stage-1-create, stage-2-update, stage-3-replace, stage-4-delete, stage-5-desired-state, stage-6-special, stage-7-cicd]
    if: always()
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Download All Results
        uses: actions/download-artifact@v4
        with:
          path: all-results/
          pattern: stage-*-results-${{ needs.setup.outputs.test-run-id }}

      - name: Setup PowerShell Modules
        shell: pwsh
        run: |
          Install-Module -Name Az.Accounts -Force -Scope CurrentUser
          Install-Module -Name Az.Resources -Force -Scope CurrentUser

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ env.AZURE_CLIENT_ID }}
          tenant-id: ${{ env.AZURE_TENANT_ID }}
          subscription-id: ${{ env.TEST_SUBSCRIPTION_ID }}
          enable-AzPSSession: true

      - name: Generate Final Summary
        shell: pwsh
        run: |
          # Collect stage results from job outputs
          $stageResults = @{
            1 = @{ Passed = ${{ needs.stage-1-create.outputs.tests-passed || 0 }}; Failed = ${{ needs.stage-1-create.outputs.tests-failed || 0 }}; Status = "${{ needs.stage-1-create.outputs.stage-passed || 'skipped' }}" }
            2 = @{ Passed = ${{ needs.stage-2-update.outputs.tests-passed || 0 }}; Failed = ${{ needs.stage-2-update.outputs.tests-failed || 0 }}; Status = "${{ needs.stage-2-update.outputs.stage-passed || 'skipped' }}" }
            3 = @{ Passed = ${{ needs.stage-3-replace.outputs.tests-passed || 0 }}; Failed = ${{ needs.stage-3-replace.outputs.tests-failed || 0 }}; Status = "${{ needs.stage-3-replace.outputs.stage-passed || 'skipped' }}" }
            4 = @{ Passed = ${{ needs.stage-4-delete.outputs.tests-passed || 0 }}; Failed = ${{ needs.stage-4-delete.outputs.tests-failed || 0 }}; Status = "${{ needs.stage-4-delete.outputs.stage-passed || 'skipped' }}" }
            5 = @{ Passed = ${{ needs.stage-5-desired-state.outputs.tests-passed || 0 }}; Failed = ${{ needs.stage-5-desired-state.outputs.tests-failed || 0 }}; Status = "${{ needs.stage-5-desired-state.outputs.stage-passed || 'skipped' }}" }
            6 = @{ Passed = ${{ needs.stage-6-special.outputs.tests-passed || 0 }}; Failed = ${{ needs.stage-6-special.outputs.tests-failed || 0 }}; Status = "${{ needs.stage-6-special.outputs.stage-passed || 'skipped' }}" }
            7 = @{ Passed = ${{ needs.stage-7-cicd.outputs.tests-passed || 0 }}; Failed = ${{ needs.stage-7-cicd.outputs.tests-failed || 0 }}; Status = "${{ needs.stage-7-cicd.outputs.stage-passed || 'skipped' }}" }
          }
          
          $totalPassed = ($stageResults.Values | ForEach-Object { $_.Passed } | Measure-Object -Sum).Sum
          $totalFailed = ($stageResults.Values | ForEach-Object { $_.Failed } | Measure-Object -Sum).Sum
          $totalTests = $totalPassed + $totalFailed
          $overallSuccess = $totalFailed -eq 0
          
          # Generate markdown summary for GitHub
          $summary = @"
          # 🧪 EPAC Regression Test Results
          
          ## Overall Result: $(if ($overallSuccess) { '✅ PASSED' } else { '❌ FAILED' })
          
          | Metric | Value |
          |--------|-------|
          | **Total Tests** | $totalTests |
          | **Passed** | $totalPassed |
          | **Failed** | $totalFailed |
          | **Pass Rate** | $([math]::Round(($totalPassed / [math]::Max($totalTests, 1)) * 100, 1))% |
          
          ## Stage Results
          
          | Stage | Description | Passed | Failed | Status |
          |-------|-------------|--------|--------|--------|
          | 1 | Create Operations | $($stageResults[1].Passed) | $($stageResults[1].Failed) | $(if ($stageResults[1].Status -eq 'true') { '✅' } elseif ($stageResults[1].Status -eq 'false') { '❌' } else { '⏭️' }) |
          | 2 | Update Operations | $($stageResults[2].Passed) | $($stageResults[2].Failed) | $(if ($stageResults[2].Status -eq 'true') { '✅' } elseif ($stageResults[2].Status -eq 'false') { '❌' } else { '⏭️' }) |
          | 3 | Replace Operations | $($stageResults[3].Passed) | $($stageResults[3].Failed) | $(if ($stageResults[3].Status -eq 'true') { '✅' } elseif ($stageResults[3].Status -eq 'false') { '❌' } else { '⏭️' }) |
          | 4 | Delete Operations | $($stageResults[4].Passed) | $($stageResults[4].Failed) | $(if ($stageResults[4].Status -eq 'true') { '✅' } elseif ($stageResults[4].Status -eq 'false') { '❌' } else { '⏭️' }) |
          | 5 | Desired State | $($stageResults[5].Passed) | $($stageResults[5].Failed) | $(if ($stageResults[5].Status -eq 'true') { '✅' } elseif ($stageResults[5].Status -eq 'false') { '❌' } else { '⏭️' }) |
          | 6 | Special Scenarios | $($stageResults[6].Passed) | $($stageResults[6].Failed) | $(if ($stageResults[6].Status -eq 'true') { '✅' } elseif ($stageResults[6].Status -eq 'false') { '❌' } else { '⏭️' }) |
          | 7 | CI/CD Integration | $($stageResults[7].Passed) | $($stageResults[7].Failed) | $(if ($stageResults[7].Status -eq 'true') { '✅' } elseif ($stageResults[7].Status -eq 'false') { '❌' } else { '⏭️' }) |
          
          ---
          *Test Run ID: ${{ needs.setup.outputs.test-run-id }}*
          "@
          
          $summary >> $env:GITHUB_STEP_SUMMARY
          
          # Save summary to file for artifact
          $summary | Set-Content "./final-summary.md"

      - name: Cleanup Test Resources
        if: ${{ github.event.inputs.skip_cleanup != 'true' }}
        shell: pwsh
        run: |
          Write-Host "Cleaning up test resources..." -ForegroundColor Yellow
          ./Tests/Scripts/Cleanup-TestEnvironment.ps1 -ManagementGroupId "${{ env.TEST_MANAGEMENT_GROUP_ID }}"
          Write-Host "Cleanup complete" -ForegroundColor Green

      - name: Upload Final Summary
        uses: actions/upload-artifact@v4
        with:
          name: final-summary-${{ needs.setup.outputs.test-run-id }}
          path: final-summary.md
          retention-days: 30

      - name: Set Final Exit Code
        shell: pwsh
        run: |
          $stage1 = "${{ needs.stage-1-create.outputs.stage-passed }}"
          $stage2 = "${{ needs.stage-2-update.outputs.stage-passed }}"
          $stage3 = "${{ needs.stage-3-replace.outputs.stage-passed }}"
          $stage4 = "${{ needs.stage-4-delete.outputs.stage-passed }}"
          $stage5 = "${{ needs.stage-5-desired-state.outputs.stage-passed }}"
          $stage6 = "${{ needs.stage-6-special.outputs.stage-passed }}"
          $stage7 = "${{ needs.stage-7-cicd.outputs.stage-passed }}"
          
          $allPassed = @($stage1, $stage2, $stage3, $stage4, $stage5, $stage6, $stage7) | 
            Where-Object { $_ -ne '' } | 
            ForEach-Object { $_ -eq 'true' }
          
          if ($allPassed -contains $false) {
            Write-Host "❌ One or more stages failed" -ForegroundColor Red
            exit 1
          }
          
          Write-Host "✅ All stages passed!" -ForegroundColor Green
```

### Required GitHub Secrets

Configure these secrets in your GitHub repository:

| Secret Name | Description |
|-------------|-------------|
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_CLIENT_ID` | Service principal client ID (for OIDC federation) |
| `TEST_MANAGEMENT_GROUP_ID` | Management group for test deployments |
| `TEST_SUBSCRIPTION_ID` | Subscription for resource group scoped tests |

### Federated Credentials Setup

For OIDC authentication (recommended), configure federated credentials on your Azure AD app registration:

1. Navigate to Azure AD > App Registrations > Your App > Certificates & secrets
2. Add federated credential:
   - **Organization:** Your GitHub organization
   - **Repository:** Your repo name  
   - **Entity type:** Pull Request
   - **Subject identifier:** `repo:org/repo:pull_request`

---

## Invoke-StageTests.ps1

Helper script to run all tests for a specific stage.

```powershell
<#
.SYNOPSIS
    Runs all tests for a specific stage.
.DESCRIPTION
    Executes all test cases under a stage folder and returns aggregated results.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$Stage,
    
    [Parameter(Mandatory = $true)]
    [string]$ManagementGroupId,
    
    [Parameter(Mandatory = $false)]
    [string]$TestRootFolder = "./Tests",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "GitHubActions")]
    [string]$OutputFormat = "Console"
)

$stageFolder = Get-ChildItem -Path "$TestRootFolder/TestCases" -Directory | 
    Where-Object { $_.Name -like "Stage$Stage-*" }

if (-not $stageFolder) {
    throw "Stage $Stage folder not found"
}

$results = @{
    Stage = $Stage
    StagePassed = $true
    Passed = 0
    Failed = 0
    Results = @()
    MarkdownSummary = ""
}

$testCases = Get-ChildItem -Path $stageFolder.FullName -Directory

foreach ($testCase in $testCases) {
    $manifestPath = Join-Path $testCase.FullName "manifest.json"
    if (-not (Test-Path $manifestPath)) { continue }
    
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    
    Write-Host "Running test: $($manifest.testCaseId)" -ForegroundColor Cyan
    
    try {
        # Build expected plan parameters
        $expectedPlan = @{}
        if ($manifest.expectedPlan.policyDefinitions) {
            $expectedPlan.PolicyDefinitionsNew = $manifest.expectedPlan.policyDefinitions.new
            $expectedPlan.PolicyDefinitionsUpdate = $manifest.expectedPlan.policyDefinitions.update
            $expectedPlan.PolicyDefinitionsDelete = $manifest.expectedPlan.policyDefinitions.delete
        }
        
        # Run test
        $testResult = & "$TestRootFolder/Scripts/Invoke-TestStage.ps1" `
            -TestCaseId $manifest.testCaseId `
            -TestCasePath $testCase.FullName `
            -ManagementGroupId $ManagementGroupId `
            -DefinitionsFolder "$TestRootFolder/Definitions" `
            -OutputFolder "$TestRootFolder/Output" `
            -ResultsFolder "$TestRootFolder/Results/Stage$Stage" `
            -DeployChanges:$manifest.deploy `
            -ExpectedPlan $expectedPlan
        
        $results.Results += $testResult
        
        if ($testResult.Success) {
            $results.Passed++
            Write-Host "  ✓ PASSED" -ForegroundColor Green
        } else {
            $results.Failed++
            $results.StagePassed = $false
            Write-Host "  ✗ FAILED: $($testResult.ErrorMessage)" -ForegroundColor Red
        }
    }
    catch {
        $results.Failed++
        $results.StagePassed = $false
        Write-Host "  ✗ ERROR: $_" -ForegroundColor Red
        $results.Results += @{
            TestCaseId = $manifest.testCaseId
            Success = $false
            ErrorMessage = $_.Exception.Message
        }
    }
}

# Generate markdown summary
$results.MarkdownSummary = @"
## Stage $Stage Results

| Test Case | Status | Duration |
|-----------|--------|----------|
$(foreach ($r in $results.Results) {
"| $($r.TestCaseId) | $(if ($r.Success) { '✅ Pass' } else { '❌ Fail' }) | $($r.Duration.ToString('mm\:ss')) |"
})

**Total:** $($results.Passed) passed, $($results.Failed) failed
"@

# Create results directory if needed
$resultsDir = "$TestRootFolder/Results/Stage$Stage"
if (-not (Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
}

# Save stage results
$results | ConvertTo-Json -Depth 10 | Set-Content "$resultsDir/stage-results.json"

return $results
```

---

## Next Steps

1. **Phase 1:** Create test folder structure and baseline definition files
   - Create `Tests/Definitions/` with global-settings.jsonc
   - Create baseline policy, set, assignment, and exemption files
   - Create `Tests/Scripts/` with orchestration scripts

2. **Phase 2:** Implement Stage 1 test cases
   - Create test case folders under `Tests/TestCases/Stage1-Create/`
   - Each folder contains manifest.json and policy files
   - Run and validate all create operations

3. **Phase 3:** Implement Stage 2-4 test cases
   - Build on Stage 1 resources for update tests
   - Test replace and delete scenarios
   
4. **Phase 4:** Implement Stage 5-6 test cases
   - Desired state strategy testing (may require environment resets)
   - Special scenarios and error handling

5. **Phase 5:** Implement Stage 7 test cases
   - CI/CD flag validation
   - Pipeline integration testing

6. **Phase 6:** Deploy to CI/CD
   - Add `.github/workflows/regression-tests.yml` to repository
   - Configure GitHub secrets for Azure authentication
   - Test workflow on a feature branch PR
