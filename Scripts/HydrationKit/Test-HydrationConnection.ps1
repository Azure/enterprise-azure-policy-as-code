<#
.SYNOPSIS
    Tests the hydration connection to a specified Fully Qualified Domain Name (FQDN).

.DESCRIPTION
    The Test-HydrationConnection function tests the internet connection to a specified Fully Qualified Domain Name (FQDN). 
    It logs the results of the test to a specified log file and can use UTC time for timestamps. 
    Additionally, it can run silently without verbose output.

.PARAMETER FullyQualifiedDomainName
    Specifies the FQDN to test the connection. This parameter is optional.

.PARAMETER Output
    Specifies the output path for logs. The default value is "./Output".

.PARAMETER UseUtc
    Switch to use UTC time for timestamps in the logs. This parameter is optional.

.PARAMETER LogFilePath
    Specifies the path to the log file. If not specified, a default log file path is used.

.PARAMETER Silent
    Switch to run the function silently without verbose output. This parameter is optional.

.EXAMPLE
    Test-HydrationConnection -FullyQualifiedDomainName "example.com" -Output "./Output" -UseUtc -Silent

    This example tests the connection to "example.com", logs the results to the specified output path, uses UTC time for timestamps, and runs silently.

.NOTES
    The function creates a log file if it does not exist and logs the results of the connection test.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>
function Test-HydrationConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the FQDN to test the connection. This parameter is optional.")]
        [string]
        $FullyQualifiedDomainName,
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
    $testType = "internetConnection"
    if (!($LogFilePath)) {
        $logFileName = "hydrationTests.log"
        $LogFilePath = Join-Path $Output "Logs" $logFileName
    }
    if (!(Test-Path $(Split-Path $logFilePath))) {
        $null = New-Item -ItemType Directory -Path $(Split-Path $logFilePath) -Force
        Write-HydrationLogFile -EntryType logEntryDataAsPresented `
            -EntryData "Created container for `"$logFileName`"  at $(Split-Path $logFilePath)" `
            -LogFilePath $logFilePath `
            -UseUtc:$UseUtc `
            -Silent:$Silent
    }
    if ($debug) {
        $command = "Test-HydrationAccess -TestType $testType -TestedValue:$FullyQualifiedDomainName -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent:$Silent"
        Write-HydrationLogFile -EntryType commandStart `
            -EntryData $command `
            -LogFilePath $logFilePath `
            -UseUtc:$UseUtc
    }
    $testResult = Test-HydrationAccess -TestType $testType `
        -TestedValue:$FullyQualifiedDomainName `
        -LogFilePath $logFilePath `
        -UseUtc:$UseUtc `
        -Silent:$Silent
    return $testResult 
}