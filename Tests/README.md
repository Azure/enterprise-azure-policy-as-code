# EPAC Regression Test Suite

This folder contains the regression test suite for Enterprise Policy as Code (EPAC).

## Quick Start

### Prerequisites

1. **PowerShell 7+** (recommended)
2. **Required Modules:**
   ```powershell
   Install-Module -Name Az.Accounts -Force -Scope CurrentUser
   Install-Module -Name Az.Resources -Force -Scope CurrentUser
   Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
   Install-Module -Name EnterprisePolicyAsCode -Force -Scope CurrentUser
   ```

3. **Azure Access:**
   - A test Azure tenant
   - A test management group for policy deployments
   - Appropriate permissions (Policy Contributor, User Access Administrator)

### Running Tests Locally

```powershell
# Navigate to the repository root
cd c:\epac-projects\epac-github

# Run Stage 1 tests (plan only - no Azure changes)
.\Tests\Scripts\Run-LocalTests.ps1 `
    -TenantId "your-tenant-id" `
    -TestManagementGroupId "your-test-mg-id" `
    -Stages 1

# Run Stage 1 tests with deployment to Azure
.\Tests\Scripts\Run-LocalTests.ps1 `
    -TenantId "your-tenant-id" `
    -TestManagementGroupId "your-test-mg-id" `
    -Stages 1 `
    -Deploy

# Run specific test cases
.\Tests\Scripts\Run-LocalTests.ps1 `
    -TenantId "your-tenant-id" `
    -TestManagementGroupId "your-test-mg-id" `
    -TestCaseIds "PD-001", "PD-002" `
    -Deploy

# Run and skip cleanup (keep resources for inspection)
.\Tests\Scripts\Run-LocalTests.ps1 `
    -TenantId "your-tenant-id" `
    -TestManagementGroupId "your-test-mg-id" `
    -Stages 1 `
    -Deploy `
    -SkipCleanup
```

## Folder Structure

```
Tests/
├── Scripts/                    # Test orchestration scripts
│   ├── Run-LocalTests.ps1      # Main entry point for local testing
│   ├── Initialize-TestEnvironment.ps1
│   ├── Invoke-TestStage.ps1    # Runs a single test case
│   ├── Assert-AzureState.ps1   # Pester-based Azure validation
│   └── Cleanup-TestEnvironment.ps1
│
├── Definitions/                # Working definitions (generated)
│   ├── global-settings.jsonc
│   ├── policyDefinitions/
│   ├── policySetDefinitions/
│   ├── policyAssignments/
│   └── policyExemptions/
│
├── TestCases/                  # Test case definitions
│   ├── Stage1-Create/          # Create operations
│   ├── Stage2-Update/          # Update operations
│   ├── Stage3-Replace/         # Replace operations
│   ├── Stage4-Delete/          # Delete operations
│   ├── Stage5-DesiredState/    # Desired state tests
│   ├── Stage6-Special/         # Special scenarios
│   └── Stage7-CICD/            # CI/CD integration tests
│
├── Output/                     # Build-DeploymentPlans output
├── Results/                    # Test results and reports
└── REGRESSION-TEST-PLAN.md     # Full test plan documentation
```

## Test Case Structure

Each test case is a folder containing:

```
TestCases/Stage1-Create/PD-001-SinglePolicyDefinition/
├── manifest.json               # Test metadata and expected results
└── files/                      # Policy files to deploy
    └── policyDefinitions/
        └── test-pd-001-audit-resource-location.json
```

### manifest.json Schema

```json
{
    "testCaseId": "PD-001",
    "description": "Deploy a single policy definition",
    "stage": 1,
    "category": "Create",
    "objectType": "policyDefinition",
    "deploy": true,
    "expectedPlan": {
        "policyDefinitions": { "new": 1, "update": 0, "delete": 0 }
    },
    "expectedAzureState": {
        "policyDefinitions": [
            { "name": "test-pd-001-...", "displayName": "..." }
        ]
    }
}
```

## Stage 1 Test Cases

| Test ID | Description | Object Type |
|---------|-------------|-------------|
| PD-001 | Single policy definition (Audit) | Policy Definition |
| PD-002 | Policy with Deny effect | Policy Definition |
| PD-003 | Multiple policy definitions | Policy Definition |
| PSD-001 | Policy set with custom policies | Policy Set |
| PA-001 | Built-in policy assignment | Assignment |
| PA-002 | Custom policy assignment | Assignment |
| PA-003 | DoNotEnforce mode assignment | Assignment |
| PA-004 | Policy set assignment | Assignment |
| PE-001 | Waiver exemption | Exemption |
| PE-002 | Mitigated exemption | Exemption |

## Scripts

### Run-LocalTests.ps1

Main entry point with parameters:

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-TenantId` | Yes | Azure AD tenant ID |
| `-TestManagementGroupId` | Yes | Management group for test deployments |
| `-Stages` | No | Stages to run (default: 1-7) |
| `-TestCaseIds` | No | Specific test case IDs to run |
| `-Deploy` | No | Deploy changes to Azure |
| `-SkipCleanup` | No | Keep resources after tests |
| `-ContinueOnError` | No | Continue on test failure |
| `-SkipInit` | No | Skip environment initialization |

### Invoke-TestStage.ps1

Runs a single test case:

1. Copies test files to Definitions folder
2. Runs `Build-DeploymentPlans`
3. Validates plan output matches expected
4. Optionally deploys with `Deploy-PolicyPlan`
5. Optionally validates Azure state with Pester

### Assert-AzureState.ps1

Uses Pester to validate Azure resources:

- Policy definitions exist with correct properties
- Policy set definitions exist with correct policy count
- Policy assignments exist with correct enforcement mode
- Policy exemptions exist with correct category
- Resources that should NOT exist are absent

## Test Naming Convention

All test resources use the `test-` prefix:

- `test-pd-XXX-*` - Policy Definitions
- `test-psd-XXX-*` - Policy Set Definitions
- `test-pa-XXX-*` - Policy Assignments
- `test-pe-XXX-*` - Policy Exemptions

This allows easy identification and cleanup.

## Adding New Test Cases

1. Create a folder under the appropriate stage: `TestCases/Stage1-Create/YOUR-TEST/`
2. Create `manifest.json` with test metadata and expected results
3. Create `files/` subfolder with policy definition files
4. Run the test to verify

## Troubleshooting

### "Module not found" errors

Install required modules:
```powershell
Install-Module -Name EnterprisePolicyAsCode -Force -Scope CurrentUser
```

### "Not connected to Azure" errors

Connect to Azure first:
```powershell
Connect-AzAccount -TenantId "your-tenant-id"
```

### Plan validation failures

Check the output in `Tests/Output/TESTCASE-ID/` for the actual plan.

### Azure state validation failures

Check `Tests/Results/TESTCASE-ID-pester-results.xml` for detailed failures.
