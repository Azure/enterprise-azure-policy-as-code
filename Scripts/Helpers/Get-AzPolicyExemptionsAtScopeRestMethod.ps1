function Get-AzPolicyExemptionsAtScopeRestMethod {
    [CmdletBinding()]
    param (
        [string] $Scope
    )

    $response = Invoke-AzRestMethod -Path "$($Scope)/providers/Microsoft.Authorization/policyExemptions?api-version=2022-07-01-preview" -Method GET

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Policy Exemption error $($statusCode) -- $($content)" -ErrorAction Stop
    }

    $content = $response.Content
    $exemptions = $content | ConvertFrom-Json
    return $exemptions.value

}
