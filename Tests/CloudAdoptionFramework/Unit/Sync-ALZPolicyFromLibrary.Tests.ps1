BeforeAll {
    $script:SyncScriptPath = Join-Path $PSScriptRoot '../../../Scripts/CloudAdoptionFramework/Sync-ALZPolicyFromLibrary.ps1'
    $script:DefinitionsRoot = Join-Path $TestDrive 'Definitions'
    $script:LibraryRoot = Join-Path $TestDrive 'library'
    $script:AMBARepoRoot = Join-Path $TestDrive 'amba-source'
    $script:Tag = 'platform/amba/2025.11.0'
    $script:HelperScriptPath = Join-Path $TestDrive 'run-sync.ps1'

    foreach ($path in @(
            $script:DefinitionsRoot
            (Join-Path $script:DefinitionsRoot 'policyStructures')
            (Join-Path $script:DefinitionsRoot 'policyDefinitions')
            (Join-Path $script:DefinitionsRoot 'policyDefinitions/AMBA/monitoring/alerts')
            (Join-Path $script:DefinitionsRoot 'policyAssignments')
            (Join-Path $script:LibraryRoot 'platform/amba/policy_definitions')
            (Join-Path $script:LibraryRoot 'platform/amba/policy_set_definitions')
            (Join-Path $script:LibraryRoot 'platform/amba/archetype_definitions')
            (Join-Path $script:LibraryRoot 'platform/amba/policy_assignments')
            (Join-Path $script:AMBARepoRoot 'services/monitoring/alerts/policy')
        )) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }

    Set-Content -Path (Join-Path $script:DefinitionsRoot 'global-settings.jsonc') -Value @'
{
  "telemetryOptOut": true,
  "pacEnvironments": ["epac-dev"]
}
'@

    Set-Content -Path (Join-Path $script:DefinitionsRoot 'policyStructures/amba.policy_default_structure.epac-dev.jsonc') -Value @'
{
  "enforcementMode": "Default",
  "managementGroupNameMappings": {},
  "defaultParameterValues": {},
  "archetypes": []
}
'@

    Set-Content -Path (Join-Path $script:AMBARepoRoot 'services/monitoring/alerts/policy/extended-policy.json') -Value @'
{
  "name": "Extended-Policy-Test",
  "properties": {
    "displayName": "Extended Policy Test",
    "description": "Test policy"
  }
}
'@

    $helperScript = @'
function Invoke-RestMethod {
    param(
        [string] $Uri
    )

    [pscustomobject]@{
        ref = @('__TAG_REF_VALUE__')
    }
}

function git {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]] $Arguments
    )

    if ($Arguments[0] -ne 'clone' -or (($Arguments -join ' ') -notmatch 'azure-monitor-baseline-alerts\.git')) {
        throw "Unexpected git invocation: $Arguments"
    }

    $destination = $Arguments[-1]
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Copy-Item -Path '__AMBA_REPO_ROOT__/*' -Destination $destination -Recurse -Force | Out-Null
    $global:LASTEXITCODE = 0
}

& '__SYNC_SCRIPT__' `
    -DefinitionsRootFolder '__DEFINITIONS_ROOT__' `
    -LibraryPath '__LIBRARY_ROOT__' `
    -Type AMBA `
    -PacEnvironmentSelector 'epac-dev' `
    -Tag '__TAG__' `
    -SyncAMBAExtendedPolicies
'@

    $helperScript = $helperScript.Replace('__SYNC_SCRIPT__', $script:SyncScriptPath.Replace("'", "''"))
    $helperScript = $helperScript.Replace('__DEFINITIONS_ROOT__', $script:DefinitionsRoot.Replace("'", "''"))
    $helperScript = $helperScript.Replace('__LIBRARY_ROOT__', $script:LibraryRoot.Replace("'", "''"))
    $helperScript = $helperScript.Replace('__AMBA_REPO_ROOT__', $script:AMBARepoRoot.Replace("'", "''"))
    $escapedTag = $script:Tag.Replace("'", "''")
    $helperScript = $helperScript.Replace('__TAG__', $escapedTag)
    $helperScript = $helperScript.Replace('__TAG_REF_VALUE__', "refs/tags/$escapedTag")

    Set-Content -Path $script:HelperScriptPath -Value $helperScript
}

AfterAll {
    Remove-Item function:git -ErrorAction SilentlyContinue
    Remove-Item function:Invoke-RestMethod -ErrorAction SilentlyContinue
}

Describe 'Sync-ALZPolicyFromLibrary' {
    It 'syncs AMBA extended policy definitions from the secondary repo' {
        & pwsh -NoLogo -NoProfile -File $script:HelperScriptPath | Out-Null
        $LASTEXITCODE | Should -Be 0

        $outputFile = Join-Path $script:DefinitionsRoot 'policyDefinitions/AMBA/monitoring/alerts/extended-policy.json'

        Test-Path $outputFile | Should -BeTrue
        (Get-Content $outputFile -Raw | ConvertFrom-Json).name | Should -Be 'Extended-Policy-Test'
    }
}
