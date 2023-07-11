#Requires -PSEdition Core

Param(
    [Parameter(Mandatory = $true)] [string] $DefinitionsRootFolder,
    [ValidateSet('AzureCloud', 'AzureChinaCloud', 'AzureUSGovernment')]
    [string] $CloudEnvironment = 'AzureCloud'
)

Write-Warning -Message "This function will be renamed in a future release. Use Sync-ALZPolicies instead."

if ($DefinitionsRootFolder -eq "") {
    if ($null -eq $env:PAC_DEFINITIONS_FOLDER) {
        $DefinitionsRootFolder = "$PSScriptRoot/../../Definitions"
    }
    else {
        $DefinitionsRootFolder = $env:PAC_DEFINITIONS_FOLDER
    }
}

New-Item -Path "$DefinitionsRootFolder\policyDefinitions" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$DefinitionsRootFolder\policyDefinitions\CAF" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$DefinitionsRootFolder\policySetDefinitions" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$DefinitionsRootFolder\policySetDefinitions\CAF" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$DefinitionsRootFolder\policyAssignments" -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path "$DefinitionsRootFolder\policyAssignments\CAF" -ItemType Directory -Force -ErrorAction SilentlyContinue

. .\Scripts\Helpers\ConvertTo-HashTable.ps1

$defaultPolicyURIs = @(
    'https://raw.githubusercontent.com/Azure/Enterprise-Scale/main/eslzArm/managementGroupTemplates/policyDefinitions/policies.json'
)

foreach ($PolicyUri in $defaultPolicyURIs) {
    $rawContent = (Invoke-WebRequest -Uri $PolicyUri).Content | ConvertFrom-Json
    $jsonPolicyDefsHash = $rawContent.variables | ConvertTo-HashTable
    $jsonPolicyDefsHash.GetEnumerator() | Foreach-Object {
        if ($_.Key -match 'fxv') {
            $type = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Type
            if ($type -eq 'Microsoft.Authorization/policyDefinitions') {
                $Name = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                $environments = ($_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties).metadata.alzCloudEnvironments
                if ($environments -contains $CloudEnvironment) {
                    $baseTemplate = @{
                        name       = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                        properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                    }
                    $category = $baseTemplate.properties.Metadata.category
                    if (!(Test-Path $DefinitionsRootFolder\policyDefinitions\CAF\$category)) {
                        New-Item -Path $DefinitionsRootFolder\policyDefinitions\CAF\$category -ItemType Directory -Force -ErrorAction SilentlyContinue
                    }
                    $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $DefinitionsRootFolder\policyDefinitions\CAF\$category\$Name.json -Force
                    (Get-Content $DefinitionsRootFolder\policyDefinitions\CAF\$category\$Name.json) -replace "\[\[", "[" | Set-Content $DefinitionsRootFolder\policyDefinitions\CAF\$category\$Name.json
                }
                
            }
            if ($type -match 'Microsoft.Authorization/policySetDefinitions') {
                $Name = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                $environments = ($_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties).metadata.alzCloudEnvironments
                if ($environments -contains $CloudEnvironment) {
                    if ($environments.Length -eq 3) {
                        $fileName = $Name
                    }
                    else {
                        switch ($environments | Select-Object -First 1) {
                            "AzureChinaCloud" { $fileName = "$Name.$_" }
                            "AzureUSGovernment" { $fileName = "$Name.$_" }
                            "AzureCloud" { $fileName = $Name }
                        }
                    }
                    $baseTemplate = @{
                        name       = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                        properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                    }
                    $category = $baseTemplate.properties.Metadata.category
                    if (!(Test-Path $DefinitionsRootFolder\policySetDefinitions\CAF\$category)) {
                        New-Item -Path $DefinitionsRootFolder\policySetDefinitions\CAF\$category -ItemType Directory -Force -ErrorAction SilentlyContinue
                    }
                    $baseTemplate | ConvertTo-Json -Depth 50 | Out-File -FilePath $DefinitionsRootFolder\policySetDefinitions\CAF\$category\$fileName.json -Force
                    (Get-Content $DefinitionsRootFolder\policySetDefinitions\CAF\$category\$fileName.json) -replace "\[\[", "[" | Set-Content $DefinitionsRootFolder\policySetDefinitions\CAF\$category\$fileName.json
                    (Get-Content $DefinitionsRootFolder\policySetDefinitions\CAF\$category\$fileName.json) -replace "variables\('scope'\)", "'/providers/Microsoft.Management/managementGroups/$managementGroupId'" | Set-Content $DefinitionsRootFolder\policySetDefinitions\CAF\$category\$fileName.json
                    (Get-Content $DefinitionsRootFolder\policySetDefinitions\CAF\$category\$fileName.json) -replace "', '", "" | Set-Content $DefinitionsRootFolder\policySetDefinitions\CAF\$category\$fileName.json
                    (Get-Content $DefinitionsRootFolder\policySetDefinitions\CAF\$category\$fileName.json) -replace "\[concat\(('(.+)')\)\]", "`$2" | Set-Content $DefinitionsRootFolder\policySetDefinitions\CAF\$category\$fileName.json
                }
                
            }
        }
    }
}

foreach ($PolicySetFile in Get-ChildItem "$DefinitionsRootFolder\policySetDefinitions\CAF" -Recurse -Filter *.json) {
    $rawContent = Get-Content $PolicySetFile | ConvertFrom-Json -Depth 20
    $jsonContent = ConvertTo-HashTable $rawContent
    $jsonContent.properties.policyDefinitions | Foreach-Object {

        $_ | Add-Member -Type NoteProperty -Name policyDefinitionName -Value $_.policyDefinitionId.Split("/")[-1]
        $_.psObject.Properties.Remove('policyDefinitionId')

    }
    $jsonContent | ConvertTo-Json -Depth 20 | Set-Content $PolicySetFile
}

if ($ModuleRoot) {
    Copy-Item -Path $ModuleRoot\policyAssignments\*.* -Destination "$DefinitionsRootFolder\policyAssignments\CAF\" -Force
}
else {
    Copy-Item -Path .\Scripts\CloudAdoptionFramework\policyAssignments\*.* -Destination "$DefinitionsRootFolder\policyAssignments\CAF\" -Force
}
