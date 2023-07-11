function Set-AssignmentNode {
    [CmdletBinding()]
    param (
        $TreeNode,
        $AssignmentNode,
        [string[]] $PropertyNames
    )

    $remainingPropertyNames = [System.Collections.ArrayList]::new()
    foreach ($PropertyName in $PropertyNames) {
        if ($TreeNode.ContainsKey($PropertyName)) {
            $PropertyValue = $TreeNode.$PropertyName
            switch ($PropertyName) {
                parameters {
                    if ($null -ne $PropertyValue -and $PropertyValue.psbase.Count -gt 0) {
                        $null = $AssignmentNode.Add("parameters", $PropertyValue)
                    }
                    break
                }
                overrides {
                    if ($null -ne $PropertyValue) {
                        $null = $AssignmentNode.Add("overrides", $PropertyValue)
                    }
                    break
                }
                resourceSelectors {
                    if ($null -ne $PropertyValue) {
                        $null = $AssignmentNode.Add("resourceSelectors", $PropertyValue)
                    }
                    break
                }
                enforcementMode {
                    if ($null -ne $PropertyValue -and $PropertyValue -ne "Default") {
                        $null = $AssignmentNode.Add("enforcementMode", $PropertyValue)
                    }
                    break
                }
                nonComplianceMessages {
                    if ($null -ne $PropertyValue -and $PropertyValue.Count -gt 0) {
                        if ($AssignmentNode.nodeName -eq "/root") {
                            # special case for nonComplianceMessages
                            $AssignmentDefinitionEntry = $AssignmentNode.definitionEntry
                            $null = $AssignmentDefinitionEntry.Add("nonComplianceMessages", $PropertyValue)
                        }
                        else {
                            $null = $AssignmentNode.Add("nonComplianceMessages", $PropertyValue)
                        }
                    }
                    break
                }
                metadata {
                    if ($null -ne $PropertyValue -and $PropertyValue.psbase.Count -gt 0) {
                        $null = $AssignmentNode.Add("metadata", $PropertyValue)
                    }
                    break
                }
                assignmentNameEx {
                    $null = $AssignmentNode.Add("assignment", @{
                            name        = $PropertyValue.name
                            displayName = $PropertyValue.displayName
                            description = $PropertyValue.description
                        }
                    )
                    break
                }
                additionalRoleAssignments {
                    $additionalRoleAssignmentsEntry = @{}
                    foreach ($selector in $PropertyValue.Keys) {
                        $additionalRoleAssignments = $PropertyValue.$selector
                        if ($null -ne $additionalRoleAssignments -and $additionalRoleAssignments.Count -gt 0) {
                            $additionalRoleAssignmentsEntry[$selector] = $additionalRoleAssignments
                        }
                    }
                    if ($additionalRoleAssignmentsEntry.Count -gt 0) {
                        $null = $AssignmentNode.Add("additionalRoleAssignments", $additionalRoleAssignmentsEntry)
                    }
                    break
                }
                identityEntry {
                    $locationEntry = @{}
                    $userAssigned = @{}
                    foreach ($selector in $PropertyValue.Keys) {
                        $value = $PropertyValue.$selector
                        if ($null -ne $value) {
                            $location = $value.location
                            if ($null -ne $location) {
                                $locationEntry[$selector] = $location
                            }
                            $userAssignedValue = $value.userAssigned
                            if ($null -ne $userAssignedValue) {
                                $userAssigned[$selector] = $userAssignedValue
                            }
                        }
                    }
                    if ($locationEntry.Count -gt 0) {
                        $null = $AssignmentNode.Add("managedIdentityLocations", $locationEntry)
                    }
                    if ($userAssigned.Count -gt 0) {
                        $null = $AssignmentNode.Add("userAssignedIdentity", $userAssigned)
                    }
                    break
                }
                notScopes {
                    $NotScopesValue = @{}
                    foreach ($selector in $PropertyValue.Keys) {
                        $NotScopes = $PropertyValue.$selector
                        if ($null -ne $NotScopes -and $NotScopes.Count -gt 0) {
                            $NotScopesValue[$selector] = $NotScopes
                        }
                    }
                    if ($NotScopesValue.Count -gt 0) {
                        $null = $AssignmentNode.Add("notScope", $NotScopesValue)
                    }
                    break
                }
                scopes {
                    $ScopeValue = @{}
                    foreach ($selector in $PropertyValue.Keys) {
                        $Scopes = $PropertyValue.$selector
                        if ($null -ne $Scopes -and $Scopes.Count -gt 0) {
                            $ScopeValue[$selector] = $Scopes
                        }
                    }
                    if ($ScopeValue.Count -gt 0) {
                        $null = $AssignmentNode.Add("scope", $ScopeValue)
                    }
                    break
                }
            }
        }
        else {
            $null = $remainingPropertyNames.Add($PropertyName)
        }
    }

    if ($remainingPropertyNames.Count -gt 0) {
        $remainingPropertyNames = $remainingPropertyNames.ToArray()
        $children = $TreeNode.children
        $count = $children.Count
        if ($count -eq 1) {
            # an only child, collapse tree
            $child = $children[0]
            Set-AssignmentNode `
                -TreeNode $child `
                -AssignmentNode $AssignmentNode `
                -PropertyNames $remainingPropertyNames
        }
        elseif ($count -gt 1) {
            # multiple siblings, create a children entry and iterate through the children
            $newAssignmentNodeChildren = [System.Collections.ArrayList]::new()
            $i = 0
            foreach ($child in $children) {
                $newAssignmentNode = [ordered]@{
                    nodeName = "/child-$i"
                }
                $null = $newAssignmentNodeChildren.Add($newAssignmentNode)

                Set-AssignmentNode `
                    -TreeNode $child `
                    -AssignmentNode $newAssignmentNode `
                    -PropertyNames $remainingPropertyNames
                $i++
            }
            $null = $AssignmentNode.Add("children", $newAssignmentNodeChildren.ToArray())
        }
    }
}
