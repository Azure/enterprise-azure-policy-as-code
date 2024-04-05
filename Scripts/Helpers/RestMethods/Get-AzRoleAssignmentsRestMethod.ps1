function Get-AzRoleAssignmentsRestMethod {
    [CmdletBinding()]
    param (
        [string] $Scope,
        [string] $ApiVersion,
        [string] $TenantId = ""
    )

    $tenantIdString = ""
    if (-not [string]::IsNullOrEmpty($TenantId)) {
        $tenantIdString = "&tenantId=$TenantId"
    }
    # Invoke the REST API
    $response = Invoke-AzRestMethod -Path "$($Scope)/providers/Microsoft.Authorization/roleAssignments?api-version=$($ApiVersion)$($tenantIdString)" -Method GET

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Get Role Assignment error for '$Scope' $($statusCode) -- $($content)" -ErrorAction Stop
    }

    $content = $response.Content
    $roleAssignments = $content | ConvertFrom-Json -Depth 100
    Write-Output $roleAssignments.value -NoEnumerate
}

# $roleAssignments1 = Get-AzRoleAssignmentsRestMethod -ApiVersion "2022-04-01" -Scope "/subscriptions/d1f55a08-5325-4bd8-910f-f8e1456c8c0f"
# $null = $null
# $roleAssignments2 = Get-AzRoleAssignmentsRestMethod -ApiVersion "2022-04-01" -Scope "/providers/Microsoft.Management/managementGroups/mg-Dev"
# $null = $null
