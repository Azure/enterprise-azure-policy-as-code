#Requires -PSEdition Core

Param(
    [Parameter(Mandatory = $false)] [string] $DefinitionsRootFolder
)

if ($definitionsRootFolder -eq "") {
    if ($null -eq $env:PAC_DEFINITIONS_FOLDER) {
        $definitionsRootFolder = "$PSScriptRoot/../../Definitions"
    }
    else {
        $definitionsRootFolder = $env:PAC_DEFINITIONS_FOLDER
    }
}

New-Item -Path "$definitionsRootFolder\Policies" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\policies\CAF\CAF" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\Initiatives" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\initiatives\CAF\CAF" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\Assignments" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\Assignments\CAF" -ItemType Directory -Force -ErrorAction SilentlyContinue

. .\Scripts\Helpers\ConvertTo-HashTable.ps1

$defaultPolicyURIs = @(
    'https://raw.githubusercontent.com/Azure/Enterprise-Scale/main/eslzArm/managementGroupTemplates/policyDefinitions/policies.json'
)

foreach ($policyUri in $defaultPolicyURIs) {
    $rawContent = (Invoke-WebRequest -Uri $policyUri).Content | ConvertFrom-Json
    $rawContent.variables[0].policies.policyDefinitions | Foreach-Object {
        $baseTemplate = @{
            name       = $_.Name
            properties = $_.properties
        }
        $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $definitionsRootFolder\policies\CAF\$($_.Name).json -Force
        (Get-Content $definitionsRootFolder\policies\CAF\$($_.Name).json) -replace "\[\[", "[" | Set-Content $definitionsRootFolder\policies\CAF\$($_.Name).json
    }
    $rawContent.variables[0].initiatives.policySetDefinitions | Foreach-Object {
        $baseTemplate = @{
            name       = $_.Name
            properties = $_.properties
        }
        $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $definitionsRootFolder\initiatives\CAF\$($_.Name).json -Force
        (Get-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json) -replace "\[\[", "[" | Set-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json
        (Get-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json) -replace "variables\('scope'\)", "'/providers/Microsoft.Management/managementGroups/$managementGroupId'" | Set-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json
        (Get-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json) -replace "', '", "" | Set-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json
        (Get-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json) -replace "\[concat\(('(.+)')\)\]", "`$2" | Set-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json
    }
}

$additionalPolicyURIs = @(
    'https://raw.githubusercontent.com/Azure/Enterprise-Scale/main/eslzArm/managementGroupTemplates/policyDefinitions/DENY-PublicEndpointsPolicySetDefinition.json',
    'https://raw.githubusercontent.com/Azure/Enterprise-Scale/main/eslzArm/managementGroupTemplates/policyDefinitions/DINE-PrivateDNSZonesPolicySetDefinition.json'
)

foreach ($policyUri in $additionalPolicyURIs) {
    $rawContent = (Invoke-WebRequest -Uri $policyUri).Content | ConvertFrom-Json
    $rawContent.resources | Foreach-Object {
        $baseTemplate = @{
            name       = $_.Name
            properties = $_.properties
        }
        $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $definitionsRootFolder\initiatives\CAF\$($_.Name).json -Force
        (Get-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json) -replace "\[\[", "[" | Set-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json
        (Get-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json) -replace "variables\('scope'\)", "'/providers/Microsoft.Management/managementGroups/$($v.($globals.tenantId).id)'" | Set-Content $definitionsRootFolder\initiatives\CAF\$($_.Name).json
    }
}



foreach ($initiativeFile in Get-ChildItem $definitionsRootFolder\Initiatives -Filter *.json) {
    $rawContent = Get-Content $initiativeFile | ConvertFrom-Json -Depth 20
    $jsonContent = ConvertTo-HashTable $rawContent
    $jsonContent.properties.policyDefinitions | Foreach-Object {

        $_ | Add-Member -Type NoteProperty -Name policyDefinitionName -Value $_.policyDefinitionId.Split("/")[-1]
        $_.psObject.Properties.Remove('policyDefinitionId')

    }
    $jsonContent | ConvertTo-Json -Depth 20 | Set-Content $initiativeFile
}

Copy-Item -Path .\Scripts\CloudAdoptionFramework\Assignments\*.json -Destination "$definitionsRootFolder\assignments\CAF\" -Force