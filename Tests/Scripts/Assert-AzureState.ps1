<#
.SYNOPSIS
    Validates Azure Policy resources match expected state using Pester.
.DESCRIPTION
    Uses Pester v5.0+ to validate that Azure Policy resources exist
    with the expected properties after deployment.
.EXAMPLE
    .\Assert-AzureState.ps1 -ManagementGroupId "epac-test-mg" -ExpectedState $expected
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManagementGroupId,
    
    [Parameter(Mandatory = $true)]
    [hashtable]$ExpectedState,
    
    [Parameter(Mandatory = $false)]
    [string]$TestCaseId = "Unknown",
    
    [Parameter(Mandatory = $false)]
    [string]$ResultsFolder = "./Tests/Results"
)

$ErrorActionPreference = "Stop"

# Ensure Pester is loaded
if (-not (Get-Module -Name Pester)) {
    Import-Module Pester -MinimumVersion 5.0.0
}

# Build Pester container with test data
$container = New-PesterContainer -ScriptBlock {
    param($ManagementGroupId, $ExpectedState, $TestCaseId)
    
    Describe "Azure State Validation for $TestCaseId" {
        
        BeforeAll {
            $script:mgScope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"
            $script:mgId = $ManagementGroupId
            $script:state = $ExpectedState
        }
        
        # Validate Policy Definitions
        if ($ExpectedState.policyDefinitions -and $ExpectedState.policyDefinitions.Count -gt 0) {
            Context "Policy Definitions" {
                It "Policy definition '<name>' should exist" -ForEach $ExpectedState.policyDefinitions {
                    $policy = Get-AzPolicyDefinition -Name $name -ManagementGroupName $script:mgId -ErrorAction SilentlyContinue
                    $policy | Should -Not -BeNullOrEmpty
                }
            }
            
            Context "Policy Definition Properties" {
                It "Policy definition '<name>' should have correct displayName" -ForEach ($ExpectedState.policyDefinitions | Where-Object { $_.displayName }) {
                    $policy = Get-AzPolicyDefinition -Name $name -ManagementGroupName $script:mgId
                    $policy.DisplayName | Should -Be $displayName
                }
                
                It "Policy definition '<name>' should have correct mode" -ForEach ($ExpectedState.policyDefinitions | Where-Object { $_.mode }) {
                    $policy = Get-AzPolicyDefinition -Name $name -ManagementGroupName $script:mgId
                    $policy.Mode | Should -Be $mode
                }
                
                It "Policy definition '<name>' should have correct effect '<policyRule.effect>'" -ForEach ($ExpectedState.policyDefinitions | Where-Object { $_.policyRule -and $_.policyRule.effect }) {
                    $policy = Get-AzPolicyDefinition -Name $name -ManagementGroupName $script:mgId
                    $policy.PolicyRule.then.effect | Should -Be $policyRule.effect
                }
            }
        }
        
        # Validate Policy Set Definitions
        if ($ExpectedState.policySetDefinitions -and $ExpectedState.policySetDefinitions.Count -gt 0) {
            Context "Policy Set Definitions" {
                It "Policy set '<name>' should exist" -ForEach $ExpectedState.policySetDefinitions {
                    $policySet = Get-AzPolicySetDefinition -Name $name -ManagementGroupName $script:mgId -ErrorAction SilentlyContinue
                    $policySet | Should -Not -BeNullOrEmpty
                }
            }
            
            Context "Policy Set Properties" {
                It "Policy set '<name>' should have correct displayName" -ForEach ($ExpectedState.policySetDefinitions | Where-Object { $_.displayName }) {
                    $policySet = Get-AzPolicySetDefinition -Name $name -ManagementGroupName $script:mgId
                    $policySet.DisplayName | Should -Be $displayName
                }
                
                It "Policy set '<name>' should contain correct policy count" -ForEach ($ExpectedState.policySetDefinitions | Where-Object { $_.policyCount }) {
                    $policySet = Get-AzPolicySetDefinition -Name $name -ManagementGroupName $script:mgId
                    $policySet.PolicyDefinition.Count | Should -Be $policyCount
                }
            }
        }
        
        # Validate Policy Assignments
        if ($ExpectedState.policyAssignments -and $ExpectedState.policyAssignments.Count -gt 0) {
            Context "Policy Assignments" {
                It "Policy assignment '<name>' should exist" -ForEach $ExpectedState.policyAssignments {
                    $assignment = Get-AzPolicyAssignment -Name $name -Scope $script:mgScope -ErrorAction SilentlyContinue
                    $assignment | Should -Not -BeNullOrEmpty
                }
            }
            
            Context "Policy Assignment Properties" {
                It "Policy assignment '<name>' should have correct displayName" -ForEach ($ExpectedState.policyAssignments | Where-Object { $_.displayName }) {
                    $assignment = Get-AzPolicyAssignment -Name $name -Scope $script:mgScope
                    $assignment.DisplayName | Should -Be $displayName
                }
                
                It "Policy assignment '<name>' should have correct enforcementMode" -ForEach ($ExpectedState.policyAssignments | Where-Object { $_.enforcementMode }) {
                    $assignment = Get-AzPolicyAssignment -Name $name -Scope $script:mgScope
                    $assignment.EnforcementMode | Should -Be $enforcementMode
                }
                
                It "Policy assignment '<name>' should have correct parameters" -ForEach ($ExpectedState.policyAssignments | Where-Object { $_.parameters }) {
                    $assignment = Get-AzPolicyAssignment -Name $name -Scope $script:mgScope
                    foreach ($paramName in $parameters.Keys) {
                        $actualValue = $assignment.Parameter.$paramName.Value
                        $expectedValue = $parameters[$paramName]
                        # Compare as JSON for complex types like arrays
                        ($actualValue | ConvertTo-Json -Compress) | Should -Be ($expectedValue | ConvertTo-Json -Compress)
                    }
                }
            }
        }
        
        # Validate Policy Exemptions
        if ($ExpectedState.policyExemptions -and $ExpectedState.policyExemptions.Count -gt 0) {
            Context "Policy Exemptions" {
                It "Policy exemption '<name>' should exist" -ForEach $ExpectedState.policyExemptions {
                    $exemption = Get-AzPolicyExemption -Name $name -Scope $script:mgScope -ErrorAction SilentlyContinue
                    $exemption | Should -Not -BeNullOrEmpty
                }
            }
            
            Context "Policy Exemption Properties" {
                It "Policy exemption '<name>' should have correct category" -ForEach ($ExpectedState.policyExemptions | Where-Object { $_.exemptionCategory }) {
                    $exemption = Get-AzPolicyExemption -Name $name -Scope $script:mgScope
                    $exemption.ExemptionCategory | Should -Be $exemptionCategory
                }
            }
        }
        
        # Validate resources should NOT exist
        if ($ExpectedState.shouldNotExist) {
            Context "Resources That Should Not Exist" {
                if ($ExpectedState.shouldNotExist.policyDefinitions -and $ExpectedState.shouldNotExist.policyDefinitions.Count -gt 0) {
                    It "Policy definition '<_>' should NOT exist" -ForEach $ExpectedState.shouldNotExist.policyDefinitions {
                        # Azure Policy cmdlets throw terminating errors when resource not found
                        # This is actually success for "should not exist" tests
                        $policy = $null
                        try {
                            $policy = Get-AzPolicyDefinition -Name $_ -ManagementGroupName $script:mgId -ErrorAction Stop
                        }
                        catch {
                            # Expected - resource not found is success for "should not exist"
                            $policy = $null
                        }
                        $policy | Should -BeNullOrEmpty
                    }
                }
                
                if ($ExpectedState.shouldNotExist.policySetDefinitions -and $ExpectedState.shouldNotExist.policySetDefinitions.Count -gt 0) {
                    It "Policy set '<_>' should NOT exist" -ForEach $ExpectedState.shouldNotExist.policySetDefinitions {
                        $policySet = $null
                        try {
                            $policySet = Get-AzPolicySetDefinition -Name $_ -ManagementGroupName $script:mgId -ErrorAction Stop
                        }
                        catch {
                            # Expected - resource not found is success for "should not exist"
                            $policySet = $null
                        }
                        $policySet | Should -BeNullOrEmpty
                    }
                }
                
                if ($ExpectedState.shouldNotExist.policyAssignments -and $ExpectedState.shouldNotExist.policyAssignments.Count -gt 0) {
                    It "Policy assignment '<_>' should NOT exist" -ForEach $ExpectedState.shouldNotExist.policyAssignments {
                        $assignment = $null
                        try {
                            $assignment = Get-AzPolicyAssignment -Name $_ -Scope $script:mgScope -ErrorAction Stop
                        }
                        catch {
                            # Expected - resource not found is success for "should not exist"
                            $assignment = $null
                        }
                        $assignment | Should -BeNullOrEmpty
                    }
                }
                
                if ($ExpectedState.shouldNotExist.policyExemptions -and $ExpectedState.shouldNotExist.policyExemptions.Count -gt 0) {
                    It "Policy exemption '<_>' should NOT exist" -ForEach $ExpectedState.shouldNotExist.policyExemptions {
                        $exemption = $null
                        try {
                            $exemption = Get-AzPolicyExemption -Name $_ -Scope $script:mgScope -ErrorAction Stop
                        }
                        catch {
                            # Expected - resource not found is success for "should not exist"
                            $exemption = $null
                        }
                        $exemption | Should -BeNullOrEmpty
                    }
                }
            }
        }
    }
} -Data @{
    ManagementGroupId = $ManagementGroupId
    ExpectedState     = $ExpectedState
    TestCaseId        = $TestCaseId
}

# Configure Pester
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Container = $container
$pesterConfig.Run.PassThru = $true
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'
$pesterConfig.TestResult.OutputPath = "$ResultsFolder/$TestCaseId-pester-results.xml"

# Run Pester tests
$pesterResult = Invoke-Pester -Configuration $pesterConfig

# Build result object
$result = @{
    AllPassed         = $pesterResult.FailedCount -eq 0
    TotalTests        = $pesterResult.TotalCount
    PassedTests       = $pesterResult.PassedCount
    FailedTests       = $pesterResult.FailedCount
    SkippedTests      = $pesterResult.SkippedCount
    Duration          = $pesterResult.Duration
    ResultFile        = "$ResultsFolder/$TestCaseId-pester-results.xml"
    FailedTestDetails = @()
}

# Collect failed test details
foreach ($test in $pesterResult.Failed) {
    $result.FailedTestDetails += @{
        Name         = $test.Name
        ErrorMessage = $test.ErrorRecord.Exception.Message
        Block        = $test.Block.Name
    }
}

return $result
