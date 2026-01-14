<#
.SYNOPSIS
    Executes a single EPAC regression test case.
.DESCRIPTION
    Copies test case files to definitions folder, runs Build-DeploymentPlans,
    validates the plan output, optionally deploys, and validates Azure state.
.EXAMPLE
    .\Invoke-TestStage.ps1 -TestCaseId "PD-001" -TestCasePath "./Tests/TestCases/Stage1-Create/PD-001"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TestCaseId,
    
    [Parameter(Mandatory = $true)]
    [string]$TestCasePath,
    
    [Parameter(Mandatory = $false)]
    [string]$ManagementGroupId,
    
    [Parameter(Mandatory = $false)]
    [string]$DefinitionsFolder = "./Tests/Definitions",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputFolder = "./Tests/Output",
    
    [Parameter(Mandatory = $false)]
    [string]$ResultsFolder = "./Tests/Results",
    
    [Parameter(Mandatory = $false)]
    [switch]$DeployChanges,
    
    [Parameter(Mandatory = $false)]
    [hashtable]$ExpectedPlan = @{},
    
    [Parameter(Mandatory = $false)]
    [hashtable]$ExpectedAzureState = @{}
)

$ErrorActionPreference = "Stop"
$startTime = Get-Date

# Dot source the modern output functions
. "$PSScriptRoot/../../Scripts/Helpers/Write-ModernOutput.ps1"

$result = @{
    TestCaseId       = $TestCaseId
    Success          = $false
    PlanValidation   = $null
    DeploymentResult = $null
    AzureValidation  = $null
    ErrorMessage     = $null
    Duration         = $null
}

