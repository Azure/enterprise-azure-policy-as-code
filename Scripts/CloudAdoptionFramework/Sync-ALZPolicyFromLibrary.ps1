Param(
    [Parameter(Mandatory = $true)]
    [string] $DefinitionsRootFolder,

    [ValidateSet("ALZ", "AMBA", "FSI", "SLZ")]
    [string] $Type = "ALZ",
 
    [Parameter(Mandatory = $true)]
    [string] $PacEnvironmentSelector,

    [string] $LibraryPath,

    [ValidateScript({ "refs/tags/$_" -in (Invoke-RestMethod -Uri 'https://api.github.com/repos/Azure/Azure-Landing-Zones-Library/git/refs/tags/').ref }, ErrorMessage = "Tag must be a valid tag." )]
    [string] $Tag,
    
    [switch] $CreateGuardrailAssignments,

    [switch] $EnableOverrides
)

# Dot Source Helper Scripts
. "$PSScriptRoot/../Helpers/Add-HelperScripts.ps1"

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

Write-ModernHeader -Title "Syncing Policies From Library" -Subtitle "Type: $Type, Tag: $Tag"

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

# Ensure the output directory exists
$structureDirectory = "$DefinitionsRootFolder\policyStructures"
if (-not (Test-Path -Path $structureDirectory)) {
    New-Item -ItemType Directory -Path $structureDirectory
}

try {
    $telemetryEnabled = (Get-Content $DefinitionsRootFolder/global-settings.jsonc | ConvertFrom-Json).telemetryOptOut
    $deploymentRootScope = (Get-Content $DefinitionsRootFolder/global-settings.jsonc | ConvertFrom-Json).pacEnvironments[0]
    if (!($telemetryEnabled)) {
        Write-ModernStatus -Message "Telemetry is enabled" -Status "info" -Indent 2
        Submit-EPACTelemetry -Cuapid "pid-adaa7564-1962-46e6-92b4-735e91f76d43" -DeploymentRootScope $deploymentRootScope
    }
    else {
        Write-ModernStatus -Message "Telemetry is disabled" -Status "info" -Indent 2
    }
}
catch {
    Write-ModernStatus -Message "Telemetry could not be enabled: $($_.Exception.Message)" -Status "warning" -Indent 2
}

Write-ModernSection -Title "Creating Policy Definition Objects" -Indent 0
#region Create policy definition objects
foreach ($file in Get-ChildItem -Path "$LibraryPath/platform/$($Type.ToLower())/policy_definitions" -Recurse -File -Include *.json) {
    $fileContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
    $baseTemplate = [ordered]@{
        '$schema'  = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-definition-schema.json"
        name       = $fileContent.name
        properties = $fileContent.properties
    }
    $category = $baseTemplate.properties.Metadata.category
    ([PSCustomObject]$baseTemplate | Select-Object -Property "`$schema", name, properties | ConvertTo-Json -Depth 50) -replace "\[\[", "[" | New-Item -Path "$DefinitionsRootFolder/policyDefinitions/$Type/$category" -ItemType File -Name "$($fileContent.name).json" -Force -ErrorAction SilentlyContinue
}
Write-ModernSection -Title "Creating Policy Set Definition Objects" -Indent 0
#endregion Create policy definition objects

