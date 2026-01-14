<#
.SYNOPSIS
    Runs EPAC regression tests locally.
.DESCRIPTION
    Main entry point for local test execution. Authenticates to Azure,
    runs all or selected test stages, and generates a summary report.
.EXAMPLE
    .\Run-LocalTests.ps1 -TenantId "xxx" -TestManagementGroupId "epac-test-mg"
.EXAMPLE
    .\Run-LocalTests.ps1 -TenantId "xxx" -TestManagementGroupId "epac-test-mg" -Stages 1 -SkipCleanup
.EXAMPLE
    .\Run-LocalTests.ps1 -TenantId "xxx" -TestManagementGroupId "epac-test-mg" -TestCases "PA-002-CustomPolicyAssignment"
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
    
    [Parameter(Mandatory = $false, HelpMessage = "Specific test case IDs (from manifest) to run")]
    [string[]]$TestCaseIds,
    
    [Parameter(Mandatory = $false, HelpMessage = "Specific test case folder names to run (e.g., 'PA-002-CustomPolicyAssignment')")]
    [string[]]$TestCases,
    
    [Parameter(Mandatory = $false, HelpMessage = "Skip cleanup after tests")]
    [switch]$SkipCleanup,
    
    [Parameter(Mandatory = $false, HelpMessage = "Continue on test failure")]
    [switch]$ContinueOnError,
    
    [Parameter(Mandatory = $false, HelpMessage = "Deploy changes to Azure (default: plan only)")]
    [switch]$Deploy,
    
    [Parameter(Mandatory = $false, HelpMessage = "Skip initialization (use existing definitions)")]
    [switch]$SkipInit
)

$ErrorActionPreference = if ($ContinueOnError) { "Continue" } else { "Stop" }

# Resolve paths
$ScriptRoot = $PSScriptRoot
$TestRootFolder = Split-Path $ScriptRoot -Parent

# Dot source the modern output functions
. "$ScriptRoot/../../Scripts/Helpers/Write-ModernOutput.ps1"

# Helper function to convert PSCustomObject to Hashtable (recursive)
function ConvertTo-Hashtable {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )
    
    if ($null -eq $InputObject) {
        return @{}
    }
    
    if ($InputObject -is [System.Collections.Hashtable]) {
        return $InputObject
    }
    
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $result = @()
        foreach ($item in $InputObject) {
            if ($item -is [PSCustomObject]) {
                $result += ConvertTo-Hashtable -InputObject $item
            }
            else {
                $result += $item
            }
        }
        return $result
    }
    
    if ($InputObject -is [PSCustomObject]) {
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        }
        return $hash
    }
    
    return $InputObject
}

# Helper function to copy files and replace placeholders
function Copy-WithPlaceholderReplacement {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$ManagementGroupId
    )
    
    if (-not (Test-Path $SourcePath)) { return }
    
    Get-ChildItem -Path $SourcePath -File -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourcePath.Length).TrimStart('\', '/')
        $destFile = Join-Path $DestinationPath $relativePath
        $destDir = Split-Path $destFile -Parent
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        # Read content and replace placeholders
        $content = Get-Content $_.FullName -Raw
        $content = $content -replace '\{\{MANAGEMENT_GROUP_ID\}\}', $ManagementGroupId
        $content = $content -replace '\{\{ManagementGroupId\}\}', $ManagementGroupId
        
        # Write to destination
        Set-Content -Path $destFile -Value $content -Encoding UTF8
    }
}

# Helper function to copy files from a test case folder
function Copy-TestCaseFiles {
    param(
        [string]$TestCaseFilesFolder,
        [string]$DefinitionsFolder,
        [string]$ManagementGroupId
    )
    
    if (-not (Test-Path $TestCaseFilesFolder)) { return }
    
    # Copy policy definitions
    $policyDefSrc = Join-Path $TestCaseFilesFolder "policyDefinitions"
    if (Test-Path $policyDefSrc) {
        $policyDefDest = Join-Path $DefinitionsFolder "policyDefinitions"
        Copy-WithPlaceholderReplacement -SourcePath $policyDefSrc -DestinationPath $policyDefDest -ManagementGroupId $ManagementGroupId
    }
    
    # Copy policy set definitions
    $policySetSrc = Join-Path $TestCaseFilesFolder "policySetDefinitions"
    if (Test-Path $policySetSrc) {
        $policySetDest = Join-Path $DefinitionsFolder "policySetDefinitions"
        Copy-WithPlaceholderReplacement -SourcePath $policySetSrc -DestinationPath $policySetDest -ManagementGroupId $ManagementGroupId
    }
    
    # Copy policy assignments
    $assignmentsSrc = Join-Path $TestCaseFilesFolder "policyAssignments"
    if (Test-Path $assignmentsSrc) {
        $assignmentsDest = Join-Path $DefinitionsFolder "policyAssignments"
        Copy-WithPlaceholderReplacement -SourcePath $assignmentsSrc -DestinationPath $assignmentsDest -ManagementGroupId $ManagementGroupId
    }
    
    # Copy policy exemptions
    $exemptionsSrc = Join-Path $TestCaseFilesFolder "policyExemptions"
    if (Test-Path $exemptionsSrc) {
        # Exemptions go to PAC environment-specific folder
        $exemptionsDest = Join-Path $DefinitionsFolder "policyExemptions/epac-test"
        Copy-WithPlaceholderReplacement -SourcePath $exemptionsSrc -DestinationPath $exemptionsDest -ManagementGroupId $ManagementGroupId
    }
}

# Helper function to clean definitions folder
function Clear-DefinitionsFolder {
    param(
        [string]$DefinitionsFolder
    )
    
    $foldersToClean = @(
        "policyDefinitions",
        "policySetDefinitions", 
        "policyAssignments",
        "policyExemptions"
    )
    foreach ($folder in $foldersToClean) {
        $folderPath = Join-Path $DefinitionsFolder $folder
        if (Test-Path $folderPath) {
            Get-ChildItem -Path $folderPath -Recurse -File | Remove-Item -Force
        }
    }
}

# Banner
Write-ModernHeader -Title "EPAC Regression Test Suite" -Subtitle "Local Execution"

$startTime = Get-Date
Write-ModernStatus -Message "Start Time:       $startTime" -Status "info" -Indent 2
Write-ModernStatus -Message "Tenant ID:        $TenantId" -Status "info" -Indent 2
Write-ModernStatus -Message "Management Group: $TestManagementGroupId" -Status "info" -Indent 2
Write-ModernStatus -Message "Stages to run:    $($Stages -join ', ')" -Status "info" -Indent 2
if ($TestCases) {
    Write-ModernStatus -Message "Test Cases:       $($TestCases -join ', ')" -Status "info" -Indent 2
}
if ($TestCaseIds) {
    Write-ModernStatus -Message "Test Case IDs:    $($TestCaseIds -join ', ')" -Status "info" -Indent 2
}
Write-ModernStatus -Message "Deploy changes:   $Deploy" -Status "info" -Indent 2
Write-ModernStatus -Message "Test Root:        $TestRootFolder" -Status "info" -Indent 2

