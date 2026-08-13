function Get-AzPolicyEnrollments {
    [CmdletBinding()]
    param (
        $DeployedPolicyResources,
        $PacEnvironment,
        $ScopeTable
    )

    $query = "policyresources | where type =~ 'microsoft.authorization/policyenrollments'"
    $policyResources = Search-AzGraphAllItems -Query $query -ProgressItemName "Policy Enrollments"
    $policyResourcesTable = $DeployedPolicyResources.policyenrollments
    $counters = $policyResourcesTable.counters
    $excludedScopesTable = $ScopeTable.root.excludedScopesTable
    $excludedPolicyResources = $PacEnvironment.desiredState.excludedPolicyAssignments

    foreach ($policyResource in $policyResources) {
        if ($policyResource.tenantId -notin @($null, "", $PacEnvironment.tenantId) -and $null -eq $PacEnvironment.managedTenantId) {
            continue
        }

        $properties = Get-PolicyResourceProperties $policyResource
        $included, $resourceIdParts = Confirm-PolicyResourceExclusions `
            -TestId $properties.policyAssignmentId `
            -ResourceId $policyResource.id `
            -ScopeTable $ScopeTable `
            -ExcludedScopesTable $excludedScopesTable `
            -ExcludedIds $excludedPolicyResources `
            -PolicyResourceTable $policyResourcesTable
        if (-not $included) {
            continue
        }

        $pacOwner = Confirm-PacOwner `
            -ThisPacOwnerId $PacEnvironment.pacOwnerId `
            -PolicyResource $policyResource `
            -ManagedByCounters $counters.managedBy
        $policyResourcesTable.managed[$policyResource.id] = @{
            id                           = $policyResource.id
            name                         = $policyResource.name
            scope                        = $resourceIdParts.scope
            displayName                  = $properties.displayName
            description                  = $properties.description
            metadata                     = $properties.metadata
            policyAssignmentId           = $properties.policyAssignmentId
            policyDefinitionReferenceIds = $properties.policyDefinitionReferenceIds
            resourceSelectors            = $properties.resourceSelectors
            assignmentScopeValidation    = $properties.assignmentScopeValidation
            pacOwner                     = $pacOwner
        }
    }
}