<#
.SYNOPSIS
This PowerShell script creates remediation tasks for all non-compliant resources in the current
Azure Active Directory (AAD) tenant.

.DESCRIPTION
The New-AzRemediationTasks.ps1 PowerShell creates remediation tasks for all non-compliant resources
in the current AAD tenant. If one or multiple remediation tasks fail, their respective objects are
added to a PowerShell variable that is outputted for later use in the Azure DevOps Pipeline.

.PARAMETER PacEnvironmentSelector
Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

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
Filter by Policy effect (array).

.EXAMPLE
New-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev"

.EXAMPLE
New-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions"

.EXAMPLE
New-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -Interactive $false

.EXAMPLE
New-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -OnlyCheckManagedAssignments

.EXAMPLE
New-AzRemediationTasks.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\git\policy-as-code\Definitions" -PolicyDefinitionFilter "Require tag 'Owner' on resource groups" -PolicySetDefinitionFilter "Require tag 'Owner' on resource groups" -PolicyAssignmentFilter "Require tag 'Owner' on resource groups"

.INPUTS
None.

.OUTPUTS
The New-AzRemediationTasks.ps1 PowerShell script outputs multiple string values for logging purposes, a JSON
string containing all the failed Remediation Tasks and a boolean value, both of which are used in a later stage
of the Azure DevOps Pipeline.

.LINK
https://learn.microsoft.com/en-us/azure/governance/policy/concepts/remediation-structure
https://docs.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources
https://azure.github.io/enterprise-azure-policy-as-code/operational-scripts/#build-policyassignmentdocumentationps1
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $Interactive = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Create remediation task only for Policy assignments owned by this Policy as Code repo")]
    [switch] $OnlyCheckManagedAssignments,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy definition names or ids")]
    [string[]] $PolicyDefinitionFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Set definition names or ids")]
    [string[]] $PolicySetDefinitionFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Assignment names or ids")]
    [string[]] $PolicyAssignmentFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Policy Effect")]
    [string[]] $PolicyEffectFilter = $null,

    [Parameter(Mandatory = $false, HelpMessage = "Do not wait for the tasks to complete")]
    [switch] $NoWait,
    
    [Parameter(Mandatory = $false, HelpMessage = "Used to output the remediation tasks that would occur if 'New-AzRemediationTasks' runs.")]
    [switch] $TestRun
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

# Make a local of the parameters
$onlyCheckManagedAssignments = $OnlyCheckManagedAssignments.IsPresent
$policySetDefinitionFilter = $PolicySetDefinitionFilter
$policyAssignmentFilter = $PolicyAssignmentFilter
$policyEffectFilter = $PolicyEffectFilter

# Setting the local copies of parameters to simplify debugging
# $onlyCheckManagedAssignments = $true
# $policySetDefinitionFilter = @( "org-sec-initiative", "/providers/Microsoft.Authorization/policySetDefinitions/11111111-1111-1111-1111-111111111111" )
# $policyAssignmentFilter = @( "/providers/microsoft.management/managementgroups/11111111-1111-1111-1111-111111111111/providers/microsoft.authorization/policyassignments/taginh-env", "prod-asb" )
# $policyEffectFilter = @( "deployifnotexists" )

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -Interactive $pacEnvironment.interactive

# Telemetry
if ($pacEnvironment.telemetryEnabled) {
    Write-Information "Telemetry is enabled"
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("pid-6f4dcbef-f6e2-4c29-ba2a-eef748d88157") 
}
else {
    Write-Information "Telemetry is disabled"
}
Write-Information ""

