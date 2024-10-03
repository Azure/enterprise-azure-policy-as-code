<#
.SYNOPSIS
    Exports Azure Policy from https://www.azadvertizer.net/ and builds EPAC templates for deploying PolicySets and Assignments.

.PARAMETER AzAdvertizerUrl
    Mandatory url of the policy or policy set from AzAdvertizer.

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
    "./Out-AzAdvertizerPolicy.ps1" -AzAdvertizerUrl "https://www.azadvertizer.net/azpolicyinitiativesadvertizer/Deny-PublicPaaSEndpoints.html" -AutoCreateParameters $True -UseBuiltIn $True 
    Retrieves Policy from AzAdvertizer, auto creates parameters to be manipulated in the assignment and sets assignment and policy set to use built-in policies rather than self hosted.

.EXAMPLE
    "./Out-AzAdvertizerPolicy.ps1" -AzAdvertizerUrl "https://www.azadvertizer.net/azpolicyinitiativesadvertizer/Deny-PublicPaaSEndpoints.html" -PacSelector "EPAC-Prod" -Scope "/providers/Microsoft.Management/managementGroups/4fb849a3-3ff3-4362-af8e-45174cd753dd" 
    Retrieves Policy from AzAdvertizer, sets the PacSelector in the assignment files to "EPAC-Prod" and the scope to the management group path provided.

.LINK
    https://azure.github.io/enterprise-azure-policy-as-code/policy-exemptions/
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "Mandatory url of the policy or policy set from AzAdvertizer")]
    [string] $AzAdvertizerUrl,

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

#region Policy

# Validate session with Azure exists
if (-not (Get-AzContext)) {
    $null = Connect-AzAccount
}

# Pull HTML
try {
    $restResponse = Invoke-RestMethod -Uri "$AzAdvertizerUrl" -Method Get
}
catch {
    if ($_.Exception.Response.StatusCode -lt 200 -or $_.Exception.Response.StatusCode -ge 300) {
        Write-Error "Error gathering Policy Information, please validate AzAdvertizerUrl is valid." -ErrorAction Stop
    }
}

# Determine if PolicySet or Policy Assignment
if ($AzAdvertizerUrl -match "azpolicyadvertizer") {
    $policyType = "policyDefinitions"
    # Pull Built-In Policies and Policy Sets
    $builtInPolicies = Get-AzPolicyDefinition -Builtin
    $builtInPolicyNames = $builtInPolicies.name
}
elseif ($AzAdvertizerUrl -match "azpolicyinitiativesadvertizer") {
    $policyType = "policySetDefinitions"
    # Pull Built-In Policies and Policy Sets
    $builtInPolicies = Get-AzPolicyDefinition -Builtin
    $builtInPolicyNames = $builtInPolicies.name
    $builtInPolicySets = Get-AzPolicySetDefinition -Builtin
    $builtInPolicySetNames = $builtInPolicySets.name
}
else {
    Write-Error "AzAdvertizerUrl is not referencing Policy or Policy Initiative"
}

# Parse HTML response to find copyEPACDef
Write-Information "" -InformationAction Continue
$response = $restResponse.split("function copyEPACDef() ")[1]

try {
    $response = $response.split("const obj = ")[1]
    if ($null -eq $response) {
        throw "Split resulted in null"
    }
}
catch {
    try {
        $response = $restResponse.split("function copyEPACDef() ")[1]
        $response = $response.split("const objEPAC = ")[1]
        if ($null -eq $response) {
            throw "Both splits resulted in null"
        }
    }
    catch {
        Write-Information "Both splits failed and resulted in null." -InformationAction Continue
    }
}

$response = $response.split("};")[0] + "}"

# Convert from JSON to get object
$policyObject = $response | ConvertFrom-Json

# Use Object to get policy name
$policyName = $policyObject.name

# Get Display Name
$policyDisplayName = $policyObject.properties.displayName

# Get Description
$policyDescription = $policyObject.properties.description

# Export policy definition or policy set definition
$policyJson = $policyObject | ConvertTo-Json -Depth 100

# Overwrite Output folder
if ($OutputFolder -eq "") {
    $OutputFolder = "Output"
}
if ($OverwriteOutput) {
    if (Test-Path -Path "$OutputFolder/ALZ-Export") {
        Remove-Item -Path "$OutputFolder/ALZ-Export" -Recurse -Force
    }
}

