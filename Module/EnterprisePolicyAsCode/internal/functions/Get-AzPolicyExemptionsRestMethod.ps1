function Get-AzPolicyExemptionsRestMethod {
    [CmdletBinding()]
    param (
        [string] $Scope,
        [string] $Filter = "",
        [string] $ApiVersion
    )

    $filterString = ""
    if (-not [string]::IsNullOrEmpty($Filter)) {
        $filterString = "`$filter=$Filter&"
    }

    $response = Invoke-AzRestMethod -Path "$($Scope)/providers/Microsoft.Authorization/policyExemptions?$($filterString)api-version=$ApiVersion" -Method GET

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Policy Exemption error for scope '$Scope' $($statusCode) -- $($content)" -ErrorAction Stop
    }

    $content = $response.Content
    $exemptions = $content | ConvertFrom-Json -Depth 100
    Write-Output $exemptions.value -NoEnumerate
}
