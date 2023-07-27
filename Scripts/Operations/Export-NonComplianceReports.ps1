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

.PARAMETER PolicyDefinitionFilter
Filter by Policy definition names (array) or ids (array).

.PARAMETER PolicySetDefinitionFilter
Filter by Policy Set definition names (array) or ids (array).

.PARAMETER PolicyAssignmentFilter
Filter by Policy Assignment names (array) or ids (array).

.PARAMETER PolicyEffectFilter
Filter by Policy Effect (array).

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

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy definition names or ids")]
    [string[]] $PolicyDefinitionFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Set definition names or ids")]
    [string[]] $PolicySetDefinitionFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Assignment names or ids")]
    [string[]] $PolicyAssignmentFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Effect")]
    [string[]] $PolicyEffectFilter = $null
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

# Make a local of the parameters
$windowsNewLineCells = $WindowsNewLineCells.IsPresent
$onlyCheckManagedAssignments = $OnlyCheckManagedAssignments.IsPresent
$policySetDefinitionFilter = $PolicySetDefinitionFilter
$policyAssignmentFilter = $PolicyAssignmentFilter
$policyEffectFilter = $PolicyEffectFilter

# Setting the local copies of parameters to simplify debugging
# $windowsNewLineCells = $true
# $onlyCheckManagedAssignments = $true
# $policySetDefinitionFilter = @( "org-sec-initiative", "/providers/Microsoft.Authorization/policySetDefinitions/11111111-1111-1111-1111-111111111111" )
# $policyAssignmentFilter = @( "/providers/microsoft.management/managementgroups/11111111-1111-1111-1111-111111111111/providers/microsoft.authorization/policyassignments/taginh-env", "prod-asb" )
# $policyEffectFilter = @( "deny" )

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive

