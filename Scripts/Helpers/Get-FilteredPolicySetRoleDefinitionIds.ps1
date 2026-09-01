function Get-FilteredPolicySetRoleDefinitionIds {
    <#
    .SYNOPSIS
    Removes roleDefinitionIds which are only contributed by Policy Set members whose effect the
    Policy Set hard-codes (pins) to a non-deploying literal value.

    .DESCRIPTION
    requiredRoleAssignments for a Policy Set assignment is normally the union of the
    roleDefinitionIds of every member Policy, regardless of the effect each member will actually
    evaluate with. Members pinned by the Policy Set to a literal such as AuditIfNotExists never
    deploy anything, so the roles they contribute are not required by the assignment's Managed
    Identity.

    A pinned literal is only a default though: an assignment may use an override of kind
    'policyEffect' to raise a member back to a deploying effect. When an override targets a pinned
    member with DeployIfNotExists or Modify, that member's roles are required again and are kept.

    Only roles contributed exclusively by pinned, non-overridden members are removed. Roles that are
    also contributed by any other member, or that cannot be attributed to a member, are always kept.
    #>

    [CmdletBinding()]
    param (
        [string] $PolicySetId,
        $PolicySetDetails,
        [hashtable] $PolicyRoleIds,
        $OverridesList
    )

    $unfilteredRoleDefinitionIds = @($PolicyRoleIds.$PolicySetId)
    if ($unfilteredRoleDefinitionIds.Count -eq 0 -or $null -eq $PolicySetDetails -or $null -eq $PolicySetDetails.policyDefinitions) {
        return $unfilteredRoleDefinitionIds
    }

    # Modify and DeployIfNotExists are the only effects which can require a role assignment.
    # Manual is deliberately excluded: no built-in definition combines Manual with roleDefinitionIds.
    $deployingEffects = @("DeployIfNotExists", "Modify")

    #region classify members into pinned (non-deploying literal) and unconditional

    $pinnedRoleIdsByReferenceId = @{}
    $unconditionalRoleIds = @{}
    foreach ($policyInPolicySet in $PolicySetDetails.policyDefinitions) {
        $policyId = $policyInPolicySet.id
        if (-not $PolicyRoleIds.ContainsKey($policyId)) {
            continue
        }
        $memberRoleIds = $PolicyRoleIds.$policyId
        $isPinnedNonDeploying = $policyInPolicySet.effectReason -eq "PolicySet Fixed" `
            -and $policyInPolicySet.effectValue -notin $deployingEffects
        if ($isPinnedNonDeploying) {
            $referenceId = $policyInPolicySet.policyDefinitionReferenceId
            $collected = $pinnedRoleIdsByReferenceId.$referenceId
            if ($null -eq $collected) {
                $collected = @{}
                $null = $pinnedRoleIdsByReferenceId.Add($referenceId, $collected)
            }
            foreach ($roleDefinitionId in $memberRoleIds) {
                $collected[$roleDefinitionId] = $true
            }
        }
        else {
            foreach ($roleDefinitionId in $memberRoleIds) {
                $unconditionalRoleIds[$roleDefinitionId] = $true
            }
        }
    }

    if ($pinnedRoleIdsByReferenceId.psbase.Count -eq 0) {
        return $unfilteredRoleDefinitionIds
    }

    #endregion classify members

    #region determine which pinned members an override raises to a deploying effect

    $raisedReferenceIds = @{}
    foreach ($override in $OverridesList) {
        if ($override.kind -ne "policyEffect" -or $override.value -notin $deployingEffects) {
            continue
        }
        $scopedByReferenceId = $false
        foreach ($selector in $override.selectors) {
            if ($selector.kind -ne "policyDefinitionReferenceId") {
                continue
            }
            $scopedByReferenceId = $true
            if ($null -ne $selector.in) {
                foreach ($referenceId in $selector.in) {
                    $raisedReferenceIds[$referenceId] = $true
                }
            }
            elseif ($null -ne $selector.notIn) {
                $excluded = @{}
                foreach ($referenceId in $selector.notIn) {
                    $excluded[$referenceId] = $true
                }
                foreach ($referenceId in $pinnedRoleIdsByReferenceId.Keys) {
                    if (-not $excluded.ContainsKey($referenceId)) {
                        $raisedReferenceIds[$referenceId] = $true
                    }
                }
            }
        }
        if (-not $scopedByReferenceId) {
            # A deploying override which cannot be attributed to specific members may raise any of
            # them. Keep every role.
            return $unfilteredRoleDefinitionIds
        }
    }

    #endregion determine raised members

    #region subtract only the roles which no remaining member requires

    $requiredRoleIds = $unconditionalRoleIds.Clone()
    foreach ($referenceId in $raisedReferenceIds.Keys) {
        $collected = $pinnedRoleIdsByReferenceId.$referenceId
        if ($null -ne $collected) {
            foreach ($roleDefinitionId in $collected.Keys) {
                $requiredRoleIds[$roleDefinitionId] = $true
            }
        }
    }

    $removableRoleIds = @{}
    foreach ($referenceId in $pinnedRoleIdsByReferenceId.Keys) {
        foreach ($roleDefinitionId in $pinnedRoleIdsByReferenceId.$referenceId.Keys) {
            if (-not $requiredRoleIds.ContainsKey($roleDefinitionId)) {
                $removableRoleIds[$roleDefinitionId] = $true
            }
        }
    }

    if ($removableRoleIds.psbase.Count -eq 0) {
        return $unfilteredRoleDefinitionIds
    }

    # Filter the original union so unattributed roles and the original ordering are preserved.
    $filteredRoleDefinitionIds = [System.Collections.ArrayList]::new()
    foreach ($roleDefinitionId in $unfilteredRoleDefinitionIds) {
        if (-not $removableRoleIds.ContainsKey($roleDefinitionId)) {
            $null = $filteredRoleDefinitionIds.Add($roleDefinitionId)
        }
    }

    #endregion subtract roles

    return $filteredRoleDefinitionIds.ToArray()
}
