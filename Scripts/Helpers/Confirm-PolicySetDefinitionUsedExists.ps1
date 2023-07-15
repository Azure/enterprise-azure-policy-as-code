function Confirm-PolicySetDefinitionUsedExists {
    [CmdletBinding()]
    param(
        $Id = $null,
        $Name = $null,
        $PolicyDefinitionsScopes,

        [hashtable] $AllPolicySetDefinitions
    )

    # Are the parameters correct?
    if (!($null -eq $Id -xor $null -eq $Name)) {
        Write-Error "Confirm-PolicySetDefinitionUsedExists called with a contradictory parameters: must supply either PolicySet id or PolicySet name." -ErrorAction Stop
    }

    # Find the Policy Set
    if ($null -ne $Id) {
        if ($AllPolicySetDefinitions.ContainsKey($Id)) {
            return $Id
        }
        else {
            Write-Error "    PolicySet '$Id' not found."
            return $null
        }
    }
    else {
        foreach ($scopeId in $PolicyDefinitionsScopes) {
            $Id = "$scopeId/providers/Microsoft.Authorization/policySetDefinitions/$Name"
            if ($AllPolicySetDefinitions.ContainsKey($Id)) {
                return $Id
            }
        }

        Write-Error "    PolicySet name '$Name' not found in custom or built-in Policy Sets."
        return $null
    }
}
