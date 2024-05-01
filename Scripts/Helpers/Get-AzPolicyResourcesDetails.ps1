function Get-AzPolicyResourcesDetails {
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
        $scopeTable = Build-ScopeTableForDeploymentRootScope -PacEnvironment $PacEnvironment
        # $NoParallelProcessing = $true
        $deployed = Get-AzPolicyResources `
            -PacEnvironment $PacEnvironment `
            -ScopeTable $scopeTable `
            -SkipRoleAssignments `
            -SkipExemptions

        $policyResourceDetails = Convert-PolicyResourcesToDetails `
            -AllPolicyDefinitions $deployed.policydefinitions.all `
            -AllPolicySetDefinitions $deployed.policysetdefinitions.all
        $null = $policyResourceDetails.policyAssignments = $deployed.policyassignments.managed
        $null = $CachedPolicyResourceDetails.Add($PacEnvironmentSelector, $policyResourceDetails)
    }

    return $policyResourceDetails
}
