<#
.SYNOPSIS
    Creates a global-settings.jsonc file with a new guid, managed identity location and tenant information

.DESCRIPTION
    Creates a global-settings.jsonc file with a new guid, managed identity location and tenant information

.PARAMETER ManagedIdentityLocation
    The Azure location to store the managed identities (Get-AzLocation|Select Location)

.PARAMETER Tenant
    The Azure tenant ID for the solution ((Get-AzContext).Tenant)

.PARAMETER DefinitionsPath
    The folder path to where the New-EPACDefinitionsFolder command created the definitions root folder (C:\definitions\)

.EXAMPLE
    .\New-EPACGlobalSettings.ps1 -ManagedIdentityLocation NorthCentralUS -Tenant 00000000-0000-0000-0000-000000000000

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ManagedIdentityLocation,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Tenant,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$DefinitionsPath
)

$DefinitionsPath = $DefinitionsPath.TrimEnd('\')

if (Test-Path -Path $DefinitionsPath) {
    if (Get-AzLocation | Where-Object {$_.Location -eq $ManagedIdentityLocation}) {
        $jsonstrings = @("{""`$schema"": ""https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json"", ""pacOwnerId"": """,
                    """, ""managedIdentityLocations"": { ""*"": """,
                    """}, ""globalNotScopes"": { ""*"": [""/resourceGroupPatterns/excluded-rg*""] }, ""pacEnvironments"": [{ ""pacSelector"": ""quick-start"",""cloud"": ""AzureCloud"", ""tenantId"": """,
                    """, ""deploymentRootScope"": ""/providers/Microsoft.Management/managementGroups/epacroot""}]}"
        )
    
        $jsonpackage = $jsonstrings[0] + (New-Guid).Guid + $jsonstrings[1] + $ManagedIdentityLocation + $jsonstrings[2] + $Tenant + $jsonstrings[3]
    
        Set-Content -Value $jsonpackage -Path $DefinitionsPath\global-settings.jsonc -Encoding Ascii -Force
    
        Get-Content -Path $DefinitionsPath\global-settings.jsonc
    } else {
        Write-Output "Location $ManagedIdentityLocation invalid. Please check the location with Get-AzLocation"
    }
} else {
    Write-Output "Definition path not found. Specify a valid definition folder path."
}