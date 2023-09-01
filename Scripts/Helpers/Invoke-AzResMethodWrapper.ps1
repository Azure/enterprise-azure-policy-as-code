function Invoke-AzRestMethodWrapper {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ObjectName,

        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [string] $Method,

        [Parameter(Mandatory = $false)]
        [string] $Payload = ""
    )
    
    $response = $null
    if ([string]::IsNullOrWhiteSpace($Payload)) {
        $response = Invoke-AzRestMethod -Path $Path -Method $Method
    }
    else {
        $response = Invoke-AzRestMethod -Path $Path -Method $Method -Payload $Payload
    }

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        # truncate $Payload to avoid spamming the log
        $PayLoadTruncated = $Payload
        if ($Payload.Length -gt 200) {
            $PayLoadTruncated = $Payload.Substring(0, 199) + "..."
        }
        Write-Information "$($ObjectName) error:"
        Write-Information "    httpStatus = $($statusCode)"
        Write-Information "    error      = '$($content)'"
        Write-Information "    path       = '$($path)'"
        Write-Information "    payload    = '$($PayLoadTruncated)'"
        Write-Error "Invoke-AzRestMethod returned an error" -ErrorAction Continue
    }
    $response
}