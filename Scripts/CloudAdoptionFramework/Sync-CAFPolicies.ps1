#Requires -PSEdition Core

Param(
    [Parameter(Mandatory = $false)] [string] $DefinitionsRootFolder
)

if ($definitionsRootFolder -eq "") {
    if ($null -eq $env:PAC_DEFINITIONS_FOLDER) {
        $definitionsRootFolder = "$PSScriptRoot/../../Definitions"
    } else {
        $definitionsRootFolder = $env:PAC_DEFINITIONS_FOLDER
    }
}

New-Item -Path "$definitionsRootFolder\Policies" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\policies\CAF" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\Initiatives" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\initiatives\CAF" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\Assignments" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\Assignments\CAF" -ItemType Directory -Force -ErrorAction SilentlyContinue

. .\Scripts\Helpers\ConvertTo-HashTable.ps1

$defaultPolicyURIs = @(
    'https://raw.githubusercontent.com/Azure/Enterprise-Scale/main/eslzArm/managementGroupTemplates/policyDefinitions/policies.json'
)

foreach ($policyUri in $defaultPolicyURIs) {
    $rawContent = (Invoke-WebRequest -Uri $policyUri).Content | ConvertFrom-Json
    $jsonPolicyDefsHash = $rawContent.variables | ConvertTo-HashTable
    $jsonPolicyDefsHash.GetEnumerator() | ForEach-Object {
        if ($_.Key -match 'fxv') {
            $type = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Type
            if ($type -eq 'Microsoft.Authorization/policyDefinitions') {
                $name = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                $baseTemplate = @{
                    name       = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                    properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                }
                $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $definitionsRootFolder\policies\CAF\$name.json -Force
                (Get-Content $definitionsRootFolder\policies\CAF\$name.json) -replace "\[\[", "[" | Set-Content $definitionsRootFolder\policies\CAF\$name.json
            }
            if ($type -match 'Microsoft.Authorization/policySetDefinitions') {
                $name = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                $environments = ($_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties).metadata.alzCloudEnvironments
                if ($environments.Length -eq 3) {
                    $fileName = $name
                } else {
                    switch ($environments | Select-Object -First 1) {
                        "AzureChinaCloud" { $fileName = "$name.$_" }
                        "AzureUSGovernment" { $fileName = "$name.$_" }
                        "AzureCloud" { $fileName = "$name" }
                    }
                }
                $baseTemplate = @{
                    name       = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                    properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                }
                $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $definitionsRootFolder\initiatives\CAF\$fileName.json -Force
                (Get-Content $definitionsRootFolder\initiatives\CAF\$fileName.json) -replace "\[\[", "[" | Set-Content $definitionsRootFolder\initiatives\CAF\$fileName.json
                (Get-Content $definitionsRootFolder\initiatives\CAF\$fileName.json) -replace "variables\('scope'\)", "'/providers/Microsoft.Management/managementGroups/$managementGroupId'" | Set-Content $definitionsRootFolder\initiatives\CAF\$fileName.json
                (Get-Content $definitionsRootFolder\initiatives\CAF\$fileName.json) -replace "', '", "" | Set-Content $definitionsRootFolder\initiatives\CAF\$fileName.json
                (Get-Content $definitionsRootFolder\initiatives\CAF\$fileName.json) -replace "\[concat\(('(.+)')\)\]", "`$2" | Set-Content $definitionsRootFolder\initiatives\CAF\$fileName.json
            } 
            
        }
    }
}

foreach ($initiativeFile in Get-ChildItem $definitionsRootFolder\Initiatives\CAF -Filter *.json) {
    $rawContent = Get-Content $initiativeFile | ConvertFrom-Json -Depth 20
    $jsonContent = ConvertTo-HashTable $rawContent
    $jsonContent.properties.policyDefinitions | ForEach-Object {

        $_ | Add-Member -Type NoteProperty -Name policyDefinitionName -Value $_.policyDefinitionId.Split("/")[-1]
        $_.psObject.Properties.Remove('policyDefinitionId')

    }
    $jsonContent | ConvertTo-Json -Depth 20 | Set-Content $initiativeFile
}

Copy-Item -Path .\Scripts\CloudAdoptionFramework\Assignments\*.* -Destination "$definitionsRootFolder\assignments\CAF\" -Force