#region Create policy set definition objects
foreach ($file in Get-ChildItem -Path "$LibraryPath/platform/$($Type.ToLower())/policy_set_definitions" -Recurse -File -Include *.json) {
    $fileContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
    $baseTemplate = [ordered]@{
        "`$schema" = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-set-definition-schema.json"
        name       = $fileContent.name
        properties = [ordered]@{
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
        $obj = [ordered]@{
            parameters                  = $policyDefinition.parameters
            groupNames                  = $policyDefinition.groupNames
            policyDefinitionReferenceId = $policyDefinition.policyDefinitionReferenceId
        }
        if ($policyDefinition.policyDefinitionId -match "managementGroups") {
            $obj.Add("policyDefinitionName", $policyDefinition.policyDefinitionId.split("/")[ - 1])
        }
        else {
            $obj.Add("policyDefinitionId", $policyDefinition.policyDefinitionId)
        }
        $policyDefinitions += $obj
    }
    $baseTemplate.properties.policyDefinitions = $policyDefinitions

    # Force property order
    $orderedProps = [ordered]@{
        description            = $baseTemplate.properties.description
        displayName            = $baseTemplate.properties.displayName
        metadata               = $baseTemplate.properties.metadata
        parameters             = $baseTemplate.properties.parameters
        policyDefinitions      = $baseTemplate.properties.policyDefinitions
        policyType             = $baseTemplate.properties.policyType
        policyDefinitionGroups = $baseTemplate.properties.policyDefinitionGroups
    }
    $baseTemplate.properties = $orderedProps

    $category = $baseTemplate.properties.Metadata.category
    ([PSCustomObject]$baseTemplate | Select-Object -Property "`$schema", name, properties | ConvertTo-Json -Depth 50) -replace "\[\[", "[" `
        -replace "variables\('scope'\)", "'/providers/Microsoft.Management/managementGroups/$managementGroupId'" `
        -replace "', '", "" `
        -replace "\[concat\(('(.+)')\)\]", "`$2" | New-Item -Path "$DefinitionsRootFolder/policySetDefinitions/$Type/$category" -ItemType File -Name "$($fileContent.name).json" -Force -ErrorAction SilentlyContinue
}
Write-ModernSection -Title "Creating Assignment Objects" -Indent 0
#endregion Create policy set definition objects

#region Create assignment objects
try {
    If (Test-Path -Path "$structureDirectory/$($Type.ToLower()).policy_default_structure.$PacEnvironmentSelector.jsonc") {
        $structureFilePath = "$structureDirectory/$($Type.ToLower()).policy_default_structure.$PacEnvironmentSelector.jsonc"
        $defaultStructurePAC = $PacEnvironmentSelector
    }
    else {
        $structureFilePath = "$structureDirectory/$($Type.ToLower()).policy_default_structure.jsonc"
        $defaultStructurePAC = $PacEnvironmentSelector
    }
    $structureFile = Get-Content $structureFilePath -Raw -ErrorAction Stop | ConvertFrom-Json
    Write-ModernStatus -Message "Policy default structure file: $structureFilePath" -Status "info" -Indent 2
    switch ($structureFile.enforcementMode) {
        "Default" { $enforcementModeText = "must" }
        "DoNotEnforce" { $enforcementModeText = "should" }
    }
}
catch {
    Write-ModernStatus -Message "Error reading the policy default structure file: $($_.Exception.Message)" -Status "error" -Indent 2
    Write-ModernStatus -Message "Please run New-ALZPolicyDefaultStructure.ps1 first" -Status "warning" -Indent 2
    exit
}

if ($EnableOverrides) {
    Write-ModernStatus -Message "Overrides enabled: Custom management group structures and assignments will be used where available." -Status "info" -Indent 2
    if ($structureFile.overrides.archetypes.ignore) {
        $ignoreArchetypes = $structureFile.overrides.archetypes.ignore
    }
    if ($structureFile.overrides.archetypes.custom) {
        $customArchetypes = $structureFile.overrides.archetypes.custom
    }
}

try {
    # Determine if custom archetypes should be injected
    $archetypeArray = @()
    foreach ($file in Get-ChildItem -Path "$LibraryPath/platform/$($Type.ToLower())/archetype_definitions" -Recurse -File -Include *.json) {
        $customArchetypeContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        $archetypeArray += $customArchetypeContent
    }
    foreach ($customArchetype in $customArchetypes) {
        #Check if included in management group mappings
        if (-not ($structureFile.managementGroupNameMappings.PSObject.Properties.Name -contains $customArchetype.name)) {
            Write-ModernStatus -Message "Custom archetype '$($customArchetype.name)' not found in management group mappings. Skipping." -Status "warning" -Indent 2
            continue
        }
        $archetypeArray += $customArchetype
    }
    # Modify default archetypes if requested
    $finalArchetypeArray = @()
    # Modify anything that is existing
    foreach ($archetype in $archetypeArray | Where-Object { $_.type -eq "existing" }) {
        $archetypeObj = @{
            name               = $archetype.name
            policy_assignments = $archetypeArray | Where-Object { $_.name -eq $archetype.name -and $_.PSObject.properties.name -notcontains "type" } | Select-Object -ExpandProperty policy_assignments | Where-Object { $_ -notin $archetype.policy_assignments_to_remove }
        }
        if ($archetype.policy_assignments_to_add) {
            $archetypeObj.policy_assignments += $archetype.policy_assignments_to_add
        }
        $finalArchetypeArray += $archetypeObj
    }
    foreach ($archetype in $archetypeArray | Where-Object { $_.type -ne "existing" -and $_.name -notin ($finalArchetypeArray.name) }) {
        $finalArchetypeArray += $archetype
    }

    foreach ($archetype in $finalArchetypeArray) {
        if ($archetype.name -in $ignoreArchetypes) {
            Write-ModernStatus -Message "Ignoring archetype: $($archetype.name)" -Status "info" -Indent 2
            continue
        }
        foreach ($requiredAssignment in ($archetype.policy_assignments | Where-Object { ($_ -notmatch "^Enforce-(GR|Encrypt)-\w+0") })) {
            switch ($Type) {
                "ALZ" { $fileContent = Get-ChildItem -Path "$LibraryPath/platform/$($Type.ToLower())/policy_assignments" | Where-Object { $_.BaseName.Split(".")[0] -eq $requiredAssignment } | Get-Content -Raw | ConvertFrom-Json }
                "AMBA" { $fileContent = Get-ChildItem -Path "$LibraryPath/platform/$($Type.ToLower())/policy_assignments" | Where-Object { $_.BaseName.Split(".")[0].Replace("_", "-") -eq $requiredAssignment } | Get-Content -Raw | ConvertFrom-Json }
                "SLZ" { $fileContent = Get-ChildItem -Path "$LibraryPath/platform/$($Type.ToLower())/policy_assignments" | Where-Object { $_.BaseName.Split(".")[0].Replace("_", "-") -eq $requiredAssignment } | Get-Content -Raw | ConvertFrom-Json }
                "FSI" { $fileContent = Get-ChildItem -Path "$LibraryPath/platform/$($Type.ToLower())/policy_assignments" | Where-Object { $_.BaseName.Split(".")[0].Replace("_", "-") -eq $requiredAssignment } | Get-Content -Raw | ConvertFrom-Json }
                default { $fileContent = Get-ChildItem -Path "$LibraryPath/platform/$($Type.ToLower())/policy_assignments" | Where-Object { $_.BaseName.Split(".")[0] -eq $requiredAssignment } | Get-Content -Raw | ConvertFrom-Json }
            }
        

            $baseTemplate = [ordered]@{
                "`$schema"      = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-assignment-schema.json"
                nodeName        = "$($archetype.name)/$($fileContent.name)"
                assignment      = [ordered]@{
                    name        = $fileContent.Name
                    displayName = $fileContent.properties.displayName
                    description = $fileContent.properties.description
                }
                definitionEntry = [ordered]@{
                    displayName = $fileContent.properties.displayName
                }
                parameters      = [ordered]@{}
                enforcementMode = $structureFile.enforcementMode
            }

            # Definition Version
            if ($null -ne $fileContent.properties.definitionVersion) {
                $baseTemplate.Add("definitionVersion", $fileContent.properties.definitionVersion)
            }
    
            # Definition Entry
            if ($fileContent.properties.policyDefinitionId -match "placeholder.+policySetDefinition") {
                $baseTemplate.definitionEntry.Add("policySetName", ($fileContent.properties.policyDefinitionId).Split("/")[ - 1])
            }
            elseif ($fileContent.properties.policyDefinitionId -match "placeholder.+policyDefinition") {
                $baseTemplate.definitionEntry.Add("policyName", ($fileContent.properties.policyDefinitionId).Split("/")[ - 1])
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
            $scopeTrim = $archetype.name
            if ($scopeTrim -eq "root") {
                $scopeTrim = "alz"
            }
            if ($scopeTrim -eq "landing_zones") {
                $scopeTrim = "landingzones"
            }
            if ($scopeTrim -eq "global") {
                $scopeTrim = "mcfs"
            }
            if ($Type -eq "FSI" -and $scopeTrim -ne "confidential") {
                $scopeTrim = "fsi"
            }
            if ($scopeTrim -eq "confidential") {
                $scopes = foreach ($key in $structureFile.managementGroupNameMappings.psObject.Properties.Name) {
                    if ($structureFile.managementGroupNameMappings.$key.management_group_function -match $scopeTrim) {
                        # Handle both string and array values
                        $value = $structureFile.managementGroupNameMappings.$key.value
                        if ($value -is [array]) {
                            $value
                        }
                        else {
                            $value
                        }
                    }
                }
                $scope = [ordered]@{
                    $PacEnvironmentSelector = $scopes
                }
            }
            else {
                # Handle both string and array values for regular scope mappings
                $scopeValue = $structureFile.managementGroupNameMappings.$scopeTrim.value
                if ($scopeValue -is [array]) {
                    $scope = [ordered]@{
                        $PacEnvironmentSelector = $scopeValue
                    }
                }
                else {
                    $scope = [ordered]@{
                        $PacEnvironmentSelector = @(
                            $scopeValue
                        )
                    }
                }
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
                # Check for override parameter values
                if ($EnableOverrides) {
                    if ($structureFile.overrides.parameters.$($archetype.name)) {
                        foreach ($overrideParameters in $structureFile.overrides.parameters.$($archetype.name) | Where-Object { $_.policy_assignment_name -eq $fileContent.name }) {
                            foreach ($param in $overrideParameters.parameters) {
                                $baseTemplate.parameters[$param.parameter_name] = $param.value
                            }
                        }
                        
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
                
                $additionalRoleAssignments = @{
                    $PacEnvironmentSelector = @(
                        @{
                            roleDefinitionId = "/providers/microsoft.authorization/roleDefinitions/b12aa53e-6015-4669-85d0-8515ebb3ae7f"
                            scope            = "/subscriptions/$($structureFile.defaultParameterValues.private_dns_zone_subscription_id.parameters.value)"
                        }
                    ) 
                }
                $baseTemplate.Add("additionalRoleAssignments", $additionalRoleAssignments)
                    
                
            }

            $category = $structureFile.managementGroupNameMappings.$scopeTrim.management_group_function
            ([PSCustomObject]$baseTemplate | Select-Object -Property "`$schema", nodeName, assignment, definitionEntry, definitionVersion, enforcementMode, parameters, nonComplianceMessages, scope | ConvertTo-Json -Depth 50) -replace "\[\[", "[" | New-Item -Path "$DefinitionsRootFolder/policyAssignments/$Type/$defaultStructurePAC/$category" -ItemType File -Name "$($fileContent.name).jsonc" -Force -ErrorAction SilentlyContinue
            if ($fileContent.name -eq "Deploy-Private-DNS-Zones") {
                ([PSCustomObject]$baseTemplate | Select-Object -Property "`$schema", nodeName, assignment, definitionEntry, definitionVersion, enforcementMode, parameters, nonComplianceMessages, scope, additionalRoleAssignments | ConvertTo-Json -Depth 50) -replace "\[\[", "[" | New-Item -Path "$DefinitionsRootFolder/policyAssignments/$Type/$defaultStructurePAC/$category" -ItemType File -Name "$($fileContent.name).jsonc" -Force -ErrorAction SilentlyContinue
                (Get-Content "$DefinitionsRootFolder/policyAssignments/$Type/$defaultStructurePAC/$category/$($fileContent.name).jsonc") -replace "\.ne\.", ".$dnsZoneRegion." | Set-Content "$DefinitionsRootFolder/policyAssignments/$Type/$defaultStructurePAC/$category/$($fileContent.name).jsonc"
            }
        }
    }

    if ($CreateGuardrailAssignments -and $Type -eq "ALZ") {
        foreach ($deployment in $structureFile.enforceGuardrails.deployments) {
            foreach ($file in Get-ChildItem "$LibraryPath/platform/$($Type.ToLower())/policy_set_definitions" -Recurse -File -Include *.json) {
                if (($file.Name -match "^Enforce-(Guardrails|Encryption)-") -and ($file.Name.Split(".")[0] -in $deployment.policy_set_names)) {
                    $fileContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -Depth 100

                    $baseTemplate = [ordered]@{
                        "`$schema"      = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-assignment-schema.json"
                        nodeName        = "$($fileContent.name)"
                        assignment      = [ordered]@{
                            name        = $fileContent.Name -replace "Enforce-Guardrails", "GR" -replace "Enforce-Encryption", "EN"
                            displayName = $fileContent.properties.displayName
                            description = $fileContent.properties.description
                        }
                        definitionEntry = [ordered]@{
                            displayName   = $fileContent.properties.displayName
                            policySetName = $fileContent.name
                        }
                        parameters      = @{}
                        enforcementMode = $structureFile.enforcementMode
                    }

                    foreach ($key in $structureFile.defaultParameterValues.psObject.Properties.Name) {
                        if ($structureFile.defaultParameterValues.$key.policy_assignment_name -eq $fileContent.name) {
                            $keyName = $structureFile.defaultParameterValues.$key.parameters.parameter_name
                            $baseTemplate.parameters.Add($keyName, $structureFile.defaultParameterValues.$key.parameters.value)
                        }
                    }

                    $scope = [ordered]@{
                        $PacEnvironmentSelector = @(
                            $deployment.scope
                        )
                    }
                    if ($deployment.scope.Count -gt 1) {
                        $baseTemplate.Add("scope", $scope)
                        ([PSCustomObject]$baseTemplate | Select-Object -Property "`$schema", nodeName, assignment, definitionEntry, enforcementMode, parameters, scope | ConvertTo-Json -Depth 100) -replace "\[\[", "[" | New-Item -Path "$DefinitionsRootFolder/policyAssignments/$Type/$defaultStructurePAC/Guardrails/multiScopeAssignments" -ItemType File -Name "$($fileContent.name).jsonc" -Force -ErrorAction SilentlyContinue
                    }
                    else {
                        $baseTemplate.Add("scope", $scope)
                        $scopeShortName = $deployment.Scope.Split("/")[-1]
                        ([PSCustomObject]$baseTemplate | Select-Object -Property "`$schema", nodeName, assignment, definitionEntry, enforcementMode, parameters, scope | ConvertTo-Json -Depth 100) -replace "\[\[", "[" | New-Item -Path "$DefinitionsRootFolder/policyAssignments/$Type/$defaultStructurePAC/Guardrails/$scopeShortName" -ItemType File -Name "$($fileContent.name).jsonc" -Force -ErrorAction SilentlyContinue
                    } 
                }
            }
        }
    }

    if ($LibraryPath -eq $tempPath) {
        Remove-Item $LibraryPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-ModernStatus -Message "ALZ Policy sync completed successfully" -Status "success" -Indent 0
}
catch {
    Write-ModernStatus -Message "Error during sync: $($_.Exception.Message)" -Status "error" -Indent 0
    exit 
}
#endregion Create assignment objects
