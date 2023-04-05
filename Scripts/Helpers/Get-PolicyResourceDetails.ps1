function Get-PolicyResourceDetails {
    [CmdletBinding()]
    param (
        [string] $pacEnvironmentSelector,
        [hashtable] $pacEnvironment,
        [hashtable] $cachedPolicyResourceDetails
    )

    $policyResourceDetails = $null
    if ($cachedPolicyResourceDetails.ContainsKey($pacEnvironmentSelector)) {
        $policyResourceDetails = $cachedPolicyResourceDetails.$pacEnvironmentSelector
    }
    else {
        # New root scope found
        $scopeTable = Get-AzScopeTree -pacEnvironment $pacEnvironment
        $deployed = Get-AzPolicyResources `
            -pacEnvironment $pacEnvironment `
            -scopeTable $scopeTable `
            -skipRoleAssignments `
            -skipExemptions

        $policyResourceDetails = Convert-PolicySetsToDetails -allPolicyDefinitions $deployed.policydefinitions.all -allPolicySetDefinitions $deployed.policysetdefinitions.all
        $null = $policyResourceDetails.policyAssignments = $deployed.policyassignments.managed
        $null = $cachedPolicyResourceDetails.Add($pacEnvironmentSelector, $policyResourceDetails)
    }

    return $policyResourceDetails
}