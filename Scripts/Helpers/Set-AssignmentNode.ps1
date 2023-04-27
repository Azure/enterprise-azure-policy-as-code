function Set-AssignmentNode {
    [CmdletBinding()]
    param (
        $treeNode,
        $assignmentNode,
        [string[]] $propertyNames
    )

    $remainingPropertyNames = [System.Collections.ArrayList]::new()
    foreach ($propertyName in $propertyNames) {
        if ($treeNode.ContainsKey($propertyName)) {
            $propertyValue = $treeNode.$propertyName
            switch ($propertyName) {
                parameters {
                    if ($null -ne $propertyValue -and $propertyValue.psbase.Count -gt 0) {
                        $null = $assignmentNode.Add("parameters", $propertyValue)
                    }
                    break
                }
                overrides {
                    if ($null -ne $propertyValue) {
                        $null = $assignmentNode.Add("overrides", $propertyValue)
                    }
                    break
                }
                resourceSelectors {
                    if ($null -ne $propertyValue) {
                        $null = $assignmentNode.Add("resourceSelectors", $propertyValue)
                    }
                    break
                }
                enforcementMode {
                    if ($null -ne $propertyValue -and $propertyValue -ne "Default") {
                        $null = $assignmentNode.Add("enforcementMode", $propertyValue)
                    }
                    break
                }
                nonComplianceMessages {
                    if ($null -ne $propertyValue -and $propertyValue.Count -gt 0) {
                        if ($assignmentNode.nodeName -eq "/root") {
                            # special case for nonComplianceMessages
                            $assignmentDefinitionEntry = $assignmentNode.definitionEntry
                            $null = $assignmentDefinitionEntry.Add("nonComplianceMessages", $propertyValue)
                        }
                        else {
                            $null = $assignmentNode.Add("nonComplianceMessages", $propertyValue)
                        }
                    }
                    break
                }
                metadata {
                    if ($null -ne $propertyValue -and $propertyValue.psbase.Count -gt 0) {
                        $null = $assignmentNode.Add("metadata", $propertyValue)
                    }
                    break
                }
                assignmentNameEx {
                    $null = $assignmentNode.Add("assignment", @{
                            name        = $propertyValue.name
                            displayName = $propertyValue.displayName
                            description = $propertyValue.description
                        }
                    )
                    break
                }
                additionalRoleAssignments {
                    $additionalRoleAssignmentsEntry = @{}
                    foreach ($selector in $propertyValue.Keys) {
                        $additionalRoleAssignments = $propertyValue.$selector
                        if ($null -ne $additionalRoleAssignments -and $additionalRoleAssignments.Count -gt 0) {
                            $additionalRoleAssignmentsEntry[$selector] = $additionalRoleAssignments
                        }
                    }
                    if ($additionalRoleAssignmentsEntry.Count -gt 0) {
                        $null = $assignmentNode.Add("additionalRoleAssignments", $additionalRoleAssignmentsEntry)
                    }
                    break
                }
                identityEntry {
                    $locationEntry = @{}
                    $userAssigned = @{}
                    foreach ($selector in $propertyValue.Keys) {
                        $value = $propertyValue.$selector
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
                        $null = $assignmentNode.Add("managedIdentityLocations", $locationEntry)
                    }
                    if ($userAssigned.Count -gt 0) {
                        $null = $assignmentNode.Add("userAssignedIdentity", $userAssigned)
                    }
                    break
                }
                notScopes {
                    $notScopesValue = @{}
                    foreach ($selector in $propertyValue.Keys) {
                        $notScopes = $propertyValue.$selector
                        if ($null -ne $notScopes -and $notScopes.Count -gt 0) {
                            $notScopesValue[$selector] = $notScopes
                        }
                    }
                    if ($notScopesValue.Count -gt 0) {
                        $null = $assignmentNode.Add("notScope", $notScopesValue)
                    }
                    break
                }
                scopes {
                    $scopeValue = @{}
                    foreach ($selector in $propertyValue.Keys) {
                        $scopes = $propertyValue.$selector
                        if ($null -ne $scopes -and $scopes.Count -gt 0) {
                            $scopeValue[$selector] = $scopes
                        }
                    }
                    if ($scopeValue.Count -gt 0) {
                        $null = $assignmentNode.Add("scope", $scopeValue)
                    }
                    break
                }
            }
        }
        else {
            $null = $remainingPropertyNames.Add($propertyName)
        }
    }

    if ($remainingPropertyNames.Count -gt 0) {
        $remainingPropertyNames = $remainingPropertyNames.ToArray()
        $children = $treeNode.children
        $count = $children.Count
        if ($count -eq 1) {
            # an only child, collapse tree
            $child = $children[0]
            Set-AssignmentNode `
                -treeNode $child `
                -assignmentNode $assignmentNode `
                -propertyNames $remainingPropertyNames
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
                    -treeNode $child `
                    -assignmentNode $newAssignmentNode `
                    -propertyNames $remainingPropertyNames
                $i++
            }
            $null = $assignmentNode.Add("children", $newAssignmentNodeChildren.ToArray())
        }
    }
}
