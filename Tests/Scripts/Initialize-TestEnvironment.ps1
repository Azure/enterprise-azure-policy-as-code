<#
.SYNOPSIS
    Initializes the EPAC regression test environment.
.DESCRIPTION
    Creates the test folder structure and generates the global-settings.jsonc
    for the test environment.
.EXAMPLE
    .\Initialize-TestEnvironment.ps1 -TenantId "xxx" -TestManagementGroupId "epac-test-mg"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure Tenant ID for testing")]
    [string]$TenantId,
    
    [Parameter(Mandatory = $true, HelpMessage = "Management Group ID for test deployments")]
    [string]$TestManagementGroupId,
    
    [Parameter(Mandatory = $false, HelpMessage = "Test subscription ID (for RG-scoped tests)")]
    [string]$TestSubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$TestRootFolder = "./Tests"
)

$ErrorActionPreference = "Stop"

# Dot source modern output functions
. "$PSScriptRoot/../../Scripts/Helpers/Write-ModernOutput.ps1"

Write-ModernHeader -Title "Initializing EPAC Test Environment"

# Resolve to absolute path
$resolvedPath = Resolve-Path $TestRootFolder -ErrorAction SilentlyContinue
if ($resolvedPath) {
    $TestRootFolder = $resolvedPath.Path
}
else {
    $TestRootFolder = $PSScriptRoot | Split-Path -Parent
}

Write-ModernStatus -Message "Test Root Folder: $TestRootFolder" -Status "info"

# Clean up old test files from Definitions folder (except global-settings.jsonc)
Write-ModernStatus -Message "Cleaning up old test files..." -Status "processing"
$definitionsPath = "$TestRootFolder/Definitions"
foreach ($subFolder in @("policyDefinitions", "policySetDefinitions", "policyAssignments", "policyExemptions")) {
    $folderPath = Join-Path $definitionsPath $subFolder
    if (Test-Path $folderPath) {
        Get-ChildItem -Path $folderPath -File -Recurse | Where-Object { $_.Name -like "test-*" } | Remove-Item -Force
    }
}

# Clean up Output folder
$outputPath = "$TestRootFolder/Output"
if (Test-Path $outputPath) {
    Get-ChildItem -Path $outputPath -Directory | Remove-Item -Recurse -Force
}

# Create folder structure
$folders = @(
    "$TestRootFolder/Definitions/policyDefinitions",
    "$TestRootFolder/Definitions/policySetDefinitions",
    "$TestRootFolder/Definitions/policyAssignments",
    "$TestRootFolder/Definitions/policyExemptions",
    "$TestRootFolder/Output",
    "$TestRootFolder/Results",
    "$TestRootFolder/TestCases/Stage1-Create",
    "$TestRootFolder/TestCases/Stage2-Update",
    "$TestRootFolder/TestCases/Stage3-Replace",
    "$TestRootFolder/TestCases/Stage4-Delete",
    "$TestRootFolder/TestCases/Stage5-DesiredState",
    "$TestRootFolder/TestCases/Stage6-Special",
    "$TestRootFolder/TestCases/Stage7-CICD"
)

foreach ($folder in $folders) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-ModernStatus -Message "Created: $folder" -Status "success" -Indent 2
    }
}

# Generate global-settings.jsonc
$globalSettings = @{
    "`$schema"        = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json"
    pacOwnerId        = "epac-regression-test"
    pacEnvironments   = @(
        @{
            pacSelector             = "epac-test"
            cloud                   = "AzureCloud"
            tenantId                = $TenantId
            deploymentRootScope     = "/providers/Microsoft.Management/managementGroups/$TestManagementGroupId"
            desiredState            = @{
                strategy                   = "full"
                keepDfcSecurityAssignments = $false
            }
            managedIdentityLocation = "eastus"
        }
    )
    "telemetryOptOut" = $true
}

$globalSettingsPath = "$TestRootFolder/Definitions/global-settings.jsonc"
$globalSettings | ConvertTo-Json -Depth 10 | Set-Content $globalSettingsPath -Encoding UTF8
Write-ModernStatus -Message "Created: $globalSettingsPath" -Status "success" -Indent 2

# Create test environment info file
$envInfo = @{
    tenantId              = $TenantId
    testManagementGroupId = $TestManagementGroupId
    testSubscriptionId    = $TestSubscriptionId
    createdAt             = Get-Date -Format "o"
    pacSelector           = "epac-test"
}

$envInfoPath = "$TestRootFolder/test-environment.json"
$envInfo | ConvertTo-Json -Depth 5 | Set-Content $envInfoPath -Encoding UTF8
Write-ModernStatus -Message "Created: $envInfoPath" -Status "success" -Indent 2

Write-Host ""
Write-ModernStatus -Message "Test environment initialized successfully" -Status "success"
Write-ModernStatus -Message "Run tests with: .\Tests\Scripts\Run-LocalTests.ps1 -Stages 1" -Status "info"

return @{
    TestRootFolder     = $TestRootFolder
    GlobalSettingsPath = $globalSettingsPath
    EnvironmentInfo    = $envInfo
}
