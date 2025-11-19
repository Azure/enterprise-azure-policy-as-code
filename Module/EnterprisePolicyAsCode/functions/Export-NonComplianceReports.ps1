function Export-NonComplianceReports {
<#
Exports Non-Compliance Reports in CSV format

Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

Output Folder. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER or './Outputs'.

Formats CSV multi-object cells to use new lines and saves it as UTF-8 with BOM - works only fro Excel in Windows. Default uses commas to separate array elements within a cell

Set to false if used non-interactive

Include non-compliance data only for Policy assignments owned by this Policy as Code repo

Filter by Policy definition names (array) or ids (array).

Filter by Policy Set definition names (array) or ids (array).

Filter by Policy Assignment names (array) or ids (array).

Filter by Policy Effect (array).

Switch parameter to filter out Policy Effect Manual

Filter by Policy Effect "deployifnotexists" and "modify" and compliance status "NonCompliant"

Export-NonComplianceReports -PacEnvironmentSelector "dev"

Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs"

Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs" -WindowsNewLineCells

Export-NonComplianceReports -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\MyPacRepo\Definitions" -OutputFolder "C:\MyPacRepo\Outputs" -OnlyCheckManagedAssignments

Export-NonComplianceReports -PolicySetDefinitionFilter "org-sec-initiative", "/providers/Microsoft.Authorization/policySetDefinitions/11111111-1111-1111-1111-111111111111"

Export-NonComplianceReports -PolicyAssignmentFilter "/providers/microsoft.management/managementgroups/11111111-1111-1111-1111-111111111111/providers/microsoft.authorization/policyassignments/taginh-env", "prod-asb"

Export-NonComplianceReports -PolicyEffectFilter "deny"

Export-NonComplianceReports -PolicyEffectFilter "deny", "audit"

Export-NonComplianceReports -ExcludeManualPolicyEffect

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
    [ValidateScript( {
            $allowedEffects = @("audit", "deny", "deployifnotexists", "modify", "append", "auditifnotexists", "manual", "disabled")
            foreach ($effect in $_) {
                if ($effect -cnotin $allowedEffects) {
                    throw "Invalid policy effect: $effect. Valid effects are: $($allowedEffects -join ', ')"
                }
                if ($effect -cne $effect.ToLower()) {
                    throw "Policy effect '$effect' must be lowercase"
                }
            }
            return $true
        })]
    [string[]] $PolicyEffectFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Switch parameter to filter out Policy Effect Manual")]
    [switch] $ExcludeManualPolicyEffect,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Effect `"deployifnotexists`" and `"modify`" and compliance status `"NonCompliant`"")]
    [switch] $RemediationOnly
)

# Dot Source Helper Scripts

# Make a local of the parameters
$windowsNewLineCells = $WindowsNewLineCells.IsPresent
$onlyCheckManagedAssignments = $OnlyCheckManagedAssignments.IsPresent
$policySetDefinitionFilter = $PolicySetDefinitionFilter
$policyAssignmentFilter = $PolicyAssignmentFilter
$policyEffectFilter = $PolicyEffectFilter
$excludeManualPolicyEffect = $ExcludeManualPolicyEffect.IsPresent
$remediationOnly = $RemediationOnly.IsPresent

# Setting the local copies of parameters to simplify debugging
# $windowsNewLineCells = $true
# $onlyCheckManagedAssignments = $true
# $policySetDefinitionFilter = @( "org-sec-initiative", "/providers/Microsoft.Authorization/policySetDefinitions/11111111-1111-1111-1111-111111111111" )
# $policyAssignmentFilter = @( "/providers/microsoft.management/managementgroups/11111111-1111-1111-1111-111111111111/providers/microsoft.authorization/policyassignments/taginh-env", "prod-asb" )
# $policyEffectFilter = @( "auditifnotexists", "deny" )
# $excludeManualPolicyEffect = $true
# $remediationOnly = $true

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
$tenantId = $pacEnvironment.tenantId
$account = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $tenantId -Interactive $pacEnvironment.interactive

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-ModernStatus -Message "Telemetry is enabled" -Status "info" -Indent 2
    Submit-EPACTelemetry -Cuapid "pid-f464b017-898b-4156-9da5-af932831fa2f" -DeploymentRootScope $pacEnvironment.deploymentRootScope
}
else {
    Write-ModernStatus -Message "Telemetry is disabled" -Status "info" -Indent 2
}
Write-Information ""

