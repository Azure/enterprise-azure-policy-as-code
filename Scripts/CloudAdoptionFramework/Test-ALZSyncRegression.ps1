Param(
    [Parameter(Mandatory = $true)]
    [string] $DefinitionsRootFolder,

    [Parameter(Mandatory = $true)]
    [string] $PacEnvironmentSelector,

    [string] $LibraryPath,

    [ValidateSet("ALZ", "AMBA", "FSI", "SLZ")]
    [string[]] $Types = @("ALZ", "AMBA", "SLZ"),

    [string] $BaselineDefinitionsRootFolder,

    [switch] $CleanOutput
)

$ErrorActionPreference = "Continue"

function New-ParameterSet {
    param(
        [string] $Type,
        [switch] $IncludeSyncAssignmentsOnly
    )

    $params = @{
        DefinitionsRootFolder  = $DefinitionsRootFolder
        PacEnvironmentSelector = $PacEnvironmentSelector
        Type                   = $Type
    }

    if (-not [string]::IsNullOrWhiteSpace($LibraryPath)) {
        $params.LibraryPath = $LibraryPath
    }

    if ($IncludeSyncAssignmentsOnly) {
        $params.SyncAssignmentsOnly = $true
    }

    return $params
}

function Add-Failure {
    param(
        [string] $Type,
        [string] $Message
    )

    $script:Failures += [PSCustomObject]@{
        Type    = $Type
        Message = $Message
    }
}

function Test-Assignments {
    param(
        [string] $Type
    )

    $assignmentRoot = Join-Path $DefinitionsRootFolder ("policyAssignments/{0}/{1}" -f $Type, $PacEnvironmentSelector)
    if (-not (Test-Path -Path $assignmentRoot)) {
        Add-Failure -Type $Type -Message ("Assignment folder not found: {0}" -f $assignmentRoot)
        return
    }

    $assignmentFiles = Get-ChildItem -Path $assignmentRoot -Recurse -File -Include *.jsonc -ErrorAction SilentlyContinue
    if (($assignmentFiles | Measure-Object).Count -eq 0) {
        Add-Failure -Type $Type -Message "No assignment files were generated."
        return
    }

    foreach ($assignmentFile in $assignmentFiles) {
        $assignment = Get-Content -Path $assignmentFile.FullName -Raw | ConvertFrom-Json
        $scopePropertyNames = @($assignment.scope.PSObject.Properties.Name)

        if ($scopePropertyNames -notcontains $PacEnvironmentSelector) {
            Add-Failure -Type $Type -Message ("Missing scope selector '{0}' in {1}" -f $PacEnvironmentSelector, $assignmentFile.FullName)
            continue
        }

        $scopeValues = @($assignment.scope.$PacEnvironmentSelector)
        if (($scopeValues | Measure-Object).Count -eq 0) {
            Add-Failure -Type $Type -Message ("Empty scope array in {0}" -f $assignmentFile.FullName)
            continue
        }

        $invalidScopeValues = @($scopeValues | Where-Object { $null -eq $_ -or [string]::IsNullOrWhiteSpace("$_") })
        if (($invalidScopeValues | Measure-Object).Count -gt 0) {
            Add-Failure -Type $Type -Message ("Null/empty scope value in {0}" -f $assignmentFile.FullName)
        }
    }
}

function Test-Structure {
    param(
        [string] $Type
    )

    $structureFile = Join-Path $DefinitionsRootFolder ("policyStructures/{0}.policy_default_structure.{1}.jsonc" -f $Type.ToLower(), $PacEnvironmentSelector)
    if (-not (Test-Path -Path $structureFile)) {
        Add-Failure -Type $Type -Message ("Structure file not found: {0}" -f $structureFile)
        return
    }

    $structure = Get-Content -Path $structureFile -Raw | ConvertFrom-Json
    $propertyNames = @($structure.PSObject.Properties.Name)
    $hasArchetypeScopeMappings = $propertyNames -contains "archetypeScopeMappings"

    if ($Type -eq "SLZ") {
        if (-not $hasArchetypeScopeMappings) {
            Add-Failure -Type $Type -Message "Missing archetypeScopeMappings in SLZ structure output."
            return
        }

        $mappingProperties = @($structure.archetypeScopeMappings.PSObject.Properties.Name)
        if (($mappingProperties | Measure-Object).Count -eq 0) {
            Add-Failure -Type $Type -Message "archetypeScopeMappings exists but is empty for SLZ."
            return
        }

        if ($mappingProperties -notcontains "sovereign_l2_controls") {
            Add-Failure -Type $Type -Message "Expected SLZ mapping entry 'sovereign_l2_controls' not found."
        }
    }
    elseif ($Type -in @("ALZ", "AMBA")) {
        if ($hasArchetypeScopeMappings) {
            Add-Failure -Type $Type -Message "Unexpected archetypeScopeMappings found; ALZ/AMBA output should remain unchanged."
        }
    }
}

function Get-FileHashMap {
    param(
        [string] $RootPath
    )

    $hashMap = @{}
    if (-not (Test-Path -Path $RootPath)) {
        return $hashMap
    }

    foreach ($file in Get-ChildItem -Path $RootPath -Recurse -File) {
        $relativePath = $file.FullName.Substring($RootPath.Length).TrimStart('\\', '/')
        $hashMap[$relativePath] = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    }

    return $hashMap
}

