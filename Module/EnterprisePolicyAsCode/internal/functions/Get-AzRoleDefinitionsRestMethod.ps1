function Get-AzRoleDefinitionsRestMethod {
    [CmdletBinding()]
    param (
        [string] $Scope,
        [string] $ApiVersion
    )

    # Invoke the REST API
    $response = Invoke-AzRestMethod -Path "$($Scope)/providers/Microsoft.Authorization/roleDefinitions?$filter=atScopeAndBelow&api-version=$($ApiVersion)" -Method GET

    # Process response
    $statusCode = $response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        $content = $response.Content
        Write-Error "Get Role Assignment error for scope '$Scope' $($statusCode) -- $($content)" -ErrorAction Stop
    }

    $content = $response.Content
    $roleDefinitions = $content | ConvertFrom-Json -Depth 100
    Write-Output $roleDefinitions.value -NoEnumerate
}

# $roleDefinitions0 = Get-AzRoleDefinitionsRestMethod -ApiVersion "2022-04-01" -Scope "/subscriptions/d1f55a08-5325-4bd8-910f-f8e1456c8c0f"
# foreach ($roleDefinition in $roleDefinitions0) {
#     $id = $roleDefinition.id
#     if ($id.StartsWith("/providers/Microsoft.Management/managementGroups")) {
#         $null = $null
#     }
#     elseif ($id.StartsWith("/subscriptions")) {
#         foreach ($assignableScope in $roleDefinition.properties.assignableScopes) {
#             if ($assignableScope.StartsWith("/subscriptions/d1f55a08-5325-4bd8-910f-f8e1456c8c0f")) {
#                 $null = $null
#             }
#             else {
#                 $null = $null
#             }
#         }
#     }
#     else {
#         $null = $null
#     }
# }
# $null = $null
# $roleDefinitions1 = Get-AzRoleDefinitionsRestMethod -ApiVersion "2022-04-01" -Scope "/providers/Microsoft.Management/managementGroups/mg-Enterprise"
# foreach ($roleDefinition in $roleDefinitions1) {
#     $id = $roleDefinition.id
#     if ($id.StartsWith("/providers/Microsoft.Management/managementGroups")) {
#         $null = $null
#     }
#     elseif ($id.StartsWith("/subscriptions")) {
#         $null = $null
#     }
#     else {
#         $null = $null
#     }
# }
# $null = $null
# $roleDefinitions2 = Get-AzRoleDefinitionsRestMethod -ApiVersion "2022-04-01" -Scope ""
# foreach ($roleDefinition in $roleDefinitions2) {
#     $id = $roleDefinition.id
#     if ($id.StartsWith("/providers/Microsoft.Management/managementGroups")) {
#         $null = $null
#     }
#     elseif ($id.StartsWith("/subscriptions")) {
#         $null = $null
#     }
#     else {
#         $null = $null
#     }
# }
# $null = $null
