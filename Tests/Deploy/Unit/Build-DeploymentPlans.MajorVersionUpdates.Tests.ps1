Describe 'Build-DeploymentPlans major version handling' {

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

    It 'retains the ReportMajorVersionUpdates compatibility switch' {
        $command = Get-Command -Name $script:scriptPath
        $parameter = $command.Parameters['ReportMajorVersionUpdates']

        $parameter | Should -Not -BeNullOrEmpty
        $parameter.ParameterType | Should -Be ([switch])
    }

    It 'exposes a SuppressVersionUpdateInformation switch' {
        $parameter = (Get-Command -Name $script:scriptPath).Parameters['SuppressVersionUpdateInformation']

        $parameter | Should -Not -BeNullOrEmpty
        $parameter.ParameterType | Should -Be ([switch])
    }

    It 'exposes an AutoUpgradeMajorVersions switch' {
        $parameter = (Get-Command -Name $script:scriptPath).Parameters['AutoUpgradeMajorVersions']

        $parameter | Should -Not -BeNullOrEmpty
        $parameter.ParameterType | Should -Be ([switch])
    }

    It 'passes the new switches through to Build-AssignmentPlan' {
        $script:scriptContent | Should -Match '-SuppressVersionUpdateInformation:\$SuppressVersionUpdateInformation'
        $script:scriptContent | Should -Match '-AutoUpgradeMajorVersions:\$AutoUpgradeMajorVersions'
    }
}

Describe 'Build-AssignmentPlan major version handling' {

    BeforeAll {
        $script:assignmentPlanPath = Join-Path $PSScriptRoot '../../../Scripts/Helpers/Build-AssignmentPlan.ps1'
    }

    It 'parses without syntax errors' {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:assignmentPlanPath, [ref] $tokens, [ref] $errors) | Out-Null

        $errors | Should -BeNullOrEmpty
    }

    It 'accepts a SuppressVersionUpdateInformation switch' {
        . $script:assignmentPlanPath
        $parameter = (Get-Command -Name Build-AssignmentPlan).Parameters['SuppressVersionUpdateInformation']

        $parameter | Should -Not -BeNullOrEmpty
        $parameter.ParameterType | Should -Be ([switch])
    }

    It 'accepts an AutoUpgradeMajorVersions switch' {
        . $script:assignmentPlanPath
        $parameter = (Get-Command -Name Build-AssignmentPlan).Parameters['AutoUpgradeMajorVersions']

        $parameter | Should -Not -BeNullOrEmpty
        $parameter.ParameterType | Should -Be ([switch])
    }

    It 'reports available versions by default at information level' {
        $content = Get-Content -Path $script:assignmentPlanPath -Raw

        $content | Should -Match 'if \(-not \$SuppressVersionUpdateInformation\)'
        $content | Should -Not -Match 'Write-Warning "Built-in'
        $content | Should -Match 'Major version updates available.*-Status "info"'
    }

    It 'does not write diagnostic version statuses to the deployment plan' {
        $content = Get-Content -Path $script:assignmentPlanPath -Raw

        $content | Should -Not -Match '\$Assignments\.majorVersionUpdatesAvailable'
        $content | Should -Not -Match '\$Assignments\.definitionVersionStatuses'
    }
}
