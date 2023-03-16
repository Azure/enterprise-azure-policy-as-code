<#
.SYNOPSIS
    Creates a definitions folder with the correct folder structure and blank global settings file.
.DESCRIPTION
    Creates a definitions folder with the correct folder structure and blank global settings file.
.EXAMPLE
    New-EPACDefinitionFolder -definitionsRootFolder = "Definitions"

    Scaffold a definitions folder called "Definitions"
#>
[CmdletBinding()]

Param ([string]$DefinitionsRootFolder = "Definitions")

if (!(Test-Path $DefinitionsRootFolder)) {
    New-Item -ItemType Directory -Name $DefinitionsRootFolder
    "policyAssignments", "policySetDefinitions", "policyDefinitions", "policyDocumentations" | ForEach-Object {
        New-Item -ItemType Directory -Path $DefinitionsRootFolder\$_
    }
    "{}" | Set-Content -Path $DefinitionsRootFolder\global-settings.jsonc
}

