<#
.SYNOPSIS
Exports Non-Compliance Reports in CSV format

.PARAMETER PacEnvironmentSelector
Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER OutputFolder
Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

.PARAMETER WindowsNewLineCells
Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell

.PARAMETER Interactive
Set to false if used non-interactive

.PARAMETER OnlyCheckManagedAssignments
Include non-compliance data only for Policy assignments owned by this Policy as Code repo

.PARAMETER PolicySetDefinitionFilter
Filter by Policy Set definition names (array) or ids (array). Can only be used when PolicyAssignmentFilter is not used.

.PARAMETER PolicyAssignmentFilter
Filter by Policy Assignment names (array) or ids (array). Can only be used when PolicySetDefinitionFilter is not used.

.EXAMPLE
Export-NonComplianceReports -PacEnvironmentSelector "dev"

.EXAMPLE
Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs"

.EXAMPLE
Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs" -WindowsNewLineCells

.EXAMPLE
Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs" -OnlyCheckManagedAssignments

.EXAMPLE
Export-NonComplianceReports -PolicySetDefinitionFilter "org-sec-initiative", "/providers/Microsoft.Authorization/policySetDefinitions/11111111-1111-1111-1111-111111111111"

.EXAMPLE
Export-NonComplianceReports -PolicyAssignmentFilter "/providers/microsoft.management/managementgroups/11111111-1111-1111-1111-111111111111/providers/microsoft.authorization/policyassignments/taginh-env", "prod-asb"

#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.")]
    [string] $OutputFolder = "",

    [Parameter(Mandatory = $false, HelpMessage = "Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell")]
    [switch] $WindowsNewLineCells,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $Interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Create reports only for Policy assignments owned by this Policy as Code repo")]
    [switch] $OnlyCheckManagedAssignments,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Set definition names or ids")]
    [string[]] $PolicySetDefinitionFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Assignment names or ids")]
    [string[]] $PolicyAssignmentFilter = $null
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

# Make a local of the parameters
$windowsNewLineCells = $WindowsNewLineCells.IsPresent
$onlyCheckManagedAssignments = $OnlyCheckManagedAssignments.IsPresent
$policySetDefinitionFilter = $PolicySetDefinitionFilter
$policyAssignmentFilter = $PolicyAssignmentFilter

# Setting the local copies of parameters to simplify debugging
# $windowsNewLineCells = $true
# $onlyCheckManagedAssignments = $true
# $policySetDefinitionFilter = @( "org-sec-initiative", "/providers/Microsoft.Authorization/policySetDefinitions/11111111-1111-1111-1111-111111111111" )
# $policyAssignmentFilter = @( "/providers/microsoft.management/managementgroups/11111111-1111-1111-1111-111111111111/providers/microsoft.authorization/policyassignments/taginh-env", "prod-asb" )

# Verify that at most one of the parameters PolicySetDefinitionFilter and PolicyAssignmentFilter is supplied
if ($policySetDefinitionFilter -and $policyAssignmentFilter) {
    throw "At most one of the filtering parameters PolicySetDefinitionFilter and PolicyAssignmentFilter is allowed"
}

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive

Write-Information "==================================================================================================="
Write-Information "Retrieve Policy Commpliance List"
Write-Information "==================================================================================================="
$query = 'policyresources | where type == "microsoft.policyinsights/policystates" and properties.complianceState <> "Compliant"'
$result = @() + (Search-AzGraphAllItems -Query $query -Scope @{ UseTenantScope = $true } -ProgressItemName "Policy compliance records")
Write-Information ""

