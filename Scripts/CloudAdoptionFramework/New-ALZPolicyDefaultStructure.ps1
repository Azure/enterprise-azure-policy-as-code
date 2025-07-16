
Param(
    [Parameter(Mandatory = $true)]
    [string] $DefinitionsRootFolder,

    [ValidateSet('ALZ', 'FSI', 'AMBA', 'SLZ')]
    [string] $Type = 'ALZ',

    [string] $LibraryPath,

    [ValidateScript({ "refs/tags/$_" -in (Invoke-RestMethod -Uri 'https://api.github.com/repos/Azure/Azure-Landing-Zones-Library/git/refs/tags/').ref }, ErrorMessage = "Tag must be a valid tag." )]
    [string] $Tag,

    [string] $PacEnvironmentSelector
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

# Latest tag values
if ($Tag -eq "") {
    switch ($Type) {
        'ALZ' {
            $Tag = "platform/alz/2025.02.0"
        }
        'FSI' {
            $Tag = "platform/fsi/2025.03.0"
        }
        'AMBA' {
            $Tag = "platform/amba/2025.05.0"
        }
        'SLZ' {
            $Tag = "platform/slz/2025.03.0"
        }
    }
}

if ($LibraryPath -eq "") {
    $LibraryPath = Join-Path -Path (Get-Location) -ChildPath "temp"
}

git clone --config advice.detachedHead=false --depth 1 --branch $Tag https://github.com/Azure/Azure-Landing-Zones-Library.git $LibraryPath

$jsonOutput = [ordered]@{
    managementGroupNameMappings = [ordered]@{}
    enforcementMode             = "Default"
    defaultParameterValues      = [ordered]@{}
    enforceGuardrails           = @{
        deployments = @()
    }
}

# Get Management Group Names

$archetypeDefinitionFile = Get-Content -Path "$LibraryPath\platform\$($Type.ToLower())\architecture_definitions\$($Type.ToLower()).alz_architecture_definition.json" | ConvertFrom-Json

foreach ($mg in $archetypeDefinitionFile.management_groups) {
    $obj = @{
        management_group_function = $mg.display_Name
        value                     = "/providers/Microsoft.Management/managementGroups/$($mg.id)"
    }

    $jsonOutput.managementGroupNameMappings.Add($mg.id, $obj)
}

# Static Parameter Values

$additionalValues = @(
    [PSCustomObject]@{
        default_name       = "ama_mdfc_sql_workspace_region"
        description        = "The region short name (e.g. `westus`) that should be used for the Log Analytics workspace for the SQL MDFC deployment."
        policy_assignments = @(
            @{
                policy_assignment_name = "Deploy-MDFC-DefSQL-AMA"
                parameter_names        = @("workspaceRegion")
            }
        )
    },
    [PSCustomObject]@{
        default_name       = "mdfc_email_security_contact"
        description        = "Email address for Microsoft Defender for Cloud alerts."
        policy_assignments = @(
            @{
                policy_assignment_name = "Deploy-MDFC-Config-H224"
                parameter_names        = @("emailSecurityContact")
            }
        )
    },
    [PSCustomObject]@{
        default_name       = "mdfc_export_resource_group_name"
        description        = "Resource Group name for the export to Log Analytics workspace configuration"
        policy_assignments = @(
            @{
                policy_assignment_name = "Deploy-MDFC-Config-H224"
                parameter_names        = @("ascExportResourceGroupName")
            }
        )
    },
    [PSCustomObject]@{
        default_name       = "mdfc_export_resource_group_location"
        description        = "Resource Group location for the export to Log Analytics workspace configuration"
        policy_assignments = @(
            @{
                policy_assignment_name = "Deploy-MDFC-Config-H224"
                parameter_names        = @("ascExportResourceGroupLocation")
            }
        )
    }
)

# Build Parameter Values

$policyDefaultFile = Get-Content -Path "$LibraryPath\platform\$($Type.ToLower())\alz_policy_default_values.json" | ConvertFrom-Json

$policyDefaults = @()

$policyDefaults += $policyDefaultFile.defaults
if ($Type -eq "ALZ") {
    $additionalValues | ForEach-Object {
        $policyDefaults += $_
    }
}

foreach ($parameter in $policyDefaults) {
    # Grab the first policy assignment to grab default value of the parameter
    $parameterAssignmentName = $parameter.policy_assignments[0].parameter_names[0]
    $assignment = $parameter.policy_assignments[0]

    $assignmentFileName = ("$($assignment.policy_assignment_name).alz_policy_assignment.json")
    if ($Type -eq "AMBA") {
        $assignmentFileName = $assignmentFileName -replace ("-", "_")
    }
    $file = Get-ChildItem -Recurse -Path ".\temp" -Filter "$assignmentFileName" -File | Select-Object -First 1
    $jsonContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
    $tempDefaultParamValue = $jsonContent.properties.parameters.$parameterAssignmentName.value
    
    $obj = @(
        @{
            description            = $parameter.description
            policy_assignment_name = $parameter.policy_assignments.policy_assignment_name
            parameters             = @{
                parameter_name = $parameter.policy_assignments[0].parameter_names[0]
                value          = $tempDefaultParamValue
            }
        })

    $jsonOutput.defaultParameterValues.Add($parameter.default_name, $obj)
}

# Build Guardrail Deployment Object

if ($Type -eq "ALZ") {
    $guardRailPolicyFileNames = Get-ChildItem $LibraryPath\platform\$($Type.ToLower())\policy_set_definitions\*.json | Where-Object { $_.Name -match "^Enforce-Guardrails-" } | Select-Object -ExpandProperty Name
    $policySetNames = $guardRailPolicyFileNames | Foreach-Object { $_.Split(".")[0] }
    $obj = @{
        policy_set_names = $policySetNames
        scope            = @(
            "/providers/Microsoft.Management/managementGroups/landingzones",
            "/providers/Microsoft.Management/managementGroups/platform"
        )
    }
    $jsonOutput.enforceGuardrails.deployments += $obj
}


# Ensure the output directory exists
$outputDirectory = "$DefinitionsRootFolder\policyStructures"
if (-not (Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory
}

if ($PacEnvironmentSelector) {
    Out-File "$outputDirectory\$($Type.ToLower()).policy_default_structure.$PacEnvironmentSelector.jsonc" -InputObject ($jsonOutput | ConvertTo-Json -Depth 10) -Encoding utf8 -Force
}
else {
    Out-File "$outputDirectory\$($Type.ToLower()).policy_default_structure.jsonc" -InputObject ($jsonOutput | ConvertTo-Json -Depth 10) -Encoding utf8 -Force
}

$tempPath = Join-Path -Path (Get-Location) -ChildPath "temp"
if ($LibraryPath -eq $tempPath) {
    Remove-Item $LibraryPath -Recurse -Force -ErrorAction SilentlyContinue
}
