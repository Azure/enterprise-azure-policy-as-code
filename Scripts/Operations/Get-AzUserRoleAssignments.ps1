#Requires -PSEdition Core

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Users/RoleAssignments.csv or './Outputs/Users/RoleAssignments.csv'.")]
    [string] $OutputFileName,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true
)

. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"

$InformationPreference = "Continue"
Invoke-AzCli config set extension.use_dynamic_install=yes_without_prompt -SuppressOutput
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -interactive $pacEnvironment.interactive

$targetTenant = $environment.targetTenant
if ($OutputFileName -eq "") {
    $OutputFileName = "$($environment.outputFolder)/Users/RoleAssignments.csv"
}

Write-Information "==================================================================================================="
Write-Information "Processing"
Write-Information "==================================================================================================="

$subs = Get-AzSubscription -TenantId $targetTenant | Where-Object { $_.state -EQ "Enabled" }

$assignments = @()

foreach ($sub in $subs) {

    Set-AzContext -Subscription $sub.name

    Write-Output $sub.Name

    $assignments += Get-AzRoleAssignment | Where-Object { $_.ObjectType -eq "User" -and $_.Scope -notlike "*managementGroups*" } | Select-Object displayname, signinname, RoleDefinitionName, scope, @{
        Name       = 'Subscription'
        Expression = { $sub.Name }
    }

}

if ($OutputFileName) {
    if (-not (Test-Path $OutputFileName)) {
        New-Item $OutputFileName -Force
    }
    Export-Csv -Path $OutputFileName -NoTypeInformation
}
else {
    $assignments
}