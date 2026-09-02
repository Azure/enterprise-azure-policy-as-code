function Get-AzPolicySetDefinitionVersionsRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $PolicySetId,

        [Parameter(Mandatory = $true)]
        [string] $ApiVersion
    )

    # Versions are only exposed for Policy Sets which publish a version history. Built-in Policy Sets
    # always do; custom Policy Sets may not. A missing or inaccessible versions endpoint is not an
    # error condition, so return $null and let the caller fall back to the latest definition.
    try {
        $response = Invoke-AzRestMethod -Path "$($PolicySetId)/versions?api-version=$ApiVersion" -Method GET
    }
    catch {
        Write-Verbose "Get Policy Set versions failed for '$PolicySetId' -- $($_.Exception.Message)"
        return $null
    }

    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        Write-Verbose "Get Policy Set versions returned $statusCode for '$PolicySetId' -- $($response.Content)"
        return $null
    }

    $content = $response.Content | ConvertFrom-Json -Depth 100
    return $content.value
}