function Test-Baseline {
    param(
        [string] $Type
    )

    if ([string]::IsNullOrWhiteSpace($BaselineDefinitionsRootFolder)) {
        return
    }

    $currentStructurePath = Join-Path $DefinitionsRootFolder "policyStructures"
    $baselineStructurePath = Join-Path $BaselineDefinitionsRootFolder "policyStructures"

    $currentAssignmentsPath = Join-Path $DefinitionsRootFolder ("policyAssignments/{0}/{1}" -f $Type, $PacEnvironmentSelector)
    $baselineAssignmentsPath = Join-Path $BaselineDefinitionsRootFolder ("policyAssignments/{0}/{1}" -f $Type, $PacEnvironmentSelector)

    $currentStructureFile = Join-Path $currentStructurePath ("{0}.policy_default_structure.{1}.jsonc" -f $Type.ToLower(), $PacEnvironmentSelector)
    $baselineStructureFile = Join-Path $baselineStructurePath ("{0}.policy_default_structure.{1}.jsonc" -f $Type.ToLower(), $PacEnvironmentSelector)

    if ((Test-Path -Path $currentStructureFile) -and (Test-Path -Path $baselineStructureFile)) {
        $currentStructureHash = (Get-FileHash -Path $currentStructureFile -Algorithm SHA256).Hash
        $baselineStructureHash = (Get-FileHash -Path $baselineStructureFile -Algorithm SHA256).Hash
        if ($currentStructureHash -ne $baselineStructureHash) {
            Add-Failure -Type $Type -Message "Structure file hash differs from baseline."
        }
    }
    else {
        Add-Failure -Type $Type -Message "Unable to compare structure against baseline; one or both files are missing."
    }

    $currentHashMap = Get-FileHashMap -RootPath $currentAssignmentsPath
    $baselineHashMap = Get-FileHashMap -RootPath $baselineAssignmentsPath

    foreach ($path in $currentHashMap.Keys) {
        if (-not $baselineHashMap.ContainsKey($path)) {
            Add-Failure -Type $Type -Message ("Generated file not found in baseline: {0}" -f $path)
            continue
        }

        if ($currentHashMap[$path] -ne $baselineHashMap[$path]) {
            Add-Failure -Type $Type -Message ("Generated file content differs from baseline: {0}" -f $path)
        }
    }

    foreach ($path in $baselineHashMap.Keys) {
        if (-not $currentHashMap.ContainsKey($path)) {
            Add-Failure -Type $Type -Message ("Baseline file missing in generated output: {0}" -f $path)
        }
    }
}

$Failures = @()

if ($CleanOutput) {
    foreach ($type in $Types) {
        $structureFile = Join-Path $DefinitionsRootFolder ("policyStructures/{0}.policy_default_structure.{1}.jsonc" -f $type.ToLower(), $PacEnvironmentSelector)
        if (Test-Path -Path $structureFile) {
            Remove-Item -Path $structureFile -Force -ErrorAction SilentlyContinue
        }

        $assignmentFolder = Join-Path $DefinitionsRootFolder ("policyAssignments/{0}/{1}" -f $type, $PacEnvironmentSelector)
        if (Test-Path -Path $assignmentFolder) {
            Remove-Item -Path $assignmentFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$newStructureScript = Join-Path $PSScriptRoot "New-ALZPolicyDefaultStructure.ps1"
$syncScript = Join-Path $PSScriptRoot "Sync-ALZPolicyFromLibrary.ps1"

foreach ($type in $Types) {
    Write-Host ("[RUN] Type={0} - generating structure" -f $type)
    $newParams = New-ParameterSet -Type $type
    $canContinueType = $true
    try {
        & $newStructureScript @newParams
    }
    catch {
        Add-Failure -Type $type -Message ("Structure generation failed: {0}" -f $_.Exception.Message)
        $canContinueType = $false
    }

    if (-not $?) {
        Add-Failure -Type $type -Message "Structure generation returned a non-success status."
        $canContinueType = $false
    }

    if (-not $canContinueType) {
        continue
    }

    Write-Host ("[RUN] Type={0} - syncing assignments" -f $type)
    $syncParams = New-ParameterSet -Type $type -IncludeSyncAssignmentsOnly
    try {
        & $syncScript @syncParams
    }
    catch {
        Add-Failure -Type $type -Message ("Assignment sync failed: {0}" -f $_.Exception.Message)
        continue
    }

    if (-not $?) {
        Add-Failure -Type $type -Message "Assignment sync returned a non-success status."
        continue
    }

    Write-Host ("[TEST] Type={0} - validating structure" -f $type)
    Test-Structure -Type $type

    Write-Host ("[TEST] Type={0} - validating assignment scopes" -f $type)
    Test-Assignments -Type $type

    if ($type -in @("ALZ", "AMBA")) {
        Write-Host ("[TEST] Type={0} - baseline comparison" -f $type)
        Test-Baseline -Type $type
    }
}

if (($Failures | Measure-Object).Count -gt 0) {
    Write-Host ""
    Write-Host "Regression validation failed:" -ForegroundColor Red
    foreach ($failure in $Failures) {
        Write-Host (" - [{0}] {1}" -f $failure.Type, $failure.Message) -ForegroundColor Red
    }
    exit 1
}

Write-Host ""
Write-Host "Regression validation passed for all requested types." -ForegroundColor Green
exit 0