$rawNonCompliantList = [System.Collections.ArrayList]::new()
if ($result.Count -ne 0) {
    # Get all Policy Assignments, Policy Definitions and Policy Set Definitions
    $scopeTable = Get-AzScopeTree -pacEnvironment $pacEnvironment
    $deployedPolicyResources = Get-AzPolicyResources -pacEnvironment $pacEnvironment -scopeTable $scopeTable -skipExemptions -skipRoleAssignments
    $allAssignments = $deployedPolicyResources.policyassignments.all
    $strategy = $pacEnvironment.desiredState.strategy
    # Filter result
    if (-not $onlyCheckManagedAssignments -and -not $policySetDefinitionFilter -and -not $policySetDefinitionFilter) {
        $null = $rawNonCompliantList.AddRange($result)
    }
    else {
        foreach ($entry in $result) {
            $entryProperties = $entry.properties
            $policyAssignmentId = $entryProperties.policyAssignmentId
            if ($allAssignments.ContainsKey($policyAssignmentId)) {
                $assignment = $allAssignments.$policyAssignmentId
                $assignmentPacOwner = $assignment.pacOwner
                if (-not $onlyCheckManagedAssignments -or ($assignmentPacOwner -eq "thisPaC" -or ($assignmentPacOwner -eq "unknownOwner" -and $strategy -eq "full"))) {
                    if ($policySetDefinitionFilter) {
                        foreach ($filterValue in $policySetDefinitionFilter) {
                            if ($entryProperties.policySetDefinitionName -eq $filterValue -or $entryProperties.policySetDefinitionId -eq $filterValue) {
                                $null = $rawNonCompliantList.Add($entry)
                                break
                            }
                        }
                    }
                    elseif ($policyAssignmentFilter) {
                        foreach ($filterValue in $policyAssignmentFilter) {
                            if ($entryProperties.policyAssignmentName -eq $filterValue -or $entryProperties.policyAssignmentId -eq $filterValue) {
                                $null = $rawNonCompliantList.Add($entry)
                                break
                            }
                        }
                    }
                    else {
                        $null = $rawNonCompliantList.Add($entry)
                    }
                }
            }
        }
    }
}
Write-Information ""

Write-Information "==================================================================================================="
Write-Information "Collating non-compliant resources into simplified lists"
Write-Information "==================================================================================================="

$collatedByCategoryAndPolicyId = @{}
$allPolicyDefinitions = $deployedPolicyResources.policydefinitions.all
$summaryList = [System.Collections.ArrayList]::new()
$detailsList = [System.Collections.ArrayList]::new()

