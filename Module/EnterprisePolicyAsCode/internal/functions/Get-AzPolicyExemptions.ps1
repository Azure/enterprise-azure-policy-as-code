function Get-AzPolicyExemptions {
    [CmdletBinding()]
    param (
        $DeployedPolicyResources,
        $PacEnvironment,
        $ScopeTable
    )

    $desiredState = $PacEnvironment.desiredState
    $excludedPolicyResources = $desiredState.excludedPolicyAssignments
    $rootScopeDetails = $ScopeTable.root
    $excludedScopesTable = $rootScopeDetails.excludedScopesTable

    $policyResources = [System.Collections.ArrayList]::new()
    $ProgressItemName = "Policy Exemptions"
    $now = Get-Date -AsUTC
    if ($PacEnvironment.cloud -eq "AzureChinaCloud") {
        # if ($PacEnvironment.cloud -ne "AzureChinaCloud") {
        # test china cloud in normal environment
        $count = 0
        $lastCount = 0
        $exemptionsProcessed = @{}
        foreach ($scopeId in $ScopeTable.Keys) {
            $scopeInformation = $ScopeTable.$scopeId
            if ($scopeInformation.type -ne "microsoft.resources/subscriptions/resourceGroups" -and $scopeId -ne "root") {
                $exemptionsLocal = @()
                if ($scopeInformation.type -ne "Microsoft.Management/managementGroups") {
                    $exemptionsLocal = Get-AzPolicyExemptionsRestMethod -Scope $scopeId -ApiVersion $PacEnvironment.apiVersions.policyExemptions
                }
                elseif ($scopeInformation.type -eq "Microsoft.Management/managementGroups") {
                    $exemptionsLocal = Get-AzPolicyExemptionsRestMethod -Scope $scopeId -Filter "atScope()" -ApiVersion $PacEnvironment.apiVersions.policyExemptions
                }
                $count += $exemptionsLocal.Count
                if (($lastCount + 1000) -le $count) {
                    Write-Information "Retrieved $count $($ProgressItemName)"
                    $lastCount = $count
                }
                foreach ($exemption in $exemptionsLocal) {
                    $id = $exemption.id
                    if (!$exemptionsProcessed.ContainsKey($id)) {
                        $null = $exemptionsProcessed.Add($id, $true)
                        $null = $policyResources.Add($exemption)
                    }
                }
            }
        }
        Write-Information "Retrieved $($count) $($ProgressItemName), collected $($exemptionsProcessed.Count) unique $($ProgressItemName)"
    }
    else {
        $query = "PolicyResources | where type == 'microsoft.authorization/policyexemptions'"
        $policyResources = Search-AzGraphAllItems -Query $query -ProgressItemName $ProgressItemName
    }

    $thisPacOwnerId = $PacEnvironment.pacOwnerId
    $environmentTenantId = $PacEnvironment.tenantId

    $policyResourcesTable = $DeployedPolicyResources.policyexemptions
    $policyExemptionsCounters = $policyResourcesTable.counters

    foreach ($policyResource in $policyResources) {
        $resourceTenantId = $policyResource.tenantId
        if ($resourceTenantId -in @($null, "", $environmentTenantId)) {
            $properties = Get-PolicyResourceProperties $policyResource

            $id = $policyResource.id
            $name = $policyResource.name
            $testId = $properties.policyAssignmentId

            $included, $resourceIdParts = Confirm-PolicyResourceExclusions `
                -TestId $testId `
                -ResourceId $id `
                -ScopeTable $ScopeTable `
                -ExcludedScopesTable $excludedScopesTable `
                -ExcludedIds $excludedPolicyResources `
                -PolicyResourceTable $policyResourcesTable
            if ($included) {
                $displayName = $properties.displayName
                if ($null -ne $displayName -and $displayName -eq "") {
                    $displayName = $null
                }
                $description = $properties.description
                if ($null -ne $description -and $description -eq "") {
                    $description = $null
                }
                $exemptionCategory = $properties.exemptionCategory
                $expiresOnRaw = $properties.expiresOn
                $expiresOn = $null
                if ($null -ne $expiresOnRaw -and $expiresOnRaw -ne "") {
                    if ($expiresOnRaw -is [datetime]) {
                        $expiresOn = $expiresOnRaw.ToUniversalTime
                    }
                    else {
                        $expiresOnDate = [datetime]::Parse($expiresOnRaw)
                        $expiresOn = $expiresOnDate.ToUniversalTime()
                    }
                    $expiresOn = $expiresOnRaw.ToUniversalTime()
                }
                $metadataRaw = $properties.metadata
                $metadata = $null
                if ($null -ne $metadataRaw -and $metadataRaw -ne @{} ) {
                    $metadata = $metadataRaw
                }
                $policyAssignmentId = $properties.policyAssignmentId
                $policyDefinitionReferenceIdsRaw = $properties.policyDefinitionReferenceIds
                $policyDefinitionReferenceIds = $null
                if ($null -ne $policyDefinitionReferenceIdsRaw -and $policyDefinitionReferenceIdsRaw.Count -gt 0) {
                    $policyDefinitionReferenceIds = $policyDefinitionReferenceIdsRaw
                }
                $resourceSelectors = $properties.resourceSelectors
                $assignmentScopeValidation = $properties.assignmentScopeValidation
                $pacOwner = Confirm-PacOwner -ThisPacOwnerId $thisPacOwnerId -PolicyResource $policyResource -ManagedByCounters $policyExemptionsCounters.managedBy
                $status = "active"
                $expiresInDays = [Int32]::MaxValue
                if ($expiresOn) {
                    $expiresIn = New-TimeSpan -Start $now -End $expiresOn
                    $expiresInDays = $expiresIn.Days
                    if ($expiresInDays -lt -15) {
                        $status = "expired-over-15-days"
                        $policyExemptionsCounters.expired += 1
                    }
                    elseif ($expiresInDays -lt 0) {
                        $status = "expired-less-within-15-days"
                        $policyExemptionsCounters.expired += 1
                    }
                    elseif ($expiresInDays -lt 15) {
                        $status = "active-expiring-within-15-days"
                    }
                }

                $exemption = @{
                    id                           = $id
                    name                         = $name
                    scope                        = $resourceIdParts.scope
                    displayName                  = $displayName
                    description                  = $description
                    exemptionCategory            = $exemptionCategory
                    expiresOn                    = $expiresOn
                    metadata                     = $metadata
                    policyAssignmentId           = $policyAssignmentId
                    policyDefinitionReferenceIds = $policyDefinitionReferenceIds
                    resourceSelectors            = $resourceSelectors
                    assignmentScopeValidation    = $assignmentScopeValidation
                    pacOwner                     = $pacOwner
                    status                       = $status
                    expiresInDays                = $expiresInDays
                }
                $null = $policyResourcesTable.managed.Add($id, $exemption)
            }
            else {
                Write-Verbose "Policy resource $id excluded"
            }
        }
    }
}

