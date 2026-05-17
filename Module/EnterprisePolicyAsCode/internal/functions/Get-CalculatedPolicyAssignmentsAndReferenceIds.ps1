function Get-CalculatedPolicyAssignmentsAndReferenceIds {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array] $Assignments,

        [Parameter(Mandatory = $true)]
        [hashtable] $CombinedPolicyDetails
    )
    
    # calculated assignments
    $byAssignmentIdCalculatedAssignments = @{}
    $byPolicySetIdCalculatedAssignments = @{}
    $byPolicyIdCalculatedAssignments = @{}

    # by Policy Set calculated policyDefinitionReferenceIds and by policyDefinitionIds in Policy Set  policyDefinitionReferenceIds
    $byPolicySetIdPolicyDefinitionReferences = @{}

    $index = 0
    foreach ($assignment in $Assignments) {
        $assignmentId = $assignment.id
        $assignmentProperties = Get-PolicyResourceProperties $assignment
        $assignedPolicyDefinitionId = $assignmentProperties.policyDefinitionId

        if ($assignedPolicyDefinitionId.Contains("/providers/Microsoft.Authorization/policyDefinitions/", [StringComparison]::InvariantCultureIgnoreCase)) {

            #region calculate assignment for this policyAssignment and assignments for the Policy definition id
            $calculatedPolicyAssignment = @{
                id                             = $assignmentId
                scope                          = $assignment.scope
                name                           = $assignment.name
                displayName                    = $assignmentProperties.displayName
                assignedPolicyDefinitionId     = $assignedPolicyDefinitionId
                policyDefinitionId             = $assignedPolicyDefinitionId
                notScopes                      = $assignmentProperties.notScopes
                isPolicyAssignment             = $true
                allowReferenceIdsInRow         = $false
                policyDefinitionReferenceIds   = $null
                policyDefinitionIds            = $null
                byPolicyDefinitionIdReferences = $null
            }
            $calculatedPolicyAssignments = [System.Collections.ArrayList]::new()
            $calculatedPolicyAssignments.Add($calculatedPolicyAssignment)
            $null = $byAssignmentIdCalculatedAssignments.Add($assignmentId, $calculatedPolicyAssignments)

            $calculatedPolicyAssignments = $null
            if ($byPolicyIdCalculatedAssignments.ContainsKey($assignedPolicyDefinitionId)) {
                $calculatedPolicyAssignments = $byPolicyIdCalculatedAssignments.$assignedPolicyDefinitionId
            }
            else {
                $calculatedPolicyAssignments = [System.Collections.ArrayList]::new()
                $null = $byPolicyIdCalculatedAssignments.Add($assignedPolicyDefinitionId, $calculatedPolicyAssignments)
            }
            $null = $calculatedPolicyAssignments.Add($calculatedPolicyAssignment)
            #endregion calculate assignment for this policyAssignment and assignments for the Policy definition id

        }
        elseif ($assignedPolicyDefinitionId.Contains("/providers/Microsoft.Authorization/policySetDefinitions/", [StringComparison]::InvariantCultureIgnoreCase)) {
            $thisPolicySetReferences = $null

            #region calculate referenceId values for this Policy Set
            if ($byPolicySetIdPolicyDefinitionReferences.ContainsKey($assignedPolicyDefinitionId)) {
                # use previously calculated values
                $thisPolicySetReferences = $byPolicySetIdPolicyDefinitionReferences.$assignedPolicyDefinitionId
            }
            else {
                # create empty values for this Policy Set
                $thisPolicySetReferences = @{
                    policyDefinitionIds            = [System.Collections.ArrayList]::new()
                    policyDefinitionReferenceIds   = [System.Collections.ArrayList]::new()
                    byPolicyDefinitionIdReferences = @{}
                }
                $null = $byPolicySetIdPolicyDefinitionReferences.Add($assignedPolicyDefinitionId, $thisPolicySetReferences)

                # calculate values for this Policy Set
                $policySetDetailsHt = $CombinedPolicyDetails.policySets
                $thisPolicySetDetails = $policySetDetailsHt.$assignedPolicyDefinitionId
                $policyIndex = 0
                foreach ($policyDefinitionInPolicySet in $thisPolicySetDetails.policyDefinitions) {
                    $policyDefinitionId = $policyDefinitionInPolicySet.id
                    $policyDefinitionReferenceId = $policyDefinitionInPolicySet.policyDefinitionReferenceId

                    # flat lists
                    $null = $thisPolicySetReferences.policyDefinitionIds.Add($policyDefinitionId)
                    $null = $thisPolicySetReferences.policyDefinitionReferenceIds.Add($policyDefinitionReferenceId)

                    # calculate per Policy
                    $thisPolicyDefinitionIdReferences = $null
                    if ($thisPolicySetReferences.byPolicyDefinitionIdReferences.ContainsKey($policyDefinitionId)) {
                        $thisPolicyDefinitionIdReferences = $thisPolicySetReferences.byPolicyDefinitionIdReferences[$policyDefinitionId]
                    }
                    else {
                        $thisPolicyDefinitionIdReferences = @{
                            referenceIds  = [System.Collections.ArrayList]::new()
                            policyIndexes = [System.Collections.ArrayList]::new()
                        }
                        $null = $thisPolicySetReferences.byPolicyDefinitionIdReferences.Add($policyDefinitionId, $thisPolicyDefinitionIdReferences)
                    }
                    $null = $thisPolicyDefinitionIdReferences.referenceIds.Add($policyDefinitionReferenceId)
                    $null = $thisPolicyDefinitionIdReferences.policyIndexes.Add($policyIndex)
                    $policyIndex++
                }
            }
            #endregion calculate referenceId values for this Policy Set

            #region calculated assignment for this policyAssignment AND for this policySetId
            $calculatedPolicyAssignment = @{
                id                             = $assignmentId
                scope                          = $assignment.scope
                name                           = $assignment.name
                displayName                    = $assignmentProperties.displayName
                assignedPolicyDefinitionId     = $assignedPolicyDefinitionId
                policyDefinitionId             = $null
                notScopes                      = $assignmentProperties.notScopes
                isPolicyAssignment             = $false
                allowReferenceIdsInRow         = $true
                policyDefinitionReferenceIds   = $thisPolicySetReferences.policyDefinitionReferenceIds
                policyDefinitionIds            = $thisPolicySetReferences.policyDefinitionIds
                byPolicyDefinitionIdReferences = $thisPolicySetReferences.byPolicyDefinitionIdReferences
            }
            $calculatedPolicyAssignments = [System.Collections.ArrayList]::new()
            $calculatedPolicyAssignments.Add($calculatedPolicyAssignment)
            $null = $byAssignmentIdCalculatedAssignments.Add($assignmentId, $calculatedPolicyAssignments)

            $calculatedPolicyAssignments = $null
            if ($byPolicySetIdCalculatedAssignments.ContainsKey($assignedPolicyDefinitionId)) {
                $calculatedPolicyAssignments = $byPolicySetIdCalculatedAssignments.$assignedPolicyDefinitionId
            }
            else {
                $calculatedPolicyAssignments = [System.Collections.ArrayList]::new()
                $null = $byPolicySetIdCalculatedAssignments.Add($assignedPolicyDefinitionId, $calculatedPolicyAssignments)
            }
            $null = $calculatedPolicyAssignments.Add($calculatedPolicyAssignment)
            #endregion calculated assignment for this policyAssignment AND for this policySetId

            #region calculated assignment for each policyDefinition id in this Policy Set
            foreach ($policyDefinitionId in $thisPolicySetReferences.policyDefinitionIds) {
                $thisPolicyReferences = $thisPolicySetReferences.byPolicyDefinitionIdReferences.$policyDefinitionId
                $calculatedPolicyAssignment = @{
                    ordinal                        = $index
                    id                             = $assignmentId
                    scope                          = $assignment.scope
                    name                           = $assignment.name
                    displayName                    = $assignmentProperties.displayName
                    assignedPolicyDefinitionId     = $assignedPolicyDefinitionId
                    policyDefinitionId             = $policyDefinitionId
                    notScopes                      = $assignmentProperties.notScopes
                    isPolicyAssignment             = $false
                    allowReferenceIdsInRow         = $false
                    policyDefinitionReferenceIds   = $thisPolicyReferences.referenceIds
                    policyDefinitionIds            = $null
                    byPolicyDefinitionIdReferences = $null
                }
                $calculatedPolicyAssignments = $null
                if ($byPolicyIdCalculatedAssignments.ContainsKey($policyDefinitionId)) {
                    $calculatedPolicyAssignments = $byPolicyIdCalculatedAssignments.$policyDefinitionId
                }
                else {
                    $calculatedPolicyAssignments = [System.Collections.ArrayList]::new()
                    $null = $byPolicyIdCalculatedAssignments.Add($policyDefinitionId, $calculatedPolicyAssignments)
                }
                $null = $calculatedPolicyAssignments.Add($calculatedPolicyAssignment)
            }
            #endregion calculated assignment for each policyDefinition id in this Policy Set
        }
        else {
            #should NEVER happen
            throw "Invalid Policy definition id ($assignedPolicyDefinitionId) in Policy assignment '$($assignment.displayName)'($assignmentId)"
        }
        $index++
    }

    $result = @{
        byAssignmentIdCalculatedAssignments = $byAssignmentIdCalculatedAssignments
        byPolicySetIdCalculatedAssignments  = $byPolicySetIdCalculatedAssignments
        byPolicyIdCalculatedAssignments     = $byPolicyIdCalculatedAssignments
    }

    return $result
}