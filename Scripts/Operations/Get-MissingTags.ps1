
[CmdletBinding()]
param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] 
        [string] $TargetTenant,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)] 
        [string] $OutputFileName = ".\missing-tags-results.csv"
)

# Connect to Azure Tenant
Connect-AzAccount -Tenant $TargetTenant

$subscriptionList = Get-AzSubscription -TenantId $TargetTenant
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
$results | Export-Csv $OutputFileName 
