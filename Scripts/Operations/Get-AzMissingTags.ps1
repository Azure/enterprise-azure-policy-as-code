#Requires -PSEdition Core

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/missing-tags-results.csv or './Outputs/Tags/missing-tags-results.csv'.")]
    [string] $OutputFileName,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $interactive = $true
)

. "$PSScriptRoot/../Helpers/Get-PacFolders.ps1"
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Select-PacEnvironment.ps1"
. "$PSScriptRoot/../Helpers/Set-AzCloudTenantSubscription.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -definitionsRootFolder $DefinitionsRootFolder -outputFolder $OutputFolder -interactive $interactive
Set-AzCloudTenantSubscription -cloud $pacEnvironment.cloud -tenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -interactive $pacEnvironment.interactive

$targetTenant = $pacEnvironment.targetTenant
if ($OutputFileName -eq "") {
    $OutputFileName = "$($pacEnvironment.outputFolder)/Tags/missing-tags-results.csv"
}

Write-Information "==================================================================================================="
Write-Information "Processing"
Write-Information "==================================================================================================="

$subscriptionList = Get-AzSubscription -TenantId $targetTenant
$subscriptionList | Format-Table | Out-Default

$results = @()
foreach ($subscription in $subscriptionList) {

    $resultsForSubscription = (Get-AzPolicyState -SubscriptionId $subscription.Id -errorvariable errorVariable 2>$null) | `
        Where-Object { $_.ComplianceState -eq "NonCompliant" -and $_.ResourceType -eq "Microsoft.Resources/subscriptions/resourceGroups" } | `
        Select-Object SubscriptionId, @{ Name = 'SubscriptionName'; Expression = { $subscription.Name } }, ResourceGroup, PolicyAssignmentName | `
        Select-Object SubscriptionName, ResourceGroup, PolicyAssignmentName

    $resultsForSubscription | Format-Table | Out-Default

    if ($results.LongLength -eq 0) {
        $results = $resultsForSubscription
    }
    else {
        $results += $resultsForSubscription
    }
}

if (-not (Test-Path $OutputFileName)) {
    New-Item $OutputFileName -Force
}
$results | Export-Csv $OutputFileName
