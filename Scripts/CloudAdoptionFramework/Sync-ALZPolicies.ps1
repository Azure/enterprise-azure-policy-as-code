#Requires -PSEdition Core

Param(
    [Parameter(Mandatory = $true)]
    [string] $DefinitionsRootFolder,

    [Parameter(Mandatory = $false)]
    [ValidateScript({ ($_ -eq 'latest') -or ($_.StartsWith("tags/")) }, ErrorMessage = "Allowed values are 'latest' and 'tags/TAG_NAME'")]
    [string] $GithubRelease = 'latest',

    [Parameter(Mandatory = $false)]
    [ValidateSet('AzureCloud', 'AzureChinaCloud', 'AzureUSGovernment')]
    [string] $CloudEnvironment = 'AzureCloud',

    [Parameter(Mandatory = $false)]
    [securestring] $GithubToken
)

# Setup headers for connecting to GitHub
$GitHubHeaders = @{
    'Accept'               = 'application/vnd.github.v3+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
if ($null -ne $GithubToken) {
    $GitHubHeaders['Authorization'] = "Bearer $((New-Object PSCredential 0, $GithubToken).GetNetworkCredential().Password)"
}
elseif ($null -ne $env:GITHUB_TOKEN) {
    $GitHubHeaders['Authorization'] = "Bearer $env:GITHUB_TOKEN"
}

Write-Warning "This command is deprecated and will be removed in a future release. Please see https://azure.github.io/enterprise-azure-policy-as-code/integrating-with-alz/ for details."

# Verify release exists
$GithubReleaseTag = Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/Azure/Enterprise-Scale/releases/$GithubRelease" -Headers $GitHubHeaders -ErrorAction Stop | Select-Object -ExpandProperty tag_name
$defaultPolicyURIs = @(
    "https://raw.githubusercontent.com/Azure/Enterprise-Scale/$GithubReleaseTag/eslzArm/managementGroupTemplates/policyDefinitions/policies.json",
    "https://raw.githubusercontent.com/Azure/Enterprise-Scale/$GithubReleaseTag/eslzArm/managementGroupTemplates/policyDefinitions/initiatives.json"
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

try {
    $telemetryEnabled = (Get-Content $DefinitionsRootFolder/global-settings.jsonc | ConvertFrom-Json).telemetryOptOut
    $deploymentRootScope = (Get-Content $DefinitionsRootFolder/global-settings.jsonc | ConvertFrom-Json).pacEnvironments[0]
    if (!($telemetryEnabled)) {
        Write-Information "Telemetry is enabled"
        Submit-EPACTelemetry -Cuapid "pid-a5e82cd0-9dda-417b-948c-68ec81596c32" -DeploymentRootScope $deploymentRootScope
    }
    else {
        Write-Information "Telemetry is disabled"
    }
}
catch {}

. "$PSScriptRoot/../Helpers/ConvertTo-HashTable.ps1"

foreach ($policyUri in $defaultPolicyURIs) {
    $rawContent = (Invoke-WebRequest -Uri $policyUri -Headers $GitHubHeaders).Content | ConvertFrom-Json
    $jsonPolicyDefsHash = $rawContent.variables | ConvertTo-HashTable
    $jsonPolicyDefsHash.GetEnumerator() | Foreach-Object {
        if ($_.Key -match 'fxv') {
            $type = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Type
            if ($type -eq 'Microsoft.Authorization/policyDefinitions') {
                $name = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                $environments = ($_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties).metadata.alzCloudEnvironments
                if ($environments -contains $CloudEnvironment) {
                    $baseTemplate = [ordered]@{
                        schema     = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-definition-schema.json"
                        name       = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                        properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                    }
                    $category = $baseTemplate.properties.Metadata.category
                    ($baseTemplate | ConvertTo-Json -Depth 50) -replace "\[\[", "[" | New-Item -Path $DefinitionsRootFolder\policyDefinitions\ALZ\$category -ItemType File -Name "$name.json" -Force -ErrorAction SilentlyContinue
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
                    $baseTemplate = [ordered]@{
                        schema     = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-set-definition-schema.json"
                        name       = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                        properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                    }
                    $category = $baseTemplate.properties.Metadata.category
                    ($baseTemplate | ConvertTo-Json -Depth 50) -replace "\[\[", "[" `
                        -replace "variables\('scope'\)", "'/providers/Microsoft.Management/managementGroups/$managementGroupId'" `
                        -replace "', '", "" `
                        -replace "\[concat\(('(.+)')\)\]", "`$2" | New-Item -Path $DefinitionsRootFolder\policySetDefinitions\ALZ\$category -ItemType File -Name "$fileName.json" -Force -ErrorAction SilentlyContinue
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

New-Item -Path "$DefinitionsRootFolder\policyAssignments\ALZ" -ItemType Directory -Force -ErrorAction SilentlyContinue
if ($ModuleRoot) {
    Copy-Item -Path "$ModuleRoot/policyAssignments/*.*" -Destination "$DefinitionsRootFolder\policyAssignments\ALZ\" -Force
}
else {
    Copy-Item -Path "$PSScriptRoot/policyAssignments/*.*" -Destination "$DefinitionsRootFolder\policyAssignments\ALZ\" -Force
}
