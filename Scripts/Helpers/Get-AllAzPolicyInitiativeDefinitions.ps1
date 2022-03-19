#Requires -PSEdition Core

function Get-AllAzPolicyInitiativeDefinitions {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)] [string] $rootScopeId,
        [switch] $byId
    )

    Write-Information "==================================================================================================="
    Write-Information "Fetching existing Policy definitions from scope ""$rootScopeId"""
    Write-Information "==================================================================================================="

    $policyList = Invoke-AzCli policy definition list
    $existingCustomPolicyDefinitions = @{}
    $builtInPolicyDefinitions = @{}
    $null = $policyList | `
        Where-Object { $_.policyType -eq "Custom" -and $_.id -like "$rootScopeId*" } | `
        ForEach-Object { $existingCustomPolicyDefinitions.Add(($byId.IsPresent) ? $_.id : $_.name, $_) }
    $null = $policyList | `
        Where-Object { $_.policyType -eq "BuiltIn" } | `
        ForEach-Object { $builtInPolicyDefinitions.Add(($byId.IsPresent) ? $_.id : $_.name, $_) }

    Write-Information "Custom: $($existingCustomPolicyDefinitions.Count)"
    Write-Information "Built-In: $($builtInPolicyDefinitions.Count)"
    Write-Information ""
    Write-Information ""

    Write-Information "==================================================================================================="
    Write-Information "Fetching existing Initiative definitions from scope ""$rootScopeId"""
    Write-Information "==================================================================================================="

    $initiativeList = Invoke-AzCli policy set-definition list
    $existingCustomInitiativeDefinitions = @{}
    $builtInInitiativeDefinitions = @{}
    $null = $initiativeList | `
        Where-Object { $_.policyType -eq "Custom" -and $_.id -like "$rootScopeId*" } | `
        ForEach-Object { $existingCustomInitiativeDefinitions.Add(($byId.IsPresent) ? $_.id : $_.name, $_) }
    $null = $initiativeList | `
        Where-Object { $_.policyType -eq "BuiltIn" } | `
        ForEach-Object { $builtInInitiativeDefinitions.Add(($byId.IsPresent) ? $_.id : $_.name, $_) }

    Write-Information "Custom: $($existingCustomInitiativeDefinitions.Count)"
    Write-Information "Built-In: $($builtInInitiativeDefinitions.Count)"
    Write-Information ""
    Write-Information ""

    $collections = @{
        existingCustomPolicyDefinitions     = $existingCustomPolicyDefinitions
        builtInPolicyDefinitions            = $builtInPolicyDefinitions
        existingCustomInitiativeDefinitions = $existingCustomInitiativeDefinitions
        builtInInitiativeDefinitions        = $builtInInitiativeDefinitions
    }
    $collections
}
