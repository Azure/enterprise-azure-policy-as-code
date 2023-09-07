function Export-AssignmentNode {
    [CmdletBinding()]
    param (
        $TreeNode,
        $AssignmentNode,
        [string[]] $PropertyNames
    )

    $remainingPropertyNames = [System.Collections.ArrayList]::new()
    foreach ($propertyName in $PropertyNames) {
        if ($TreeNode.ContainsKey($propertyName)) {
            $propertyValue = $TreeNode.$propertyName
            switch ($propertyName) {
                parameters {
                    if ($null -ne $propertyValue -and $propertyValue.psbase.Count -gt 0) {
                        $null = $AssignmentNode.Add("parameters", $propertyValue)
                    }
                    break
                }
                overrides {
                    if ($null -ne $propertyValue) {
                        $null = $AssignmentNode.Add("overrides", $propertyValue)
                    }
                    break
                }
                resourceSelectors {
                    if ($null -ne $propertyValue) {
                        $null = $AssignmentNode.Add("resourceSelectors", $propertyValue)
                    }
                    break
                }
                enforcementMode {
                    if ($null -ne $propertyValue -and $propertyValue -ne "Default") {
                        $null = $AssignmentNode.Add("enforcementMode", $propertyValue)
                    }
                    break
                }
                nonComplianceMessages {
                    if ($null -ne $propertyValue -and $propertyValue.Count -gt 0) {
                        if ($AssignmentNode.nodeName -eq "/root") {
                            # special case for nonComplianceMessages
                            $assignmentDefinitionEntry = $AssignmentNode.definitionEntry
                            $null = $assignmentDefinitionEntry.Add("nonComplianceMessages", $propertyValue)
                        }
                        else {
                            $null = $AssignmentNode.Add("nonComplianceMessages", $propertyValue)
                        }
                    }
                    break
                }
                metadata {
                    if ($null -ne $propertyValue -and $propertyValue.psbase.Count -gt 0) {
                        $null = $AssignmentNode.Add("metadata", $propertyValue)
                    }
                    break
                }
                assignmentNameEx {
                    $null = $AssignmentNode.Add("assignment", [ordered]@{
                            name        = $propertyValue.name
                            displayName = $propertyValue.displayName
                            description = $propertyValue.description
                        }
                    )
                    break
                }
                additionalRoleAssignments {
                    $additionalRoleAssignmentsEntry = [ordered]@{}
                    foreach ($selector in $propertyValue.Keys) {
                        $additionalRoleAssignments = $propertyValue.$selector
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
                    $locationEntry = [ordered]@{}
                    $userAssigned = [ordered]@{}
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
                        $null = $AssignmentNode.Add("managedIdentityLocations", $locationEntry)
                    }
                    if ($userAssigned.Count -gt 0) {
                        $null = $AssignmentNode.Add("userAssignedIdentity", $userAssigned)
                    }
                    break
                }
                notScopes {
                    $notScopesValue = [ordered]@{}
                    foreach ($selector in $propertyValue.Keys) {
                        $notScopes = $propertyValue.$selector
                        if ($null -ne $notScopes -and $notScopes.Count -gt 0) {
                            $notScopesValue[$selector] = $notScopes
                        }
                    }
                    if ($notScopesValue.Count -gt 0) {
                        $null = $AssignmentNode.Add("notScope", $notScopesValue)
                    }
                    break
                }
                scopes {
                    $scopeValue = [ordered]@{}
                    foreach ($selector in $propertyValue.Keys) {
                        $scopes = $propertyValue.$selector
                        if ($null -ne $scopes -and $scopes.Count -gt 0) {
                            $scopeValue[$selector] = $scopes
                        }
                    }
                    if ($scopeValue.Count -gt 0) {
                        $null = $AssignmentNode.Add("scope", $scopeValue)
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
        $children = $TreeNode.children
        $count = $children.Count
        if ($count -eq 1) {
            # an only child, collapse tree
            $child = $children[0]
            Export-AssignmentNode `
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

                Export-AssignmentNode `
                    -TreeNode $child `
                    -AssignmentNode $newAssignmentNode `
                    -PropertyNames $remainingPropertyNames
                $i++
            }
            $null = $AssignmentNode.Add("children", $newAssignmentNodeChildren.ToArray())
        }
    }
}
