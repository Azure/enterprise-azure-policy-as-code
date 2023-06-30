#Requires -PSEdition Core

Param(
    [Parameter(Mandatory = $true)] [string] $DefinitionsRootFolder,
    [ValidateSet('AzureCloud', 'AzureChinaCloud', 'AzureUSGovernment')]
    [string] $CloudEnvironment = 'AzureCloud'
)

if ($definitionsRootFolder -eq "") {
    if ($null -eq $env:PAC_DEFINITIONS_FOLDER) {
        $definitionsRootFolder = "$PSScriptRoot/../../Definitions"
    }
    else {
        $definitionsRootFolder = $env:PAC_DEFINITIONS_FOLDER
    }
}

New-Item -Path "$definitionsRootFolder\policyDefinitions" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\policyDefinitions\ALZ" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\policySetDefinitions" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\policySetDefinitions\ALZ" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\policyAssignments" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$definitionsRootFolder\policyAssignments\ALZ" -ItemType Directory -Force -ErrorAction SilentlyContinue

. .\Scripts\Helpers\ConvertTo-HashTable.ps1

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
                    if (!(Test-Path $definitionsRootFolder\policyDefinitions\ALZ\$category)) {
                        New-Item -Path $definitionsRootFolder\policyDefinitions\ALZ\$category -ItemType Directory -Force -ErrorAction SilentlyContinue
                    }
                    $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $definitionsRootFolder\policyDefinitions\ALZ\$category\$name.json -Force
                    (Get-Content $definitionsRootFolder\policyDefinitions\ALZ\$category\$name.json) -replace "\[\[", "[" | Set-Content $definitionsRootFolder\policyDefinitions\ALZ\$category\$name.json
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
                    if (!(Test-Path $definitionsRootFolder\policySetDefinitions\ALZ\$category)) {
                        New-Item -Path $definitionsRootFolder\policySetDefinitions\ALZ\$category -ItemType Directory -Force -ErrorAction SilentlyContinue
                    }
                    $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $definitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json -Force
                    (Get-Content $definitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json) -replace "\[\[", "[" | Set-Content $definitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json
                    (Get-Content $definitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json) -replace "variables\('scope'\)", "'/providers/Microsoft.Management/managementGroups/$managementGroupId'" | Set-Content $definitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json
                    (Get-Content $definitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json) -replace "', '", "" | Set-Content $definitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json
                    (Get-Content $definitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json) -replace "\[concat\(('(.+)')\)\]", "`$2" | Set-Content $definitionsRootFolder\policySetDefinitions\ALZ\$category\$fileName.json
                }
                
            }
        }
    }
}

foreach ($policySetFile in Get-ChildItem "$definitionsRootFolder\policySetDefinitions\ALZ" -Recurse -Filter *.json) {
    $rawContent = Get-Content $policySetFile | ConvertFrom-Json -Depth 20
    $jsonContent = ConvertTo-HashTable $rawContent
    $jsonContent.properties.policyDefinitions | Foreach-Object {

        $_ | Add-Member -Type NoteProperty -Name policyDefinitionName -Value $_.policyDefinitionId.Split("/")[-1]
        $_.psObject.Properties.Remove('policyDefinitionId')

    }
    $jsonContent | ConvertTo-Json -Depth 20 | Set-Content $policySetFile
}

if ($ModuleRoot) {
    Copy-Item -Path $ModuleRoot\policyAssignments\*.* -Destination "$definitionsRootFolder\policyAssignments\ALZ\" -Force
}
else {
    Copy-Item -Path .\Scripts\CloudAdoptionFramework\policyAssignments\*.* -Destination "$definitionsRootFolder\policyAssignments\ALZ\" -Force
}
