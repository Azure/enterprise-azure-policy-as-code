function Confirm-PolicyDefinitionsUsedMatch {
    [CmdletBinding()]
    param (
        [array] $MatchingPolicyDefinitions,
        [array] $DefinedPolicyDefinitions
    )

    $matchingHt = @{}
    foreach ($pd in $MatchingPolicyDefinitions) {
        $Parameters = "{}"
        $groupNames = "[]"
        if ($null -ne $pd.parameters) {
            $Parameters = $pd.parameters | ConvertTo-Json -Depth 100
        }
        if ($null -ne $pd.groupNames) {
            $groupNames = $pd.groupNames | ConvertTo-Json -Depth 100
        }
        # Write-Host "pd = $($pd | ConvertTo-Json -Depth 100)"
        # Write-Host "policyDefinitionReferenceId = $($pd.policyDefinitionReferenceId)"
        $matchingHt[$pd.policyDefinitionReferenceId] = @{
            policyDefinitionId = $pd.policyDefinitionId
            parameters         = $Parameters
            groupNames         = $groupNames
        }
    }

    $matching = $true
    foreach ($pd in $DefinedPolicyDefinitions) {
        $pdRef = $pd.policyDefinitionReferenceId
        if ($matchingHt.ContainsKey($pdRef)) {
            $mpd = $matchingHt.$pdRef
            $matchingHt.Remove($pdRef)
            $Parameters = "{}"
            $groupNames = "[]"
            if ($null -ne $pd.parameters) {
                $Parameters = $pd.parameters | ConvertTo-Json -Depth 100
            }
            if ($null -ne $pd.groupNames) {
                $groupNames = $pd.groupNames | ConvertTo-Json -Depth 100
            }
            $matchingItem = ($mpd.policyDefinitionId -eq $pd.policyDefinitionId) `
                -and ($mpd.parameters -eq $Parameters) `
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
