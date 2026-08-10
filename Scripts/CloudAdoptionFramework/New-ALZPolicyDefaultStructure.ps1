
Param(
    [Parameter(Mandatory = $true)]
    [string] $DefinitionsRootFolder,

    [ValidateSet('ALZ', 'FSI', 'AMBA', 'SLZ')]
    [string] $Type = 'ALZ',

    [string] $LibraryPath,

    [ValidateScript({ "refs/tags/$_" -in (Invoke-RestMethod -Uri 'https://api.github.com/repos/Azure/Azure-Landing-Zones-Library/git/refs/tags/').ref }, ErrorMessage = "Tag must be a valid tag." )]
    [string] $Tag,

    [Parameter(Mandatory = $true)]
    [string] $PacEnvironmentSelector,

    [switch] $GenerateParameterFile
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

if ($GenerateParameterFile -and $Type -ne "AMBA") {
    throw "-GenerateParameterFile is only supported when -Type is AMBA."
}

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
            $Tag = "platform/alz/2026.04.2"
        }
        'FSI' {
            $Tag = "platform/fsi/2025.03.0"
        }
        'AMBA' {
            $Tag = "platform/amba/2026.06.1"
        }
        'SLZ' {
            $Tag = "platform/slz/2026.04.2"
        }
    }
}

Write-ModernHeader -Title "Creating Policy Default Structure" -Subtitle "Type: $Type, Tag: $Tag"

if ($LibraryPath -eq "") {
    $LibraryPath = Join-Path -Path (Get-Location) -ChildPath "temp"
    if (Test-Path $LibraryPath) {
        Write-ModernStatus -Message "Removing existing temp folder..." -Status "processing" -Indent 2
        Remove-Item -Path $LibraryPath -Recurse -Force
    }
    Write-ModernStatus -Message "Cloning Azure Landing Zones Library repository..." -Status "processing" -Indent 2
    git clone --config advice.detachedHead=false --depth 1 --branch $Tag https://github.com/Azure/Azure-Landing-Zones-Library.git $LibraryPath
    if ($LASTEXITCODE -eq 0) {
        Write-ModernStatus -Message "Repository cloned successfully" -Status "success" -Indent 4
    }
    else {
        Write-ModernStatus -Message "Failed to clone repository" -Status "error" -Indent 4
        exit 1
    }
}

$jsonOutput = [ordered]@{
    "`$schema"                  = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-structure-schema.json"
    managementGroupNameMappings = [ordered]@{}
    enforcementMode             = "Default"
    defaultParameterValues      = [ordered]@{}
    enforceGuardrails           = @{
        deployments = @()
    }
}

if ($Type -eq "SLZ") {
    $jsonOutput.Add("archetypeScopeMappings", [ordered]@{})
}

Write-ModernSection -Title "Processing Management Group Names" -Indent 0
# Get Management Group Names

$archetypeDefinitionFile = Get-Content -Path "$LibraryPath\platform\$($Type.ToLower())\architecture_definitions\$($Type.ToLower()).alz_architecture_definition.json" | ConvertFrom-Json

foreach ($mg in $archetypeDefinitionFile.management_groups) {
    $obj = @{
        management_group_function = $mg.display_Name
        value                     = "/providers/Microsoft.Management/managementGroups/$($mg.id)"
    }

    $jsonOutput.managementGroupNameMappings.Add($mg.id, $obj)

    if ($Type -eq "SLZ") {
        foreach ($archetype in $mg.archetypes | Where-Object { $_ -match "sovereign" }) {
            if ([string]::IsNullOrWhiteSpace($archetype)) {
                continue
            }

            if (-not $jsonOutput.archetypeScopeMappings.Contains($archetype)) {
                $jsonOutput.archetypeScopeMappings.Add($archetype, @())
            }

            $scopeValue = "/providers/Microsoft.Management/managementGroups/$($mg.id)"
            if ($scopeValue -notin $jsonOutput.archetypeScopeMappings.$archetype) {
                $jsonOutput.archetypeScopeMappings.$archetype += $scopeValue
            }
        }
    }
}

Write-ModernSection -Title "Building Parameter Values" -Indent 0

# Build Parameter Values

