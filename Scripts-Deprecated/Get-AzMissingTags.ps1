<#
.SYNOPSIS
    Gets all resources that are missing tags in the current subscription.

.PARAMETER PacEnvironmentSelector
    Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.

.PARAMETER DefinitionsRootFolder
    Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.

.PARAMETER OutputFileName
    Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/missing-tags-results.csv or './Outputs/Tags/missing-tags-results.csv'.

.PARAMETER Interactive
    Set to false if used non-interactive

.EXAMPLE
    .\Get-AzMissingTags.ps1 -PacEnvironmentSelector "dev" -DefinitionsRootFolder "C:\Src\Definitions" -OutputFolder "C:\Src\Outputs" -Interactive $true
    Gets all resources that are missing tags in the current subscription.

.EXAMPLE
    .\Get-AzMissingTags.ps1 -Interactive $true
    Gets all resources that are missing tags in the current subscription. The script prompts for the PAC environment and uses the default definitions and output folders.
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, HelpMessage = "Defines which Policy as Code (PAC) environment we are using, if omitted, the script prompts for a value. The values are read from `$DefinitionsRootFolder/global-settings.jsonc.", Position = 0)]
    [string] $PacEnvironmentSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Output file name. Defaults to environment variable `$env:PAC_OUTPUT_FOLDER/Tags/missing-tags-results.csv or './Outputs/Tags/missing-tags-results.csv'.")]
    [string] $OutputFileName,

    [Parameter(Mandatory = $false, HelpMessage = "Set to false if used non-interactive")]
    [bool] $Interactive = $true
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

$InformationPreference = "Continue"
$pacEnvironment = Select-PacEnvironment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -Interactive $Interactive
$null = Set-AzCloudTenantSubscription -Cloud $pacEnvironment.cloud -TenantId $pacEnvironment.tenantId -subscriptionId $pacEnvironment.defaultSubscriptionId -Interactive $pacEnvironment.interactive

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
