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
    
    Write-ModernSection -Title "Retrieving Policy Resources" -Color Blue
    Write-ModernStatus -Message "Environment: $($PacEnvironment.pacSelector)" -Status "info" -Indent 2
    Write-ModernStatus -Message "Root scope: $($deploymentRootScope -replace '/providers/Microsoft.Management','')" -Status "info" -Indent 2

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

    Write-ModernSection -Title "Policy Resource Summary" -Color Blue

    foreach ($kind in @("policydefinitions", "policysetdefinitions")) {
        $deployedPolicyTable = $deployedPolicyResources.$kind
        $counters = $deployedPolicyTable.counters
        $managedBy = $counters.managedBy
        $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown

        if ($kind -eq "policydefinitions") {
            Write-ModernStatus -Message "Policy Definitions:" -Status default -Indent 0
        }
        else {
            Write-ModernStatus -Message "`nPolicy Set Definitions:" -Status default -Indent 2
        }
        Write-ModernStatus -Message "Built-in: $($counters.builtIn)" -Status "info" -Indent 3
        Write-ModernStatus -Message "Managed ($($managedByAny)):" -Status "info" -Indent 3
        Write-ModernStatus -Message "This PaC: $($managedBy.thisPaC)" -Status "success" -Indent 6
        Write-ModernStatus -Message "Other PaC: $($managedBy.otherPaC)" -Status "warning" -Indent 6
        Write-ModernStatus -Message "Unknown: $($managedBy.unknown)" -Status "warning" -Indent 6
        Write-ModernStatus -Message "Inherited: $($counters.inherited)" -Status "info" -Indent 3
        Write-ModernStatus -Message "Excluded: $($counters.excluded)" -Status "skip" -Indent 3
    }

    $counters = $deployedPolicyResources.policyassignments.counters
    $managedBy = $counters.managedBy
    $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown + $managedBy.dfcSecurityPolicies + $managedBy.dfcDefenderPlans
    Write-ModernStatus -Message "`nPolicy Assignments:" -Status default -Indent 2
    Write-ModernStatus -Message "Managed ($($managedByAny)):" -Status "info" -Indent 3
    Write-ModernStatus -Message "This PaC: $($managedBy.thisPaC)" -Status "success" -Indent 6
    Write-ModernStatus -Message "Other PaC: $($managedBy.otherPaC)" -Status "warning" -Indent 6
    Write-ModernStatus -Message "Unknown: $($managedBy.unknown)" -Status "warning" -Indent 6
    Write-ModernStatus -Message "DfC Security Policies: $($managedBy.dfcSecurityPolicies)" -Status "info" -Indent 6
    Write-ModernStatus -Message "DfC Defender Plans: $($managedBy.dfcDefenderPlans)" -Status "info" -Indent 6
    Write-ModernStatus -Message "With identity: $($counters.withIdentity)" -Status "info" -Indent 3
    Write-ModernStatus -Message "Excluded: $($counters.excluded)" -Status "skip" -Indent 3

    if (!$skipExemptionsLocal) {
        $counters = $deployedPolicyResources.policyexemptions.counters
        $managedBy = $counters.managedBy
        $managedByAny = $managedBy.thisPaC + $managedBy.otherPaC + $managedBy.unknown
        Write-ModernStatus -Message "`nPolicy Exemptions:" -Status default -Indent 2
        Write-ModernStatus -Message "Managed ($($managedByAny)):" -Status "info" -Indent 3
        Write-ModernStatus -Message "This PaC: $($managedBy.thisPaC)" -Status "success" -Indent 6
        Write-ModernStatus -Message "Other PaC: $($managedBy.otherPaC)" -Status "warning" -Indent 6
        Write-ModernStatus -Message "Unknown: $($managedBy.unknown)" -Status "warning" -Indent 6
        Write-ModernStatus -Message "Expired: $($counters.expired)" -Status "error" -Indent 3
        Write-ModernStatus -Message "Excluded: $($counters.excluded)" -Status "skip" -Indent 3
    }

    if (!$SkipRoleAssignments) {
        $managedRoleAssignmentsByPrincipalId = $deployedPolicyResources.roleAssignmentsByPrincipalId
        $numberPrincipalIds = $deployedPolicyResources.numberOfPrincipleIds
        $numberPrincipalIdsWithRoleAssignments = $managedRoleAssignmentsByPrincipalId.Count
        if ($numberPrincipalIds -ne $numberPrincipalIdsWithRoleAssignments) {
            Write-ModernStatus -Message "Role assignment retrieval incomplete ($($numberPrincipalIds) in assignments, $($numberPrincipalIdsWithRoleAssignments) retrieved)" -Status "warning" -Indent 2
            Write-ModernStatus -Message "This is likely due to missing permissions for the SPN running the pipeline" -Status "warning" -Indent 3
            $deployedPolicyResources.roleAssignmentsNotRetrieved = $numberPrincipalIdsWithRoleAssignments -eq 0
        }
        Write-ModernStatus -Message "`nRole Assignments:"  -Status default  -Indent 2
        Write-ModernStatus -Message "Principal IDs: $($numberPrincipalIds)" -Status "info" -Indent 3
        Write-ModernStatus -Message "With Role Assignments: $($numberPrincipalIdsWithRoleAssignments)" -Status "info" -Indent 3
        Write-ModernStatus -Message "Total Role Assignments: $($deployedPolicyResources.numberOfRoleAssignments)" -Status "info" -Indent 3
        if ($PacEnvironment.managingTenantId) {
            Write-ModernStatus -Message "`nRemote Role Assignments: $($deployedPolicyResources.remoteAssignmentsCount)" -Status "info" -Indent 3
        }
    }    return $deployedPolicyResources
}
