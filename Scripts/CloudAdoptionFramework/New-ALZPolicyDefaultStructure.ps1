
Param(
    [Parameter(Mandatory = $true)]
    [string] $DefinitionsRootFolder,

    [ValidateSet('ALZ', 'FSI', 'AMBA', 'SLZ')]
    [string]$Type = 'ALZ',

    [string]$LibraryPath,

    [string]$Tag,

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

if ($LibraryPath -eq "") {
    $LibraryPath = Join-Path -Path (Get-Location) -ChildPath "temp"
    if ($Tag) {
        git clone --depth 1 --branch $Tag https://github.com/anwather/Azure-Landing-Zones-Library.git $LibraryPath
    }
    else {
        git clone --depth 1 https://github.com/anwather/Azure-Landing-Zones-Library.git $LibraryPath
    }
}

$jsonOutput = [ordered]@{
    managementGroupNameMappings = @{}
    enforcementMode             = "Default"
    defaultParameterValues      = @{}
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

# Build Parameter Values

$policyDefaultFile = Get-Content -Path "$LibraryPath\platform\$($Type.ToLower())\alz_policy_default_values.json" | ConvertFrom-Json

foreach ($parameter in $policyDefaultFile.defaults) {
    # Grab the first policy assignment to grab default value of the parameter
    $parameterAssignmentName = $parameter.policy_assignments[0].parameter_names[0]
    $assignment = $parameter.policy_assignments[0]

    $assingmentFileName = ("$($assignment.policy_assignment_name).alz_policy_assignment.json")
    if ($Type -eq "AMBA") {
        $assingmentFileName = $assingmentFileName -replace ("-", "_")
    }
    $file = Get-ChildItem -Recurse -Path ".\temp" -Filter "$assingmentFileName" -File | Select-Object -First 1
    $jsonContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
    $tempDefaultParamValue = $jsonContent.properties.parameters.$parameterAssignmentName.value
    
    $obj = @{
        description            = $parameter.description
        policy_assignment_name = $parameter.policy_assignments.policy_assignment_name
        parameters             = @{
            parameter_name = $parameter.policy_assignments[0].parameter_names[0]
            value          = $tempDefaultParamValue
        }
    }

    $jsonOutput.defaultParameterValues.Add($parameter.default_name, $obj)
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
