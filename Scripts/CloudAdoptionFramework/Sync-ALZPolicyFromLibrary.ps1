Param(
   
    [Parameter(Mandatory = $true)]
    [string] $DefinitionsRootFolder,

    [ValidateSet("ALZ", "AMBA")]
    [string]$Type = "ALZ",
 
    [Parameter(Mandatory = $true)]
    [string]$PacEnvironmentSelector,

    [string]$LibraryPath
)

if ($LibraryPath -eq "") {
    if ($Tag) {
        git clone --depth 1 --branch $Tag https://github.com/anwather/Azure-Landing-Zones-Library.git .\temp
        $LibraryPath = "./temp"
    }
    else {
        git clone --depth 1 https://github.com/anwather/Azure-Landing-Zones-Library.git .\temp
        $LibraryPath = "./temp"
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

try {
    $telemetryEnabled = (Get-Content $DefinitionsRootFolder/global-settings.jsonc | ConvertFrom-Json).telemetryOptOut
    $deploymentRootScope = (Get-Content $DefinitionsRootFolder/global-settings.jsonc | ConvertFrom-Json).pacEnvironments[0]
    if (!($telemetryEnabled)) {
        Write-Information "Telemetry is enabled"
        Submit-EPACTelemetry -Cuapid "pid-adaa7564-1962-46e6-92b4-735e91f76d43" -DeploymentRootScope $deploymentRootScope
    }
    else {
        Write-Information "Telemetry is disabled"
    }
}
catch {}

# Create policy definition objects

foreach ($file in Get-ChildItem -Path "$LibraryPath\platform\$($Type.ToLower())\policy_definitions" -Recurse -File -Include *.json) {
    $fileContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
    $baseTemplate = [ordered]@{
        name       = $fileContent.name
        properties = $fileContent.properties
    }
    $category = $baseTemplate.properties.Metadata.category
    ($baseTemplate | Select-Object name, properties | ConvertTo-Json -Depth 50) -replace "\[\[", "[" | New-Item -Path $DefinitionsRootFolder\policyDefinitions\$Type\$category -ItemType File -Name "$($fileContent.name).json" -Force -ErrorAction SilentlyContinue
}

# Create policy set definition objects

foreach ($file in Get-ChildItem -Path "$LibraryPath\platform\$($Type.ToLower())\policy_set_definitions" -Recurse -File -Include *.json) {
    $fileContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
    $baseTemplate = [ordered]@{
        name       = $fileContent.name
        properties = @{
            description            = $fileContent.properties.description
            displayName            = $fileContent.properties.displayName
            metadata               = $fileContent.properties.metadata
            parameters             = $fileContent.properties.parameters
            policyType             = $fileContent.properties.policyType
            policyDefinitionGroups = $fileContent.properties.policyDefinitionGroups
        }
    }
    $policyDefinitions = @()
    # Fix the policyDefinitionIds for custom policies
    foreach ($policyDefinition in $fileContent.properties.policyDefinitions) {
        $obj = @{
            parameters                  = $policyDefinition.parameters
            groupNames                  = $policyDefinition.groupNames
            policyDefinitionReferenceId = $policyDefinition.policyDefinitionReferenceId
        }
        if ($policyDefinition.policyDefinitionId -match "managementGroups") {
            $obj.Add("policyDefinitionName", $policyDefinition.policyDefinitionId.split("/")[-1])
        }
        else {
            $obj.Add("policyDefinitionId", $policyDefinition.policyDefinitionId)
        }
        $policyDefinitions += $obj
    }
    $baseTemplate.properties.policyDefinitions = $policyDefinitions

    $category = $baseTemplate.properties.Metadata.category
    ($baseTemplate | Select-Object name, properties | ConvertTo-Json -Depth 50) -replace "\[\[", "[" `
        -replace "variables\('scope'\)", "'/providers/Microsoft.Management/managementGroups/$managementGroupId'" `
        -replace "', '", "" `
        -replace "\[concat\(('(.+)')\)\]", "`$2" | New-Item -Path $DefinitionsRootFolder\policySetDefinitions\$Type\$category -ItemType File -Name "$($fileContent.name).json" -Force -ErrorAction SilentlyContinue
}

# Create assignment objects

try {
    $structureFile = Get-Content $DefinitionsRootFolder\$Type.policy_default_structure.json -ErrorAction Stop | ConvertFrom-Json
    switch ($structureFile.enforcementMode) {
        "Default" { $enforcementModeText = "must" }
        "DoNotEnforce" { $enforcementModeText = "should" }
    }
}
catch {
    Write-Host "No policy default structure file found. Please run New-ALZPolicyDefaultStructure.ps1 first and ensure the file is in the same directory as the global-settings.jsonc file"
    exit
}

foreach ($file in Get-ChildItem -Path "$LibraryPath\platform\$($Type.ToLower())\archetype_definitions" -Recurse -File -Include *.json) {
    $archetypeContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
    foreach ($requiredAssignment in $archetypeContent.policy_assignments) {
        switch ($Type) {
            "ALZ" { $fileContent = Get-ChildItem -Path $LibraryPath\platform\$Type\policy_assignments | Where-Object { $_.BaseName.Split(".")[0] -eq $requiredAssignment } | Get-Content -Raw | ConvertFrom-Json }
            "AMBA" { $fileContent = Get-ChildItem -Path $LibraryPath\platform\$Type\policy_assignments | Where-Object { $_.BaseName.Split(".")[0].Replace("_", "-") -eq $requiredAssignment } | Get-Content -Raw | ConvertFrom-Json }
            default { $fileContent = Get-ChildItem -Path $LibraryPath\platform\$Type\policy_assignments | Where-Object { $_.BaseName.Split(".")[0] -eq $requiredAssignment } | Get-Content -Raw | ConvertFrom-Json }
        }
        

        $baseTemplate = [ordered]@{
            "`$schema"      = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-assignment-schema.json"
            nodeName        = "$($archetypeContent.name)/$($fileContent.name)"
            assignment      = @{
                name        = $fileContent.Name
                displayName = $fileContent.properties.displayName
                description = $fileContent.properties.description
            }
            definitionEntry = @{
                displayName = $fileContent.properties.displayName
            }
            parameters      = @{}
            enforcementMode = $structureFile.enforcementMode
        }

        # Definition Version
        if ($null -ne $fileContent.properties.definitionVersion) {
            $baseTemplate.Add("definitionVersion", $fileContent.properties.definitionVersion)
        }
    
        # Definition Entry
        if ($fileContent.properties.policyDefinitionId -match "placeholder.+policySetDefinition") {
            $baseTemplate.definitionEntry.Add("policySetName", ($fileContent.properties.policyDefinitionId).Split("/")[-1])
        }
        elseif ($fileContent.properties.policyDefinitionId -match "placeholder.+policyDefinition") {
            $baseTemplate.definitionEntry.Add("policyName", ($fileContent.properties.policyDefinitionId).Split("/")[-1])
        }
        else {
            if ($fileContent.properties.policyDefinitionId -match "policySetDefinitions") {
                $baseTemplate.definitionEntry.Add("policySetId", ($fileContent.properties.policyDefinitionId))
            }
            else {
                $baseTemplate.definitionEntry.Add("policyId", ($fileContent.properties.policyDefinitionId))
            }
            
        }
    
        #Scope
        $scopeTrim = $file.BaseName.split(".")[0]
        if ($scopeTrim -eq "root") {
            $scopeTrim = "alz"
        }
        if ($scopeTrim -eq "landing_zones") {
            $scopeTrim = "landingzones"
        }
        $scope = @{
            $PacEnvironmentSelector = @(
                $structureFile.managementGroupNameMappings.$scopeTrim.value
            )
        }
        $baseTemplate.Add("scope", $scope)

        # Base Parameters
        if ($fileContent.name -ne "Deploy-Private-DNS-Zones") {
            foreach ($parameter in $fileContent.properties.parameters.psObject.Properties.Name) {
                $baseTemplate.parameters.Add($parameter, $fileContent.properties.parameters.$parameter.value)
            }
        }

        # Non-compliance messages
        if ($null -ne $fileContent.properties.nonComplianceMessages) {
            $obj = @(
                @{
                    message = $fileContent.properties.nonComplianceMessages.message -replace "{enforcementMode}", $enforcementModeText
                }
            )
            $baseTemplate.Add("nonComplianceMessages", $obj)
        }
    

        # Check for explicit parameters
        if ($fileContent.name -ne "Deploy-Private-DNS-Zones") {
            foreach ($key in $structureFile.defaultParameterValues.psObject.Properties.Name) {
                if ($structureFile.defaultParameterValues.$key.policy_assignment_name -eq $fileContent.name) {
                    $keyName = $structureFile.defaultParameterValues.$key.parameters.parameter_name
                    $baseTemplate.parameters.$keyName = $structureFile.defaultParameterValues.$key.parameters.value
                }
            }
        }
        else {
            $dnsZoneRegion = $structureFile.defaultParameterValues.private_dns_zone_region.parameters.value
            $dnzZoneSubscription = $structureFile.defaultParameterValues.private_dns_zone_subscription_id.parameters.value
            $dnzZoneResourceGroupName = $structureFile.defaultParameterValues.private_dns_zone_resource_group_name.parameters.value
            foreach ($parameter in $fileContent.properties.parameters.psObject.Properties.Name) {
                $value = "/subscriptions/$dnzZoneSubscription/resourceGroups/$dnzZoneResourceGroupName/providers/Microsoft.Network/privateDnsZones/$($fileContent.properties.parameters.$parameter.value.split("/")[-1])"
                #$value = $fileContent.properties.parameters.$parameter.value -replace "00000000-0000-0000-0000-000000000000", $dnzZoneSubscription -replace "placeholder", $dnzZoneResourceGroupName
                $baseTemplate.parameters.Add($parameter, $value)
            }
        }
        

        $category = $structureFile.managementGroupNameMappings.$scopeTrim.management_group_function
        ($baseTemplate | Select-Object "`$schema", nodeName, assignment, definitionEntry, definitionVersion, enforcementMode, parameters, nonComplianceMessages, scope | ConvertTo-Json -Depth 50) -replace "\[\[", "[" | New-Item -Path $DefinitionsRootFolder\policyAssignments\$Type\$category -ItemType File -Name "$($fileContent.name).json" -Force -ErrorAction SilentlyContinue
        if ($fileContent.name -eq "Deploy-Private-DNS-Zones") {
            (Get-Content $DefinitionsRootFolder\policyAssignments\$Type\$category\$($fileContent.name).json) -replace "\.ne\.", ".$dnsZoneRegion." | Set-Content $DefinitionsRootFolder\policyAssignments\$Type\$category\$($fileContent.name).json
        }
    }
    

}

if ($LibraryPath -eq "./temp") {
    Remove-Item ./temp -Recurse -Force -ErrorAction SilentlyContinue
}

