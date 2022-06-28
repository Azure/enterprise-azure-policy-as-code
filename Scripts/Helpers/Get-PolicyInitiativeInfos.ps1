#Requires -PSEdition Core

function Get-PolicyInitiativeInfos {
    [CmdletBinding()]
    param (
        [string] $pacEnvironmentSelector,
        [hashtable] $pacEnvironment,
        [hashtable] $cachedPolicyInitiativeInfos
    )

    $policyInitiativeInfo = $null
    if ($cachedPolicyInitiativeInfos.ContainsKey($pacEnvironmentSelector)) {
        $policyInitiativeInfo = $cachedPolicyInitiativeInfos.$pacEnvironmentSelector
    }
    else {
        # New root scope found

        $rootScopeId = $pacEnvironment.rootScopeId
        $rootScope = $pacEnvironment.rootScope

        $allAzPolicyInitiativeDefinitions = Get-AzPolicyInitiativeDefinitions -rootScope $rootScope -rootScopeId $rootScopeId -byId
        $policyInitiativeInfo = Convert-PolicyInitiativeDefinitionsToInfo -allAzPolicyInitiativeDefinitions $allAzPolicyInitiativeDefinitions
        $null = $cachedPolicyInitiativeInfos.Add($pacEnvironmentSelector, $policyInitiativeInfo)
    }

    return $policyInitiativeInfo
}