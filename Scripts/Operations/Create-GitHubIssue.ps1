<#
  .SYNOPSIS
  This PowerShell script creates an Issue when there are one or multiple failed Remedation Tasks.

  .DESCRIPTION
  The Create-GitHubIssue.ps1 PowerShell script creates an Issue in a GitHub Repository that is located under
  a GitHub Organization when one or multiple Remediation Tasks failed. The Bug is formatted as an HTML table
  and contains information on the name and Url properties. As a result, the team can easily locate and resolve
  the Remediation Tasks that failed.

  .PARAMETER FailedPolicyRemediationTasksJsonString
  Specifies the JSON string that contains the objects of one or multiple failed Remediation Tasks.

  .PARAMETER OrganizationName
  Specifies the name of the GitHub Organization.

  .PARAMETER RepositoryName
  Specifies the name of the GitHub Repository.

  .PARAMETER PersonalAccessToken
  Specifies the Personal Access Token that is used for authentication purposes.

  .EXAMPLE
  Create-GitHubIssue.ps1 `
    -FailedPolicyRemediationTasksJsonString '<JSON string>'`
    -OrganizationName 'basvanbennekommsft' `
    -RepositoryName 'Blog-Posts' `
    -PersonalAccessToken '<secret string>' `

  .INPUTS
  None.

  .OUTPUTS
  The Create-GitHubIssue.ps1 PowerShell script outputs multiple string values for logging purposes.
#>

[CmdLetBinding()]
Param (
    [Parameter (Mandatory = $true)]
    [String] $FailedPolicyRemediationTasksJsonString,

    [Parameter (Mandatory = $true)]
    [String] $OrganizationName,

    [Parameter (Mandatory = $true)]
    [String] $RepositoryName,

    [Parameter (Mandatory = $true)]
    [String] $PersonalAccessToken
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

#region Create the HTML table that will be included in the Issue
Write-Output "`nCreate the HTML table that will be included in the Issue"
$failedPolicyRemediationTasks = ConvertFrom-Json -InputObject $FailedPolicyRemediationTasksJsonString

Write-Verbose "For each failed Remediation Task object, add the 'Remediation Task Url' property"
foreach ($failedPolicyRemediationTask in $failedPolicyRemediationTasks) {
    $staticUrlComponent = "https://portal.azure.com/#view/Microsoft_Azure_Policy/ManageRemediationTaskBlade/assignmentId/"
    $variableUrlComponent = "$($failedPolicyRemediationTask.'Policy Assignment Id'.Replace("/","%2F"))/remediationTaskId/$($failedPolicyRemediationTask.'Remediation Task Id'.Replace("/","%2F"))"
    Add-Member -InputObject $failedPolicyRemediationTask -NotePropertyName 'Remediation Task Url' -NotePropertyValue "$($staticUrlComponent)$($variableUrlComponent)"
}

Write-Verbose "Build the content and post-content of the HTML table"
$preContent = "The Remediation Tasks in <i>Table 1</i> have failed. Please investigate and resolve the reason for failure as soon as possible."
$postContent = "<i>Table 1: Failed Remediation Tasks</i>"
$htmlParams = @{
    'Property'    = 'Remediation Task Name', 'Remediation Task Url', 'Provisioning State'
    'PostContent' = $postContent
    'PreContent'  = $preContent
}
$htmlTable = $failedPolicyRemediationTasks | ConvertTo-Html @htmlParams -Fragment
$htmlBody = @"
$htmlTable
"@
Write-Output "Succesfully created the HTML table that will be included in the Issue"
#endregion

#region Create the Issue in Github
Write-Verbose "Set the variables that are used during the creation of the Issue"
$title = ('Failed Remediation Tasks - {0}' -f $(Get-Date -Format 'yyyyMMdd'))
$labels = @("Operations")

Write-Output "`nCreate the Issue in the '$($RepositoryName)' GitHub Repository that is located under the '$($OrganizationName)' GitHub Organization"
try {
    $uri = "https://api.github.com/repos/{0}/{1}/issues" -f $OrganizationName, $RepositoryName
    $authenticationToken = [System.Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))
    $headers = @{
        "Authorization" = [String]::Format("Basic {0}", $authenticationToken)
        "Content-Type"  = "application/json"
    }
    $body = @{
        title  = $title
        body   = $htmlBody
        labels = $labels
    } | ConvertTo-Json

    Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body | Out-Null
    Write-Output "Succesfully created the Issue in the '$($RepositoryName)' GitHub Repository that is located under the '$($OrganizationName)' GitHub Organization"
}
catch {
    Write-Error $_
}
#endregion