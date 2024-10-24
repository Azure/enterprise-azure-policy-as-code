<#
.SYNOPSIS
    Exports Policies and Policy Sets from Azure Portal as well as ALZ Policies and builds EPAC templates for deploying PolicySets and Assignments.

.PARAMETER PolicyDefinitionId
    Policy Definition ID - example: '/providers/Microsoft.Authorization/policyDefinitions/72f8cee7-2937-403d-84a1-a4e3e57f3c21'

.PARAMETER PolicySetDefinitionId
    "PolicySet Definition ID - example: '/providers/Microsoft.Authorization/policySetDefinitions/f08c57cd-dbd6-49a4-a85e-9ae77ac959b0'

.PARAMETER ALZPolicyDefinitionId
    ALZ Definition ID - example: 'Deny-APIM-TLS"

.PARAMETER ALZPolicySetDefinitionId
    ALZ PolicySet Definition ID - example: 'Enforce-Guardrails-OpenAI'

.PARAMETER OutputFolder
    Output Folder. Defaults to the path 'Output'.
    
.PARAMETER AutoCreateParameters
    Automatically create parameters for Azure Policy Sets and Assignment Files.

.PARAMETER UseBuiltIn    
    Default to using builtin policies rather than local versions.

.PARAMETER Scope
    Used to set scope value on each assignment file.

.PARAMETER PacSelector
    Used to set PacEnvironment for each assignment file.

.PARAMETER OverwriteOutput
    Used to Overwrite the contents of the output folder with each run. Helpful when running consecutively.

.EXAMPLE
    "./Export-PolicyToEPAC.ps1" -PolicyDefinitionID "/providers/Microsoft.Authorization/policySetDefinitions/051cba44-2429-45b9-9649-46cec11c7119" -AutoCreateParameters $True -UseBuiltIn $True 
    Retrieves Policy from Azure Portal, auto creates parameters to be manipulated in the assignment and sets assignment and policy set to use built-in policies rather than self hosted.

.EXAMPLE
    "./Export-PolicyToEPAC.ps1" -ALZPolicySetDefinitionId "Enforce-Guardrails-OpenAI" -PacSelector "EPAC-Prod" -Scope "/providers/Microsoft.Management/managementGroups/4fb849a3-3ff3-4362-af8e-45174cd753dd" 
    Retrieves Policy from ALZ Repo, sets the PacSelector in the assignment files to "EPAC-Prod" and the scope to the management group path provided.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Policy Definition ID - example: '/providers/Microsoft.Authorization/policyDefinitions/051cba44-2429-45b9-9649-46cec11c7119'")]
    [string] $PolicyDefinitionId,

    [Parameter(Mandatory = $false, HelpMessage = "PolicySet Definition ID - example: '/providers/Microsoft.Authorization/policySetDefinitions/f08c57cd-dbd6-49a4-a85e-9ae77ac959b0'")]
    [string] $PolicySetDefinitionId,
    
    [Parameter(Mandatory = $false, HelpMessage = "ALZ Definition ID - example: 'Deny-APIM-TLS")]
    [string] $ALZPolicyDefinitionId,

    [Parameter(Mandatory = $false, HelpMessage = "ALZ PolicySet Definition ID - example: 'Enforce-Guardrails-OpenAI'")]
    [string] $ALZPolicySetDefinitionId,

    [Parameter(Mandatory = $false, HelpMessage = "Output Folder. Defaults to the path 'Output'")]
    [string] $OutputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Automatically create parameters for Azure Policy Sets and Assignment Files")]
    [bool] $AutoCreateParameters = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Default to using builtin policies rather than local versions")]
    [bool] $UseBuiltIn = $true,

    [Parameter(Mandatory = $false, HelpMessage = "Used to set scope value on each assignment file")]
    [string] $Scope,

    [Parameter(Mandatory = $false, HelpMessage = "Used to set PacEnvironment for each assignment file")]
    [string] $PacSelector,

    [Parameter(Mandatory = $false, HelpMessage = "Used to Overwrite the contents of the output folder with each run. Helpful when running consecutively")]
    [bool] $OverwriteOutput = $true
)

# Validate session with Azure exists
if (-not (Get-AzContext)) {
    $null = Connect-AzAccount
}

# Overwrite Output folder
if ($OutputFolder -eq "") {
    $OutputFolder = "Output"
}
if ($OverwriteOutput) {
    if (Test-Path -Path "$OutputFolder/Export") {
        Remove-Item -Path "$OutputFolder/Export" -Recurse -Force
    }
}

Write-Information "" -InformationAction Continue

