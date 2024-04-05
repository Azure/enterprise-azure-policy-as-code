function Remove-AzResourceByIdRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Id,

        [Parameter(Mandatory = $true)]
        [string] $ApiVersion
    )

    # Write log info
    Write-Information $Id

    # Invoke the REST API
    $path = "$($Id)?api-version=$($ApiVersion)"
    # Write-Information "DELETE $path"
    $response = Invoke-AzRestMethod -Path $path -Method DELETE

    # Process response
    $statusCode = $response.StatusCode
    if (($statusCode -lt 200 -or $statusCode -ge 300) -and $statusCode -ne 404) {
        $content = $response.Content
        if ($content.Contains("ScopeLocked", [StringComparison]::InvariantCultureIgnoreCase)) {
            Write-Warning "Ignoring scope locked error: $($statusCode) -- $($content)"
        }
        else {
            Write-Error "Remove Az Resource error $($statusCode) -- $($content)"
        }
    }
}
