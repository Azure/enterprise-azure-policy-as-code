<#
.SYNOPSIS
    Creates a definitions folder with the correct folder structure and blank global settings file.
.DESCRIPTION
    Creates a definitions folder with the correct folder structure and blank global settings file.
.EXAMPLE
    New-HydrationDefinitionFolder -DefinitionsRootFolder = "Definitions"

    Scaffold a definitions folder called "Definitions"
#>
function New-HydrationDefinitionsFolder {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = "Definitions folder path. Defaults to environment variable `$env:PAC_DEFINITIONS_FOLDER or './Definitions'.")]
        [string]
        $DefinitionsRootFolder = "Definitions"
    )

    if (!(Test-Path $DefinitionsRootFolder)) {
        $null = New-Item -ItemType Directory -Name $DefinitionsRootFolder
        $ct = @'
{
    "$schema": "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json"
}
'@
    $ct | Set-Content -Path $DefinitionsRootFolder\global-settings.jsonc
    }
    @("policyAssignments", "policySetDefinitions", "policyDefinitions", "policyDocumentations") | ForEach-Object {
        $newPath = Join-Path -Path $DefinitionsRootFolder -ChildPath $_
        if(!(Test-Path $newPath)) {
            $null = New-Item -ItemType Directory -Path $newPath
        }
    }
}
