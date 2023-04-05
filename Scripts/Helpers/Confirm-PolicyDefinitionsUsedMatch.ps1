function Confirm-PolicyDefinitionsUsedMatch {
    [CmdletBinding()]
    param (
        [array] $matchingPolicyDefinitions,
        [array] $definedPolicyDefinitions
    )

    $matchingHt = @{}
    foreach ($pd in $matchingPolicyDefinitions) {
        $parameters = "{}"
        $groupNames = "[]"
        if ($null -ne $pd.parameters) {
            $parameters = $pd.parameters | ConvertTo-Json -Depth 100
        }
        if ($null -ne $pd.groupNames) {
            $groupNames = $pd.groupNames | ConvertTo-Json -Depth 100
        }
        # Write-Host "pd = $($pd | ConvertTo-Json -Depth 100)"
        # Write-Host "policyDefinitionReferenceId = $($pd.policyDefinitionReferenceId)"
        $matchingHt[$pd.policyDefinitionReferenceId] = @{
            policyDefinitionId = $pd.policyDefinitionId
            parameters         = $parameters
            groupNames         = $groupNames
        }
    }

    $matching = $true
    foreach ($pd in $definedPolicyDefinitions) {
        $pdRef = $pd.policyDefinitionReferenceId
        if ($matchingHt.ContainsKey($pdRef)) {
            $mpd = $matchingHt.$pdRef
            $matchingHt.Remove($pdRef)
            $parameters = "{}"
            $groupNames = "[]"
            if ($null -ne $pd.parameters) {
                $parameters = $pd.parameters | ConvertTo-Json -Depth 100
            }
            if ($null -ne $pd.groupNames) {
                $groupNames = $pd.groupNames | ConvertTo-Json -Depth 100
            }
            $matchingItem = ($mpd.policyDefinitionId -eq $pd.policyDefinitionId) `
                -and ($mpd.parameters -eq $parameters) `
                -and ($mpd.groupNames -eq $groupNames)
            if (-not $matchingItem) {
                # policyDefinitionReferenceId matches, but rest of Policy Definition doesn't
                $matching = $false
                break
            }
        }
        else {
            # new definition added a Policy (new policyDefinitionReferenceId)
            $matching = $false
        }
    }
    if ($matching -and ($matchingHt.psbase.Count -gt 0)) {
        # removed a Policy definition (removed policyDefinitionReferenceId)
        $matching = $false
    }

    return $matching
}
