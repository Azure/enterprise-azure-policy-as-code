#Requires -PSEdition Core

[CmdletBinding()]
param(
    [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector = "dev",
    [Parameter(Mandatory = $false, ValueFromPipeline = $true)] [string] $OutputFileName = ".\missing-tags-results.csv",
    [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable PacDefinitionsRootFolder or './Definitions'.")] [string]$DefinitionsRootFolder
)

. "$PSScriptRoot/../Helpers/Initialize-Environment.ps1"

$InformationPreference = "Continue"
$environment = Initialize-Environment $PacEnvironmentSelector -DefinitionsRootFolder $DefinitionsRootFolder
$targetTenant = $environment.targetTenant

# Connect to Azure Tenant
Connect-AzAccount -Tenant $targetTenant

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