$rawNonCompliantList, $deployedPolicyResources, $scopeTable = Find-AzNonCompliantResources `
    -RemediationOnly `
    -PacEnvironment $pacEnvironment `
    -OnlyCheckManagedAssignments:$onlyCheckManagedAssignments `
    -PolicyDefinitionFilter:$policyDefinitionFilter `
    -PolicySetDefinitionFilter:$policySetDefinitionFilter `
    -PolicyAssignmentFilter:$policyAssignmentFilter `
    -PolicyEffectFilter $policyEffectFilter

Write-Information "==================================================================================================="
Write-Information "Collating non-compliant resources by Assignment Id and (if Policy Set) policyDefinitionReferenceId"
Write-Information "==================================================================================================="


$total = $rawNonCompliantList.Count
if ($total -eq 0) {
    Write-Information "No non-compliant resources found - no remediation tasks created"
}
else {
    Write-Information "Processing $total non-compliant resources"

    $collatedByAssignmentId = @{}
    $allPolicyDefinitions = $deployedPolicyResources.policydefinitions.all
    foreach ($entry in $rawNonCompliantList) {
        $entryProperties = $entry.properties
        $policyAssignmentId = $entryProperties.policyAssignmentId
        $policyAssignmentName = $entryProperties.policyAssignmentName
        $policyAssignmentScope = $entryProperties.policyAssignmentScope
        $policyDefinitionId = $entryProperties.policyDefinitionId
        $policyDefinitionReferenceId = $entryProperties.policyDefinitionReferenceId
        $policyDefinitionAction = $entryProperties.policyDefinitionAction
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
        $taskName = "$policyAssignmentName-$(New-Guid)"
        $shortScope = $policyAssignmentScope -replace "/providers/microsoft.management", ""
        $parametersSplat = $null
        if ($policyDefinitionReferenceId -and $policyDefinitionReferenceId -ne "") {
            $parametersSplat = [ordered]@{
                Name                        = $taskName
                Scope                       = $policyAssignmentScope
                PolicyAssignmentId          = $policyAssignmentId
                PolicyDefinitionReferenceId = $policyDefinitionReferenceId
                ResourceDiscoveryMode       = "ExistingNonCompliant"
                ResourceCount               = 50000
                ParallelDeploymentCount     = 30
            }
        }
        else {
            $parametersSplat = [ordered]@{
                Name                    = $taskName
                Scope                   = $policyAssignmentScope
                PolicyAssignmentId      = $policyAssignmentId
                ResourceDiscoveryMode   = "ExistingNonCompliant"
                ResourceCount           = 50000
                ParallelDeploymentCount = 30
            }
        }

        $key = "$policyAssignmentId|$policyDefinitionReferenceId"
        if (-not $collatedByAssignmentId.ContainsKey($key)) {
            $remediationEntry = @{
                policyAssignmentId          = $policyAssignmentId
                policyAssignmentName        = $policyAssignmentName
                shortScope                  = $shortScope
                policyDefinitionReferenceId = $policyDefinitionReferenceId
                category                    = $category
                policyDefinitionName        = $policyDefinitionName
                policyDefinitionAction      = $policyDefinitionAction
                resourceCount               = 1
                parametersSplat             = $parametersSplat
            }
            $null = $collatedByAssignmentId.Add($key, $remediationEntry)
        }
        else {
            $collatedByAssignmentId.$key.resourceCount += 1
        }
    }

    Write-Information ""
    if ($TestRun) {
        Write-Information "==================================================================================================="
        Write-Information "TEST RUN: Testing the creation of $($collatedByAssignmentId.Count) remediation tasks..."
        Write-Information "==================================================================================================="
    }
    else {
        Write-Information "==================================================================================================="
        Write-Information "Creating $($collatedByAssignmentId.Count) remediation tasks..."
        Write-Information "==================================================================================================="
    }
    $failedPolicyRemediationTasks = [System.Collections.ArrayList]::new()
    $runningPolicyRemediationTasks = [System.Collections.ArrayList]::new()
    $needed = $collatedByAssignmentId.Count
    $created = 0
    $failedToCreate = 0
    $failed = 0
    $succeeded = 0
    $collatedByAssignmentId.Values | Sort-Object { $_.policyAssignmentId }, { $_.category }, { $_.policyName } | ForEach-Object {
        if ($_.policyDefinitionReferenceId) {
            Write-Information "'$($_.shortScope)/$($_.policyAssignmentName)|$($_.policyDefinitionReferenceId)': $($_.resourceCount) resources, '$($_.policyDefinitionName)', $($_.policyDefinitionAction)"
        }
        else {
            Write-Information "'$($_.shortScope)/$($_.policyAssignmentName)': $($_.resourceCount) resources, '$($_.policyDefinitionName)', $($_.policyDefinitionAction)"
        }
        $parameters = $_.parametersSplat
        Write-Verbose "Parameters: $($parameters | ConvertTo-Json -Depth 99)"
        if ($TestRun) {
            Write-Information "`TEST RUN: Remediation Task would have been created."
            $newPolicyRemediationTask = [ordered]@{
                Name               = $parameters.Name
                Id                 = $parameters.Name
                PolicyAssignmentId = $_.PolicyAssignmentId
                ProvisioningState  = "Running"
            }
            # $null = $runningPolicyRemediationTasks.Add($newPolicyRemediationTask)
            $created++
            $succeeded++
        }
        else {
            $newPolicyRemediationTask = Start-AzPolicyRemediation @parameters -ErrorAction SilentlyContinue

            if ($null -eq $newPolicyRemediationTask) {
                Write-Information "`tRemediation Task could not be created."
                $failedPolicyRemediationTask = [ordered]@{
                    Name               = $parameters.Name
                    Id                 = "Not created"
                    PolicyAssignmentId = $_.PolicyAssignmentId
                    ProvisioningState  = "Failed"
                }
                $null = $failedPolicyRemediationTasks.Add($failedPolicyRemediationTask)
                $failedToCreate++
            }
            elseif ($newPolicyRemediationTask.ProvisioningState -eq 'Succeeded') {
                Write-Information "`tRemediation Task succeeded immediately."
                $succeeded++
                $created++
            }
            elseif ($newPolicyRemediationTask.ProvisioningState -eq 'Failed') {
                Write-Information "`tRemediation Task failed immediately."
                $null = $failedPolicyRemediationTasks.Add($newPolicyRemediationTask)
                $failed++
                $created++
            }
            else {
                Write-Information "`tRemediation Task started."
                $null = $runningPolicyRemediationTasks.Add($newPolicyRemediationTask)
                $created++
            }
        }
    }

    $maxNumberOfChecks = 30
    $waitPeriod = 60
    $checkForMinutes = [int]([math]::Ceiling($waitPeriod * $maxNumberOfChecks / 60))
    Write-Information ""
    if ($runningPolicyRemediationTasks.Count -gt 0) {
        if ($NoWait) {
            $maxNumberOfChecks = 1
            $waitPeriod = 120
            $checkForMinutes = [int]([math]::Ceiling($waitPeriod * $maxNumberOfChecks / 60))
            Write-Information "==================================================================================================="
            Write-Information "NoWait: waiting $checkForMinutes minutes for remediation tasks to complete or fail..."
            Write-Information "==================================================================================================="
        }
        else {
            Write-Information "==================================================================================================="
            Write-Information "Waiting for remediation tasks to complete or fail, checking every minute for $checkForMinutes minutes..."
            Write-Information "==================================================================================================="
        }
        $numberOfChecks = 0
        $canceled = 0
        while ($runningPolicyRemediationTasks.Count -ge 1 -and $numberOfChecks -lt $maxNumberOfChecks) {
            $numberOfChecks++
            Start-Sleep -Seconds $waitPeriod
            Write-Information "`nChecking $($runningPolicyRemediationTasks.Count) remediation tasks' provisioning state..."
            $count = $runningPolicyRemediationTasks.Count
            $newRunningPolicyRemediationTasks = [System.Collections.ArrayList]::new()
            for ($i = 0; $i -lt $count; $i++) {
                $runningPolicyRemediationTask = $runningPolicyRemediationTasks[$i]
                $remediationTaskState = "Check for status failed"
                $taskDone = $false
                if ($TestRun) {
                    $remediationTaskState = "TEST RUN - Succeeded"
                    Write-Information "`TEST RUN: Remediation Task '$($runningPolicyRemediationTask.Name)' might have succeeded."
                    $taskDone = $true
                    $succeeded++
                }
                else {
                    Write-Verbose "`tChecking the provisioning state of the '$($runningPolicyRemediationTask.Name)' Remediation Task"
                    $remediationTaskResult = Get-AzPolicyRemediation -ResourceId $runningPolicyRemediationTask.Id -ErrorAction Continue
                    if ($null -ne $remediationTaskResult) {
                        $remediationTaskState = $remediationTaskResult.ProvisioningState
                    }
                    if ($remediationTaskState -eq 'Succeeded') {
                        Write-Information "`tRemediation Task '$($runningPolicyRemediationTask.Name)' succeeded."
                        $taskDone = $true
                        $succeeded++
                    }
                    elseif ($remediationTaskState -eq 'Failed') {
                        Write-Information "`tRemediation Task '$($runningPolicyRemediationTask.Name)' failed."
                        $failedPolicyRemediationTask = [ordered]@{
                            Name               = $runningPolicyRemediationTask.Name
                            Id                 = $runningPolicyRemediationTask.Id
                            PolicyAssignmentId = $runningPolicyRemediationTask.PolicyAssignmentId
                            ProvisioningState  = $runningPolicyRemediationTask.ProvisioningState
                        }
                        $failedPolicyRemediationTasks += $failedPolicyRemediationTask
                        $taskDone = $true
                        $failed++
                    }
                    elseif ($remediationTaskState -eq 'Canceled') {
                        Write-Information "`tRemediation Task '$($runningPolicyRemediationTask.Name)' was canceled."
                        $canceled++
                        $taskDone = $true
                    }
                    else {
                        Write-Information "`tRemediation Task '$($runningPolicyRemediationTask.Name)' provisioning state is '$($remediationTaskState)'."
                    }
                }
                if (-not $taskDone) {
                    $null = $newRunningPolicyRemediationTasks.Add($runningPolicyRemediationTask)
                }
            }
            $runningPolicyRemediationTasks = $newRunningPolicyRemediationTasks
        }
    }

    $createWorkItem = $false
    Write-Information ""
    if ($TestRun) {
        Write-Information "==================================================================================================="
        Write-Information "TEST RUN: Remediation Task Status (NO ACTION TAKEN)"
        Write-Information "==================================================================================================="
        Write-Information "TEST RUN: $needed needed"
        Write-Information "TEST RUN: $created created"
        Write-Information "TEST RUN: $succeeded succeeded"
    }
    else {
        Write-Information "==================================================================================================="
        Write-Information "Remediation Task Status"
        Write-Information "==================================================================================================="
        $stillRunning = $runningPolicyRemediationTasks.Count
        Write-Information "$needed needed"
        if ($failedToCreate -gt 0) {
            Write-Information "$failedToCreate failed to create"
        }
        Write-Information "$created created"
        Write-Information "$succeeded succeeded"
        if ($failed -gt 0) {
            Write-Information "$failed failed"
        }
        if ($canceled -gt 0) {
            Write-Information "$canceled canceled"
        }
        if ($stillRunning -gt 0) {
            Write-Information "$stillRunning still running after $checkForMinutes minutes"
        }
        if (-not $Interactive) {
            if (($failed -gt 0) -or ($failedToCreate -gt 0)) {
                $failedPolicyRemediationTasksJsonString = $failedPolicyRemediationTasks | ConvertTo-Json -Depth 10 -Compress
                Write-Output "##vso[task.setvariable variable=failedPolicyRemediationTasksJsonString;isOutput=true]$($failedPolicyRemediationTasksJsonString)"
                $createWorkItem = $true
            } 
              
            Write-Output "##vso[task.setvariable variable=createWorkItem;isOutput=true]$($createWorkItem)"
        }
    }
}
