function New-ExportNode {
    [CmdletBinding()]
    param (
        [hashtable] $parentNode,
        [string] $pacSelector,
        [string] $propertyName,
        $propertyValue
    )

    $propertyValueModified = $propertyValue
    switch ($propertyName) {
        additionalRoleAssignments {
            $roleAssignments = $propertyValue.ToArray()
            $propertyValueModified = @{
                $pacSelector = $roleAssignments
            }
        }
        identityEntry {
            $propertyValueModified = @{
                $pacSelector = $propertyValue
            }
        }
        scopes {
            $scopes = ConvertTo-ArrayList $propertyValue
            $propertyValueModified = @{
                $pacSelector = $scopes
            }
        }
        notScopes {
            $propertyValueModified = @{
                $pacSelector = $propertyValue
            }
        }
    }

    $node = @{
        $propertyName = $propertyValueModified
        parent        = $parentNode
        children      = [System.Collections.ArrayList]::new()
        clusters      = @{}
    }

    return $node
}
