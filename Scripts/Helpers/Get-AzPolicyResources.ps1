function Get-AzPolicyResources {
    [CmdletBinding()]
    param (
        [hashtable] $PacEnvironment,
        [hashtable] $ScopeTable,

        [switch] $SkipRoleAssignments,
        [switch] $SkipExemptions,
        [switch] $CollectAllPolicies
    )

    $deploymentRootScope = $PacEnvironment.deploymentRootScope
    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Get Policy Resources for EPAC environment '$($PacEnvironment.pacSelector)' at root scope $($deploymentRootScope -replace '/providers/Microsoft.Management','')"
    Write-Information "==================================================================================================="

    $skipExemptionsLocal = $SkipExemptions.IsPresent
    $skipRoleAssignmentsLocal = $SkipRoleAssignments.IsPresent
    $collectAllPoliciesLocal = $CollectAllPolicies.IsPresent

    $deployedPolicyResources = @{
        policydefinitions            = @{
            all      = @{}
            readOnly = @{}
            managed  = @{}
            counters = @{
                builtIn         = 0
                inherited       = 0
                managedBy       = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
                excluded        = 0
                unmanagedScopes = 0
            }
        }
        policysetdefinitions         = @{
            all      = @{}
            readOnly = @{}
            managed  = @{}
            counters = @{
                builtIn         = 0
                inherited       = 0
                managedBy       = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
                excluded        = 0
                unmanagedScopes = 0
            }
        }
        policyassignments            = @{
            managed  = @{}
            counters = @{
                managedBy       = @{
                    thisPaC             = 0
                    otherPaC            = 0
                    dfcSecurityPolicies = 0
                    dfcDefenderPlans    = 0
                    unknown             = 0
                }
                excluded        = 0
                unmanagedScopes = 0
                withIdentity    = 0
            }
        }
        policyexemptions             = @{
            managed  = @{}
            counters = @{
                managedBy       = @{
                    thisPaC  = 0
                    otherPaC = 0
                    unknown  = 0
                }
                orphaned        = 0
                expired         = 0
                excluded        = 0
                unmanagedScopes = 0
            }
        }
        roleAssignmentsByPrincipalId = @{}
        numberOfRoleAssignments      = 0
        numberOfPrincipleIds         = 0
        remoteAssignmentsCount       = 0
        roleDefinitions              = @{}
        roleAssignmentsNotRetrieved  = $false
        excludedScopes               = $excludedScopes
    }

    $collectionList = [System.Collections.ArrayList]::new()
    if ($skipExemptionsLocal) {
        $collectionList.AddRange(@( `
                    "policyDefinitions", `
                    "policySetDefinitions", `
                    "policyAssignments"))
    }
    else {
        $collectionList.AddRange(@( `
                    "policyDefinitions", `
                    "policySetDefinitions", `
                    "policyAssignments", `
                    "policyExemptions"))
    }

    foreach ($collectionItem in $collectionList) {
        switch ($collectionItem) {
            policyDefinitions {
                Get-AzPolicyOrSetDefinitions `
                    -DefinitionType "policyDefinitions" `
                    -PolicyResourcesTable $deployedPolicyResources.policydefinitions `
                    -PacEnvironment $PacEnvironment `
                    -ScopeTable $ScopeTable `
                    -CollectAllPolicies $collectAllPoliciesLocal
                break
            }
            policySetDefinitions {
                Get-AzPolicyOrSetDefinitions `
                    -DefinitionType "policySetDefinitions" `
                    -PolicyResourcesTable $deployedPolicyResources.policysetdefinitions `
                    -PacEnvironment $PacEnvironment `
                    -ScopeTable $ScopeTable `
                    -CollectAllPolicies $collectAllPoliciesLocal
                break
            }
            policyAssignments {
                Get-AzPolicyAssignments `
                    -DeployedPolicyResources $deployedPolicyResources `
                    -PacEnvironment $PacEnvironment `
                    -ScopeTable $ScopeTable `
                    -SkipRoleAssignments $skipRoleAssignmentsLocal
                break
            }
            policyExemptions {
                Get-AzPolicyExemptions `
                    -DeployedPolicyResources $deployedPolicyResources `
                    -PacEnvironment $PacEnvironment `
                    -ScopeTable $ScopeTable
                break
            }
        }
    }

    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Policy Resources found for EPAC environment '$($PacEnvironment.pacSelector)' at root scope $($deploymentRootScope -replace '/providers/Microsoft.Management', '')"
    Write-Information "==================================================================================================="

    foreach ($kind in @("policydefinitions", "policysetdefinitions")) {
        $deployedPolicyTable = $deployedPolicyResources.$kind
        $counters = $deployedPolicyTable.counters
        $managedBy = $counters.managedBy
        $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown
        Write-Information ""
        if ($kind -eq "policydefinitions") {
            Write-Information "Policy counts:"
        }
        else {
            Write-Information "Policy Set counts:"
        }
        Write-Information "    BuiltIn        = $($counters.builtIn)"
        Write-Information "    Managed ($($managedByAny)) by:"
        Write-Information "        This PaC   = $($managedBy.thisPaC)"
        Write-Information "        Other PaC  = $($managedBy.otherPaC)"
        Write-Information "        Unknown    = $($managedBy.unknown)"
        Write-Information "    Inherited      = $($counters.inherited)"
        Write-Information "    Excluded       = $($counters.excluded)"
        Write-Verbose "    Not our scopes = $($counters.unmanagedScopes)"
    }

    $counters = $deployedPolicyResources.policyassignments.counters
    $managedBy = $counters.managedBy
    $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown + $managedBy.dfcSecurityPolicies + $managedBy.dfcDefenderPlans
    Write-Information ""
    Write-Information "Policy Assignment counts:"
    Write-Information "    Managed ($($managedByAny)) by:"
    Write-Information "        This PaC              = $($managedBy.thisPaC)"
    Write-Information "        Other PaC             = $($managedBy.otherPaC)"
    Write-Information "        Unknown               = $($managedBy.unknown)"
    Write-Information "        DfC Security Policies = $($managedBy.dfcSecurityPolicies)"
    Write-Information "        DfC Defender Plans    = $($managedBy.dfcDefenderPlans)"
    Write-Information "    With identity             = $($counters.withIdentity)"
    Write-Information "    Excluded                  = $($counters.excluded)"
    Write-Verbose "    Not our scopes = $($counters.unmanagedScopes)"

    if (!$skipExemptionsLocal) {
        $counters = $deployedPolicyResources.policyexemptions.counters
        $managedBy = $counters.managedBy
        $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown
        Write-Information ""
        Write-Information "Policy Exemptions:"
        Write-Information "    Managed ($($managedByAny)) by:"
        Write-Information "        This PaC  = $($managedBy.thisPaC)"
        Write-Information "        Other PaC = $($managedBy.otherPaC)"
        Write-Information "        Unknown   = $($managedBy.unknown)"
        Write-Information "    Expired       = $($counters.expired)"
        Write-Information "    Excluded      = $($counters.excluded)"
    }

    if (!$SkipRoleAssignments) {
        $managedRoleAssignmentsByPrincipalId = $deployedPolicyResources.roleAssignmentsByPrincipalId
        Write-Information ""
        $numberPrincipalIds = $deployedPolicyResources.numberOfPrincipleIds
        $numberPrincipalIdsWithRoleAssignments = $managedRoleAssignmentsByPrincipalId.Count
        if ($numberPrincipalIds -ne $numberPrincipalIdsWithRoleAssignments) {
            Write-Warning "Role assignment not retrieved for every principal Id ($($numberPrincipalIds) in assignments, $($numberPrincipalIdsWithRoleAssignments) retrieved).`n    This is likely due to a missing permission for the SPN running the pipeline. Please read the pipeline documentation in EPAC.`n    In rare cases, this can happen when a previous role assignment failed." -WarningAction Continue
            $deployedPolicyResources.roleAssignmentsNotRetrieved = $numberPrincipalIdsWithRoleAssignments -eq 0
        }
        Write-Information "Role Assignments:"
        Write-Information "    Principal Ids         = $($numberPrincipalIds)"
        Write-Information "    With Role Assignments = $($numberPrincipalIdsWithRoleAssignments)"
        Write-Information "    Role Assignments      = $($deployedPolicyResources.numberOfRoleAssignments)"
        if ($PacEnvironment.managingTenantId) {
            Write-Information "    Remote Role Assignments = $($deployedPolicyResources.remoteAssignmentsCount)"
        }
    }
    Write-Information ""

    return $deployedPolicyResources
}