# Export File
if ($policyType -eq "policyDefinitions") {
    if ($UseBuiltIn -and $builtInPolicyNames -contains $policyName) {
    }
    else {
        # Check Output folder exists
        if (-not (Test-Path -Path "$OutputFolder/ALZ-Export/$policyType")) {
            # Create folder if does not exist
            $null = New-Item -Path "$OutputFolder/ALZ-Export/$policyType" -ItemType Directory
        }
        Write-Information "Created Policy Definition - $policyName.jsonc" -InformationAction Continue
        $policyJson | Out-File -FilePath "$OutputFolder/ALZ-Export/$policyType/$policyName.jsonc"
    }
}
if ($policyType -eq "policySetDefinitions") {
    if ($UseBuiltIn -and $builtInPolicySetNames -contains $policyName) {
    }
    else {
        # Check Output folder exists
        if (-not (Test-Path -Path "$OutputFolder/ALZ-Export/$policyType")) {
            # Create folder if does not exist
            $null = New-Item -Path "$OutputFolder/ALZ-Export/$policyType" -ItemType Directory
        }
        Write-Information "Created Policy Set Definition - $policyName.jsonc" -InformationAction Continue
        $policyJson | Out-File -FilePath "$OutputFolder/ALZ-Export/$policyType/$policyName.jsonc"
    }
}

#region Policy Set individual Custom Definitions
if ($policyType -eq "policySetDefinitions") {
    # Get policy names that are used
    $policySetDefinitions = $policyObject.properties.policyDefinitions.policyDefinitionName

    foreach ($definition in $policySetDefinitions) {
        if ($UseBuiltIn -and $builtInPolicyNames -contains $definition) {
        }
        else {
            # Set URL
            $tempURL = "https://www.azadvertizer.net/azpolicyadvertizer/$definition.html"
            # Pull HTML
            $tempRestResponse = Invoke-RestMethod -Uri $tempURL

            # Parse HTML response to find copyEPACDef
            $tempResponse = $tempRestResponse.split("function copyEPACDef() ")[1]

            try {
                $tempResponse = $tempResponse.split("const obj = ")[1]
                if ($null -eq $tempResponse) {
                    throw "Split resulted in null"
                }
            }
            catch {
                try {
                    $tempResponse = $tempRestResponse.split("function copyEPACDef() ")[1]
                    $tempResponse = $tempResponse.split("const objEPAC = ")[1]
                    if ($null -eq $tempResponse) {
                        throw "Both splits resulted in null"
                    }
                }
                catch {
                    Write-Information "Error parsing response for $definition." -InformationAction Continue
                }
            }

            $tempResponse = $tempResponse.split("};")[0] + "}"

            # Convert from JSON to get object
            $tempPolicyObject = $tempResponse | ConvertFrom-Json

            # Use Object to get policy name
            $tempPolicyName = $tempPolicyObject.name

            # Export policy definition or policy set definition
            $tempPolicyJson = $tempPolicyObject | ConvertTo-Json -Depth 100

            # Check Output folder exists
            if (-not (Test-Path -Path "$OutputFolder/ALZ-Export/policyDefinitions")) {
                # Create folder if does not exist
                $null = New-Item -Path "$OutputFolder/ALZ-Export/policyDefinitions" -ItemType Directory
            }

            # Export File
            Write-Information " - Created Policy Definition - $tempPolicyName.jsonc" -InformationAction Continue
            $tempPolicyJson | Out-File -FilePath "$OutputFolder/ALZ-Export/policyDefinitions/$tempPolicyName.jsonc"
        }
    }
}

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

#region Assignment

$assignmentObject = $assignmentTemplate | ConvertFrom-Json

# Set name
if ($policyType -eq "policyDefinitions" -and !$UseBuiltIn) {
    $assignmentObject.definitionEntry.policyName = "$policyName"
}
if ($policyType -eq "policyDefinitions" -and $UseBuiltIn) {
    if ($builtInPolicyNames -contains $policyName) {
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
    if ($builtInPolicySetNames -contains $policyName) {
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
if (-not (Test-Path -Path "$OutputFolder/ALZ-Export/policyAssignments")) {
    # Create folder if does not exist
    $null = New-Item -Path "$OutputFolder/ALZ-Export/policyAssignments" -ItemType Directory
}

# Export File
Write-Information "Created Policy Assignment - $policyName.jsonc" -InformationAction Continue
$assignmentJson | Out-File -FilePath "$OutputFolder/ALZ-Export/policyAssignments/$policyName.jsonc"
