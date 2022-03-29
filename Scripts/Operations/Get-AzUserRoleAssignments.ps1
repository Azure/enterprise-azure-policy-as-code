#Requires -PSEdition Core

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector,
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)] [string] $OutputFileName = ".\missing-tags-results.csv",
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable PacDefinitionsRootFolder or './Definitions'.")] [string]$DefinitionsRootFolder
)

. "$PSScriptRoot/../Helpers/Initialize-Environment.ps1"

$InformationPreference = "Continue"
$environment = Initialize-Environment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder
$targetTenant = $environment.targetTenant

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