# Step 1: Check prerequisites
Write-ModernSection -Title "[1/5] Checking prerequisites"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-ModernStatus -Message "PowerShell 7+ recommended. Current: $($PSVersionTable.PSVersion)" -Status "warning" -Indent 2
}

$requiredModules = @('Az.Accounts', 'Az.Resources', 'Pester', 'EnterprisePolicyAsCode')
foreach ($module in $requiredModules) {
    $mod = Get-Module -ListAvailable -Name $module | Select-Object -First 1
    if (-not $mod) {
        Write-ModernStatus -Message "Module not found: $module" -Status "error" -Indent 2
        Write-ModernStatus -Message "Install with: Install-Module -Name $module -Force -Scope CurrentUser" -Status "info" -Indent 4
        throw "Required module not found: $module"
    }
    else {
        Write-ModernStatus -Message "$module ($($mod.Version))" -Status "success" -Indent 2
    }
}

# Step 2: Verify Azure connection
Write-ModernSection -Title "[2/5] Verifying Azure connection"
$context = Get-AzContext
if (-not $context) {
    Write-ModernStatus -Message "Not connected to Azure. Connecting..." -Status "warning" -Indent 2
    Connect-AzAccount -TenantId $TenantId
    $context = Get-AzContext
}

if ($context.Tenant.Id -ne $TenantId) {
    Write-ModernStatus -Message "Switching to tenant: $TenantId" -Status "warning" -Indent 2
    Connect-AzAccount -TenantId $TenantId
    $context = Get-AzContext
}

Write-ModernStatus -Message "Connected as: $($context.Account.Id)" -Status "success" -Indent 2
Write-ModernStatus -Message "Tenant: $($context.Tenant.Id)" -Status "info" -Indent 4

# Step 3: Initialize test environment
if (-not $SkipInit) {
    Write-ModernSection -Title "[3/5] Initializing test environment"
    & "$ScriptRoot/Initialize-TestEnvironment.ps1" `
        -TenantId $TenantId `
        -TestManagementGroupId $TestManagementGroupId `
        -TestSubscriptionId $TestSubscriptionId `
        -TestRootFolder $TestRootFolder
}
else {
    Write-ModernSection -Title "[3/5] Skipping initialization (--SkipInit)"
}

# Step 4: Run tests
Write-ModernSection -Title "[4/5] Executing test stages"

$allResults = @()
$stageResults = @{}

# If TestCases is specified, find which stages contain those test cases
if ($TestCases) {
    $stageFolders = Get-ChildItem -Path "$TestRootFolder/TestCases" -Directory
    $detectedStages = @()
    foreach ($stageFolder in $stageFolders) {
        $stageFolderPath = "$stageFolder"
        $stageFolderName = Split-Path $stageFolderPath -Leaf
        foreach ($testCaseName in $TestCases) {
            $testCasePath = Join-Path $stageFolderPath $testCaseName
            if (Test-Path $testCasePath) {
                # Extract stage number from folder name (e.g., "Stage1-Create" -> 1)
                if ($stageFolderName -match 'Stage(\d+)') {
                    $stageNum = [int]$Matches[1]
                    if ($stageNum -notin $detectedStages) {
                        $detectedStages += $stageNum
                    }
                }
            }
        }
    }
    if ($detectedStages.Count -gt 0) {
        $Stages = $detectedStages | Sort-Object
        Write-ModernStatus -Message "Auto-detected stages for specified test cases: $($Stages -join ', ')" -Status "info" -Indent 2
    }
}

