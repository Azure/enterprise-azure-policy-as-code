function New-ExportNode {
    [CmdletBinding()]
    param (
        [hashtable] $ParentNode,
        [string] $PacSelector,
        [string] $PropertyName,
        $PropertyValue
    )

    $PropertyValueModified = $PropertyValue
    switch ($PropertyName) {
        additionalRoleAssignments {
            $RoleAssignments = $PropertyValue.ToArray()
            $PropertyValueModified = @{
                $PacSelector = $RoleAssignments
            }
        }
        identityEntry {
            $PropertyValueModified = @{
                $PacSelector = $PropertyValue
            }
        }
        scopes {
            $Scopes = ConvertTo-ArrayList $PropertyValue
            $PropertyValueModified = @{
                $PacSelector = $Scopes
            }
        }
        notScopes {
            $PropertyValueModified = @{
                $PacSelector = $PropertyValue
            }
        }
    }

    $node = @{
        $PropertyName = $PropertyValueModified
        parent        = $ParentNode
        children      = [System.Collections.ArrayList]::new()
        clusters      = @{}
    }

    return $node
}
