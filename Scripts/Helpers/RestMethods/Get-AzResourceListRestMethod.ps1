function Get-AzResourceListRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $SubscriptionId,

        [string] $ApiVersion = "2021-04-01"
    )
    
    $path = "/subscriptions/$SubscriptionId/resources?api-version=$ApiVersion"
    $response = Invoke-AzRestMethod -Path $path -Method GET

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Warning "Policy Exemption error for scope '$Scope' $($statusCode) -- $($content)"
        Write-Output @() -NoEnumerate
    }

    $content = $response.Content
    $resources = $content | ConvertFrom-Json -Depth 100 -AsHashtable
    $nextLink = ($response.Content | ConvertFrom-Json -Depth 100 -AsHashtable).nextLink
    while ($null -ne $nextLink) {
      $appendURL = (([uri]$nextlink).Query -split '&')[-1]
      $response = Invoke-AzRestMethod -Path ($path + '&' + $appendURL)  -Method GET
      $resources.value += ($response.Content | ConvertFrom-Json -Depth 100 -AsHashtable).value
      $nextLink = ($response.Content | ConvertFrom-Json -Depth 100 -AsHashtable).nextLink
   }
  
    Write-Output $resources.value -NoEnumerate
}
