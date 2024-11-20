function Test-HydrationCaf3Hierarchy {
    <#
.SYNOPSIS
    Tests the hierarchy of Azure Management Groups for a specified tenant to see if a standard CAF 3.0 hierarchy is in place.

.DESCRIPTION
    This script retrieves the structure of Azure Management Groups for a specified tenant and verifies that the management groups have the correct parent-child relationships.

.PARAMETER TenantId
    The Tenant ID of the Azure Active Directory tenant. If not specified, the Tenant ID from the current Azure context will be used.

.EXAMPLE
    .\Test-HydrationCaf3Hierarchy -TenantId "your-tenant-id"

    This example runs the script for the specified Tenant ID.

.EXAMPLE
    .\Test-HydrationCaf3Hierarchy

    This example runs the script using the Tenant ID from the current Azure context.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
    
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $TenantId,
        [Parameter(Mandatory = $false)]
        [string]
        $TenantIntermediateRoot = "TenantIntermediateRoot",
        $LogFilePath,
        $Output = "./Output"
    )
    if (!($LogFilePath)) {
        $LogFilePath = Join-Path $Output "Logs" "HydrationTests.log"
    }
    $mgPairs = [ordered]@{
        LandingZones            = @("Corp", "Online")
        Platform                = @("Identity", "Management", "Connectivity")
        $TenantIntermediateRoot = @("Decomissioned", "Sandbox", "Platform", "LandingZones")
    }
    if ((!$TenantId) -or ($TenantId -eq "")) {
        $TenantId = (Get-AzContext).Tenant.Id
    }
    $mgPullIncrement = 0
    do {
        $mgPullIncrement++
        try {
            $mgStructure = Get-AzManagementGroupRestMethod -GroupId $TenantId -Expand -Recurse
        }
        catch {
            if ($mgPullIncrement -eq 3) {
                Write-Error "Failed to retrieve Management Group structure after 3 attempts, exiting. Reconnect to Azure and retry test."
            
            }
            Write-Warning "Failed to retrieve Management Group structure, retrying $(10-$mgPullIncrement) more times..."
        }
    }until($mgStructure -or $mgPullIncrement -eq 3)

    $testResults = @{}
    try {
        $tenantIntermediateRootResult = Get-AzManagementGroupRestMethod -GroupId $TenantIntermediateRoot -ErrorAction Stop
    }
    catch {
        if (($_.Exception.Message -like "*error 403*" -or $_.Exception.Message -like "*error 404*")) {
            $tenantIntermediateRootResult = "Available"  
        }
        else {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$_.Exception.Message"   -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
            Write-Error $_.Exception.Message
        }
    }
    foreach ($mgKey in $mgPairs.keys) {
        $currentList = $mgPairs.$mgKey
        $parentName = $mgKey
        foreach ($mg in $currentList) {
            try {
                $mgListing = Get-AzManagementGroupRestMethod -GroupId $mg -ErrorAction Stop
            }
            catch {
                if ($_.Exception.Message -like "*error 403*" -or $_.Exception.Message -like "*error 404*") {
                    $testResults.add($mg, "Available")
                    Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$mg Available: Failed to retrieve management group $mg" -Silent  -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
                    continue
                }
                else {
                    Write-Error $_.Exception.Message
                    Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$_.Exception.Message" -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Red
                    return "Failed"
                }
            }
            if ($mgListing.properties.details.parent.name -eq $parentName) {
                $testResults.add($mg, "ParentPassed")
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "$mg has standard CAF3 parent, $parentName" -Silent -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
            }
            else {
                Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Standard CAF3 Naming Option Will Fail: Actual Parent `"$($mgListing.properties.details.parent.name)`" for management group `"$mg`"  does not match expected parent `"$parentName`"..." -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Yellow
                return "FailedNameCollision"
            }
        }
    }
    if ($testResults.count -gt 1) {
        if ($testResults.Values -contains "ParentPassed" -and (!($testResults.Values -contains "Available"))) {
            Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Passed: All Management Groups have the correct parent-child relationships in the CAF3 hierarchy under the management group `"$TenantIntermediateRoot`"."   -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
            return "PassedCaf3Exists"
        }
        elseif ($testResults.Values -contains "Available" -and (!($testResults.Values -contains "FailedNameCollision"))) {
            # Write-HydrationLogFile -EntryType logEntryDataAsPresented -EntryData "Passed: There are existing Management Groups with the same name, but they exist in the appropriate place in the CAF3 hierarchy under the management group `"$TenantIntermediateRoot`". However, the deployment remains incomplete."   -LogFilePath $logFilePath -UseUtc:$UseUtc -ForegroundColor Green
            return "PassedRunCaf3"
            
        }
        else {
            $failString = $testResults | ConvertTo-Json -Depth 20
            return "Failed, report bug to EPAC team. Data: $failString"
        }
    }
    else {
        return "Failed, report bug to EPAC team. No evaluations returned for Test-HydrationCaf3Hierarchy...."
    }
}