foreach ($stage in $Stages) {
    Write-ModernHeader -Title "Stage $stage"
    
    $stageFolder = Get-ChildItem -Path "$TestRootFolder/TestCases" -Directory | `
        Where-Object { $_.Name -like "Stage$stage-*" } | `
        Select-Object -First 1

    if (-not $stageFolder) {
        Write-ModernStatus -Message "No test cases found for Stage $stage" -Status "warning" -Indent 2
        continue
    }
    
    $stageFolderPath = "$stageFolder"
    $stageResults[$stage] = @{ Passed = 0; Failed = 0; Skipped = 0 }
    
    $testCaseFolders = Get-ChildItem -Path $stageFolderPath -Directory | Sort-Object Name
    
    # Collect all test cases for this stage
    $stageTestCases = @()
    foreach ($testCaseFolder in $testCaseFolders) {
        $testCasePath = "$testCaseFolder"
        $testCaseName = Split-Path $testCasePath -Leaf
        $manifestPath = Join-Path $testCasePath "manifest.json"
        if (-not (Test-Path $manifestPath)) {
            Write-ModernStatus -Message "Skipping $testCaseName - no manifest.json" -Status "skip" -Indent 2
            $stageResults[$stage].Skipped++
            continue
        }
        
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        
        # Filter by specific test case folder names if provided
        if ($TestCases -and $testCaseName -notin $TestCases) {
            $stageResults[$stage].Skipped++
            continue
        }
        
        # Filter by specific test case IDs (from manifest) if provided
        if ($TestCaseIds -and $manifest.testCaseId -notin $TestCaseIds) {
            $stageResults[$stage].Skipped++
            continue
        }
        
        $stageTestCases += @{
            TestCasePath = $testCasePath
            TestCaseName = $testCaseName
            Manifest     = $manifest
        }
    }
    
    if ($stageTestCases.Count -eq 0) {
        Write-ModernStatus -Message "No matching test cases for Stage $stage" -Status "info" -Indent 2
        continue
    }
    
    # Stage 1 (Create) - Batch processing: copy all files, single build/deploy, then validate all
    if ($stage -eq 1) {
        Write-ModernStatus -Message "Batch Mode: Processing $($stageTestCases.Count) test cases together" -Status "info" -Indent 2
        
        # Step 1: Clean and copy all test case files
        Write-ModernSection -Title "Copying test files for all test cases"
        Clear-DefinitionsFolder -DefinitionsFolder "$TestRootFolder/Definitions"
        
        foreach ($tc in $stageTestCases) {
            $filesFolder = Join-Path $tc.TestCasePath "files"
            if (Test-Path $filesFolder) {
                Write-ModernStatus -Message "Copying: $($tc.Manifest.testCaseId) - $($tc.Manifest.description)" -Status "info" -Indent 2
                Copy-TestCaseFiles -TestCaseFilesFolder $filesFolder -DefinitionsFolder "$TestRootFolder/Definitions" -ManagementGroupId $TestManagementGroupId
            }
        }
        
        # Calculate expected totals (excluding exemptions for first pass)
        $expectedTotals = @{
            PolicyDefinitionsNew    = 0
            PolicySetDefinitionsNew = 0
            PolicyAssignmentsNew    = 0
            PolicyExemptionsNew     = 0
        }
        foreach ($tc in $stageTestCases) {
            if ($tc.Manifest.expectedPlan) {
                if ($tc.Manifest.expectedPlan.policyDefinitions.new) {
                    $expectedTotals.PolicyDefinitionsNew += $tc.Manifest.expectedPlan.policyDefinitions.new
                }
                if ($tc.Manifest.expectedPlan.policySetDefinitions.new) {
                    $expectedTotals.PolicySetDefinitionsNew += $tc.Manifest.expectedPlan.policySetDefinitions.new
                }
                if ($tc.Manifest.expectedPlan.policyAssignments.new) {
                    $expectedTotals.PolicyAssignmentsNew += $tc.Manifest.expectedPlan.policyAssignments.new
                }
                if ($tc.Manifest.expectedPlan.policyExemptions.new) {
                    $expectedTotals.PolicyExemptionsNew += $tc.Manifest.expectedPlan.policyExemptions.new
                }
            }
        }
        
        # Step 2: Build deployment plan
        Write-ModernSection -Title "Building deployment plan"
        $planOutput = "$TestRootFolder/Output/Stage1-Batch"
        if (Test-Path $planOutput) {
            Remove-Item -Path $planOutput -Recurse -Force
        }
        New-Item -ItemType Directory -Path $planOutput -Force | Out-Null
        
        $buildParams = @{
            PacEnvironmentSelector = "epac-test"
            DefinitionsRootFolder  = "$TestRootFolder/Definitions"
            OutputFolder           = $planOutput
        }
        Build-DeploymentPlans @buildParams
        
        # Validate plan
        Write-ModernSection -Title "Validating deployment plan"
        $planFile = Get-ChildItem -Path $planOutput -Filter "policy-plan.json" -Recurse | Select-Object -First 1
        
        $planValidation = @{ Matches = $true; Errors = @() }
        if ($planFile) {
            $plan = Get-Content $planFile.FullName -Raw | ConvertFrom-Json
            
            $actualNew = @{
                PolicyDefinitions    = @($plan.policyDefinitions.new.PSObject.Properties).Count
                PolicySetDefinitions = @($plan.policySetDefinitions.new.PSObject.Properties).Count
                PolicyAssignments    = @($plan.assignments.new.PSObject.Properties).Count
                PolicyExemptions     = @($plan.exemptions.new.PSObject.Properties).Count
            }
            
            Write-ModernStatus -Message "Policy Definitions: +$($actualNew.PolicyDefinitions) (expected: +$($expectedTotals.PolicyDefinitionsNew))" -Status "info" -Indent 2
            Write-ModernStatus -Message "Policy Sets:        +$($actualNew.PolicySetDefinitions) (expected: +$($expectedTotals.PolicySetDefinitionsNew))" -Status "info" -Indent 2
            Write-ModernStatus -Message "Assignments:        +$($actualNew.PolicyAssignments) (expected: +$($expectedTotals.PolicyAssignmentsNew))" -Status "info" -Indent 2
            Write-ModernStatus -Message "Exemptions:         +$($actualNew.PolicyExemptions) (expected: +$($expectedTotals.PolicyExemptionsNew))" -Status "info" -Indent 2
            
            if ($actualNew.PolicyDefinitions -ne $expectedTotals.PolicyDefinitionsNew) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyDefinitions: expected $($expectedTotals.PolicyDefinitionsNew), got $($actualNew.PolicyDefinitions)"
            }
            if ($actualNew.PolicySetDefinitions -ne $expectedTotals.PolicySetDefinitionsNew) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicySetDefinitions: expected $($expectedTotals.PolicySetDefinitionsNew), got $($actualNew.PolicySetDefinitions)"
            }
            if ($actualNew.PolicyAssignments -ne $expectedTotals.PolicyAssignmentsNew) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyAssignments: expected $($expectedTotals.PolicyAssignmentsNew), got $($actualNew.PolicyAssignments)"
            }
            if ($actualNew.PolicyExemptions -ne $expectedTotals.PolicyExemptionsNew) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyExemptions: expected $($expectedTotals.PolicyExemptionsNew), got $($actualNew.PolicyExemptions)"
            }
        }
        else {
            $planValidation.Matches = $false
            $planValidation.Errors += "Plan file not found"
        }
        
        if (-not $planValidation.Matches) {
            Write-ModernStatus -Message "Plan validation failed:" -Status "error" -Indent 2
            foreach ($err in $planValidation.Errors) {
                Write-ModernStatus -Message "- $err" -Status "error" -Indent 4
            }
            foreach ($tc in $stageTestCases) {
                $stageResults[$stage].Failed++
                $allResults += @{
                    TestCaseId   = $tc.Manifest.testCaseId
                    Success      = $false
                    ErrorMessage = "Plan validation failed: $($planValidation.Errors -join '; ')"
                    Duration     = [TimeSpan]::Zero
                }
            }
            continue
        }
        
        Write-ModernStatus -Message "Plan validation passed" -Status "success" -Indent 2
        
        # Step 3: Deploy if requested
        if ($Deploy) {
            Write-ModernSection -Title "Deploying resources"
            
            $deployParams = @{
                PacEnvironmentSelector = "epac-test"
                DefinitionsRootFolder  = "$TestRootFolder/Definitions"
                InputFolder            = $planOutput
            }
            
            Deploy-PolicyPlan @deployParams
            
            # Deploy roles if needed
            $rolesFile = Get-ChildItem -Path $planOutput -Filter "roles-plan.json" -Recurse | Select-Object -First 1
            if ($rolesFile) {
                Deploy-RolesPlan @deployParams
            }
            
            Write-ModernStatus -Message "Deployment complete" -Status "success" -Indent 2
            
            # Step 4: Validate each test case's Azure state
            Write-ModernSection -Title "Validating Azure state for each test case"
            
            foreach ($tc in $stageTestCases) {
                Write-ModernStatus -Message "Validating: $($tc.Manifest.testCaseId)" -Status "processing" -Indent 2
                
                $expectedAzureState = @{}
                if ($tc.Manifest.expectedAzureState) {
                    $expectedAzureState = ConvertTo-Hashtable -InputObject $tc.Manifest.expectedAzureState
                }
                
                if ($expectedAzureState.Count -gt 0) {
                    $assertParams = @{
                        ManagementGroupId = $TestManagementGroupId
                        ExpectedState     = $expectedAzureState
                        TestCaseId        = $tc.Manifest.testCaseId
                        ResultsFolder     = "$TestRootFolder/Results"
                    }
                    
                    $azureValidation = & "$ScriptRoot/Assert-AzureState.ps1" @assertParams
                    
                    if ($azureValidation.AllPassed) {
                        Write-ModernStatus -Message "$($tc.Manifest.testCaseId) - PASSED ($($azureValidation.PassedTests)/$($azureValidation.TotalTests) tests)" -Status "success" -Indent 4
                        $stageResults[$stage].Passed++
                        $allResults += @{
                            TestCaseId      = $tc.Manifest.testCaseId
                            Success         = $true
                            AzureValidation = $azureValidation
                            Duration        = $azureValidation.Duration
                        }
                    }
                    else {
                        Write-ModernStatus -Message "$($tc.Manifest.testCaseId) - FAILED ($($azureValidation.FailedTests) tests failed)" -Status "error" -Indent 4
                        $stageResults[$stage].Failed++
                        $allResults += @{
                            TestCaseId      = $tc.Manifest.testCaseId
                            Success         = $false
                            ErrorMessage    = "Azure state validation failed"
                            AzureValidation = $azureValidation
                            Duration        = $azureValidation.Duration
                        }
                    }
                }
                else {
                    # No Azure state to validate - just mark as passed
                    Write-ModernStatus -Message "$($tc.Manifest.testCaseId) - PASSED (no Azure state validation)" -Status "success" -Indent 4
                    $stageResults[$stage].Passed++
                    $allResults += @{
                        TestCaseId = $tc.Manifest.testCaseId
                        Success    = $true
                        Duration   = [TimeSpan]::Zero
                    }
                }
            }
        }
        else {
            # Plan-only mode - mark all as passed if plan validated
            foreach ($tc in $stageTestCases) {
                $stageResults[$stage].Passed++
                $allResults += @{
                    TestCaseId     = $tc.Manifest.testCaseId
                    Success        = $true
                    PlanValidation = $planValidation
                    Duration       = [TimeSpan]::Zero
                }
            }
        }
        
        # Display elapsed time
        $elapsed = (Get-Date) - $startTime
        $elapsedStr = "{0:hh\:mm\:ss}" -f $elapsed
        Write-ModernStatus -Message "Stage 1 elapsed time: $elapsedStr" -Status "info" -Indent 2
    }
    # Stage 2 (Update) - Batch processing: deploy baseline, then deploy updates, validate changes
    elseif ($stage -eq 2) {
        Write-ModernStatus -Message "Batch Mode: Processing $($stageTestCases.Count) test cases together" -Status "info" -Indent 2
        
        # Step 1: Clean and copy all BASELINE files
        Write-ModernSection -Title "Copying baseline files for all test cases"
        Clear-DefinitionsFolder -DefinitionsFolder "$TestRootFolder/Definitions"
        
        foreach ($tc in $stageTestCases) {
            $baselineFolder = Join-Path $tc.TestCasePath "baseline"
            if (Test-Path $baselineFolder) {
                Write-ModernStatus -Message "Copying baseline: $($tc.Manifest.testCaseId) - $($tc.Manifest.description)" -Status "info" -Indent 2
                Copy-TestCaseFiles -TestCaseFilesFolder $baselineFolder -DefinitionsFolder "$TestRootFolder/Definitions" -ManagementGroupId $TestManagementGroupId
            }
        }
        
        # Step 2: Build and deploy baseline
        Write-ModernSection -Title "Building baseline deployment plan"
        $baselinePlanOutput = "$TestRootFolder/Output/Stage2-Baseline"
        if (Test-Path $baselinePlanOutput) {
            Remove-Item -Path $baselinePlanOutput -Recurse -Force
        }
        New-Item -ItemType Directory -Path $baselinePlanOutput -Force | Out-Null
        
        $buildParams = @{
            PacEnvironmentSelector = "epac-test"
            DefinitionsRootFolder  = "$TestRootFolder/Definitions"
            OutputFolder           = $baselinePlanOutput
        }
        Build-DeploymentPlans @buildParams
        
        if ($Deploy) {
            Write-ModernSection -Title "Deploying baseline resources"
            $deployParams = @{
                PacEnvironmentSelector = "epac-test"
                DefinitionsRootFolder  = "$TestRootFolder/Definitions"
                InputFolder            = $baselinePlanOutput
            }
            Deploy-PolicyPlan @deployParams
            Write-ModernStatus -Message "Baseline deployment complete" -Status "success" -Indent 2
        }
        
        # Step 3: Clean and copy all UPDATE files
        Write-ModernSection -Title "Copying update files for all test cases"
        Clear-DefinitionsFolder -DefinitionsFolder "$TestRootFolder/Definitions"
        
        foreach ($tc in $stageTestCases) {
            $updateFolder = Join-Path $tc.TestCasePath "update"
            if (Test-Path $updateFolder) {
                Write-ModernStatus -Message "Copying update: $($tc.Manifest.testCaseId)" -Status "info" -Indent 2
                Copy-TestCaseFiles -TestCaseFilesFolder $updateFolder -DefinitionsFolder "$TestRootFolder/Definitions" -ManagementGroupId $TestManagementGroupId
            }
        }
        
        # Calculate expected update totals
        $expectedTotals = @{
            PolicyDefinitionsUpdate    = 0
            PolicySetDefinitionsUpdate = 0
            PolicyAssignmentsUpdate    = 0
            PolicyExemptionsUpdate     = 0
        }
        foreach ($tc in $stageTestCases) {
            if ($tc.Manifest.expectedPlan) {
                if ($tc.Manifest.expectedPlan.policyDefinitions.update) {
                    $expectedTotals.PolicyDefinitionsUpdate += $tc.Manifest.expectedPlan.policyDefinitions.update
                }
                if ($tc.Manifest.expectedPlan.policySetDefinitions.update) {
                    $expectedTotals.PolicySetDefinitionsUpdate += $tc.Manifest.expectedPlan.policySetDefinitions.update
                }
                if ($tc.Manifest.expectedPlan.policyAssignments.update) {
                    $expectedTotals.PolicyAssignmentsUpdate += $tc.Manifest.expectedPlan.policyAssignments.update
                }
                if ($tc.Manifest.expectedPlan.policyExemptions.update) {
                    $expectedTotals.PolicyExemptionsUpdate += $tc.Manifest.expectedPlan.policyExemptions.update
                }
            }
        }
        
        # Step 4: Build update deployment plan
        Write-ModernSection -Title "Building update deployment plan"
        $updatePlanOutput = "$TestRootFolder/Output/Stage2-Update"
        if (Test-Path $updatePlanOutput) {
            Remove-Item -Path $updatePlanOutput -Recurse -Force
        }
        New-Item -ItemType Directory -Path $updatePlanOutput -Force | Out-Null
        
        $buildParams = @{
            PacEnvironmentSelector = "epac-test"
            DefinitionsRootFolder  = "$TestRootFolder/Definitions"
            OutputFolder           = $updatePlanOutput
        }
        Build-DeploymentPlans @buildParams
        
        # Validate update plan
        Write-ModernSection -Title "Validating update deployment plan"
        $planFile = Get-ChildItem -Path $updatePlanOutput -Filter "policy-plan.json" -Recurse | Select-Object -First 1
        
        $planValidation = @{ Matches = $true; Errors = @() }
        if ($planFile) {
            $plan = Get-Content $planFile.FullName -Raw | ConvertFrom-Json
            
            $actualUpdate = @{
                PolicyDefinitions    = @($plan.policyDefinitions.update.PSObject.Properties).Count
                PolicySetDefinitions = @($plan.policySetDefinitions.update.PSObject.Properties).Count
                PolicyAssignments    = @($plan.assignments.update.PSObject.Properties).Count
                PolicyExemptions     = @($plan.exemptions.update.PSObject.Properties).Count
            }
            
            Write-ModernStatus -Message "Policy Definitions: ~$($actualUpdate.PolicyDefinitions) (expected: ~$($expectedTotals.PolicyDefinitionsUpdate))" -Status "info" -Indent 2
            Write-ModernStatus -Message "Policy Sets:        ~$($actualUpdate.PolicySetDefinitions) (expected: ~$($expectedTotals.PolicySetDefinitionsUpdate))" -Status "info" -Indent 2
            Write-ModernStatus -Message "Assignments:        ~$($actualUpdate.PolicyAssignments) (expected: ~$($expectedTotals.PolicyAssignmentsUpdate))" -Status "info" -Indent 2
            Write-ModernStatus -Message "Exemptions:         ~$($actualUpdate.PolicyExemptions) (expected: ~$($expectedTotals.PolicyExemptionsUpdate))" -Status "info" -Indent 2
            
            if ($actualUpdate.PolicyDefinitions -ne $expectedTotals.PolicyDefinitionsUpdate) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyDefinitions update: expected $($expectedTotals.PolicyDefinitionsUpdate), got $($actualUpdate.PolicyDefinitions)"
            }
            if ($actualUpdate.PolicySetDefinitions -ne $expectedTotals.PolicySetDefinitionsUpdate) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicySetDefinitions update: expected $($expectedTotals.PolicySetDefinitionsUpdate), got $($actualUpdate.PolicySetDefinitions)"
            }
            if ($actualUpdate.PolicyAssignments -ne $expectedTotals.PolicyAssignmentsUpdate) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyAssignments update: expected $($expectedTotals.PolicyAssignmentsUpdate), got $($actualUpdate.PolicyAssignments)"
            }
            if ($actualUpdate.PolicyExemptions -ne $expectedTotals.PolicyExemptionsUpdate) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyExemptions update: expected $($expectedTotals.PolicyExemptionsUpdate), got $($actualUpdate.PolicyExemptions)"
            }
        }
        else {
            $planValidation.Matches = $false
            $planValidation.Errors += "Update plan file not found"
        }
        
        if (-not $planValidation.Matches) {
            Write-ModernStatus -Message "Update plan validation failed:" -Status "error" -Indent 2
            foreach ($err in $planValidation.Errors) {
                Write-ModernStatus -Message "- $err" -Status "error" -Indent 4
            }
            foreach ($tc in $stageTestCases) {
                $stageResults[$stage].Failed++
                $allResults += @{
                    TestCaseId   = $tc.Manifest.testCaseId
                    Success      = $false
                    ErrorMessage = "Update plan validation failed: $($planValidation.Errors -join '; ')"
                    Duration     = [TimeSpan]::Zero
                }
            }
            continue
        }
        
        Write-ModernStatus -Message "Update plan validation passed" -Status "success" -Indent 2
        
        # Step 5: Deploy updates if requested
        if ($Deploy) {
            Write-ModernSection -Title "Deploying update resources"
            
            $deployParams = @{
                PacEnvironmentSelector = "epac-test"
                DefinitionsRootFolder  = "$TestRootFolder/Definitions"
                InputFolder            = $updatePlanOutput
            }
            
            Deploy-PolicyPlan @deployParams
            Write-ModernStatus -Message "Update deployment complete" -Status "success" -Indent 2
            
            # Step 6: Validate each test case's Azure state (with updated values)
            Write-ModernSection -Title "Validating Azure state for each test case"
            
            foreach ($tc in $stageTestCases) {
                Write-ModernStatus -Message "Validating: $($tc.Manifest.testCaseId)" -Status "processing" -Indent 2
                
                $expectedAzureState = @{}
                if ($tc.Manifest.expectedAzureState) {
                    $expectedAzureState = ConvertTo-Hashtable -InputObject $tc.Manifest.expectedAzureState
                }
                
                if ($expectedAzureState.Count -gt 0) {
                    $assertParams = @{
                        ManagementGroupId = $TestManagementGroupId
                        ExpectedState     = $expectedAzureState
                        TestCaseId        = $tc.Manifest.testCaseId
                        ResultsFolder     = "$TestRootFolder/Results"
                    }
                    
                    $azureValidation = & "$ScriptRoot/Assert-AzureState.ps1" @assertParams
                    
                    if ($azureValidation.AllPassed) {
                        Write-ModernStatus -Message "$($tc.Manifest.testCaseId) - PASSED ($($azureValidation.PassedTests)/$($azureValidation.TotalTests) tests)" -Status "success" -Indent 4
                        $stageResults[$stage].Passed++
                        $allResults += @{
                            TestCaseId      = $tc.Manifest.testCaseId
                            Success         = $true
                            AzureValidation = $azureValidation
                            Duration        = $azureValidation.Duration
                        }
                    }
                    else {
                        Write-ModernStatus -Message "$($tc.Manifest.testCaseId) - FAILED ($($azureValidation.FailedTests) tests failed)" -Status "error" -Indent 4
                        $stageResults[$stage].Failed++
                        $allResults += @{
                            TestCaseId      = $tc.Manifest.testCaseId
                            Success         = $false
                            ErrorMessage    = "Azure state validation failed"
                            AzureValidation = $azureValidation
                            Duration        = $azureValidation.Duration
                        }
                    }
                }
                else {
                    Write-ModernStatus -Message "$($tc.Manifest.testCaseId) - PASSED (no Azure state validation)" -Status "success" -Indent 4
                    $stageResults[$stage].Passed++
                    $allResults += @{
                        TestCaseId = $tc.Manifest.testCaseId
                        Success    = $true
                        Duration   = [TimeSpan]::Zero
                    }
                }
            }
        }
        else {
            # Plan-only mode
            foreach ($tc in $stageTestCases) {
                $stageResults[$stage].Passed++
                $allResults += @{
                    TestCaseId     = $tc.Manifest.testCaseId
                    Success        = $true
                    PlanValidation = $planValidation
                    Duration       = [TimeSpan]::Zero
                }
            }
        }
        
        # Display elapsed time
        $elapsed = (Get-Date) - $startTime
        $elapsedStr = "{0:hh\:mm\:ss}" -f $elapsed
        Write-ModernStatus -Message "Stage 2 elapsed time: $elapsedStr" -Status "info" -Indent 2
    }
    # Stage 3 (Delete) - Batch processing: deploy baseline, then remove files and redeploy to delete
    elseif ($stage -eq 3) {
        Write-ModernStatus -Message "Batch Mode: Processing $($stageTestCases.Count) test cases together" -Status "info" -Indent 2
        
        # Step 1: Clean and copy all BASELINE files
        Write-ModernSection -Title "Copying baseline files for all test cases"
        Clear-DefinitionsFolder -DefinitionsFolder "$TestRootFolder/Definitions"
        
        foreach ($tc in $stageTestCases) {
            $baselineFolder = Join-Path $tc.TestCasePath "baseline"
            if (Test-Path $baselineFolder) {
                Write-ModernStatus -Message "Copying baseline: $($tc.Manifest.testCaseId) - $($tc.Manifest.description)" -Status "info" -Indent 2
                Copy-TestCaseFiles -TestCaseFilesFolder $baselineFolder -DefinitionsFolder "$TestRootFolder/Definitions" -ManagementGroupId $TestManagementGroupId
            }
        }
        
        # Step 2: Build and deploy baseline
        Write-ModernSection -Title "Building baseline deployment plan"
        $baselinePlanOutput = "$TestRootFolder/Output/Stage3-Baseline"
        if (Test-Path $baselinePlanOutput) {
            Remove-Item -Path $baselinePlanOutput -Recurse -Force
        }
        New-Item -ItemType Directory -Path $baselinePlanOutput -Force | Out-Null
        
        $buildParams = @{
            PacEnvironmentSelector = "epac-test"
            DefinitionsRootFolder  = "$TestRootFolder/Definitions"
            OutputFolder           = $baselinePlanOutput
        }
        Build-DeploymentPlans @buildParams
        
        if ($Deploy) {
            Write-ModernSection -Title "Deploying baseline resources"
            $deployParams = @{
                PacEnvironmentSelector = "epac-test"
                DefinitionsRootFolder  = "$TestRootFolder/Definitions"
                InputFolder            = $baselinePlanOutput
            }
            Deploy-PolicyPlan @deployParams
            Write-ModernStatus -Message "Baseline deployment complete" -Status "success" -Indent 2
            
            # Wait for Azure to propagate metadata (required for delete detection)
            Write-ModernStatus -Message "Waiting 30 seconds for Azure metadata propagation..." -Status "info" -Indent 2
            Start-Sleep -Seconds 30
        }
        
        # Step 3: Clean definitions and copy DELETE files (resources to keep, not the ones to delete)
        Write-ModernSection -Title "Copying delete-phase files (removing resources to delete)"
        Clear-DefinitionsFolder -DefinitionsFolder "$TestRootFolder/Definitions"
        
        foreach ($tc in $stageTestCases) {
            $deleteFolder = Join-Path $tc.TestCasePath "delete"
            if (Test-Path $deleteFolder) {
                Write-ModernStatus -Message "Copying delete-phase: $($tc.Manifest.testCaseId)" -Status "info" -Indent 2
                Copy-TestCaseFiles -TestCaseFilesFolder $deleteFolder -DefinitionsFolder "$TestRootFolder/Definitions" -ManagementGroupId $TestManagementGroupId
            }
            else {
                Write-ModernStatus -Message "No delete folder: $($tc.Manifest.testCaseId) (all resources will be deleted)" -Status "info" -Indent 2
            }
        }
        
        # Calculate expected delete totals
        $expectedTotals = @{
            PolicyDefinitionsDelete    = 0
            PolicySetDefinitionsDelete = 0
            PolicyAssignmentsDelete    = 0
            PolicyExemptionsDelete     = 0
        }
        foreach ($tc in $stageTestCases) {
            if ($tc.Manifest.expectedPlan) {
                if ($tc.Manifest.expectedPlan.policyDefinitions.delete) {
                    $expectedTotals.PolicyDefinitionsDelete += $tc.Manifest.expectedPlan.policyDefinitions.delete
                }
                if ($tc.Manifest.expectedPlan.policySetDefinitions.delete) {
                    $expectedTotals.PolicySetDefinitionsDelete += $tc.Manifest.expectedPlan.policySetDefinitions.delete
                }
                if ($tc.Manifest.expectedPlan.policyAssignments.delete) {
                    $expectedTotals.PolicyAssignmentsDelete += $tc.Manifest.expectedPlan.policyAssignments.delete
                }
                if ($tc.Manifest.expectedPlan.policyExemptions.delete) {
                    $expectedTotals.PolicyExemptionsDelete += $tc.Manifest.expectedPlan.policyExemptions.delete
                }
            }
        }
        
        # Step 4: Build delete deployment plan
        Write-ModernSection -Title "Building delete deployment plan"
        $deletePlanOutput = "$TestRootFolder/Output/Stage3-Delete"
        if (Test-Path $deletePlanOutput) {
            Remove-Item -Path $deletePlanOutput -Recurse -Force
        }
        New-Item -ItemType Directory -Path $deletePlanOutput -Force | Out-Null
        
        $buildParams = @{
            PacEnvironmentSelector = "epac-test"
            DefinitionsRootFolder  = "$TestRootFolder/Definitions"
            OutputFolder           = $deletePlanOutput
        }
        Build-DeploymentPlans @buildParams
        
        # Validate delete plan
        Write-ModernSection -Title "Validating delete deployment plan"
        $planFile = Get-ChildItem -Path $deletePlanOutput -Filter "policy-plan.json" -Recurse | Select-Object -First 1
        
        $planValidation = @{ Matches = $true; Errors = @() }
        if ($planFile) {
            $plan = Get-Content $planFile.FullName -Raw | ConvertFrom-Json
            
            $actualDelete = @{
                PolicyDefinitions    = @($plan.policyDefinitions.delete.PSObject.Properties).Count
                PolicySetDefinitions = @($plan.policySetDefinitions.delete.PSObject.Properties).Count
                PolicyAssignments    = @($plan.assignments.delete.PSObject.Properties).Count
                PolicyExemptions     = @($plan.exemptions.delete.PSObject.Properties).Count
            }
            
            Write-ModernStatus -Message "Policy Definitions: -$($actualDelete.PolicyDefinitions) (expected: -$($expectedTotals.PolicyDefinitionsDelete))" -Status "info" -Indent 2
            Write-ModernStatus -Message "Policy Sets:        -$($actualDelete.PolicySetDefinitions) (expected: -$($expectedTotals.PolicySetDefinitionsDelete))" -Status "info" -Indent 2
            Write-ModernStatus -Message "Assignments:        -$($actualDelete.PolicyAssignments) (expected: -$($expectedTotals.PolicyAssignmentsDelete))" -Status "info" -Indent 2
            Write-ModernStatus -Message "Exemptions:         -$($actualDelete.PolicyExemptions) (expected: -$($expectedTotals.PolicyExemptionsDelete))" -Status "info" -Indent 2
            
            if ($actualDelete.PolicyDefinitions -ne $expectedTotals.PolicyDefinitionsDelete) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyDefinitions delete: expected $($expectedTotals.PolicyDefinitionsDelete), got $($actualDelete.PolicyDefinitions)"
            }
            if ($actualDelete.PolicySetDefinitions -ne $expectedTotals.PolicySetDefinitionsDelete) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicySetDefinitions delete: expected $($expectedTotals.PolicySetDefinitionsDelete), got $($actualDelete.PolicySetDefinitions)"
            }
            if ($actualDelete.PolicyAssignments -ne $expectedTotals.PolicyAssignmentsDelete) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyAssignments delete: expected $($expectedTotals.PolicyAssignmentsDelete), got $($actualDelete.PolicyAssignments)"
            }
            if ($actualDelete.PolicyExemptions -ne $expectedTotals.PolicyExemptionsDelete) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyExemptions delete: expected $($expectedTotals.PolicyExemptionsDelete), got $($actualDelete.PolicyExemptions)"
            }
        }
        else {
            $planValidation.Matches = $false
            $planValidation.Errors += "Delete plan file not found"
        }
        
        if (-not $planValidation.Matches) {
            Write-ModernStatus -Message "Delete plan validation failed:" -Status "error" -Indent 2
            foreach ($err in $planValidation.Errors) {
                Write-ModernStatus -Message "- $err" -Status "error" -Indent 4
            }
            foreach ($tc in $stageTestCases) {
                $stageResults[$stage].Failed++
                $allResults += @{
                    TestCaseId   = $tc.Manifest.testCaseId
                    Success      = $false
                    ErrorMessage = "Delete plan validation failed: $($planValidation.Errors -join '; ')"
                    Duration     = [TimeSpan]::Zero
                }
            }
            continue
        }
        
        Write-ModernStatus -Message "Delete plan validation passed" -Status "success" -Indent 2
        
        # Step 5: Deploy deletes if requested
        if ($Deploy) {
            Write-ModernSection -Title "Deploying delete operations"
            
            $deployParams = @{
                PacEnvironmentSelector = "epac-test"
                DefinitionsRootFolder  = "$TestRootFolder/Definitions"
                InputFolder            = $deletePlanOutput
            }
            
            Deploy-PolicyPlan @deployParams
            Write-ModernStatus -Message "Delete deployment complete" -Status "success" -Indent 2
            
            # Step 6: Validate each test case's Azure state (resources should NOT exist)
            Write-ModernSection -Title "Validating Azure state for each test case"
            
            foreach ($tc in $stageTestCases) {
                Write-ModernStatus -Message "Validating: $($tc.Manifest.testCaseId)" -Status "processing" -Indent 2
                
                $expectedAzureState = @{}
                if ($tc.Manifest.expectedAzureState) {
                    $expectedAzureState = ConvertTo-Hashtable -InputObject $tc.Manifest.expectedAzureState
                }
                
                if ($expectedAzureState.Count -gt 0) {
                    $assertParams = @{
                        ManagementGroupId = $TestManagementGroupId
                        ExpectedState     = $expectedAzureState
                        TestCaseId        = $tc.Manifest.testCaseId
                        ResultsFolder     = "$TestRootFolder/Results"
                    }
                    
                    $azureValidation = & "$ScriptRoot/Assert-AzureState.ps1" @assertParams
                    
                    if ($azureValidation.AllPassed) {
                        Write-ModernStatus -Message "$($tc.Manifest.testCaseId) - PASSED ($($azureValidation.PassedTests)/$($azureValidation.TotalTests) tests)" -Status "success" -Indent 4
                        $stageResults[$stage].Passed++
                        $allResults += @{
                            TestCaseId      = $tc.Manifest.testCaseId
                            Success         = $true
                            AzureValidation = $azureValidation
                            Duration        = $azureValidation.Duration
                        }
                    }
                    else {
                        Write-ModernStatus -Message "$($tc.Manifest.testCaseId) - FAILED ($($azureValidation.FailedTests) tests failed)" -Status "error" -Indent 4
                        $stageResults[$stage].Failed++
                        $allResults += @{
                            TestCaseId      = $tc.Manifest.testCaseId
                            Success         = $false
                            ErrorMessage    = "Azure state validation failed"
                            AzureValidation = $azureValidation
                            Duration        = $azureValidation.Duration
                        }
                    }
                }
                else {
                    Write-ModernStatus -Message "$($tc.Manifest.testCaseId) - PASSED (no Azure state validation)" -Status "success" -Indent 4
                    $stageResults[$stage].Passed++
                    $allResults += @{
                        TestCaseId = $tc.Manifest.testCaseId
                        Success    = $true
                        Duration   = [TimeSpan]::Zero
                    }
                }
            }
        }
        else {
            # Plan-only mode
            foreach ($tc in $stageTestCases) {
                $stageResults[$stage].Passed++
                $allResults += @{
                    TestCaseId     = $tc.Manifest.testCaseId
                    Success        = $true
                    PlanValidation = $planValidation
                    Duration       = [TimeSpan]::Zero
                }
            }
        }
        
        # Display elapsed time
        $elapsed = (Get-Date) - $startTime
        $elapsedStr = "{0:hh\:mm\:ss}" -f $elapsed
        Write-ModernStatus -Message "Stage 3 elapsed time: $elapsedStr" -Status "info" -Indent 2
    }
    else {
        # Other stages - process each test case individually (original behavior)
        foreach ($tc in $stageTestCases) {
            $testCasePath = $tc.TestCasePath
            $manifest = $tc.Manifest
            
            # Build expected plan parameters
            $expectedPlan = @{}
            if ($manifest.expectedPlan) {
                if ($manifest.expectedPlan.policyDefinitions) {
                    $expectedPlan.PolicyDefinitionsNew = $manifest.expectedPlan.policyDefinitions.new
                    $expectedPlan.PolicyDefinitionsUpdate = $manifest.expectedPlan.policyDefinitions.update
                    $expectedPlan.PolicyDefinitionsDelete = $manifest.expectedPlan.policyDefinitions.delete
                }
                if ($manifest.expectedPlan.policySetDefinitions) {
                    $expectedPlan.PolicySetDefinitionsNew = $manifest.expectedPlan.policySetDefinitions.new
                    $expectedPlan.PolicySetDefinitionsUpdate = $manifest.expectedPlan.policySetDefinitions.update
                    $expectedPlan.PolicySetDefinitionsDelete = $manifest.expectedPlan.policySetDefinitions.delete
                }
                if ($manifest.expectedPlan.policyAssignments) {
                    $expectedPlan.PolicyAssignmentsNew = $manifest.expectedPlan.policyAssignments.new
                    $expectedPlan.PolicyAssignmentsUpdate = $manifest.expectedPlan.policyAssignments.update
                    $expectedPlan.PolicyAssignmentsDelete = $manifest.expectedPlan.policyAssignments.delete
                }
                if ($manifest.expectedPlan.policyExemptions) {
                    $expectedPlan.PolicyExemptionsNew = $manifest.expectedPlan.policyExemptions.new
                    $expectedPlan.PolicyExemptionsUpdate = $manifest.expectedPlan.policyExemptions.update
                    $expectedPlan.PolicyExemptionsDelete = $manifest.expectedPlan.policyExemptions.delete
                }
            }
            
            # Build expected Azure state (convert from PSCustomObject to Hashtable)
            $expectedAzureState = @{}
            if ($manifest.expectedAzureState -and $Deploy) {
                $expectedAzureState = ConvertTo-Hashtable -InputObject $manifest.expectedAzureState
            }
            
            # Determine if we should deploy
            $shouldDeploy = $Deploy -and ($manifest.deploy -ne $false)
            
            try {
                $result = & "$ScriptRoot/Invoke-TestStage.ps1" `
                    -TestCaseId $manifest.testCaseId `
                    -TestCasePath $testCasePath `
                    -ManagementGroupId $TestManagementGroupId `
                    -DefinitionsFolder "$TestRootFolder/Definitions" `
                    -OutputFolder "$TestRootFolder/Output" `
                    -ResultsFolder "$TestRootFolder/Results" `
                    -DeployChanges:$shouldDeploy `
                    -ExpectedPlan $expectedPlan `
                    -ExpectedAzureState $expectedAzureState
                
                $allResults += $result
                
                # Display elapsed time
                $elapsed = (Get-Date) - $startTime
                $elapsedStr = "{0:hh\:mm\:ss}" -f $elapsed
                
                if ($result.Success) {
                    $stageResults[$stage].Passed++
                    Write-ModernStatus -Message "Elapsed time: $elapsedStr" -Status "info" -Indent 2
                }
                else {
                    $stageResults[$stage].Failed++
                    Write-ModernStatus -Message "Elapsed time: $elapsedStr" -Status "info" -Indent 2
                    if (-not $ContinueOnError) {
                        throw "Test $($manifest.testCaseId) failed: $($result.ErrorMessage)"
                    }
                }
            }
            catch {
                $stageResults[$stage].Failed++
                
                # Display elapsed time even on error
                $elapsed = (Get-Date) - $startTime
                $elapsedStr = "{0:hh\:mm\:ss}" -f $elapsed
                Write-ModernStatus -Message "Elapsed time: $elapsedStr" -Status "info" -Indent 2
                
                $allResults += @{
                    TestCaseId   = $manifest.testCaseId
                    Success      = $false
                    ErrorMessage = $_.Exception.Message
                    Duration     = [TimeSpan]::Zero
                }
                
                if (-not $ContinueOnError) {
                    throw
                }
            }
        }
    }
    
    # Stage summary
    $sr = $stageResults[$stage]
    $stageSummaryStatus = if ($sr.Failed -eq 0) { "success" } else { "error" }
    Write-ModernStatus -Message "Stage $stage Summary: $($sr.Passed) passed, $($sr.Failed) failed, $($sr.Skipped) skipped" -Status $stageSummaryStatus -Indent 2
}

# Step 5: Generate summary
Write-ModernSection -Title "[5/5] Generating test summary"

$totalPassed = ($stageResults.Values | ForEach-Object { $_.Passed } | Measure-Object -Sum).Sum
$totalFailed = ($stageResults.Values | ForEach-Object { $_.Failed } | Measure-Object -Sum).Sum
$totalSkipped = ($stageResults.Values | ForEach-Object { $_.Skipped } | Measure-Object -Sum).Sum
$totalTests = $totalPassed + $totalFailed
$overallSuccess = $totalFailed -eq 0

$endTime = Get-Date
$duration = $endTime - $startTime

# Save results
$resultsFile = "$TestRootFolder/Results/test-run-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

# Convert stage results to have string keys for JSON serialization
$stageResultsForJson = @{}
foreach ($key in $stageResults.Keys) {
    $stageResultsForJson["Stage$key"] = $stageResults[$key]
}

$summary = @{
    timestamp      = Get-Date -Format "o"
    duration       = $duration.ToString()
    overallSuccess = $overallSuccess
    totals         = @{
        passed  = $totalPassed
        failed  = $totalFailed
        skipped = $totalSkipped
        total   = $totalTests
    }
    stageResults   = $stageResultsForJson
    allResults     = $allResults
}
$summary | ConvertTo-Json -Depth 10 | Set-Content $resultsFile -Encoding UTF8

# Print summary
$summaryTitle = if ($overallSuccess) { "TEST EXECUTION COMPLETE - PASSED" } else { "TEST EXECUTION COMPLETE - FAILED" }
Write-ModernHeader -Title $summaryTitle

Write-ModernSection -Title "Test Summary"
$overallStatus = if ($overallSuccess) { "success" } else { "error" }
$overallText = if ($overallSuccess) { "PASSED" } else { "FAILED" }
Write-ModernStatus -Message "Overall Result: $overallText" -Status $overallStatus -Indent 2
Write-ModernStatus -Message "Test Cases: $totalPassed passed / $totalFailed failed / $totalSkipped skipped" -Status "info" -Indent 2
Write-ModernStatus -Message "Duration: $($duration.ToString('hh\:mm\:ss'))" -Status "info" -Indent 2

Write-ModernSection -Title "Stage Breakdown"
foreach ($stage in ($stageResults.Keys | Sort-Object)) {
    $sr = $stageResults[$stage]
    $stageStatusType = if ($sr.Failed -eq 0) { "success" } else { "error" }
    Write-ModernStatus -Message "Stage $stage`: $($sr.Passed) passed, $($sr.Failed) failed, $($sr.Skipped) skipped" -Status $stageStatusType -Indent 2
}

if ($totalFailed -gt 0) {
    Write-ModernSection -Title "Failed Tests"
    foreach ($failed in ($allResults | Where-Object { -not $_.Success })) {
        $msg = if ($failed.ErrorMessage.Length -gt 50) { $failed.ErrorMessage.Substring(0, 50) + "..." } else { $failed.ErrorMessage }
        Write-ModernStatus -Message "$($failed.TestCaseId): $msg" -Status "error" -Indent 2
    }
}

Write-ModernStatus -Message "Results saved to: $resultsFile" -Status "info" -Indent 0

# Cleanup
if (-not $SkipCleanup -and $Deploy) {
    Write-ModernSection -Title "Cleaning up test resources"
    & "$ScriptRoot/Cleanup-TestEnvironment.ps1" -ManagementGroupId $TestManagementGroupId
}

if (-not $overallSuccess) {
    exit 1
}
exit 0
