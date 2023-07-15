<#
.SYNOPSIS
    Creates a definitions folder with the correct folder structure and blank global settings file.
.DESCRIPTION
    Creates a definitions folder with the correct folder structure and blank global settings file.
.EXAMPLE
    New-EPACDefinitionFolder -DefinitionsRootFolder = "Definitions"

    Scaffold a definitions folder called "Definitions"
#>
[CmdletBinding()]

Param ([string]$DefinitionsRootFolder = "Definitions")

if (!(Test-Path $DefinitionsRootFolder)) {
    New-Item -ItemType Directory -Name $DefinitionsRootFolder
    "policyAssignments", "policySetDefinitions", "policyDefinitions", "policyDocumentations" | ForEach-Object {
        New-Item -ItemType Directory -Path $DefinitionsRootFolder\$_
    }

    $ct = @'
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json"
}
'@
    $ct | Set-Content -Path $DefinitionsRootFolder\global-settings.jsonc
}