$counter = 0
$total = $rawNonCompliantList.Count
if ($total -eq 0) {
    Write-Information "No non-compliant resources found"
}
else {
    Write-Information "Processing $total non-compliant resources"
    foreach ($entry in $rawNonCompliantList) {
        $entryProperties = $entry.properties
        $policyAssignmentId = $entryProperties.policyAssignmentId
        $policyDefinitionId = $entryProperties.policyDefinitionId
        $complianceState = $entryProperties.complianceState
        $policyDefinitionAction = $entryProperties.policyDefinitionAction
        $resourceId = $entryProperties.resourceId
        $policyDefinitionGroupNames = $entryProperties.policyDefinitionGroupNames
        $policyDefinitionName = $entryProperties.policyDefinitionName
        $policyDefinition = $null
        $policyDefinitionProperties = @{}
        $category = "|unknown|"
        if ($allPolicyDefinitions.ContainsKey($policyDefinitionId)) {
            $policyDefinition = $allPolicyDefinitions.$policyDefinitionId
            $policyDefinitionProperties = Get-PolicyResourceProperties $policyDefinition
            if ($policyDefinitionProperties.displayName) {
                $policyDefinitionName = $policyDefinitionProperties.displayName
            }
            $metadata = $policyDefinitionProperties.metadata
            if ($metadata) {
                if ($metadata.category) {
                    $category = $metadata.category
                }
            }
        }
        if (-not $collatedByCategoryAndPolicyId.ContainsKey($category)) {
            $null = $collatedByCategoryAndPolicyId.Add($category, @{})
        }
        $collatedByPolicyId = $collatedByCategoryAndPolicyId.$category
        $summary = @{}
        $detailsByResourceId = @{}
        if ($collatedByPolicyId.ContainsKey($policyDefinitionId)) {
            $summary = $collatedByPolicyId.$policyDefinitionId.summary
            $detailsByResourceId = $collatedByPolicyId.$policyDefinitionId.detailsByResourceId
        }
        else {
            $summary = [ordered]@{
                "Category"      = $category
                "Policy"        = $policyDefinitionName
                "Policy Id"     = $policyDefinitionId
                "Non-Compliant" = 0
                "Unknown"       = 0
                "Exempt"        = 0
                "Conflicting"   = 0
                "Not-Started"   = 0
                "Error"         = 0
            }
            $null = $collatedByPolicyId.Add($policyDefinitionId, @{
                    summary             = $summary
                    detailsByResourceId = $detailsByResourceId
                }
            )
            $null = $summaryList.Add($summary)
        }
        if ($detailsByResourceId.ContainsKey($resourceId)) {
            $details = $detailsByResourceId.$resourceId
            # Union the policy assignment ids and policy definition group names
            $details.assignments[$policyAssignmentId] = $true
            $groupNames = $details.groupNames
            foreach ($policyDefinitionGroupName in $policyDefinitionGroupNames) {
                $groupNames[$policyDefinitionGroupName] = $true
            }

            # Update the compliance state if it is more severe than the current state (NonCompliant > Unknown > Exempt > Conflicting > NotStarted  > Error)
            if ($details.State -ne $complianceState) {
                $currentDetailsState = $details.State
                if ($complianceState -ne "Exempt" -and $complianceState -ne "NotStarted") {
                    switch ($currentDetailsState) {
                        NonCompliant {
                            $summary."Non-Compliant"--
                        }
                        Unknown {
                            $summary.Unknown--
                        }
                        Exempt {
                            $summary.Exempt--
                        }
                        Conflicting {
                            $summary.Conflicting--
                        }
                        NotStarted {
                            $summary."Not-Started"--
                        }
                        Error {
                            $summary.Error--
                        }
                    }
                    switch ($complianceState) {
                        NonCompliant {
                            $summary."Non-Compliant"++
                        }
                        Unknown {
                            $summary.Unknown++
                        }
                        Exempt {
                            $summary.Exempt++
                        }
                        Conflicting {
                            $summary.Conflicting++
                        }
                        NotStarted {
                            $summary."Not-Started"++
                        }
                        Error {
                            $summary.Error++
                        }
                    }
                    $details.State = $complianceState
                }
            }
        }
        else {
            # Increment statistics in summary
            switch ($complianceState) {
                NonCompliant {
                    $summary."Non-Compliant"++
                }
                Unknown {
                    $summary.Unknown++
                }
                Exempt {
                    $summary.Exempt++
                }
                Conflicting {
                    $summary.Conflicting++
                }
                NotStarted {
                    $summary."Not-Started"++
                }
                Error {
                    $summary.Error++
                }
            }

            # Create a new details entry
            $details = [ordered]@{
                category    = $category
                policy      = $policyDefinitionName
                effect      = $policyDefinitionAction
                state       = $complianceState
                resourceId  = $resourceId
                policyId    = $policyDefinitionId
                groupNames  = @{}
                assignments = @{ $policyAssignmentId = $true }
            }
            $groupNames = $details.groupNames
            $assignments = $details.assignments
            foreach ($groupName in $policyDefinitionGroupNames) {
                $null = $groupNames.Add($groupName, $true)
            }
            $null = $detailsList.Add($details)
            $null = $detailsByResourceId.Add($resourceId, $details)
        }
        $counter++
        if ($counter % 5000 -eq 0) {
            Write-Information "Processed $counter of $total"
        }
    }
    if ($counter % 5000 -ne 0) {
        Write-Information "Processed $counter of $total"
    }
    Write-Information ""

    Write-Information "==================================================================================================="
    Write-Information "Output CSV files"
    Write-Information "==================================================================================================="

    # determine the seperator and encoding to use based on the WindowsNewLineCells parameter
    $seperator = ","
    $encoding = "utf8NoBOM"
    if ($windowsNewLineCells) {
        $seperator = ",`r`n"
        $encoding = "utf8BOM"
    }

    # Summary CSV
    $summaryCsvPath = Join-Path $pacEnvironment.outputFolder "non-compliance-report" "summary.csv"
    $null = New-Item -Path $summaryCsvPath -ItemType File -Force | Out-Null
    Write-Information "Writing summary to $summaryCsvPath"
    $sortedSummaryList = $summaryList | Sort-Object { $_["Category"] }, { $_["Policy"] }
    $sortedSummaryList | Export-Csv -Path $summaryCsvPath -NoTypeInformation -Force -Encoding $encoding

    # Details CSV
    $detailsCsvPath = Join-Path $pacEnvironment.outputFolder "non-compliance-report" "details.csv"
    # Sort by Category, Policy, Resource Id and compress the group names and assignments into a single column
    $normalizedDetailsList = $detailsList | Sort-Object { $_.category }, { $_.policy }, { $_.resourceId } | ForEach-Object {
        $groupNamesHashtable = $_.groupNames
        $groupNames = $groupNamesHashtable.Keys -join $seperator
        $assignmentsHashtable = $_.assignments
        $assignments = $assignmentsHashtable.Keys -join $seperator
        $normalizedDetails = [ordered]@{
            "Category"    = $_.category
            "Policy"      = $_.policy
            "Effect"      = $_.effect
            "State"       = $_.state
            "Resource Id" = $_.resourceId
            "Policy Id"   = $_.policyId
            "Group Names" = $groupNames
            "Assignments" = $assignments
        }
        $normalizedDetails
    }
    $null = New-Item -Path $detailsCsvPath -ItemType File -Force
    Write-Information "Writing details to $detailsCsvPath"
    $normalizedDetailsList | Export-Csv -Path $detailsCsvPath -NoTypeInformation -Force -Encoding $encoding
}