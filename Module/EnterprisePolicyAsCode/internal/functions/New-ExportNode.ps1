function New-ExportNode {
    [CmdletBinding()]
    param (
        [hashtable] $ParentNode,
        [string] $PacSelector,
        [string] $PropertyName,
        $PropertyValue
    )

    $propertyValueModified = $PropertyValue
    switch ($PropertyName) {
        additionalRoleAssignments {
            $roleAssignments = $PropertyValue.ToArray()
            $propertyValueModified = @{
                $PacSelector = $roleAssignments
            }
        }
        identityEntry {
            $propertyValueModified = @{
                $PacSelector = $PropertyValue
            }
        }
        scopes {
            $scopes = ConvertTo-ArrayList $PropertyValue
            $propertyValueModified = @{
                $PacSelector = $scopes
            }
        }
        notScopes {
            $propertyValueModified = @{
                $PacSelector = $PropertyValue
            }
        }
    }

    $node = @{
        $PropertyName = $propertyValueModified
        parent        = $ParentNode
        children      = [System.Collections.ArrayList]::new()
        clusters      = @{}
    }

    return $node
}
