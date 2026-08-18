
Param(
    [Parameter(Mandatory = $true)]
    [string] $DefinitionsRootFolder,

    [ValidateSet('ALZ', 'FSI', 'AMBA', 'SLZ', 'MLZ')]
    [string] $Type = 'ALZ',

    [string] $LibraryPath,

    [string] $Tag,

    [Parameter(Mandatory = $true)]
    [string] $PacEnvironmentSelector
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

# MLZ is sourced from a different repository (Azure/missionlz) so the Azure Landing Zones Library tag
# list does not apply to it. Validate the tag at runtime for every other type instead of using a
# parameter attribute, otherwise the MLZ code path would be forced to supply an ALZ library tag.
if ($Type -ne 'MLZ' -and -not [string]::IsNullOrWhiteSpace($Tag)) {
    if ("refs/tags/$Tag" -notin (Invoke-RestMethod -Uri 'https://api.github.com/repos/Azure/Azure-Landing-Zones-Library/git/refs/tags/').ref) {
        throw "Tag must be a valid tag."
    }
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
            $Tag = "platform/alz/2026.08.0"
        }
        'FSI' {
            $Tag = "platform/fsi/2025.03.0"
        }
        'AMBA' {
            $Tag = "platform/amba/2026.06.2"
        }
        'SLZ' {
            $Tag = "platform/slz/2026.08.0"
        }
    }
}

if ($Type -eq 'MLZ') {
    Write-ModernHeader -Title "Creating Policy Default Structure" -Subtitle "Type: $Type"
}
else {
    Write-ModernHeader -Title "Creating Policy Default Structure" -Subtitle "Type: $Type, Tag: $Tag"
}

#region MLZ
# Mission Landing Zone (https://github.com/Azure/missionlz) has none of the Azure Landing Zones Library
# structure - no architecture definitions, archetypes or alz_policy_default_values.json. Its policy content
# is a set of flat parameter maps under src/policies that are assigned against built-in initiatives at
# subscription/resource group scope. The structure file therefore cannot be produced by the library code
# path below and is built here instead.
#
# Only the handful of values that src/modules/policy-assignment.bicep injects at deployment time are stubbed
# here, because they cannot be sourced from the repository. The several hundred baseline parameter values are
# deliberately not stubbed - they are read straight from the cloned missionlz repository during the sync step.
# Each stub fans out to the differently named parameter that each baseline uses for the same underlying value.
if ($Type -eq 'MLZ') {
    Write-ModernSection -Title "Building MLZ Structure" -Indent 0

    $mlzOutput = [ordered]@{
        "`$schema"                  = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-structure-schema.json"
        managementGroupNameMappings = [ordered]@{
            mlz = [ordered]@{
                management_group_function = "Mission Landing Zone"
                value                     = "/subscriptions/00000000-0000-0000-0000-000000000000"
            }
        }
        enforcementMode             = "Default"
        defaultParameterValues      = [ordered]@{
            log_analytics_workspace_resource_id     = @(
                [ordered]@{
                    policy_assignment_name = "NISTRev4"
                    description            = "Resource ID of the Log Analytics workspace used for VM reporting."
                    parameters             = [ordered]@{
                        parameter_name = "logAnalyticsWorkspaceIdforVMReporting"
                        value          = ""
                    }
                }
                [ordered]@{
                    policy_assignment_name = "IL5"
                    description            = "Resource ID of the Log Analytics workspace used by the VM agents."
                    parameters             = [ordered]@{
                        parameter_name = "logAnalyticsWorkspaceIDForVMAgents"
                        value          = ""
                    }
                }
                [ordered]@{
                    policy_assignment_name = @(
                        "Deploy-VMSS-Agents"
                        "Deploy-VM-Agents"
                    )
                    description            = "Resource ID of the Log Analytics workspace the deployed agents report to."
                    parameters             = [ordered]@{
                        parameter_name = "logAnalytics_1"
                        value          = ""
                    }
                }
            )
            log_analytics_workspace_customer_id     = @(
                [ordered]@{
                    policy_assignment_name = "CMMC"
                    description            = "Customer ID (workspace ID GUID, not the resource ID) of the Log Analytics workspace."
                    parameters             = [ordered]@{
                        parameter_name = "logAnalyticsWorkspaceId-f47b5582-33ec-4c5c-87c0-b010a6b2e917"
                        value          = ""
                    }
                }
            )
            windows_administrators_group_membership = @(
                [ordered]@{
                    policy_assignment_name = "NISTRev4"
                    description            = "Members to include in the Windows VM local administrators group."
                    parameters             = [ordered]@{
                        parameter_name = "listOfMembersToIncludeInWindowsVMAdministratorsGroup"
                        value          = ""
                    }
                }
                [ordered]@{
                    policy_assignment_name = "IL5"
                    description            = "Members to include in the Windows VM local administrators group."
                    parameters             = [ordered]@{
                        parameter_name = "membersToIncludeInLocalAdministratorsGroup"
                        value          = ""
                    }
                }
                [ordered]@{
                    policy_assignment_name = "CMMC"
                    description            = "Members to include in the Windows VM local administrators group. Only assigned in Azure commercial."
                    parameters             = [ordered]@{
                        parameter_name = "MembersToInclude-30f71ea1-ac77-4f26-9fc5-2d926bbd4ba7"
                        value          = ""
                    }
                }
            )
            windows_administrators_group_exclusions  = @(
                [ordered]@{
                    policy_assignment_name = "CMMC"
                    description            = "Members to exclude from the Windows VM local administrators group. Only assigned in Azure commercial."
                    parameters             = [ordered]@{
                        parameter_name = "MembersToExclude-69bf4abd-ca1e-4cf6-8b5a-762d42e61d4f"
                        value          = "admin"
                    }
                }
            )
        }
        enforceGuardrails           = @{
            deployments = @()
        }
    }

    Write-ModernStatus -Message "Added placeholder scope 'mlz' - replace the subscription id with the target subscription" -Status "info" -Indent 2
    Write-ModernStatus -Message "Added deployment time parameter stubs - populate them before running the sync" -Status "info" -Indent 2
    Write-ModernStatus -Message "Baseline parameter values are read from the missionlz repository during the sync step" -Status "info" -Indent 2

    Write-ModernSection -Title "Writing Output Files" -Indent 0
    $mlzOutputDirectory = "$DefinitionsRootFolder\policyStructures"
    if (-not (Test-Path -Path $mlzOutputDirectory)) {
        New-Item -ItemType Directory -Path $mlzOutputDirectory | Out-Null
    }

    if ($PacEnvironmentSelector) {
        $mlzOutputFile = "$mlzOutputDirectory\mlz.policy_default_structure.$PacEnvironmentSelector.jsonc"
    }
    else {
        $mlzOutputFile = "$mlzOutputDirectory\mlz.policy_default_structure.jsonc"
    }

    Out-File $mlzOutputFile -InputObject ($mlzOutput | ConvertTo-Json -Depth 10) -Encoding utf8 -Force
    Write-ModernStatus -Message "Default structure file: $mlzOutputFile" -Status "success" -Indent 2
    Write-ModernStatus -Message "MLZ Policy default structure created successfully" -Status "success" -Indent 0
    return
}
#endregion MLZ

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
