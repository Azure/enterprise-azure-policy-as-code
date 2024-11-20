<#
.SYNOPSIS
    Tests and validates the existence of a local path, with self-healing capabilities.

.DESCRIPTION
    The Test-HydrationPath function checks if a specified local path exists. If the path does not exist, it attempts to create it and logs the process. The function can log its actions to a specified log file, use UTC time for timestamps, and run silently without verbose output.

.PARAMETER LocalPath
    Specifies the local path to test and validate. This parameter is mandatory.

.PARAMETER Output
    Specifies the output path for logs. The default value is "./Output".

.PARAMETER UseUtc
    Switch to use UTC time for timestamps in the logs. This parameter is optional.

.PARAMETER LogFilePath
    Specifies the path to the log file. If not specified, a default log file path is used.

.PARAMETER Silent
    Switch to run the function without returning data being sent to the logfile. This parameter is optional.

.EXAMPLE
    Test-HydrationPath -LocalPath "C:\Test\Directory" -Output "./Output" -UseUtc -Silent

    This example tests the existence of the "C:\Test\Directory" path, logs the results to the specified output path, uses UTC time for timestamps, and runs silently.

.NOTES
    The function creates a log file if it does not exist and logs the results of the path test. If the path does not exist, it attempts to create it up to five times.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>
function Test-HydrationPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Specifies the local path to test and validate. This parameter is mandatory.")]
        [string]
        $LocalPath,
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the output path for logs. The default value is './Output'.")]
        [string]
        $Output = "./Output",
        [Parameter(Mandatory = $false, HelpMessage = "Switch to use UTC time for timestamps in the logs. This parameter is optional.")]
        [switch]
        $UseUtc,
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the path to the log file. If not specified, a default log file path is used.")]
        [string]
        $LogFilePath,
        [Parameter(Mandatory = $false, HelpMessage = "Switch to run the function silently without verbose output. This parameter is optional.")]
        [switch]
        $Silent
    )
    $testType = "path"

    if (!$LogFilePath) {
        $logFileName = "hydrationTests.log"
        $LogFilePath = Join-Path $Output "Logs" $logFileName
    }
    if ($debug) {
        $command = "Test-HydrationAccess -TestType $testType -TestedValue:$LocalPath -LogFilePath $LogFilePath -UseUtc:$UseUtc -Silent:$Silent"
        Write-HydrationLogFile -EntryType commandStart `
            -EntryData $command `
            -LogFilePath $LogFilePath `
            -UseUtc:$UseUtc `
            -Silent:$Silent
    }
    $testResult = Test-HydrationAccess -TestType $testType -TestedValue:$LocalPath -LogFilePath $LogFilePath -UseUtc:$UseUtc -Silent:$Silent
    if (($testResult -eq "Failed")) {
        $iTest = 0
        do {
            $iTest++
            Write-HydrationLogFile -EntryType logEntryDataAsPresented `
                -EntryData "Test for $LocalPath failed, but this is a self-healing test. Creating `'$LocalPath`'" `
                -LogFilePath $LogFilePath `
                -UseUtc:$UseUtc `
                -Silent:$Silent
            $null = New-Item -ItemType Directory -Path $localPath -Force
            $testResult = Test-HydrationAccess -TestType $testType -TestedValue:$LocalPath -LogFilePath $LogFilePath -UseUtc:$UseUtc -Silent:$Silent
        }
        until($testResult -eq "Passed" -or $iTest -eq 5)
        if ($iTest -eq 5 -and (!($testResult -eq "Passed"))) {
            Write-HydrationLogFile -EntryType testResult `
                -EntryData "Failed: $LocalPath could not be created" `
                -LogFilePath $LogFilePath `
                -UseUtc:$UseUtc `
                -Silent:$Silent
            Write-Error "Test for $LocalPath failed, and the self-healing test failed to create the path."
        }
    }

    return $testResult 
}