$policyDefaultFile = Get-Content -Path "$LibraryPath\platform\$($Type.ToLower())\alz_policy_default_values.json" | ConvertFrom-Json

$policyDefaults = @()

$policyDefaults += $policyDefaultFile.defaults

foreach ($parameter in $policyDefaults) {
    if ($parameter.default_name -ne "log_analytics_workspace_id" -and $parameter.default_name -ne "resource_group_location") {
        # Grab the first policy assignment to grab default value of the parameter
        $parameterAssignmentName = $parameter.policy_assignments[0].parameter_names[0]
        $assignment = $parameter.policy_assignments[0]
        $assignmentFileName = ("$($assignment.policy_assignment_name).alz_policy_assignment.json")
        $file = Get-ChildItem -Recurse -Path $LibraryPath -Filter "$assignmentFileName" -File | Select-Object -First 1
        try {
            $jsonContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        }
        catch {
            Write-ModernStatus -Message "Could not find assignment file: $assignmentFileName" -Status "warning" -Indent 4
            continue
        }
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
    else {
        $suffix = 0
        foreach ($name in $parameter.policy_assignments.parameter_names | Group-Object | Select-Object -ExpandProperty Name) {
            $parameterAssignmentName = $name
            $assignments = $parameter.policy_assignments | Where-Object { $_.parameter_names -contains $parameterAssignmentName }
            $assignment = $assignments[0]

            $assignmentFileName = ("$($assignment.policy_assignment_name).alz_policy_assignment.json")
            if ($Type -eq "AMBA") {
                $assignmentFileName = $assignmentFileName -replace ("-", "_")
            }
            $file = Get-ChildItem -Recurse -Path $LibraryPath -Filter "$assignmentFileName" -File | Select-Object -First 1
            try {
                $jsonContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            }
            catch {
                Write-ModernStatus -Message "Could not find assignment file: $assignmentFileName" -Status "warning" -Indent 6
                continue
            }
            $tempDefaultParamValue = $jsonContent.properties.parameters.$parameterAssignmentName.value
    
            $obj = @(
                @{
                    description            = $parameter.description
                    policy_assignment_name = $assignments.policy_assignment_name
                    parameters             = @{
                        parameter_name = [string]$assignment.parameter_names[0]
                        value          = $tempDefaultParamValue
                    }
                })

            $jsonOutput.defaultParameterValues.Add("$($parameter.default_name)_$suffix", $obj)
            $suffix++
        }
    }
}

# Write-ModernSection -Title "Building Guardrail Deployment Object" -Indent 0
# # Build Guardrail Deployment Object

# if ($Type -eq "ALZ") {
#     $guardRailPolicyFileNames = Get-ChildItem $LibraryPath\platform\$($Type.ToLower())\policy_set_definitions\*.json | Where-Object { ($_.Name -match "^Enforce-(Guardrails|Encryption)-") } | Select-Object -ExpandProperty Name
#     $policySetNames = $guardRailPolicyFileNames | Foreach-Object { $_.Split(".")[0] }
#     $obj = @{
#         policy_set_names = $policySetNames
#         scope            = @(
#             "/providers/Microsoft.Management/managementGroups/landingzones",
#             "/providers/Microsoft.Management/managementGroups/platform"
#         )
#     }
#     $jsonOutput.enforceGuardrails.deployments += $obj
# }

Write-ModernSection -Title "Writing Output Files" -Indent 0
# Ensure the output directory exists
$outputDirectory = "$DefinitionsRootFolder\policyStructures"
if (-not (Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory
}

if ($GenerateParameterFile) {
    $policySetDirectory = Join-Path $LibraryPath "platform\$($Type.ToLower())\policy_set_definitions"
    if (-not (Test-Path -Path $policySetDirectory)) {
        throw "Policy set definition directory not found: $policySetDirectory"
    }

    $policySetFiles = @(Get-ChildItem -Path $policySetDirectory -Filter "*.json" -File)
    if ($policySetFiles.Count -eq 0) {
        throw "No policy set definitions found in: $policySetDirectory"
    }

    $policySetsByName = @{}
    foreach ($policySetFile in $policySetFiles) {
        try {
            $policySet = Get-Content -Path $policySetFile.FullName -Raw | ConvertFrom-Json
        }
        catch {
            throw "Could not read policy set definition '$($policySetFile.FullName)': $($_.Exception.Message)"
        }

        if ([string]::IsNullOrWhiteSpace($policySet.name)) {
            throw "Policy set definition '$($policySetFile.FullName)' does not contain a name."
        }
        if ($policySetsByName.ContainsKey($policySet.name)) {
            throw "Duplicate policy set name '$($policySet.name)' found in: $policySetDirectory"
        }

        $policySetsByName.Add($policySet.name, $policySet)
    }

    $policySetNames = [string[]] @($policySetsByName.Keys)
    [Array]::Sort($policySetNames, [System.StringComparer]::Ordinal)

    $parameterFileContent = [System.Text.StringBuilder]::new()
    $null = $parameterFileContent.AppendLine("{")

    for ($policySetIndex = 0; $policySetIndex -lt $policySetNames.Count; $policySetIndex++) {
        $policySet = $policySetsByName[$policySetNames[$policySetIndex]]
        $policySetName = ConvertTo-Json -InputObject ([string] $policySet.name) -Compress
        $null = $parameterFileContent.AppendLine("  $policySetName`: {")
        $parameterNames = [string[]] @($policySet.properties.parameters.PSObject.Properties.Name | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        [Array]::Sort($parameterNames, [System.StringComparer]::Ordinal)

        for ($parameterIndex = 0; $parameterIndex -lt $parameterNames.Count; $parameterIndex++) {
            $parameter = $policySet.properties.parameters.PSObject.Properties[$parameterNames[$parameterIndex]]
            $allowedValues = $parameter.Value.PSObject.Properties["allowedValues"]
            if ($null -ne $allowedValues) {
                $allowedValuesJson = ConvertTo-Json -InputObject $allowedValues.Value -Depth 100 -Compress
                $null = $parameterFileContent.AppendLine("    // allowedValues: $allowedValuesJson")
            }

            $parameterName = ConvertTo-Json -InputObject ([string] $parameter.Name) -Compress
            $defaultValue = ConvertTo-Json -InputObject $parameter.Value.defaultValue -Depth 100 -Compress
            $parameterSuffix = if ($parameterIndex -lt ($parameterNames.Count - 1)) { "," } else { "" }
            $null = $parameterFileContent.AppendLine("    $parameterName`: $defaultValue$parameterSuffix")
        }

        $policySetSuffix = if ($policySetIndex -lt ($policySetNames.Count - 1)) { "," } else { "" }
        $null = $parameterFileContent.AppendLine("  }$policySetSuffix")
    }

    $null = $parameterFileContent.AppendLine("}")
    $parameterFilePath = Join-Path $outputDirectory "$($Type.ToLower()).policy_set_parameters.jsonc"
    Out-File -FilePath $parameterFilePath -InputObject $parameterFileContent.ToString() -Encoding utf8 -Force
    Write-ModernStatus -Message "Policy set parameter file: $parameterFilePath" -Status "success" -Indent 2
}

if ($PacEnvironmentSelector) {
    Out-File "$outputDirectory\$($Type.ToLower()).policy_default_structure.$PacEnvironmentSelector.jsonc" -InputObject ($jsonOutput | ConvertTo-Json -Depth 10) -Encoding utf8 -Force
    Write-ModernStatus -Message "Default structure file: $outputDirectory\$($Type.ToLower()).policy_default_structure.$PacEnvironmentSelector.jsonc" -Status "success" -Indent 2
}
else {
    Out-File "$outputDirectory\$($Type.ToLower()).policy_default_structure.jsonc" -InputObject ($jsonOutput | ConvertTo-Json -Depth 10) -Encoding utf8 -Force
    Write-ModernStatus -Message "Default structure file: $outputDirectory\$($Type.ToLower()).policy_default_structure.jsonc" -Status "success" -Indent 2
}

$tempPath = Join-Path -Path (Get-Location) -ChildPath "temp"
if ($LibraryPath -eq $tempPath) {
    Remove-Item $LibraryPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-ModernStatus -Message "ALZ Policy default structure created successfully" -Status "success" -Indent 0