# Set the management portal URL
$managementPortalUrlBase = $account.Environment.ManagementPortalUrl
$managementPortalUrlStem = "$($managementPortalUrlBase)#@$($tenantId)/resource"

$rawNonCompliantList, $deployedPolicyResources, $scopeTable = Find-AzNonCompliantResources `
    -PacEnvironment $pacEnvironment `
    -OnlyCheckManagedAssignments:$onlyCheckManagedAssignments `
    -PolicyDefinitionFilter:$policyDefinitionFilter `
    -PolicySetDefinitionFilter:$policySetDefinitionFilter `
    -PolicyAssignmentFilter:$policyAssignmentFilter `
    -PolicyEffectFilter $policyEffectFilter `
    -ExcludeManualPolicyEffect:$excludeManualPolicyEffect `
    -RemediationOnly:$remediationOnly

Write-ModernHeader -Title "Exporting Non-Compliance Reports" -Subtitle "Collating resources into simplified lists"
Write-ModernSection -Title "Processing Compliance Data" -Indent 0

$total = $rawNonCompliantList.Count
if ($total -eq 0) {
    Write-ModernStatus -Message "No non-compliant resources found" -Status "success" -Indent 2
}
else {
    Write-ModernStatus -Message "Processing $total non-compliant records" -Status "processing" -Indent 2

    #source
    $allPolicyDefinitions = $deployedPolicyResources.policydefinitions.all
    #$allPolicyAssignments = $deployedPolicyResources.policyassignments.managed - Why don't you work??

    Set-Variable -Name allPolicyAssignments -Value $deployedPolicyResources.policyassignments.managed

    $collatedByPolicyId = @{}
    $summaryListByPolicy = [System.Collections.ArrayList]::new()
    $detailsListByPolicy = [System.Collections.ArrayList]::new()

    $collatedByResourceId = @{}
    $summaryListByResource = [System.Collections.ArrayList]::new()
    $detailsListByResource = [System.Collections.ArrayList]::new()

    $fullDetailsList = [System.Collections.ArrayList]::new()

    # determine the separator and encoding to use based on the WindowsNewLineCells parameter
    $separator = ","
    $encoding = "utf8NoBOM"
    if ($windowsNewLineCells) {
        $separator = ",`r`n"
        $encoding = "utf8BOM"
    }

    $counter = 0
    foreach ($entry in $rawNonCompliantList) {
        
        #region retrieve and augment the entry properties
        $entryProperties = $entry.properties
        $policyAssignmentId = $entryProperties.policyAssignmentId
        $policyAssignmentName = $entryProperties.policyAssignmentName
        $policyAssignmentScope = $entryProperties.policyAssignmentScope
        $policyDefinitionId = $entryProperties.policyDefinitionId
        $complianceState = $entryProperties.complianceState
        $policyDefinitionAction = $entryProperties.policyDefinitionAction
        $policyDefinitionReferenceId = $entryProperties.policyDefinitionReferenceId
        if ($null -eq $policyDefinitionReferenceId) {
            $policyDefinitionReferenceId = ""
        }
        $resourceId = $entryProperties.resourceId
        $policyDefinitionGroupNames = $entryProperties.policyDefinitionGroupNames
        $policyDefinitionName = $entryProperties.policyDefinitionName
        $policyDefinition = $null
        $policyDefinitionProperties = @{}
        $category = "|unknown|"
        $policyDefinition = $null
        if ($allPolicyDefinitions.ContainsKey($policyDefinitionId)) {
            $policyDefinition = $allPolicyDefinitions.$policyDefinitionId
        }
        else {
            $policyDefinition = Get-AzPolicyDefinition -Id $policyDefinitionId
        }
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
        $policyAssignment = $null
        if ($allPolicyAssignments.ContainsKey($policyAssignmentId)) {
            $policyAssignment = $allPolicyAssignments.$policyAssignmentId
        }
        else {
            $policyAssignment = Get-AzPolicyAssignment -Id $policyAssignmentId
        }
        $policyAssignmentProperties = Get-PolicyResourceProperties $policyAssignment
        if ($policyAssignmentProperties.displayName) {
            $policyAssignmentName = $policyAssignmentProperties.displayName
        }
        $subscriptionId = $entryProperties.subscriptionId
        $subscriptionScope = "/subscriptions/$($subscriptionId)"
        $subscriptionName = $subscriptionId
        if ($scopeTable.ContainsKey($subscriptionScope)) {
            $subscriptionName = $scopeTable.$subscriptionScope.displayName
        }
        $splits = $resourceId -split "/"
        $segments = $splits.Length
        $resourceGroup = ""
        $resourceType = ""
        $resourceName = ""
        $resourceQualifier = ""
        for ($segment = 0; $segment -lt $segments; $segment++) {
            $currentSegment = $splits[$segment]
            $nextSegment = $splits[$segment + 1]
            if ($currentSegment -eq "resourceGroups") {
                $resourceGroup = $nextSegment
            }
            if ($currentSegment -eq "providers") {
                $resourceType = "$nextSegment/$($splits[$segment + 2])"
                $resourceName = $splits[$segment + 3]
                if ($segments -gt $segment + 4) {
                    $startSegment = $segment + 4
                    $endSegment = $segments - 1
                    $resourceQualifier = $splits[$startSegment..$endSegment] -join "/"
                }
            }
        }
        if ($resourceType -eq "") {
            if ($resourceGroup -eq "") {
                $resourceType = "subscriptions"
            }
            else {
                $resourceType = "resourceGroups"
            }
        }
        $managementPortalUrl = "$($managementPortalUrlStem)$($resourceId)"
        #endregion retrieve and augment the entry properties

        #region create full details list hash table
        $groupNames = $policyDefinitionGroupNames -join $separator
        $fullDetails = @{
            assignmentName      = $policyAssignmentName
            assignmentScope     = $policyAssignmentScope
            assignmentId        = $policyAssignmentId
            referenceId         = $policyDefinitionReferenceId
            category            = $category
            policyName          = $policyDefinitionName
            policyId            = $policyDefinitionId
            resourceId          = $resourceId
            subscriptionId      = $subscriptionId
            subscriptionName    = $subscriptionName
            resourceGroup       = $resourceGroup
            resourceType        = $resourceType
            resourceName        = $resourceName
            resourceQualifier   = $resourceQualifier
            managementPortalUrl = $managementPortalUrl
            effect              = $policyDefinitionAction
            state               = $complianceState
            groupNames          = $groupNames
        }
        $null = $fullDetailsList.Add($fullDetails)
        #endregion create full details list hash table

        #region calculate regular details list and summary list by Policy
        $summary = @{}
        $detailsByResourceId = @{}
        if ($collatedByPolicyId.ContainsKey($policyDefinitionId)) {
            $valuesForPolicyId = $collatedByPolicyId.$policyDefinitionId
            $summary = $valuesForPolicyId.summary
            $detailsByResourceId = $valuesForPolicyId.detailsByResourceId
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
            $null = $summaryListByPolicy.Add($summary)
        }
        if ($detailsByResourceId.ContainsKey($resourceId)) {
            # reconcile the details
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
            $details = [ordered]@{
                category            = $category
                policyName          = $policyDefinitionName
                policyId            = $policyDefinitionId
                effect              = $policyDefinitionAction
                state               = $complianceState
                resourceId          = $resourceId
                subscriptionId      = $subscriptionId
                subscriptionName    = $subscriptionName
                resourceGroup       = $resourceGroup
                resourceType        = $resourceType
                resourceName        = $resourceName
                resourceQualifier   = $resourceQualifier
                managementPortalUrl = $managementPortalUrl
                groupNames          = @{}
                assignments         = @{}
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

            $null = $detailsListByPolicy.Add($details)
            $null = $detailsByResourceId.Add($resourceId, $details)

        }
        #endregion calculate regular details list and summary list by Policy

        #region calculate regular summary and details list by Resource
        $summary = @{}
        $detailsByPolicyId = @{}
        if ($collatedByResourceId.ContainsKey($resourceId)) {
            $valueForResourceId = $collatedByResourceId.$resourceId
            $summary = $valueForResourceId.summary
            $detailsByPolicyId = $valueForResourceId.detailsByPolicyId
        }
        else {
            $summary = [ordered]@{
                resourceId          = $resourceId
                subscriptionId      = $subscriptionId
                subscriptionName    = $subscriptionName
                resourceGroup       = $resourceGroup
                resourceType        = $resourceType
                resourceName        = $resourceName
                resourceQualifier   = $resourceQualifier
                managementPortalUrl = $managementPortalUrl
                nonCompliant        = 0
                unknown             = 0
                notStarted          = 0
                exempt              = 0
                conflicting         = 0
                error               = 0
            }
            $null = $collatedByResourceId.Add($resourceId, @{
                    summary           = $summary
                    detailsByPolicyId = $detailsByPolicyId
                }
            )
            $null = $summaryListByResource.Add($summary)
        }
        if ($detailsByPolicyId.ContainsKey($policyDefinitionId)) {
            $details = $detailsByPolicyId.$policyDefinitionId
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
            # increment statistics in summary
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

            #create a new details entry
            $details = [ordered]@{
                resourceId          = $resourceId
                subscriptionId      = $subscriptionId
                subscriptionName    = $subscriptionName
                resourceGroup       = $resourceGroup
                resourceType        = $resourceType
                resourceName        = $resourceName
                resourceQualifier   = $resourceQualifier
                managementPortalUrl = $managementPortalUrl
                category            = $category
                policyName          = $policyDefinitionName
                policyId            = $policyDefinitionId
                effect              = $policyDefinitionAction
                state               = $complianceState
            }
            
            $null = $detailsListByResource.Add($details)
            $null = $detailsByPolicyId.Add($policyDefinitionId, $details)
        }
        #endregion calculate summary list by Resource

        $counter++
        if ($counter % 5000 -eq 0) {
            Write-ModernProgress -Current $counter -Total $total -Activity "Processing compliance records" -Indent 4
        }
    }
    if ($counter % 5000 -ne 0) {
        Write-ModernProgress -Current $counter -Total $total -Activity "Processing compliance records" -Indent 4
    }

    Write-ModernSection -Title "Output CSV files" -Indent 0

    #region summary CSV

    #region summary by Policy CSV
    $summaryCsvPath = Join-Path $pacEnvironment.outputFolder "non-compliance-report" "summary-by-policy.csv"
    Write-ModernStatus -Message "Creating summary by Policy" -Status "processing" -Indent 2
    $sortedSummaryList = $summaryListByPolicy | Sort-Object { $_.category }, { $_.policyDefinitionName } | ForEach-Object {
        $groupNamesHashtable = $_.groupNames
        $summaryGroupNames = $groupNamesHashtable.Keys -join $separator
        $assignmentsHashtable = $_.assignments
        $assignments = $assignmentsHashtable.Keys -join $separator
        $normalizedSummary = [ordered]@{
            "Category"       = $_.category
            "Policy Name"    = $_.policyName
            "Policy Id"      = $_.policyId
            "Non Compliant"  = $_.nonCompliant
            "Unknown"        = $_.unknown
            "Not Started"    = $_.notStarted
            "Exempt"         = $_.exempt
            "Conflicting"    = $_.conflicting
            "Error"          = $_.error
            "Assignment Ids" = $assignments
            "Group Names"    = $summaryGroupNames
        }
        $normalizedSummary
    }
    $null = New-Item -Path $summaryCsvPath -ItemType File -Force | Out-Null
    $sortedSummaryList | Export-Csv -Path $summaryCsvPath -NoTypeInformation -Force -Encoding $encoding
    Write-ModernStatus -Message "Summary by Policy file: $summaryCsvPath" -Status "success" -Indent 4
    #endregion summary by Policy CSV

    #region summary by Resource CSV
    $summaryCsvPath = Join-Path $pacEnvironment.outputFolder "non-compliance-report" "summary-by-resource.csv"
    Write-ModernStatus -Message "Creating summary by Resource" -Status "processing" -Indent 2
    $sortedSummaryList = $summaryListByResource | Sort-Object { $_.resourceId }, { $_.category } | ForEach-Object {
        $normalizedSummary = [ordered]@{
            "Resource Id"        = $_.resourceId
            "Subscription Id"    = $_.subscriptionId
            "Subscription Name"  = $_.subscriptionName
            "Resource Group"     = $_.resourceGroup
            "Resource Type"      = $_.resourceType
            "Resource Name"      = $_.resourceName
            "Resource Qualifier" = $_.resourceQualifier
            "Non Compliant"      = $_.nonCompliant
            "Unknown"            = $_.unknown
            "Not Started"        = $_.notStarted
            "Exempt"             = $_.exempt
            "Conflicting"        = $_.conflicting
            "Error"              = $_.error
        }
        $normalizedSummary
    }
    $null = New-Item -Path $summaryCsvPath -ItemType File -Force | Out-Null
    $sortedSummaryList | Export-Csv -Path $summaryCsvPath -NoTypeInformation -Force -Encoding $encoding
    Write-ModernStatus -Message "Summary by Resource file: $summaryCsvPath" -Status "success" -Indent 4
    #endregion summary by Resource CSV
    
    #endregion summary CSV

    #region simplified details CSV

    #region simplified details by Policy CSV
    $detailsCsvPath = Join-Path $pacEnvironment.outputFolder "non-compliance-report" "details-by-policy.csv"
    Write-ModernStatus -Message "Creating simplified details by Policy" -Status "processing" -Indent 2
    $sortedDetailsList = $detailsListByPolicy | Sort-Object { $_.category }, { $_.policyName }, { $_.resourceId } | ForEach-Object {
        $assignmentsHashtable = $_.assignments
        $assignments = $assignmentsHashtable.Keys -join $separator
        $groupNamesHashtable = $_.groupNames
        $detailsGroupNames = $groupNamesHashtable.Keys -join $separator
        $normalizedDetails = [ordered]@{
            "Category"           = $_.category
            "Policy Name"        = $_.policyName
            "Policy Id"          = $_.policyId
            "Resource Id"        = $_.resourceId
            "Subscription Id"    = $_.subscriptionId
            "Subscription Name"  = $_.subscriptionName
            "Resource Group"     = $_.resourceGroup
            "Resource Type"      = $_.resourceType
            "Resource Name"      = $_.resourceName
            "Resource Qualifier" = $_.resourceQualifier
            "Portal Url"         = $_.managementPortalUrl
            "Effect"             = $_.effect
            "Compliance State"   = $_.state
            "Assignment Ids"     = $assignments
            "Group Names"        = $detailsGroupNames
        }
        $normalizedDetails
    }
    $null = New-Item -Path $detailsCsvPath -ItemType File -Force
    $sortedDetailsList | Export-Csv -Path $detailsCsvPath -NoTypeInformation -Force -Encoding $encoding
    Write-ModernStatus -Message "Details by Policy file: $detailsCsvPath" -Status "success" -Indent 4
    #endregion simplified details by Policy CSV

    #region simplified details by Resource Id CSV
    $detailsCsvPath = Join-Path $pacEnvironment.outputFolder "non-compliance-report" "details-by-resource.csv"
    Write-ModernStatus -Message "Creating simplified details by Resource Id" -Status "processing" -Indent 2
    $sortedDetailsList = $detailsListByResource | Sort-Object { $_.resourceId }, { $_.category }, { $_.policyName } | ForEach-Object {
        $normalizedDetails = [ordered]@{
            "Resource Id"        = $_.resourceId
            "Subscription Id"    = $_.subscriptionId
            "Subscription Name"  = $_.subscriptionName
            "Resource Group"     = $_.resourceGroup
            "Resource Type"      = $_.resourceType
            "Resource Name"      = $_.resourceName
            "Resource Qualifier" = $_.resourceQualifier
            "Portal Url"         = $_.managementPortalUrl
            "Category"           = $_.category
            "Policy Name"        = $_.policyName
            "Policy Id"          = $_.policyId
            "Effect"             = $_.effect
            "Compliance State"   = $_.state
        }
        $normalizedDetails
    }
    $null = New-Item -Path $detailsCsvPath -ItemType File -Force
    $sortedDetailsList | Export-Csv -Path $detailsCsvPath -NoTypeInformation -Force -Encoding $encoding
    Write-ModernStatus -Message "Details by Resource file: $detailsCsvPath" -Status "success" -Indent 4
    #endregion simplified details by Resource Id CSV

    #endregion simplified details CSV

    #region full details CSV

    #region full details by Policy Assignment CSV
    $detailsCsvPath = Join-Path $pacEnvironment.outputFolder "non-compliance-report" "full-details-by-assignment.csv"
    Write-ModernStatus -Message "Creating full details by Assignment" -Status "processing" -Indent 2
    $sortedDetailsList = $fullDetailsList | Sort-Object { $_.assignmentName }, { $_.assignmentScope }, { $_.category }, { $_.policyName }, { $_.referenceId }, { $_.resourceId } | ForEach-Object {
        $groupNamesHashtable = $_.groupNames
        $detailsGroupNames = $groupNamesHashtable.Keys -join $separator
        $normalizedDetails = [ordered]@{
            "Assignment Name"    = $_.assignmentName
            "Assignment Scope"   = $_.assignmentScope
            "Assignment Id"      = $_.assignmentId
            "Category"           = $_.category
            "Policy Name"        = $_.policyName
            "Policy Id"          = $_.policyId
            "Reference Id"       = $_.referenceId
            "Resource Id"        = $_.resourceId
            "Subscription Id"    = $_.subscriptionId
            "Subscription Name"  = $_.subscriptionName
            "Resource Group"     = $_.resourceGroup
            "Resource Type"      = $_.resourceType
            "Resource Name"      = $_.resourceName
            "Resource Qualifier" = $_.resourceQualifier
            "Portal Url"         = $_.managementPortalUrl
            "Compliance State"   = $_.state
            "Effect"             = $_.effect
            "Group Names"        = $detailsGroupNames
        }
        $normalizedDetails
    }
    $null = New-Item -Path $detailsCsvPath -ItemType File -Force
    $sortedDetailsList | Export-Csv -Path $detailsCsvPath -NoTypeInformation -Force -Encoding $encoding
    Write-ModernStatus -Message "Full details by Assignment file: $detailsCsvPath" -Status "success" -Indent 4
    #endregion full details by Policy Assignment CSV

    #region full details by Resource Id CSV
    $detailsCsvPath = Join-Path $pacEnvironment.outputFolder "non-compliance-report" "full-details-by-resource.csv"
    Write-ModernStatus -Message "Creating full details by Resource Id" -Status "processing" -Indent 2
    $sortedDetailsList = $fullDetailsList | Sort-Object { $_.resourceId }, { $_.category }, { $_.policyName }, { $_.assignmentName }, { $_.referenceId }, { $_.assignmentScope } | ForEach-Object {
        $normalizedDetails = [ordered]@{
            "Resource Id"        = $_.resourceId
            "Subscription Id"    = $_.subscriptionId
            "Subscription Name"  = $_.subscriptionName
            "Resource Group"     = $_.resourceGroup
            "Resource Type"      = $_.resourceType
            "Resource Name"      = $_.resourceName
            "Resource Qualifier" = $_.resourceQualifier
            "Portal Url"         = $_.managementPortalUrl
            "Category"           = $_.category
            "Policy Name"        = $_.policyName
            "Policy Id"          = $_.policyId
            "Compliance State"   = $_.state
            "Effect"             = $_.effect
            "Assignment Name"    = $_.assignmentName
            "Reference Id"       = $_.referenceId
            "Assignment Scope"   = $_.assignmentScope
            "Assignment Id"      = $_.assignmentId
            "Group Names"        = $_.groupNames
        }
        $normalizedDetails
    }
    $null = New-Item -Path $detailsCsvPath -ItemType File -Force
    $sortedDetailsList | Export-Csv -Path $detailsCsvPath -NoTypeInformation -Force -Encoding $encoding
    Write-ModernStatus -Message "Full details by Resource file: $detailsCsvPath" -Status "success" -Indent 4
    #endregion full details by Resource Id CSV

    #endregion full details CSV
    
    Write-ModernStatus -Message "Non-compliance reports exported successfully" -Status "success" -Indent 0
}
}
