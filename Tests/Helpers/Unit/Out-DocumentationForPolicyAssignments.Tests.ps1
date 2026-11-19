BeforeAll {
    $helpers = Join-Path $PSScriptRoot '..\..\..\Scripts\Helpers'
    . (Join-Path $helpers 'Out-DocumentationForPolicyAssignments.ps1')
    . (Join-Path $helpers 'Convert-EffectToMarkdownString.ps1')
    . (Join-Path $helpers 'Convert-AllowedEffectsToCsvString.ps1')
    . (Join-Path $helpers 'Convert-EffectToCsvString.ps1')
    . (Join-Path $helpers 'Convert-ParametersToString.ps1')
    . (Join-Path $helpers 'Write-ModernOutput.ps1')

    function Invoke-TestDocumentation {
        param (
            [string] $FileNameStem,
            [string[]] $Categories = @()
        )

        $flatPolicyList = @{}
        foreach ($category in $Categories) {
            $flatPolicyList[$category] = @{
                name                   = "$FileNameStem-$category"
                displayName            = "$FileNameStem $category policy"
                description            = 'Test policy description'
                policyType             = 'BuiltIn'
                category               = $category
                referencePath          = ''
                isEffectParameterized  = $false
                ordinal                = 1
                effectValue            = 'Audit'
                effectDefault          = 'Audit'
                effectAllowedValues    = @{ Audit = 'Audit' }
                effectAllowedOverrides = @()
                parameters             = @{}
                groupNamesList         = @()
                policySetList          = @{}
                policySetEffectStrings = @()
            }
        }

        $specification = [pscustomobject]@{
            fileNameStem          = $FileNameStem
            title                 = $FileNameStem
            environmentCategories = @("$FileNameStem-env")
            markdownAdoWiki        = $true
        }
        $assignmentsByEnvironment = @{
            "$FileNameStem-env" = @{
                pacEnvironmentSelector = 'test'
                scopes                 = @()
                itemList               = @()
                assignmentsDetails     = @{}
                flatPolicyList         = $flatPolicyList
            }
        }
        $policyResourceDetails = @{ policies = @{} }

        Out-DocumentationForPolicyAssignments `
            -OutputPath $outputPath `
            -OutputPathServices $servicesPath `
            -DocumentationSpecification $specification `
            -AssignmentsByEnvironment $assignmentsByEnvironment `
            -PacEnvironments @{ test = @{} }
    }
}

Describe 'Out-DocumentationForPolicyAssignments services staging' {
    BeforeEach {
        Mock Write-ModernSection {}
        Mock Write-ModernStatus {}
        $outputPath = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $servicesPath = Join-Path $outputPath 'services'
        $null = New-Item -Path $servicesPath -ItemType Directory -Force
    }

    It 'removes pages from a preceding specification with disjoint categories' {
        Invoke-TestDocumentation -FileNameStem 'First' -Categories @('Tags')
        Invoke-TestDocumentation -FileNameStem 'Second' -Categories @('Compute')

        $pages = @(Get-ChildItem -LiteralPath $servicesPath -File)
        $pages.Count | Should -Be 1
        $pages.Name | Should -Be 'Compute.md'
        Get-Content -LiteralPath $pages[0].FullName -Raw | Should -Match 'Second Compute policy'
        Test-Path -LiteralPath (Join-Path $outputPath 'First.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $outputPath 'Second.md') | Should -BeTrue
    }

    It 'replaces overlapping category content and removes categories absent from the next specification' {
        Invoke-TestDocumentation -FileNameStem 'First' -Categories @('Tags', 'Compute')
        Invoke-TestDocumentation -FileNameStem 'Second' -Categories @('Tags')

        $pages = @(Get-ChildItem -LiteralPath $servicesPath -File)
        $pages.Count | Should -Be 1
        $pages.Name | Should -Be 'Tags.md'
        $content = Get-Content -LiteralPath (Join-Path $servicesPath 'Tags.md') -Raw
        $content | Should -Match 'Second Tags policy'
        $content | Should -Match 'Second-env'
        $content | Should -Not -Match 'First Tags policy|First-env'
    }

    It 'clears staged pages when the next specification produces no policy categories' {
        Invoke-TestDocumentation -FileNameStem 'First' -Categories @('Tags')
        Invoke-TestDocumentation -FileNameStem 'Empty'

        Test-Path -LiteralPath $servicesPath -PathType Container | Should -BeTrue
        @(Get-ChildItem -LiteralPath $servicesPath -File).Count | Should -Be 0
        Test-Path -LiteralPath (Join-Path $outputPath 'Empty.md') | Should -BeTrue
    }

    It 'creates a missing services staging folder' {
        Remove-Item -LiteralPath $servicesPath

        Invoke-TestDocumentation -FileNameStem 'First' -Categories @('Tags')

        Test-Path -LiteralPath (Join-Path $servicesPath 'Tags.md') -PathType Leaf | Should -BeTrue
    }
}
