#Requires -PSEdition Core

Param(
    [Parameter(Mandatory = $true)] [string] $DefinitionsRootFolder,
    [ValidateSet('AzureCloud', 'AzureChinaCloud', 'AzureUSGovernment')]
    [string] $CloudEnvironment = 'AzureCloud'
)

if ($DefinitionsRootFolder -eq "") {
    if ($null -eq $env:PAC_DEFINITIONS_FOLDER) {
        if ($ModuleRoot) {
            $DefinitionsRootFolder = "./Definitions"
        }
        else {
            $DefinitionsRootFolder = "$PSScriptRoot/../../Definitions"
        }
    }
    else {
        $DefinitionsRootFolder = $env:PAC_DEFINITIONS_FOLDER
    }
}

New-Item -Path "$DefinitionsRootFolder\policyDefinitions" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$DefinitionsRootFolder\policyDefinitions\ALZ" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$DefinitionsRootFolder\policySetDefinitions" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$DefinitionsRootFolder\policySetDefinitions\ALZ" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$DefinitionsRootFolder\policyAssignments" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$DefinitionsRootFolder\policyAssignments\ALZ" -ItemType Directory -Force -ErrorAction SilentlyContinue

. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"

$defaultPolicyURIs = @(
    'https://raw.githubusercontent.com/Azure/Enterprise-Scale/main/eslzArm/managementGroupTemplates/policyDefinitions/policies.json'
)

foreach ($policyUri in $defaultPolicyURIs) {
    $rawContent = (Invoke-WebRequest -Uri $policyUri).Content | ConvertFrom-Json
    $jsonPolicyDefsHash = $rawContent.variables | ConvertTo-HashTable
    $jsonPolicyDefsHash.GetEnumerator() | Foreach-Object {
        if ($_.Key -match 'fxv') {
            $type = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Type
            if ($type -eq 'Microsoft.Authorization/policyDefinitions') {
                $name = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                $environments = ($_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties).metadata.alzCloudEnvironments
                if ($environments -contains $CloudEnvironment) {
                    $baseTemplate = @{
                        name       = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                        properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                    }
                    $category = $baseTemplate.properties.Metadata.category
                    if (!(Test-Path $DefinitionsRootFolder\policyDefinitions\ALZ\$category)) {
                        New-Item -Path $DefinitionsRootFolder\policyDefinitions\ALZ\$category -ItemType Directory -Force -ErrorAction SilentlyContinue
                    }
                    $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $DefinitionsRootFolder\policyDefinitions\ALZ\$category\$name.json -Force
                    (Get-Content $DefinitionsRootFolder\policyDefinitions\ALZ\$category\$name.json) -replace "\[\[", "[" | Set-Content $DefinitionsRootFolder\policyDefinitions\ALZ\$category\$name.json
                }
                
            }
            if ($type -match 'Microsoft.Authorization/policySetDefinitions') {
                $name = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                $environments = ($_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties).metadata.alzCloudEnvironments
                if ($environments -contains $CloudEnvironment) {
                    if ($environments.Length -eq 3) {
                        $fileName = $name
                    }
                    else {
                        switch ($environments | Select-Object -First 1) {
                            "AzureChinaCloud" { $fileName = "$name.$_" }
                            "AzureUSGovernment" { $fileName = "$name.$_" }
                            "AzureCloud" { $fileName = $name }
                        }
                    }
                    $baseTemplate = @{
                        name       = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                        properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                    }
                    $category = $baseTemplate.properties.Metadata.category
                    if (!(Test-Path $DefinitionsRootFolder\policySetDefinitions\ALZ\$category)) {
                        New-Item -Path $DefinitionsRootFolder\policySetDefinitions\ALZ\$category -ItemType Directory -Force -ErrorAction SilentlyContinue
                    }
                    $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $DefinitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json -Force
                    (Get-Content $DefinitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json) -replace "\[\[", "[" | Set-Content $DefinitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json
                    (Get-Content $DefinitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json) -replace "variables\('scope'\)", "'/providers/Microsoft.Management/managementGroups/$managementGroupId'" | Set-Content $DefinitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json
                    (Get-Content $DefinitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json) -replace "', '", "" | Set-Content $DefinitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json
                    (Get-Content $DefinitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json) -replace "\[concat\(('(.+)')\)\]", "`$2" | Set-Content $DefinitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json
                }
                
            }
        }
    }
}

foreach ($policySetFile in Get-ChildItem "$DefinitionsRootFolder\policySetDefinitions\ALZ" -Recurse -Filter *.json) {
    $rawContent = Get-Content $policySetFile | ConvertFrom-Json -Depth 20
    $jsonContent = ConvertTo-HashTable $rawContent
    $jsonContent.properties.policyDefinitions | Foreach-Object {

        $_ | Add-Member -Type NoteProperty -Name policyDefinitionName -Value $_.policyDefinitionId.Split("/")[-1]
        $_.psObject.Properties.Remove('policyDefinitionId')

    }
    $jsonContent | ConvertTo-Json -Depth 20 | Set-Content $policySetFile
}

if ($ModuleRoot) {
    Copy-Item -Path "$ModuleRoot/policyAssignments/*.*" -Destination "$DefinitionsRootFolder\policyAssignments\ALZ\" -Force
}
else {
    Copy-Item -Path "$PSScriptRoot/policyAssignments/*.*" -Destination "$DefinitionsRootFolder\policyAssignments\ALZ\" -Force
}
