function Get-PolicyResourceDetails {
    [CmdletBinding()]
    param (
        [string] $PacEnvironmentSelector,
        [hashtable] $PacEnvironment,
        [hashtable] $CachedPolicyResourceDetails
    )

    $PolicyResourceDetails = $null
    if ($CachedPolicyResourceDetails.ContainsKey($PacEnvironmentSelector)) {
        $PolicyResourceDetails = $CachedPolicyResourceDetails.$PacEnvironmentSelector
    }
    else {
        # New root scope found
        $ScopeTable = Get-AzScopeTree -PacEnvironment $PacEnvironment
        $deployed = Get-AzPolicyResources `
            -PacEnvironment $PacEnvironment `
            -ScopeTable $ScopeTable `
            -SkipRoleAssignments `
            -SkipExemptions

        $PolicyResourceDetails = Convert-PolicySetsToDetails -AllPolicyDefinitions $deployed.policydefinitions.all -AllPolicySetDefinitions $deployed.policysetdefinitions.all
        $null = $PolicyResourceDetails.policyAssignments = $deployed.policyassignments.managed
        $null = $CachedPolicyResourceDetails.Add($PacEnvironmentSelector, $PolicyResourceDetails)
    }

    return $PolicyResourceDetails
}