#region PolicyDefinition
if ($PolicyDefinitionId) {
    # Check proper formatting
    if ($PolicyDefinitionId -notmatch "/providers/") {
        Write-Error "Policy Definition ID '$($PolicyDefinitionId)' does not match expected format. Example format expected: '/providers/Microsoft.Authorization/policyDefinitions/f0e5abd0-2554-4736-b7c0-4ffef23475ef'"
        exit 1
    }

    # Pull Built-In Policies
    $builtInPolicies = Get-AzPolicyDefinition -Builtin
    $builtInPolicyNames = $builtInPolicies.name

    # Create Policy Definition File
    if ($PolicyDefinitionId -match "/") {
        $policyName = $PolicyDefinitionId.split("/")[-1]
    }
    else {
        $policyName = $PolicyDefinitionId
    }

    try {
        $policyResponse = Get-AzPolicyDefinition -Id "$PolicyDefinitionId" | Select-Object -Property *
    }
    catch {
        $policyResponse = Get-AzPolicyDefinition -Id "/providers/Microsoft.Authorization/policyDefinitions/$PolicyDefinitionId" | Select-Object -Property *
    }
    if ($null -eq $policyResponse) {
        Write-Error "Policy Definition ID '$($PolicyDefinitionId)' Not Found!"
        exit 1
    }

    $policyType = "policyDefinitions"
    $policyDisplayName = $policyResponse.displayName
    $policyDescription = $policyResponse.description
    $policyBuiltInType = $policyResponse.policyType
    $orderedPolicy = [ordered]@{
        "displayName" = $policyResponse.displayName
        "policyType"  = $policyResponse.policyType
        "mode"        = $policyResponse.mode
        "description" = $policyResponse.description
        "metadata"    = $policyResponse.metadata
        "parameters"  = $policyResponse.parameter
        "policyRule"  = $policyResponse.policyRule
    }
    $policyObject = [ordered]@{
        "`$schema"   = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-definition-schema.json"
        "name"       = $policyName
        "properties" = $orderedPolicy
    }
    $policyObjectProperties = $policyObject.properties.metadata
    if ($policyObjectProperties.pacOwnerId) {
        $policyObjectProperties.PSObject.Properties.Remove('pacOwnerId')
    }
    if ($policyObjectProperties.deployedBy) {
        $policyObjectProperties.PSObject.Properties.Remove('deployedBy')
    }
    if ($policyObjectProperties.createdBy) {
        $policyObjectProperties.PSObject.Properties.Remove('createdBy')
    }
    if ($policyObjectProperties.createdOn) {
        $policyObjectProperties.PSObject.Properties.Remove('createdOn')
    }
    if ($policyObjectProperties.updatedBy) {
        $policyObjectProperties.PSObject.Properties.Remove('updatedBy')
    }
    if ($policyObjectProperties.updatedOn) {
        $policyObjectProperties.PSObject.Properties.Remove('updatedOn')
    }
    $policyJson = $policyObject | ConvertTo-Json -Depth 100

    if ($UseBuiltIn -and $policyResponse.policyType -eq "BuiltIn") {
    }
    else {
        # Check Output folder exists
        if (-not (Test-Path -Path "$OutputFolder/Export/policyDefinitions")) {
            # Create folder if does not exist
            $null = New-Item -Path "$OutputFolder/Export/policyDefinitions" -ItemType Directory
        }
        Write-Information "Created Policy Definition - $policyName.jsonc" -InformationAction Continue
        $policyJson | Out-File -FilePath "$OutputFolder/Export/policyDefinitions/$policyName.jsonc"
    }
}
#region PolicySetDefinition
elseif ($PolicySetDefinitionId) {
    # Check proper formatting
    if ($PolicySetDefinitionId -notmatch "/providers/") {
        Write-Error "Policy Set Definition ID '$($PolicySetDefinitionId)' does not match expected format. Example format expected: '/providers/Microsoft.Authorization/policySetDefinitions/e20d08c5-6d64-656d-6465-ce9e37fd0ebc'"
        exit 1
    }
    # Pull Built-In Policies and Policy Sets
    $builtInPolicies = Get-AzPolicyDefinition -Builtin
    $builtInPolicyNames = $builtInPolicies.name
    $builtInPolicySets = Get-AzPolicySetDefinition -Builtin
    $builtInPolicySetNames = $builtInPolicySets.name

    # Create PolicySet Definition File
    if ($PolicySetDefinitionId -match "/") {
        $policyName = $PolicySetDefinitionId.split("/")[-1]
    }
    else {
        $policyName = $PolicySetDefinitionId
    }

    try {
        $policyResponse = Get-AzPolicySetDefinition -Id "$PolicySetDefinitionId" | Select-Object -Property *
    }
    catch {
        $policyResponse = Get-AzPolicySetDefinition -Id "/providers/Microsoft.Authorization/policySetDefinitions/$PolicySetDefinitionId" | Select-Object -Property *
    }
    if ($null -eq $policyResponse) {
        Write-Error "Policy Set Definition ID '$($PolicySetDefinitionId)' Not Found!"
        exit 1
    }

    $policyType = "policySetDefinitions"
    $policyDisplayName = $policyResponse.displayName
    $policyDescription = $policyResponse.description
    $policyBuiltInType = $policyResponse.policyType
    $policyDefinitionArray = @()
    foreach ($policyDef in $policyResponse.PolicyDefinition) {
        $tempParam = $policyDef.parameters
        $orderedPolicyDefinitions = [ordered]@{
            "policyDefinitionReferenceId" = "$($policyDef.policyDefinitionReferenceId)"
            "PolicyDefinitionId"          = "$($policyDef.PolicyDefinitionId)"
            "definitionVersion"           = "$($policyDef.definitionVersion)"
            "parameters"                  = $tempParam
            "groupNames"                  = "$($policyDef.groupNames)"
        }
        if ( $orderedPolicyDefinitions.definitionVersion -eq "") {
            $orderedPolicyDefinitions.Remove('definitionVersion')
        }
        if ( $orderedPolicyDefinitions.groupNames -eq "") {
            $orderedPolicyDefinitions.Remove('groupNames')
        }
        $policyDefinitionArray += $orderedPolicyDefinitions
    }
    $orderedPolicy = [ordered]@{
        "displayName"            = $policyResponse.displayName
        "policyType"             = $policyResponse.policyType
        "description"            = $policyResponse.description
        "metadata"               = $policyResponse.metadata
        "parameters"             = $policyResponse.parameter
        "policyDefinitions"      = $policyDefinitionArray
        "policyDefinitionGroups" = $policyResponse.PolicyDefinitionGroup
    }
    if ( $null -eq $orderedPolicy.policyDefinitionGroups) {
        $orderedPolicy.Remove('policyDefinitionGroups')
    }
    $policyObject = [ordered]@{
        "`$schema"   = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-set-definition-schema.json"
        "name"       = $policyName
        "properties" = $orderedPolicy
    }
    $policyObjectProperties = $policyObject.properties.metadata
    if ($policyObjectProperties.pacOwnerId) {
        $policyObjectProperties.PSObject.Properties.Remove('pacOwnerId')
    }
    if ($policyObjectProperties.deployedBy) {
        $policyObjectProperties.PSObject.Properties.Remove('deployedBy')
    }
    if ($policyObjectProperties.createdBy) {
        $policyObjectProperties.PSObject.Properties.Remove('createdBy')
    }
    if ($policyObjectProperties.createdOn) {
        $policyObjectProperties.PSObject.Properties.Remove('createdOn')
    }
    if ($policyObjectProperties.updatedBy) {
        $policyObjectProperties.PSObject.Properties.Remove('updatedBy')
    }
    if ($policyObjectProperties.updatedOn) {
        $policyObjectProperties.PSObject.Properties.Remove('updatedOn')
    }
    $policyJson = $policyObject | ConvertTo-Json -Depth 100
    
    if ($UseBuiltIn -and $policyResponse.policyType -eq "BuiltIn") {
    }
    else {
        # Check Output folder exists
        if (-not (Test-Path -Path "$OutputFolder/Export/policySetDefinitions")) {
            # Create folder if does not exist
            $null = New-Item -Path "$OutputFolder/Export/policySetDefinitions" -ItemType Directory
        }
        Write-Information "Created PolicySet Definition - $policyName.jsonc" -InformationAction Continue
        $policyJson | Out-File -FilePath "$OutputFolder/Export/policySetDefinitions/$policyName.jsonc"
    }

    # Get individual policies within PolicySet
    $policySetDefinitions = $policyObject.properties.policyDefinitions.PolicyDefinitionId

    foreach ($definition in $policySetDefinitions) {
        if ($UseBuiltIn -and $builtInPolicyNames -contains $definition) {
        }
        else {
            # Create Policy Definition File
            $tempPolicyName = $definition.split("/")[-1]

            $tempPolicyResponse = Get-AzPolicyDefinition -Id "$definition" | Select-Object -Property *
            $tempOrderedPolicy = [ordered]@{
                "displayName" = $tempPolicyResponse.displayName
                "policyType"  = $tempPolicyResponse.policyType
                "mode"        = $tempPolicyResponse.mode
                "description" = $tempPolicyResponse.description
                "metadata"    = $tempPolicyResponse.metadata
                "parameters"  = $tempPolicyResponse.parameter
                "policyRule"  = $tempPolicyResponse.policyRule
            }
            $tempPolicyObject = [ordered]@{
                "`$schema"   = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-definition-schema.json"
                "name"       = $tempPolicyName
                "properties" = $tempOrderedPolicy
            }
            $tempPolicyObjectProperties = $tempPolicyObject.properties.metadata
            if ($tempPolicyObjectProperties.pacOwnerId) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('pacOwnerId')
            }
            if ($tempPolicyObjectProperties.deployedBy) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('deployedBy')
            }
            if ($tempPolicyObjectProperties.createdBy) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('createdBy')
            }
            if ($tempPolicyObjectProperties.createdOn) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('createdOn')
            }
            if ($tempPolicyObjectProperties.updatedBy) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('updatedBy')
            }
            if ($tempPolicyObjectProperties.updatedOn) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('updatedOn')
            }
            $tempPolicyJson = $tempPolicyObject | ConvertTo-Json -Depth 100

            if ($UseBuiltIn -and $builtInPolicyNames -contains $tempPolicyName) {
            }
            else {
                # Check Output folder exists
                if (-not (Test-Path -Path "$OutputFolder/Export/policyDefinitions")) {
                    # Create folder if does not exist
                    $null = New-Item -Path "$OutputFolder/Export/policyDefinitions" -ItemType Directory
                }
                Write-Information " - Created Policy Definition - $tempPolicyName.jsonc" -InformationAction Continue
                $tempPolicyJson | Out-File -FilePath "$OutputFolder/Export/policyDefinitions/$tempPolicyName.jsonc"
            }
        }
    }
}
#region ALZ Definitions
elseif ($ALZPolicyDefinitionId) {
    $GithubReleaseTag = Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/Azure/Enterprise-Scale/releases/latest" -ErrorAction Stop | Select-Object -ExpandProperty tag_name
    $defaultPolicyURI = "https://raw.githubusercontent.com/Azure/Enterprise-Scale/$GithubReleaseTag/eslzArm/managementGroupTemplates/policyDefinitions/policies.json"
    $rawContent = (Invoke-WebRequest -Uri $defaultPolicyURI).Content | ConvertFrom-Json
    $variables = $rawContent.variables
    [hashtable] $jsonPolicyDefsHash = @{}
    if ($null -ne $variables) {
        if ($variables -is [System.Collections.IDictionary]) {
            if ($variables -is [hashtable]) {
                return $variables
            }
            else {
                foreach ($key in $variables.Keys) {
                    $null = $jsonPolicyDefsHash[$key] = $variables[$key]
                }
            }
        }
        elseif ($variables.psobject.Properties) {
            foreach ($property in $variables.psobject.Properties) {
                $jsonPolicyDefsHash[$property.Name] = $property.Value
            }
        }
    }
    $alzHash = @{}
    $jsonPolicyDefsHash.GetEnumerator() | Foreach-Object {
        if ($_.Key -match 'fxv') {
            $type = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Type
            if ($type -eq 'Microsoft.Authorization/policyDefinitions') {
                $environments = ($_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties).metadata.alzCloudEnvironments
                if ($environments -contains "AzureCloud") {
                    $name = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                    $properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                    $alzHash[$name] = $properties
                }
            }
        }
    }
    $policyName = $ALZPolicyDefinitionId
    $policyType = "policyDefinitions"
    $policyResponse = $alzHash[$ALZPolicyDefinitionId]
    if ($null -eq $policyResponse) {
        Write-Error "ALZ Policy Definition ID '$($ALZPolicyDefinitionId)' Not Found!"
        exit 1
    }
    $policyDisplayName = $policyResponse.displayName
    $policyDescription = $policyResponse.description
    $policyBuiltInType = $policyResponse.policyType
    $orderedPolicy = [ordered]@{
        "displayName" = $policyResponse.displayName
        "policyType"  = $policyResponse.policyType
        "mode"        = $policyResponse.mode
        "description" = $policyResponse.description
        "metadata"    = $policyResponse.metadata
        "parameters"  = $policyResponse.parameters
        "policyRule"  = $policyResponse.policyRule
    }
    $policyObject = [ordered]@{
        "`$schema"   = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-definition-schema.json"
        "name"       = $ALZPolicyDefinitionId
        "properties" = $orderedPolicy
    }

    $policyJson = $policyObject | ConvertTo-Json -Depth 100
    $policyJson = $policyJson -replace "\[\[", "["

    if ($UseBuiltIn -and $policyResponse.policyType -eq "BuiltIn") {
    }
    else {
        # Check Output folder exists
        if (-not (Test-Path -Path "$OutputFolder/Export/policyDefinitions")) {
            # Create folder if does not exist
            $null = New-Item -Path "$OutputFolder/Export/policyDefinitions" -ItemType Directory
        }
        Write-Information "Created Policy Definition - $policyName.jsonc" -InformationAction Continue
        $policyJson | Out-File -FilePath "$OutputFolder/Export/policyDefinitions/$policyName.jsonc"
    }
}
#region ALZ SetDefinitions
elseif ($ALZPolicySetDefinitionId) { 
    $builtInPolicies = Get-AzPolicyDefinition -Builtin
    $builtInPolicyNames = $builtInPolicies.name
    $GithubReleaseTag = Invoke-RestMethod -Method Get -Uri "https://api.github.com/repos/Azure/Enterprise-Scale/releases/latest" -ErrorAction Stop | Select-Object -ExpandProperty tag_name
    $defaultPolicyURI = "https://raw.githubusercontent.com/Azure/Enterprise-Scale/$GithubReleaseTag/eslzArm/managementGroupTemplates/policyDefinitions/policies.json"
    $rawContent = (Invoke-WebRequest -Uri $defaultPolicyURI).Content | ConvertFrom-Json
    $variables = $rawContent.variables
    [hashtable] $jsonPolicyDefsHash = @{}
    if ($null -ne $variables) {
        if ($variables -is [System.Collections.IDictionary]) {
            if ($variables -is [hashtable]) {
                return $variables
            }
            else {
                foreach ($key in $variables.Keys) {
                    $null = $jsonPolicyDefsHash[$key] = $variables[$key]
                }
            }
        }
        elseif ($variables.psobject.Properties) {
            foreach ($property in $variables.psobject.Properties) {
                $jsonPolicyDefsHash[$property.Name] = $property.Value
            }
        }
    }
    $alzHash = @{}
    $jsonPolicyDefsHash.GetEnumerator() | Foreach-Object {
        if ($_.Key -match 'fxv') {
            $type = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Type
            if ($type -eq 'Microsoft.Authorization/policyDefinitions') {
                $environments = ($_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties).metadata.alzCloudEnvironments
                if ($environments -contains "AzureCloud") {
                    $name = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                    $properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                    $alzHash[$name] = $properties
                }
            }
        }
    }
    
    $defaultPolicySetURI = "https://raw.githubusercontent.com/Azure/Enterprise-Scale/$GithubReleaseTag/eslzArm/managementGroupTemplates/policyDefinitions/initiatives.json"
    $rawContent = (Invoke-WebRequest -Uri $defaultPolicySetURI).Content | ConvertFrom-Json
    $variables = $rawContent.variables
    [hashtable] $jsonPolicySetDefsHash = @{}
    if ($null -ne $variables) {
        if ($variables -is [System.Collections.IDictionary]) {
            if ($variables -is [hashtable]) {
                return $variables
            }
            else {
                foreach ($key in $variables.Keys) {
                    $null = $jsonPolicySetDefsHash[$key] = $variables[$key]
                }
            }
        }
        elseif ($variables.psobject.Properties) {
            foreach ($property in $variables.psobject.Properties) {
                $jsonPolicySetDefsHash[$property.Name] = $property.Value
            }
        }
    }
    $alzSetHash = @{}
    $jsonPolicySetDefsHash.GetEnumerator() | Foreach-Object {
        if ($_.Key -match 'fxv') {
            $type = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Type
            if ($type -match 'Microsoft.Authorization/policySetDefinitions') {
                $environments = ($_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties).metadata.alzCloudEnvironments
                if ($environments -contains "AzureCloud") {
                    $name = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Name
                    $properties = $_.Value | ConvertFrom-Json | Select-Object -ExpandProperty Properties
                    $alzSetHash[$name] = $properties
                }
            }
        }
    }

    $policyName = $ALZPolicySetDefinitionId
    $policyType = "policySetDefinitions"
    $policyResponse = $alzSetHash[$ALZPolicySetDefinitionId]
    if ($null -eq $policyResponse) {
        Write-Error "ALZ Policy Set Definition ID '$($ALZPolicySetDefinitionId)' Not Found!"
        exit 1
    }
    $policyDisplayName = $policyResponse.displayName
    $policyDescription = $policyResponse.description
    $policyBuiltInType = $policyResponse.policyType
    $policyDefinitionArray = @()
    foreach ($policyDef in $policyResponse.PolicyDefinitions) {
        $tempParam = $policyDef.parameters
        $orderedPolicyDefinitions = [ordered]@{
            "policyDefinitionReferenceId" = "$($policyDef.policyDefinitionReferenceId)"
            "PolicyDefinitionId"          = "$($policyDef.PolicyDefinitionId)"
            "definitionVersion"           = "$($policyDef.definitionVersion)"
            "parameters"                  = $tempParam
            "groupNames"                  = "$($policyDef.groupNames)"
        }
        if ( $orderedPolicyDefinitions.definitionVersion -eq "") {
            $orderedPolicyDefinitions.Remove('definitionVersion')
        }
        if ( $orderedPolicyDefinitions.groupNames -eq "") {
            $orderedPolicyDefinitions.Remove('groupNames')
        }
        $policyDefinitionArray += $orderedPolicyDefinitions
    }
    $orderedPolicy = [ordered]@{
        "displayName"            = $policyResponse.displayName
        "policyType"             = $policyResponse.policyType
        "description"            = $policyResponse.description
        "metadata"               = $policyResponse.metadata
        "parameters"             = $policyResponse.parameters
        "policyDefinitions"      = $policyDefinitionArray
        "policyDefinitionGroups" = $policyResponse.PolicyDefinitionGroups
    }
    if ( $null -eq $orderedPolicy.policyDefinitionGroups) {
        $orderedPolicy.Remove('policyDefinitionGroups')
    }
    $policyObject = [ordered]@{
        "`$schema"   = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-set-definition-schema.json"
        "name"       = $policyName
        "properties" = $orderedPolicy
    }
    $policyJson = $policyObject | ConvertTo-Json -Depth 100
    $policyJson = $policyJson -replace "\[\[", "["
    
    if ($UseBuiltIn -and $policyResponse.policyType -eq "BuiltIn") {
    }
    else {
        # Check Output folder exists
        if (-not (Test-Path -Path "$OutputFolder/Export/policySetDefinitions")) {
            # Create folder if does not exist
            $null = New-Item -Path "$OutputFolder/Export/policySetDefinitions" -ItemType Directory
        }
        Write-Information "Created PolicySet Definition - $policyName.jsonc" -InformationAction Continue
        $policyJson | Out-File -FilePath "$OutputFolder/Export/policySetDefinitions/$policyName.jsonc"
    }

    # Get individual policies within PolicySet
    $policySetDefinitions = $policyObject.properties.policyDefinitions.PolicyDefinitionId

    foreach ($definition in $policySetDefinitions) {
    
        if ($definition -match "/") {
            $shortName = $definition.split("/")[-1]
        }

        if ($UseBuiltIn -and $builtInPolicyNames -contains $definition -or $UseBuiltIn -and $builtInPolicyNames -contains $shortName) {
        }
        elseif (!$UseBuiltIn -and $builtInPolicyNames -contains $definition -or !$UseBuiltIn -and $builtInPolicyNames -contains $shortName) {
            # Create Policy Definition File
            $tempPolicyName = $definition.split("/")[-1]

            $tempPolicyResponse = Get-AzPolicyDefinition -Id "$definition" | Select-Object -Property *
            $tempOrderedPolicy = [ordered]@{
                "displayName" = $tempPolicyResponse.displayName
                "policyType"  = $tempPolicyResponse.policyType
                "mode"        = $tempPolicyResponse.mode
                "description" = $tempPolicyResponse.description
                "metadata"    = $tempPolicyResponse.metadata
                "parameters"  = $tempPolicyResponse.parameter
                "policyRule"  = $tempPolicyResponse.policyRule
            }
            $tempPolicyObject = [ordered]@{
                "`$schema"   = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-definition-schema.json"
                "name"       = $tempPolicyName
                "properties" = $tempOrderedPolicy
            }
            $tempPolicyObjectProperties = $tempPolicyObject.properties.metadata
            if ($tempPolicyObjectProperties.pacOwnerId) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('pacOwnerId')
            }
            if ($tempPolicyObjectProperties.deployedBy) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('deployedBy')
            }
            if ($tempPolicyObjectProperties.createdBy) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('createdBy')
            }
            if ($tempPolicyObjectProperties.createdOn) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('createdOn')
            }
            if ($tempPolicyObjectProperties.updatedBy) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('updatedBy')
            }
            if ($tempPolicyObjectProperties.updatedOn) {
                $tempPolicyObjectProperties.PSObject.Properties.Remove('updatedOn')
            }
            $tempPolicyJson = $tempPolicyObject | ConvertTo-Json -Depth 100

            if ($UseBuiltIn -and $builtInPolicyNames -contains $tempPolicyName) {
            }
            else {
                # Check Output folder exists
                if (-not (Test-Path -Path "$OutputFolder/Export/policyDefinitions")) {
                    # Create folder if does not exist
                    $null = New-Item -Path "$OutputFolder/Export/policyDefinitions" -ItemType Directory
                }
                Write-Information " - Created Policy Definition - $tempPolicyName.jsonc" -InformationAction Continue
                $tempPolicyJson | Out-File -FilePath "$OutputFolder/Export/policyDefinitions/$tempPolicyName.jsonc"
            }
        }
        else {
            $tempPolicyName = $definition
            $tempPolicyResponse = $alzHash[$definition]
            if ($null -eq $tempPolicyResponse) {
                $definition = $definition.split("/")[-1]
                $tempPolicyName = $definition
                $tempPolicyResponse = $alzHash[$definition]
            }
            $tempOrderedPolicy = [ordered]@{
                "displayName" = $tempPolicyResponse.displayName
                "policyType"  = $tempPolicyResponse.policyType
                "mode"        = $tempPolicyResponse.mode
                "description" = $tempPolicyResponse.description
                "metadata"    = $tempPolicyResponse.metadata
                "parameters"  = $tempPolicyResponse.parameters
                "policyRule"  = $tempPolicyResponse.policyRule
            }
            $tempPolicyObject = [ordered]@{
                "`$schema"   = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-definition-schema.json"
                "name"       = $ALZPolicyDefinitionId
                "properties" = $tempOrderedPolicy
            }
            $tempPolicyJson = $tempPolicyObject | ConvertTo-Json -Depth 100
            $tempPolicyJson = $tempPolicyJson -replace "\[\[", "["
            # Check Output folder exists
            if (-not (Test-Path -Path "$OutputFolder/Export/policyDefinitions")) {
                # Create folder if does not exist
                $null = New-Item -Path "$OutputFolder/Export/policyDefinitions" -ItemType Directory
            }
            Write-Information " - Created Policy Definition - $tempPolicyName.jsonc" -InformationAction Continue
            $tempPolicyJson | Out-File -FilePath "$OutputFolder/Export/policyDefinitions/$tempPolicyName.jsonc"    
        }
    }
}
else {
    Write-Error "Export-PolicyToEPAC requires at least one of the following: PolicyDefinitionId, PolicySetDefinitionId, ALZPolicyDefinitionId or ALZPolicySetDefinitionId!"
}


