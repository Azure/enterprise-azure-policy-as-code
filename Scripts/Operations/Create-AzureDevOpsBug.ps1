<#
  .SYNOPSIS
  This PowerShell script creates a Bug when there are one or multiple failed Remedation Tasks.

  .DESCRIPTION
  The Create-AzureDevOpsBug.ps1 PowerShell script creates a Bug on the current Iteration of a team when one or
  multiple Remediation Tasks failed. The Bug is formatted as an HTML table and contains information on the name
  and Url properties. As a result, the team can easily locate and resolve the Remediation Tasks that failed.

  .PARAMETER FailedPolicyRemediationTasksJsonString
  Specifies the JSON string that contains the objects of one or multiple failed Remediation Tasks.

  .PARAMETER ModuleName
  Specifies the name of the PowerShell module installed at the beginning of the PowerShell script. By default, this is the VSTeam PowerShell Module.

  .PARAMETER OrganizationName
  Specifies the name of the Azure DevOps Organization.

  .PARAMETER ProjectName
  Specifies the name of the Azure DevOps Project.

  .PARAMETER PersonalAccessToken
  Specifies the Personal Access Token that is used for authentication purposes. Make sure that you use the AzureKeyVault@2 task (link below) for this purpose.

  .PARAMETER TeamName
  Specifies the name of the Azure DevOps team.

  .EXAMPLE
  Create-AzureDevOpsBug.ps1 `
    -FailedPolicyRemediationTasksJsonString '<JSON string>'`
    -ModuleName 'VSTeam' `
    -OrganizationName 'bavanben' `
    -ProjectName 'Contoso' `
    -PersonalAccessToken '<secret string>' `
    -TeamName 'Contoso Team'

  .INPUTS
  None.

  .OUTPUTS
  The Start-PolicyAssignmentRemediation.ps1 PowerShell script outputs multiple string values for logging purposes.

  .LINK
  https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/azure-key-vault-v2?view=azure-pipelines
#>

[CmdLetBinding()]
Param (
  [Parameter (Mandatory = $true)]
  [string] $FailedPolicyRemediationTasksJsonString,

  [Parameter (Mandatory = $true)]
  [string] $ModuleName = 'VSTeam',

  [Parameter (Mandatory = $true)]
  [string] $OrganizationName,

  [Parameter (Mandatory = $true)]
  [string] $ProjectName,

  [Parameter (Mandatory = $true)]
  [string] $PersonalAccessToken,

  [Parameter (Mandatory = $true)]
  [string] $TeamName
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

#region Install and import the PowerShell module
Write-Output "`nInstall and import the '$($ModuleName)' PowerShell module"
if (Get-Module | Where-Object { $_.Name -eq $ModuleName }) {
  Write-Output "`The '$($ModuleName)' PowerShell module is already installed and imported"
}
else {
  if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $ModuleName }) {
    Write-Output "`The '$($ModuleName)' PowerShell module is not yet imported"
    try {
      Import-Module $ModuleName -Force
      Write-Output "The '$($ModuleName)' PowerShell module has been imported succesfully"
    }
    catch {
      Write-Error $_
    }
  }
  else {
    Write-Output "`The '$($ModuleName)' PowerShell module is not yet installed and imported"
    try {
      Install-Module -Name $ModuleName -Force
      Import-Module $ModuleName -Force
      Write-Output "The '$($ModuleName)' PowerShell module has been installed and imported succesfully"
    }
    catch {
      Write-Error $_
    }
  }
}
#endregion

#region Authenticate to the Azure DevOps Organization and Project"
Write-Output "`nAuthenticate to the '$($ProjectName)' Project located in the '$($OrganizationName)' Organization"
try {
  Set-VSTeamAccount -Account $OrganizationName -PersonalAccessToken $PersonalAccessToken
  Set-VSTeamDefaultProject -Project $ProjectName
  Write-Output "Succesfully authenticated to the '$($ProjectName)' Project located in the '$($OrganizationName)' Organization"
}
catch {
  Write-Error $_
}
#endregion

