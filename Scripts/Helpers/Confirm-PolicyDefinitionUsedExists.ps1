
function Confirm-PolicyDefinitionUsedExists {
    [CmdletBinding()]
    param(
        $id = $null,
        $name = $null,
        $policyDefinitionsScopes,
        [hashtable] $allDefinitions,
        [switch] $suppressErrorMessage
    )

    # Are the parameters correct?
    if (!($null -eq $id -xor $null -eq $name)) {
        Write-Error "Confirm-PolicyDefinitionUsedExists called with a contradictory parameters: must supply either Policy id or Policy name." -ErrorAction Stop
    }

    # Find the Policy
    if ($null -ne $id) {
        if ($allDefinitions.ContainsKey($id)) {
            return $id
        }
        else {
            if (!$suppressErrorMessage) {
                Write-Error "    Policy '$id' not found."
            }
            return $null
        }
    }
    else {
        foreach ($scopeId in $policyDefinitionsScopes) {
            $id = "$scopeId/providers/Microsoft.Authorization/policyDefinitions/$name"
            if ($allDefinitions.ContainsKey($id)) {
                return $id
            }
        }

        # Not found in custom Policies, try built-in Policies
        if (!$suppressErrorMessage) {
            Write-Error "    Policy name '$name' not found in custom or built-in Policies."
        }
        return $null
    }
}
