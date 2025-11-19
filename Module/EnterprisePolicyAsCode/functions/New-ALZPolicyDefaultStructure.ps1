function New-ALZPolicyDefaultStructure {

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

# Dot Source Helper Scripts

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
            $Tag = "platform/alz/2025.09.3"
        }
        'FSI' {
            $Tag = "platform/fsi/2025.03.0"
        }
        'AMBA' {
            $Tag = "platform/amba/2025.11.0"
        }
        'SLZ' {
            $Tag = "platform/slz/2025.10.1"
        }
    }
}

Write-ModernHeader -Title "Creating Policy Default Structure" -Subtitle "Type: $Type, Tag: $Tag"

if ($LibraryPath -eq "") {
    $LibraryPath = Join-Path -Path (Get-Location) -ChildPath "temp"
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

Write-ModernSection -Title "Processing Management Group Names" -Indent 0
# Get Management Group Names

$archetypeDefinitionFile = Get-Content -Path "$LibraryPath\platform\$($Type.ToLower())\architecture_definitions\$($Type.ToLower()).alz_architecture_definition.json" | ConvertFrom-Json

foreach ($mg in $archetypeDefinitionFile.management_groups) {
    $obj = @{
        management_group_function = $mg.display_Name
        value                     = "/providers/Microsoft.Management/managementGroups/$($mg.id)"
    }

    $jsonOutput.managementGroupNameMappings.Add($mg.id, $obj)
}

Write-ModernSection -Title "Building Parameter Values" -Indent 0
# Static Parameter Values

$additionalValues = @(
    
    [PSCustomObject]@{
        default_name       = "ama_mdfc_sql_workspace_id"
        description        = "Workspace Id of the Log Analytics workspace destination for the Data Collection Rule."
        policy_assignments = @(
            @{
                policy_assignment_name = "Deploy-MDFC-DefSQL-AMA"
                parameter_names        = @("userWorkspaceId")
            }
        )
    },
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
    if ($parameter.default_name -ne "log_analytics_workspace_id") {
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

Write-ModernSection -Title "Building Guardrail Deployment Object" -Indent 0
# Build Guardrail Deployment Object

if ($Type -eq "ALZ") {
    $guardRailPolicyFileNames = Get-ChildItem $LibraryPath\platform\$($Type.ToLower())\policy_set_definitions\*.json | Where-Object { ($_.Name -match "^Enforce-(Guardrails|Encryption)-") } | Select-Object -ExpandProperty Name
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

Write-ModernSection -Title "Writing Output Files" -Indent 0
# Ensure the output directory exists
$outputDirectory = "$DefinitionsRootFolder\policyStructures"
if (-not (Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory
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
}
