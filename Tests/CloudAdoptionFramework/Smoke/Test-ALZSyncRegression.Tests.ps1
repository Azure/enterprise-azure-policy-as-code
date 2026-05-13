BeforeAll {
    . (Join-Path $PSScriptRoot '..\Helpers\CloudAdoptionFrameworkTestHelpers.ps1')
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $script:RegressionScript = Join-Path $script:RepoRoot 'Scripts\CloudAdoptionFramework\Test-ALZSyncRegression.ps1'
}

Describe 'Test-ALZSyncRegression smoke coverage' {
    It 'passes end-to-end for ALZ, AMBA, and SLZ with fixture libraries' {
        $definitionsRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Definitions')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library')

        { & $script:RegressionScript -DefinitionsRootFolder $definitionsRoot -PacEnvironmentSelector 'epac-dev' -Types ALZ, AMBA, SLZ -LibraryPath $libraryRoot -CleanOutput } | Should -Not -Throw
    }

    It 'supports baseline comparison against previously generated output' {
        $baselineSource = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'BaselineSource')
        $baselineRoot = Join-Path $TestDrive 'Baseline'
        $verificationRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Verification')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library')

        { & $script:RegressionScript -DefinitionsRootFolder $baselineSource -PacEnvironmentSelector 'epac-dev' -Types ALZ, AMBA, SLZ -LibraryPath $libraryRoot -CleanOutput } | Should -Not -Throw
        Copy-Item -Path $baselineSource -Destination $baselineRoot -Recurse -Force

        { & $script:RegressionScript -DefinitionsRootFolder $verificationRoot -PacEnvironmentSelector 'epac-dev' -Types ALZ, AMBA, SLZ -LibraryPath $libraryRoot -BaselineDefinitionsRootFolder $baselineRoot -CleanOutput } | Should -Not -Throw
    }

    It 'fails when the generated output no longer matches the baseline' {
        $baselineSource = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'BaselineSource')
        $baselineRoot = Join-Path $TestDrive 'Baseline'
        $verificationRoot = New-TestDefinitionsRoot -DefinitionsRootFolder (Join-Path $TestDrive 'Verification')
        $libraryRoot = New-CompositeLibraryFixture -LibraryRoot (Join-Path $TestDrive 'Library')

        { & $script:RegressionScript -DefinitionsRootFolder $baselineSource -PacEnvironmentSelector 'epac-dev' -Types ALZ, AMBA, SLZ -LibraryPath $libraryRoot -CleanOutput } | Should -Not -Throw
        Copy-Item -Path $baselineSource -Destination $baselineRoot -Recurse -Force
        '{"changed":true}' | Set-Content -Path (Join-Path $baselineRoot 'policyStructures\alz.policy_default_structure.epac-dev.jsonc') -Encoding utf8

        { & $script:RegressionScript -DefinitionsRootFolder $verificationRoot -PacEnvironmentSelector 'epac-dev' -Types ALZ, AMBA, SLZ -LibraryPath $libraryRoot -BaselineDefinitionsRootFolder $baselineRoot -CleanOutput } | Should -Throw 'Regression validation failed.'
    }
}
