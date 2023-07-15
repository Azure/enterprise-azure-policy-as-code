function Get-PolicyResourceDetails {
    [CmdletBinding()]
    param (
        [string] $PacEnvironmentSelector,
        [hashtable] $PacEnvironment,
        [hashtable] $CachedPolicyResourceDetails
    )

    $policyResourceDetails = $null
    if ($CachedPolicyResourceDetails.ContainsKey($PacEnvironmentSelector)) {
        $policyResourceDetails = $CachedPolicyResourceDetails.$PacEnvironmentSelector
    }
    else {
        # New root scope found
        $scopeTable = Get-AzScopeTree -PacEnvironment $PacEnvironment
        $deployed = Get-AzPolicyResources `
            -PacEnvironment $PacEnvironment `
            -ScopeTable $scopeTable `
            -SkipRoleAssignments `
            -SkipExemptions

        $policyResourceDetails = Convert-PolicySetsToDetails -AllPolicyDefinitions $deployed.policydefinitions.all -AllPolicySetDefinitions $deployed.policysetdefinitions.all
        $null = $policyResourceDetails.policyAssignments = $deployed.policyassignments.managed
        $null = $CachedPolicyResourceDetails.Add($PacEnvironmentSelector, $policyResourceDetails)
    }

    return $policyResourceDetails
}