$rawNonCompliantList, $deployedPolicyResources, $scopeTable = Find-AzNonCompliantResources `
    -PacEnvironment $pacEnvironment `
    -OnlyCheckManagedAssignments:$onlyCheckManagedAssignments `
    -PolicyDefinitionFilter:$policyDefinitionFilter `
    -PolicySetDefinitionFilter:$policySetDefinitionFilter `
    -PolicyAssignmentFilter:$policyAssignmentFilter `
    -PolicyEffectFilter $policyEffectFilter

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
                category     = $category
                policyName   = $policyDefinitionName
                policyId     = $policyDefinitionId
                nonCompliant = 0
                unknown      = 0
                notStarted   = 0
                exempt       = 0
                conflicting  = 0
                error        = 0
                assignments  = @{}
                groupNames   = @{}
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

            # Union the policy assignment ids and policy definition group names for details AND summary
            $summary.assignments[$policyAssignmentId] = $true
            $summaryGroupNames = $summary.groupNames
            $details.assignments[$policyAssignmentId] = $true
            $detailsGroupNames = $details.groupNames
            foreach ($policyDefinitionGroupName in $policyDefinitionGroupNames) {
                $summaryGroupNames[$policyDefinitionGroupName] = $true
                $detailsGroupNames[$policyDefinitionGroupName] = $true
            }

            # Update the compliance state if it is more severe than the current state (NonCompliant > Unknown > Exempt > Conflicting > NotStarted  > Error)
            if ($details.State -ne $complianceState) {
                $currentDetailsState = $details.State
                if ($complianceState -ne "Exempt" -and $complianceState -ne "NotStarted") {
                    switch ($currentDetailsState) {
                        NonCompliant {
                            $summary.nonCompliant--
                        }
                        Unknown {
                            $summary.unknown--
                        }
                        NotStarted {
                            $summary.notStarted--
                        }
                        Exempt {
                            $summary.exempt--
                        }
                        Conflicting {
                            $summary.conflicting--
                        }
                        Error {
                            $summary.error--
                        }
                    }
                    switch ($complianceState) {
                        NonCompliant {
                            $summary.nonCompliant++
                        }
                        Unknown {
                            $summary.unknown++
                        }
                        NotStarted {
                            $summary.notStarted++
                        }
                        Exempt {
                            $summary.exempt++
                        }
                        Conflicting {
                            $summary.conflicting++
                        }
                        Error {
                            $summary.error++
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
                    $summary.nonCompliant++
                }
                Unknown {
                    $summary.unknown++
                }
                NotStarted {
                    $summary.notStarted++
                }
                Exempt {
                    $summary.exempt++
                }
                Conflicting {
                    $summary.conflicting++
                }
                Error {
                    $summary.error++
                }
            }

            # Create a new details entry
            $subscriptionId = $entryProperties.subscriptionId
            $subscriptionScope = "/subscriptions/$($subscriptionId)"
            $subscriptionName = $subscriptionId
            if ($scopeTable.ContainsKey($subscriptionScope)) {
                $subscriptionName = $scopeTable.$subscriptionScope.name
            }
            $details = [ordered]@{
                category         = $category
                policyName       = $policyDefinitionName
                policyId         = $policyDefinitionId
                effect           = $policyDefinitionAction
                state            = $complianceState
                resourceId       = $resourceId
                subscriptionId   = $subscriptionId
                subscriptionName = $subscriptionName
                groupNames       = @{}
                assignments      = @{}
            }

            # Union the policy assignment ids and policy definition group names for details AND summary
            $summary.assignments[$policyAssignmentId] = $true
            $summaryGroupNames = $summary.groupNames
            $details.assignments[$policyAssignmentId] = $true
            $detailsGroupNames = $details.groupNames
            foreach ($policyDefinitionGroupName in $policyDefinitionGroupNames) {
                $summaryGroupNames[$policyDefinitionGroupName] = $true
                $detailsGroupNames[$policyDefinitionGroupName] = $true
            }

            # Add the details entry to the details list and the detailsByResourceId hashtable
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

    #region Summary CSV

    $summaryCsvPath = Join-Path $pacEnvironment.outputFolder "non-compliance-report" "summary.csv"
    Write-Information "Writing summary to $summaryCsvPath"

    # Sort by Category, Policy and compress the group names and assignments into a single column
    $sortedSummaryList = $summaryList | Sort-Object { $_.category }, { $_.policyName } | ForEach-Object {
        $groupNamesHashtable = $_.groupNames
        $summaryGroupNames = $groupNamesHashtable.Keys -join $seperator
        $assignmentsHashtable = $_.assignments
        $assignments = $assignmentsHashtable.Keys -join $seperator
        $normalizedSummary = [ordered]@{
            "Category"                         = $_.category
            "Policy Name"                      = $_.policyName
            "Policy Id"                        = $_.policyId
            "Non Compliant"                    = $_.nonCompliant
            "Unknown$($seperator)not attested" = $_.unknown
            "Not Started"                      = $_.notStarted
            "Exempt"                           = $_.exempt
            "Conflicting"                      = $_.conflicting
            "Error"                            = $_.error
            "Assignment Ids"                   = $assignments
            "Group Names"                      = $summaryGroupNames
        }
        $normalizedSummary
    }

    # Write the summary to a CSV file
    $null = New-Item -Path $summaryCsvPath -ItemType File -Force | Out-Null
    $sortedSummaryList | Export-Csv -Path $summaryCsvPath -NoTypeInformation -Force -Encoding $encoding

    #endregion Summary CSV

    #region Details CSV

    $detailsCsvPath = Join-Path $pacEnvironment.outputFolder "non-compliance-report" "details.csv"
    Write-Information "Writing details to $detailsCsvPath"

    # Sort by Category, Policy, Resource Id and compress the group names and assignments into a single column
    $sortedDetailsList = $detailsList | Sort-Object { $_.category }, { $_.policyName }, { $_.resourceId } | ForEach-Object {
        $groupNamesHashtable = $_.groupNames
        $detailsGroupNames = $groupNamesHashtable.Keys -join $seperator
        $assignmentsHashtable = $_.assignments
        $assignments = $assignmentsHashtable.Keys -join $seperator
        $normalizedDetails = [ordered]@{
            "Category"          = $_.category
            "Policy Name"       = $_.policyName
            "Policy Id"         = $_.policyId
            "Effect"            = $_.effect
            "Compliance State"  = $_.state
            "Resource Id"       = $_.resourceId
            "Subscription Id"   = $_.subscriptionId
            "Subscription Name" = $_.subscriptionName
            "Assignment Ids"    = $assignments
            "Group Names"       = $detailsGroupNames
        }
        $normalizedDetails
    }

    # Write the details to a CSV file
    $null = New-Item -Path $detailsCsvPath -ItemType File -Force
    $sortedDetailsList | Export-Csv -Path $detailsCsvPath -NoTypeInformation -Force -Encoding $encoding

    #endregion Details CSV
}