BeforeAll {
    $helperPath = Join-Path $PSScriptRoot '../../../Scripts/Helpers/Add-HelperScripts.ps1'
    $helperModule = New-Module -ScriptBlock {
        param ($helperPath)
        . $helperPath
    } -ArgumentList $helperPath
}

Describe 'Add-HelperScripts' {
    It 'loads <functionName>' -ForEach @(
        @{ functionName = 'Get-ParameterNameFromValueString' }
        @{ functionName = 'Get-PolicyAssignmentsDetails' }
    ) {
        $helperModule.ExportedFunctions.ContainsKey($functionName) | Should -BeTrue
    }
}