try {
    Write-ModernSection -Title "Test Case: $TestCaseId"
    
    # Load manifest
    $manifestPath = Join-Path $TestCasePath "manifest.json"
    if (-not (Test-Path $manifestPath)) {
        throw "Manifest not found: $manifestPath"
    }
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    
    Write-ModernStatus -Message "Description: $($manifest.description)" -Status "info" -Indent 2
    
    # Step 1: Clean up previous test files and copy new test case files
    Write-ModernStatus -Message "[1/4] Copying test files..." -Status "processing" -Indent 2
    
    # Clean up previous test case files from definitions folder (but keep global-settings.jsonc)
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
        $assignmentSrc = Join-Path $TestCaseFilesFolder "policyAssignments"
        if (Test-Path $assignmentSrc) {
            $assignmentDest = Join-Path $DefinitionsFolder "policyAssignments"
            Copy-WithPlaceholderReplacement -SourcePath $assignmentSrc -DestinationPath $assignmentDest -ManagementGroupId $ManagementGroupId
        }
        
        # Copy policy exemptions
        $exemptionSrc = Join-Path $TestCaseFilesFolder "policyExemptions"
        if (Test-Path $exemptionSrc) {
            $exemptionDest = Join-Path $DefinitionsFolder "policyExemptions"
            Copy-WithPlaceholderReplacement -SourcePath $exemptionSrc -DestinationPath $exemptionDest -ManagementGroupId $ManagementGroupId
        }
    }
    
    # Copy files from prerequisite tests first
    if ($manifest.prerequisiteTests) {
        $testCasesRoot = Split-Path (Split-Path $TestCasePath -Parent) -Parent
        foreach ($prereqTestId in $manifest.prerequisiteTests) {
            # Find the prerequisite test folder by searching all stage folders
            $prereqFolder = Get-ChildItem -Path $testCasesRoot -Directory -Recurse | 
            Where-Object { $_.Name -match "^$prereqTestId-" } | 
            Select-Object -First 1
            
            if ($prereqFolder) {
                $prereqFilesFolder = Join-Path "$prereqFolder" "files"
                if (Test-Path $prereqFilesFolder) {
                    Write-ModernStatus -Message "Copying prerequisite files from $($prereqFolder.Name)..." -Status "info" -Indent 4
                    Copy-TestCaseFiles -TestCaseFilesFolder $prereqFilesFolder -DefinitionsFolder $DefinitionsFolder -ManagementGroupId $ManagementGroupId
                }
            }
            else {
                Write-ModernStatus -Message "Prerequisite test '$prereqTestId' not found" -Status "warning" -Indent 4
            }
        }
    }
    
    # Copy current test case files (after prerequisites, so they can override if needed)
    $testFilesFolder = Join-Path $TestCasePath "files"
    Copy-TestCaseFiles -TestCaseFilesFolder $testFilesFolder -DefinitionsFolder $DefinitionsFolder -ManagementGroupId $ManagementGroupId
    
    # Step 2: Run Build-DeploymentPlans
    Write-ModernStatus -Message "[2/4] Building deployment plan..." -Status "processing" -Indent 2
    
    $planOutput = Join-Path $OutputFolder $TestCaseId
    if (Test-Path $planOutput) {
        Remove-Item -Path $planOutput -Recurse -Force
    }
    New-Item -ItemType Directory -Path $planOutput -Force | Out-Null
    
    # Load environment info
    $testRootFolder = Split-Path $DefinitionsFolder -Parent
    $envInfoPath = Join-Path $testRootFolder "test-environment.json"
    $envInfo = Get-Content $envInfoPath -Raw | ConvertFrom-Json
    
    $buildParams = @{
        DefinitionsRootFolder  = $DefinitionsFolder
        OutputFolder           = $planOutput
        PacEnvironmentSelector = $envInfo.pacSelector
        DetailedOutput         = $true
    }
    
    # Execute Build-DeploymentPlans
    Build-DeploymentPlans @buildParams
    
    # Step 3: Validate plan output
    Write-ModernStatus -Message "[3/4] Validating deployment plan..." -Status "processing" -Indent 2
    
    $planFile = Get-ChildItem -Path $planOutput -Filter "policy-plan.json" -Recurse | Select-Object -First 1
    
    $planValidation = @{
        PlanFileExists       = $null -ne $planFile
        PolicyDefinitions    = @{ new = 0; update = 0; delete = 0 }
        PolicySetDefinitions = @{ new = 0; update = 0; delete = 0 }
        PolicyAssignments    = @{ new = 0; update = 0; delete = 0 }
        PolicyExemptions     = @{ new = 0; update = 0; delete = 0 }
        Matches              = $true
        Errors               = @()
    }
    
    if ($planFile) {
        $plan = Get-Content $planFile.FullName -Raw | ConvertFrom-Json
        
        # Count policy definitions (new/update/delete are hashtables, count keys)
        if ($plan.policyDefinitions) {
            $planValidation.PolicyDefinitions.new = @($plan.policyDefinitions.new.PSObject.Properties).Count
            $planValidation.PolicyDefinitions.update = @($plan.policyDefinitions.update.PSObject.Properties).Count
            $planValidation.PolicyDefinitions.delete = @($plan.policyDefinitions.delete.PSObject.Properties).Count
        }
        
        # Count policy set definitions
        if ($plan.policySetDefinitions) {
            $planValidation.PolicySetDefinitions.new = @($plan.policySetDefinitions.new.PSObject.Properties).Count
            $planValidation.PolicySetDefinitions.update = @($plan.policySetDefinitions.update.PSObject.Properties).Count
            $planValidation.PolicySetDefinitions.delete = @($plan.policySetDefinitions.delete.PSObject.Properties).Count
        }
        
        # Count policy assignments (EPAC uses "assignments" not "policyAssignments")
        if ($plan.assignments) {
            $planValidation.PolicyAssignments.new = @($plan.assignments.new.PSObject.Properties).Count
            $planValidation.PolicyAssignments.update = @($plan.assignments.update.PSObject.Properties).Count
            $planValidation.PolicyAssignments.delete = @($plan.assignments.delete.PSObject.Properties).Count
        }
        
        # Count policy exemptions (EPAC uses "exemptions" not "policyExemptions")
        if ($plan.exemptions) {
            $planValidation.PolicyExemptions.new = @($plan.exemptions.new.PSObject.Properties).Count
            $planValidation.PolicyExemptions.update = @($plan.exemptions.update.PSObject.Properties).Count
            $planValidation.PolicyExemptions.delete = @($plan.exemptions.delete.PSObject.Properties).Count
        }
        
        # Validate against expected counts
        if ($ExpectedPlan.Count -gt 0) {
            if ($ExpectedPlan.PolicyDefinitionsNew -and $planValidation.PolicyDefinitions.new -ne $ExpectedPlan.PolicyDefinitionsNew) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyDefinitions.new: expected $($ExpectedPlan.PolicyDefinitionsNew), got $($planValidation.PolicyDefinitions.new)"
            }
            if ($ExpectedPlan.PolicyDefinitionsUpdate -and $planValidation.PolicyDefinitions.update -ne $ExpectedPlan.PolicyDefinitionsUpdate) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyDefinitions.update: expected $($ExpectedPlan.PolicyDefinitionsUpdate), got $($planValidation.PolicyDefinitions.update)"
            }
            if ($ExpectedPlan.PolicyDefinitionsDelete -and $planValidation.PolicyDefinitions.delete -ne $ExpectedPlan.PolicyDefinitionsDelete) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyDefinitions.delete: expected $($ExpectedPlan.PolicyDefinitionsDelete), got $($planValidation.PolicyDefinitions.delete)"
            }
            
            # Policy Set validations
            if ($ExpectedPlan.PolicySetDefinitionsNew -and $planValidation.PolicySetDefinitions.new -ne $ExpectedPlan.PolicySetDefinitionsNew) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicySetDefinitions.new: expected $($ExpectedPlan.PolicySetDefinitionsNew), got $($planValidation.PolicySetDefinitions.new)"
            }
            if ($ExpectedPlan.PolicySetDefinitionsUpdate -and $planValidation.PolicySetDefinitions.update -ne $ExpectedPlan.PolicySetDefinitionsUpdate) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicySetDefinitions.update: expected $($ExpectedPlan.PolicySetDefinitionsUpdate), got $($planValidation.PolicySetDefinitions.update)"
            }
            if ($ExpectedPlan.PolicySetDefinitionsDelete -and $planValidation.PolicySetDefinitions.delete -ne $ExpectedPlan.PolicySetDefinitionsDelete) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicySetDefinitions.delete: expected $($ExpectedPlan.PolicySetDefinitionsDelete), got $($planValidation.PolicySetDefinitions.delete)"
            }
            
            # Policy Assignment validations
            if ($ExpectedPlan.PolicyAssignmentsNew -and $planValidation.PolicyAssignments.new -ne $ExpectedPlan.PolicyAssignmentsNew) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyAssignments.new: expected $($ExpectedPlan.PolicyAssignmentsNew), got $($planValidation.PolicyAssignments.new)"
            }
            if ($ExpectedPlan.PolicyAssignmentsUpdate -and $planValidation.PolicyAssignments.update -ne $ExpectedPlan.PolicyAssignmentsUpdate) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyAssignments.update: expected $($ExpectedPlan.PolicyAssignmentsUpdate), got $($planValidation.PolicyAssignments.update)"
            }
            if ($ExpectedPlan.PolicyAssignmentsDelete -and $planValidation.PolicyAssignments.delete -ne $ExpectedPlan.PolicyAssignmentsDelete) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyAssignments.delete: expected $($ExpectedPlan.PolicyAssignmentsDelete), got $($planValidation.PolicyAssignments.delete)"
            }
            
            # Policy Exemption validations
            if ($ExpectedPlan.PolicyExemptionsNew -and $planValidation.PolicyExemptions.new -ne $ExpectedPlan.PolicyExemptionsNew) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyExemptions.new: expected $($ExpectedPlan.PolicyExemptionsNew), got $($planValidation.PolicyExemptions.new)"
            }
            if ($ExpectedPlan.PolicyExemptionsUpdate -and $planValidation.PolicyExemptions.update -ne $ExpectedPlan.PolicyExemptionsUpdate) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyExemptions.update: expected $($ExpectedPlan.PolicyExemptionsUpdate), got $($planValidation.PolicyExemptions.update)"
            }
            if ($ExpectedPlan.PolicyExemptionsDelete -and $planValidation.PolicyExemptions.delete -ne $ExpectedPlan.PolicyExemptionsDelete) {
                $planValidation.Matches = $false
                $planValidation.Errors += "PolicyExemptions.delete: expected $($ExpectedPlan.PolicyExemptionsDelete), got $($planValidation.PolicyExemptions.delete)"
            }
        }
    }
    else {
        $planValidation.Matches = $false
        $planValidation.Errors += "Plan file not found"
    }
    
    $result.PlanValidation = $planValidation
    
    # Output plan summary
    Write-ModernStatus -Message "Policy Definitions: +$($planValidation.PolicyDefinitions.new) ~$($planValidation.PolicyDefinitions.update) -$($planValidation.PolicyDefinitions.delete)" -Status "info" -Indent 4
    Write-ModernStatus -Message "Policy Sets:        +$($planValidation.PolicySetDefinitions.new) ~$($planValidation.PolicySetDefinitions.update) -$($planValidation.PolicySetDefinitions.delete)" -Status "info" -Indent 4
    Write-ModernStatus -Message "Assignments:        +$($planValidation.PolicyAssignments.new) ~$($planValidation.PolicyAssignments.update) -$($planValidation.PolicyAssignments.delete)" -Status "info" -Indent 4
    Write-ModernStatus -Message "Exemptions:         +$($planValidation.PolicyExemptions.new) ~$($planValidation.PolicyExemptions.update) -$($planValidation.PolicyExemptions.delete)" -Status "info" -Indent 4
    
    if (-not $planValidation.Matches) {
        Write-ModernStatus -Message "Plan validation failed:" -Status "error" -Indent 4
        foreach ($errorText in $planValidation.Errors) {
            Write-ModernStatus -Message "- $errorText" -Status "error" -Indent 6
        }
        throw "Plan validation failed: $($planValidation.Errors -join '; ')"
    }
    
    Write-ModernStatus -Message "Plan matches expected" -Status "success" -Indent 4
    
    # Step 4: Deploy if requested
    if ($DeployChanges) {
        Write-ModernStatus -Message "[4/4] Deploying changes..." -Status "processing" -Indent 2
        
        $deployParams = @{
            PacEnvironmentSelector = $envInfo.pacSelector
            DefinitionsRootFolder  = $DefinitionsFolder
            InputFolder            = $planOutput
        }
        
        Deploy-PolicyPlan @deployParams
        
        # Deploy roles if needed
        $rolesFile = Get-ChildItem -Path $planOutput -Filter "roles-plan.json" -Recurse | Select-Object -First 1
        if ($rolesFile) {
            Deploy-RolesPlan @deployParams
        }
        
        $result.DeploymentResult = @{
            Success    = $true
            DeployedAt = Get-Date -Format "o"
        }
        
        Write-ModernStatus -Message "Deployment complete" -Status "success" -Indent 4
        
        # Validate Azure state if expected state provided
        if ($ExpectedAzureState.Count -gt 0) {
            Write-ModernStatus -Message "[4b/4] Validating Azure state..." -Status "processing" -Indent 2
            
            $assertParams = @{
                ManagementGroupId = $ManagementGroupId
                ExpectedState     = $ExpectedAzureState
                TestCaseId        = $TestCaseId
                ResultsFolder     = $ResultsFolder
            }
            
            $azureValidation = & "$PSScriptRoot/Assert-AzureState.ps1" @assertParams
            $result.AzureValidation = $azureValidation
            
            if (-not $azureValidation.AllPassed) {
                throw "Azure state validation failed"
            }
            
            Write-ModernStatus -Message "Azure state validated" -Status "success" -Indent 4
        }
    }
    else {
        Write-ModernStatus -Message "[4/4] Skipping deployment (plan-only mode)" -Status "skip" -Indent 2
    }
    
    $result.Success = $true
    Write-ModernStatus -Message "Test case PASSED" -Status "success" -Indent 2
    
}
catch {
    $result.Success = $false
    $result.ErrorMessage = $_.Exception.Message
    Write-ModernStatus -Message "Test case FAILED: $($_.Exception.Message)" -Status "error" -Indent 2
}

$result.Duration = (Get-Date) - $startTime

# Save result to results folder
$resultFile = Join-Path $ResultsFolder "$TestCaseId-result.json"
$result | ConvertTo-Json -Depth 10 | Set-Content $resultFile -Encoding UTF8

return $result
