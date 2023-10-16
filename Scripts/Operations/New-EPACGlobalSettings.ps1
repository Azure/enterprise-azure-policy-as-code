<#
.SYNOPSIS
    Creates a global-settings.jsonc file with a new guid, managed identity location and tenant information

.DESCRIPTION
    Creates a global-settings.jsonc file with a new guid, managed identity location and tenant information

.PARAMETER ManagedIdentityLocation
    The Azure location to store the managed identities (Get-AzLocation|Select Location)

.PARAMETER Tenant
    The Azure tenant ID for the solution ((Get-AzContext).Tenant)

.PARAMETER DefinitionsRootFolder
    The folder path to where the New-EPACDefinitionsFolder command created the definitions root folder (C:\definitions\)

.PARAMETER DeploymentRootScope
    The root management group to export definitions and assignments (/providers/Microsoft.Management/managementGroups/)

.EXAMPLE
    .\New-EPACGlobalSettings.ps1 -ManagedIdentityLocation NorthCentralUS -TenantId 00000000-0000-0000-0000-000000000000 -DefinitionsRootFolder C:\definitions\ -DeploymentRootScope /providers/Microsoft.Management/managementGroups/mgroup1

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The Azure location to store the managed identities (Get-AzLocation|Select Location)")]
    [string]$ManagedIdentityLocation,

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "The Azure tenant ID for the solution ((Get-AzContext).Tenant)")]
    [string]$TenantId,

    [Parameter(Mandatory = $true, Position = 2, HelpMessage = "The folder path to where the New-EPACDefinitionsFolder command created the definitions root folder (C:\definitions\)")]
    [string]$DefinitionsRootFolder,

    [Parameter(Mandatory = $true, Position = 3, HelpMessage = "The root management group to export definitions and assignments (/providers/Microsoft.Management/managementGroups/)")]
    [string]$DeploymentRootScope
)

$DefinitionsRootFolder = $DefinitionsRootFolder.TrimEnd('\')

if ($DeploymentRootScope.StartsWith('/providers/Microsoft.Management/managementGroups')) {
    if (Test-Path -Path $DefinitionsRootFolder) {
        if (Get-AzLocation | Where-Object { $_.Location -eq $ManagedIdentityLocation }) {
            $jsonstrings = @("{""`$schema"": ""https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json"", ""pacOwnerId"": """,
                """, ""managedIdentityLocations"": { ""*"": """,
                """}, ""globalNotScopes"": { ""*"": [""/resourceGroupPatterns/excluded-rg*""] }, ""pacEnvironments"": [{ ""pacSelector"": ""quick-start"",""cloud"": ""AzureCloud"", ""tenantId"": """,
                """, ""deploymentRootScope"": ""$DeploymentRootScope""}]}"
            )
        
            $jsonpackage = $jsonstrings[0] + (New-Guid).Guid + $jsonstrings[1] + $ManagedIdentityLocation + $jsonstrings[2] + $TenantId + $jsonstrings[3]
            
            Set-Content -Value $jsonpackage -Path $DefinitionsRootFolder\global-settings.jsonc -Encoding Ascii -Force
    
            Get-Content -Path $DefinitionsRootFolder\global-settings.jsonc
        }
        else {
            Write-Output "Location $ManagedIdentityLocation invalid. Please check the location with Get-AzLocation"
        }
    }
    else {
        Write-Output "Definition path not found. Specify a valid definition folder path."
    }
}
else {
    Write-Output "Please provide the root management group path in the format /providers/Microsoft.Management/managementGroups/<MGName>"
}