#region Assignment
if ($policyObject) {
    $assignmentTemplate = @"
{
    "`$schema" : "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-assignment-schema.json",
    "nodeName": "/Security/",
    "definitionEntry": {
        "policyName": ""
    },
    "children": [
        {
            "nodeName": "EPAC-Dev",
            "assignment": {
                "name": "",
                "displayName": "",
                "description": ""
            },
            "enforcementMode": "Default",
            "parameters": {},
            "scope": {
                "EPAC-Dev": [
                    "/providers/Microsoft.Management/managementGroups/EPAC-Dev"
                ]
            }
        }
    ]
}
"@

    $assignmentObject = $assignmentTemplate | ConvertFrom-Json

    # Set name
    if ($policyType -eq "policyDefinitions" -and !$UseBuiltIn) {
        $assignmentObject.definitionEntry.policyName = "$policyName"
    }
    if ($policyType -eq "policyDefinitions" -and $UseBuiltIn) {
        if ($policyBuiltInType -eq "BuiltIn") {
            $assignmentObject.definitionEntry | Add-Member -MemberType NoteProperty -Name "policyId" -Value "/providers/Microsoft.Authorization/policyDefinitions/$policyName"
            $assignmentObject.definitionEntry.PSObject.Properties.Remove("policyName")
        }
        else {  
            $assignmentObject.definitionEntry.policyName = "$policyName"
        }
    }
    if ($policyType -eq "policySetDefinitions" -and !$UseBuiltIn) {
        $assignmentObject.definitionEntry | Add-Member -MemberType NoteProperty -Name "policySetName" -Value "$policyName"
        $assignmentObject.definitionEntry.PSObject.Properties.Remove("policyName")
    }
    if ($policyType -eq "policySetDefinitions" -and $UseBuiltIn) {
        if ($policyBuiltInType -eq "BuiltIn") {
            $assignmentObject.definitionEntry | Add-Member -MemberType NoteProperty -Name "policySetId" -Value "/providers/Microsoft.Authorization/policySetDefinitions/$policyName"
            $assignmentObject.definitionEntry.PSObject.Properties.Remove("policyName")
        }
        else {  
            $assignmentObject.definitionEntry | Add-Member -MemberType NoteProperty -Name "policySetName" -Value "$policyName"
            $assignmentObject.definitionEntry.PSObject.Properties.Remove("policyName")
        }
    }

    # Set Assignment Properties
    $tempGuid = New-Guid
    $assignmentObject.children.assignment.name = $tempGuid.Guid.split("-")[-1]
    $assignmentObject.children.assignment.displayName = "$policyDisplayName"
    $assignmentObject.children.assignment.description = "$policyDescription"

    # Overwrite PacSelector is given
    if ($PacSelector -and $PacSelector -ne "EPAC-Dev") {
        $assignmentObject.children.scope | Add-Member -MemberType NoteProperty -Name "$PacSelector" -Value ""
        $assignmentObject.children.scope.$PacSelector = $assignmentObject.children.scope.'EPAC-Dev'
        $assignmentObject.children.scope.PSObject.Properties.Remove("EPAC-Dev")
    }

    # Overwrite Scope if given
    if ($Scope -and $PacSelector) {
        $assignmentObject.children.scope.$PacSelector = "$Scope"
    }
    elseif ($Scope -and !$PacSelector) {
        $assignmentObject.children.scope.'EPAC-Dev' = "$Scope"

    }

    #region AutoParameter
    if ($AutoCreateParameters) {
        if ($UseBuiltIn) {
            if ($policyType -eq "policySetDefinitions" -and $builtInPolicySetNames -contains $policyName) {
                $policyObject = $builtInPolicySets | Where-Object { $_.Name -eq $policyName }
                $policySetParameters = $policyObject.parameter
                $parameterNames = $policySetParameters | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                foreach ($parameter in $parameterNames) {
                    $defaultEffect = ""
                    if ($null -eq $($policySetParameters).$($parameter).defaultValue) {
                        Write-Warning "Default Value not found for '$parameter' in PolicySet '$policyName'" -InformationAction Continue
                    }
                    else {
                        $defaultEffect = $($policySetParameters).$($parameter).defaultValue
                    }
                    $assignmentObject.children.parameters | Add-Member -MemberType NoteProperty -Name "$parameter" -Value $defaultEffect
                }
            }
            elseif ($policyType -eq "policyDefinitions" -and $builtInPolicyNames -contains $policyName) {
                $policyObject = $builtInPolicies | Where-Object { $_.Name -eq $policyName }
                $policyParameters = $policyObject.parameter
                $parameterNames = $policyParameters | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                foreach ($parameter in $parameterNames) {
                    $defaultEffect = ""
                    if ($null -eq $($policyParameters).$($parameter).defaultValue) {
                        Write-Warning "Default Value not found for '$parameter' in PolicySet '$policyName'" -InformationAction Continue
                    }
                    else {
                        $defaultEffect = $($policyParameters).$($parameter).defaultValue
                    }
                    $assignmentObject.children.parameters | Add-Member -MemberType NoteProperty -Name "$parameter" -Value $defaultEffect
                }
            }
            else {
                $policySetParameters = $policyObject.properties.parameters
                $parameterNames = $policySetParameters | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        
                foreach ($parameter in $parameterNames) {
                    $defaultEffect = ""
                    if ($null -eq $($policySetParameters).$($parameter).defaultValue) {
                        Write-Warning "Default Value not found for '$parameter' in PolicySet '$policyName'" -InformationAction Continue
                    }
                    else {
                        $defaultEffect = $($policySetParameters).$($parameter).defaultValue
                    }
                    $assignmentObject.children.parameters | Add-Member -MemberType NoteProperty -Name "$parameter" -Value $defaultEffect
                }
            }
        }
        else {
            $policySetParameters = $policyObject.properties.parameters
            $parameterNames = $policySetParameters | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    
            foreach ($parameter in $parameterNames) {
                $defaultEffect = ""
                if ($null -eq $($policySetParameters).$($parameter).defaultValue) {
                    Write-Warning "Default Value not found for '$parameter' in PolicySet '$policyName'" -InformationAction Continue
                }
                else {
                    $defaultEffect = $($policySetParameters).$($parameter).defaultValue
                }
                $assignmentObject.children.parameters | Add-Member -MemberType NoteProperty -Name "$parameter" -Value $defaultEffect
            }
        }
    }

    # Convert from PSObject to Json
    $assignmentJson = $assignmentObject | ConvertTo-Json -Depth 100

    # Check Assignment Output folder exists
    if (-not (Test-Path -Path "$OutputFolder/Export/policyAssignments")) {
        # Create folder if does not exist
        $null = New-Item -Path "$OutputFolder/Export/policyAssignments" -ItemType Directory
    }

    # Export File
    Write-Information "Created Policy Assignment - $policyName.jsonc" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    $assignmentJson | Out-File -FilePath "$OutputFolder/Export/policyAssignments/$policyName.jsonc"
}