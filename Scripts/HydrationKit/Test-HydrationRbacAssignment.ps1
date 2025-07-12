<#
.SYNOPSIS
    Tests the RBAC hydration assignment for a specified Client ID and Scope.

.DESCRIPTION
    The Test-HydrationRbacAssignment function checks the RBAC hydration assignment for a specified Client ID and Scope. It logs the results of the test to a specified log file and can use UTC time for timestamps. Additionally, it can run silently without verbose output.

.PARAMETER ClientId
    Specifies the Client ID for the RBAC assignment. This parameter is optional.

.PARAMETER Scope
    Specifies the scope for the RBAC assignment. This parameter is optional.

.PARAMETER RestApiVersion
    Specifies the REST API version to use. The default value is "2022-04-01".

.PARAMETER Output
    Specifies the output path for logs. The default value is "./Output".

.PARAMETER UseUtc
    Switch to use UTC time for timestamps in the logs. This parameter is optional.

.PARAMETER LogFilePath
    Specifies the path to the log file. If not specified, a default log file path is used.

.PARAMETER Silent
    Switch to run the function silently without verbose output. This parameter is optional.

.EXAMPLE
    Test-HydrationRbacAssignment -ClientId "00000000-0000-0000-0000-000000000000" -Scope "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}" -Output "./Output" -UseUtc -Silent

    This example tests the RBAC hydration assignment for the specified Client ID and Scope, logs the results to the specified output path, uses UTC time for timestamps, and runs silently.

.NOTES
    The function creates a log file if it does not exist and logs the results of the RBAC hydration test.

#>
function Test-HydrationRbacAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the Client ID for the RBAC assignment. This parameter is optional.")]
        [guid]
        $ClientId,
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the scope for the RBAC assignment. This parameter is optional.")]
        [string]
        $Scope,
        [Parameter(Mandatory = $false, HelpMessage = "Specifies the REST API version to use. The default value is '2022-04-01'.")]
        [string]
        $RestApiVersion = "2022-04-01",
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
    $testType = "rbacHydration"
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
        $command = "Test-HydrationAccess -TestType $testType -RbacClientId $ClientId -Scope:$Scope -LogFilePath $logFilePath -UseUtc:$UseUtc -Silent:$Silent"
        Write-HydrationLogFile -EntryType commandStart `
            -EntryData $command `
            -LogFilePath $logFilePath `
            -UseUtc:$UseUtc `
            -Silent:$Silent
    }
    $testResult = Test-HydrationAccess -TestType $testType `
        -RbacClientId:$ClientId `
        -TestedValue:$Scope `
        -LogFilePath $logFilePath `
        -UseUtc:$UseUtc `
        -Silent:$Silent
    return $testResult 
}