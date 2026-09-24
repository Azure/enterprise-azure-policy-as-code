Describe 'Deploy-PolicyPlan syntax' {
    It 'parses without syntax errors' {
        $scriptPath = Join-Path $PSScriptRoot '../../../Scripts/Deploy/Deploy-PolicyPlan.ps1'

        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref] $tokens, [ref] $errors) | Out-Null

        $errors | Should -BeNullOrEmpty
    }
}
