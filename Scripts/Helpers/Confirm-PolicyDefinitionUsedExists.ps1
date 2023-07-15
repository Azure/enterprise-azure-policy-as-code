
function Confirm-PolicyDefinitionUsedExists {
    [CmdletBinding()]
    param(
        $Id = $null,
        $Name = $null,
        $PolicyDefinitionsScopes,
        [hashtable] $AllDefinitions,
        [switch] $SuppressErrorMessage
    )

    # Are the parameters correct?
    if (!($null -eq $Id -xor $null -eq $Name)) {
        Write-Error "Confirm-PolicyDefinitionUsedExists called with a contradictory parameters: must supply either Policy id or Policy name." -ErrorAction Stop
    }

    # Find the Policy
    if ($null -ne $Id) {
        if ($AllDefinitions.ContainsKey($Id)) {
            return $Id
        }
        else {
            if (!$SuppressErrorMessage) {
                Write-Error "    Policy '$Id' not found."
            }
            return $null
        }
    }
    else {
        foreach ($scopeId in $PolicyDefinitionsScopes) {
            $Id = "$scopeId/providers/Microsoft.Authorization/policyDefinitions/$Name"
            if ($AllDefinitions.ContainsKey($Id)) {
                return $Id
            }
        }

        # Not found in custom Policies, try built-in Policies
        if (!$SuppressErrorMessage) {
            Write-Error "    Policy name '$Name' not found in custom or built-in Policies."
        }
        return $null
    }
}
