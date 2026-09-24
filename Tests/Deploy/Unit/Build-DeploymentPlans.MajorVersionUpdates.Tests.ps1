Describe 'Build-DeploymentPlans major version update reporting' {

    BeforeAll {
        $script:scriptPath = Join-Path $PSScriptRoot '../../../Scripts/Deploy/Build-DeploymentPlans.ps1'
        $script:scriptContent = Get-Content -Path $script:scriptPath -Raw
    }

    It 'parses without syntax errors' {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:scriptPath, [ref] $tokens, [ref] $errors) | Out-Null

        $errors | Should -BeNullOrEmpty
    }

    It 'exposes a ReportMajorVersionUpdates switch' {
        $command = Get-Command -Name $script:scriptPath
        $parameter = $command.Parameters['ReportMajorVersionUpdates']

        $parameter | Should -Not -BeNullOrEmpty
        $parameter.ParameterType | Should -Be ([switch])
    }

    It 'passes the switch through to Build-AssignmentPlan' {
        $script:scriptContent | Should -Match '-ReportMajorVersionUpdates:\$ReportMajorVersionUpdates'
    }
}

Describe 'Build-AssignmentPlan major version update reporting' {

    BeforeAll {
        $script:assignmentPlanPath = Join-Path $PSScriptRoot '../../../Scripts/Helpers/Build-AssignmentPlan.ps1'
    }

    It 'parses without syntax errors' {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:assignmentPlanPath, [ref] $tokens, [ref] $errors) | Out-Null

        $errors | Should -BeNullOrEmpty
    }

    It 'accepts a ReportMajorVersionUpdates switch' {
        . $script:assignmentPlanPath
        $parameter = (Get-Command -Name Build-AssignmentPlan).Parameters['ReportMajorVersionUpdates']

        $parameter | Should -Not -BeNullOrEmpty
        $parameter.ParameterType | Should -Be ([switch])
    }
}