#region Retrieve the Iteration Paths of the team
Write-Output "`nRetrieve the Iterations Paths of the '$($TeamName)' team"
try {
  $authenticationToken = [System.Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))
  $headers = @{
    "Authorization" = [String]::Format("Basic {0}", $authenticationToken)
    "Content-Type"  = "application/json"
  }
  $uri = "https://dev.azure.com/{0}/{1}/{2}/_apis/work/teamsettings/iterations?api-version=5.1" -f $OrganizationName, $ProjectName, $TeamName
  $iterationPaths = (Invoke-RestMethod -Method Get -Headers $headers -Uri $uri).value
  Write-Output "Succesfully retrieved the Iterations Paths of the '$($TeamName)' team"
}
catch {
  Write-Error $_
}
#endregion

#region Create the HTML table that will be included in the Bug
Write-Output "`nCreate the HTML table that will be included in the Bug"
$failedPolicyRemediationTasks = ConvertFrom-Json -InputObject $FailedPolicyRemediationTasksJsonString

Write-Verbose "For each failed Remediation Task object, add the 'Remediation Task Url' property"
foreach ($failedPolicyRemediationTask in $failedPolicyRemediationTasks) {
  $staticUrlComponent = "https://portal.azure.com/#view/Microsoft_Azure_Policy/ManageRemediationTaskBlade/assignmentId/"
  $variableUrlComponent = "$($failedPolicyRemediationTask.'Policy Assignment Id'.Replace("/","%2F"))/remediationTaskId/$($failedPolicyRemediationTask.'Remediation Task Id'.Replace("/","%2F"))"
  Add-Member -InputObject $failedPolicyRemediationTask -NotePropertyName 'Remediation Task Url' -NotePropertyValue "$($staticUrlComponent)$($variableUrlComponent)"
}

Write-Verbose "Build the header, pre-content and post-content of the HTML table"
$header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {text-align: left; border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {text-align: left; border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@
$postContent = "<H4><i>Table 1: Failed Remediation Tasks</i></H4>"

Write-Verbose "Build the HTML table"
$htmlParams = @{
  'Property'    = 'Remediation Task Name', 'Remediation Task Url', 'Provisioning State'
  'PostContent' = $postContent
  'Head'        = $header
}
$htmlTable = $failedPolicyRemediationTasks | ConvertTo-Html @htmlParams

Write-Verbose "Add the HTML table to the Repro Steps of the Bug"
$ReproSteps = @"
$htmlTable
"@
Write-Output "Succesfully created the HTML table that will be included in the Bug"
#endregion

#region Create a Bug on the current Iteration of the team
Write-Verbose "Set the variables that are used during the creation of the Bug"
$title = ('Failed Remediation Tasks - {0}' -f $(Get-Date -Format 'yyyyMMdd'))
$description = 'As you can see in Table 1, one or more Remediation Tasks failed. Please investigate these in more detail.'
$additionalFields = @{'Microsoft.VSTS.TCM.ReproSteps' = $ReproSteps }
$currentIterationPath = $iterationPaths | Where-Object -FilterScript { $_.attributes.timeFrame -eq 'current' }

Write-Output "`nCreate a Bug on the '$($currentIterationPath.name)' Iteration of the '$($TeamName)' team"
try {
  $workItemParams = @{
    'Title'            = $title
    'Description'      = $description
    'WorkItemType'     = 'Bug'
    'AdditionalFields' = $additionalFields
    'IterationPath'    = $currentIterationPath.path
  }
  Add-VSTeamWorkItem @workItemParams | Out-Null
  Write-Output "Succesfully created a Bug on the '$($currentIterationPath.name)' Iteration of the '$($TeamName)' team"
}
catch {
  Write-Error $_
}
#endregion