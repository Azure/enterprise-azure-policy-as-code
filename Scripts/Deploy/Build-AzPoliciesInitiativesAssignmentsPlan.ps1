#Requires -PSEdition Core

<#
.SYNOPSIS
    This script plans:
    - Creates/updates/recreates/deletes Policy definitions in the management group or subscription it is running against.
    - Creates/updates/recreates/deletes Policy Set (Initiative) definitions in the management group or subscription it is running against.
    - Creates/updates/recreates/deletes Policy Assignments at the specified (in tree strucure) levels
    - Creates/updates/recreates/deletes Role Assignments
    

.NOTES
    This script is designed to be run in Azure DevOps pipelines.
    Version:        1.2
    Creation Date:  2021-07-20
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true,
        HelpMessage = "TenantID is required to disambiguate users known in multiple teannts.")]
    [string]$TenantId,

    [Parameter(Mandatory = $true,
        HelpMessage = "Fully qualified name of the scope (either a Management Group or a Subscription.")]
    [string]$RootScope,

    [Parameter(Mandatory = $false,
        HelpMessage = "Selector is used to select different scopes based on environment, most often for Policy DEV, TEST or PROD (not to be confused with regular Sandbox, Dev. QA and Prod).")]
    [string]$AssignmentSelector = "PROD",

    [Parameter(Mandatory = $false,
        HelpMessage = "When using this switch, the script includes resource groups for assignment calculations.")]
    [switch]$IncludeResourceGroupsForAssignments,

    [Parameter(Mandatory = $false,
        HelpMessage = "When using this switch, the script will NOT delete extraneous Policy definitions, Initiative definitions and Assignments.")]
    [switch]$SuppressDeletes,

    [Parameter(Mandatory = $false,
        HelpMessage = "Plan output filename.")]
    [string]$PlanFile = "./Output/Plans/current.json",

    [Parameter(Mandatory = $false,
        HelpMessage = "Path of the root folder containing the policy definitions.")]
    [string]$GlobalSettingsFile = "./Definitions/global-settings.jsonc",

    [Parameter(Mandatory = $false,
        HelpMessage = "Path of the root folder containing the policy definitions.")]
    [string]$PolicyDefinitionsRootFolder = "./Definitions/Policies",

    [Parameter(Mandatory = $false,
        HelpMessage = "Path of the root folder containing the Initiative definitions.")]
    [string]$InitiativeDefinitionsRootFolder = "./Definitions/Initiatives",

    [Parameter(Mandatory = $false,
        HelpMessage = "Path of the root folder containing the Assignments definitions.")]
    [string]$AssignmentsRootFolder = "./Definitions/Assignments"

)

function Write-AssignmentDetails {
    [CmdletBinding()]
    param (
        $printHeader,
        $def,
        $policySpecText,
        $scopeInfo,
        $roleDefinitions,
        $prefix
    )

    if ($printHeader) {
        Write-Information "    Assignment `'$($def.assignment.DisplayName)`' ($($def.assignment.Name))"
        Write-Information "                Description: $($def.assignment.Description)"
        Write-Information "                $($policySpecText)"
    }
    Write-Information "        $($prefix) at $($scopeInfo.scope)"
    # if ($roleDefinitions.Length -gt 0) {
    #     foreach ($roleDefinition in $roleDefinitions) {
    #         Write-Information "                RoleId=$($roleDefinition.roleDefinitionId), Scope=$($roleDefinition.scope)"
    #     }
    # }
}

#region Initialize

# Load cmdlets
. "$PSScriptRoot/../Helpers/Get-GlobalSettings.ps1"
. "$PSScriptRoot/../Helpers/Get-AzScopeTree.ps1"
. "$PSScriptRoot/../Helpers/Get-AllAzPolicyInitiativeDefinitions.ps1"
. "$PSScriptRoot/../Helpers/Get-AzAssignmentsAtScopeRecursive.ps1"
. "$PSScriptRoot/../Helpers/Get-AzPolicyNotScope.ps1"
. "$PSScriptRoot/../Helpers/Build-PolicyDefinitionsForInitiative.ps1"
. "$PSScriptRoot/../Helpers/Build-AzPolicyAssignmentIdentityAndRoleChanges.ps1"
. "$PSScriptRoot/../Helpers/Confirm-AssignmentParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionUsedExists.ps1"
. "$PSScriptRoot/../Helpers/Confirm-PolicyDefinitionsUsedMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-InitiativeDefinitionUsedExists.ps1"
. "$PSScriptRoot/../Helpers/Confirm-ParametersMatch.ps1"
. "$PSScriptRoot/../Helpers/Confirm-MetadataMatches.ps1"
. "$PSScriptRoot/../Helpers/Get-AssignmentDefs.ps1"
. "$PSScriptRoot/../Utils/Confirm-ObjectValueEqualityDeep.ps1"
. "$PSScriptRoot/../Utils/ConvertTo-HashTable.ps1"
. "$PSScriptRoot/../Utils/Get-DeepClone.ps1"
. "$PSScriptRoot/../Utils/Get-FilteredHashTable.ps1"
. "$PSScriptRoot/../Utils/Invoke-AzCli.ps1"

Invoke-AzCli config set extension.use_dynamic_install=yes_without_prompt -SuppressOutput

$scopeParam = @{}
if ($RootScope.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
    $scopeParam.ManagementGroupName = $RootScope -replace '^/providers/Microsoft.Management/managementGroups/', ''
}
elseif ($RootScope.StartsWith("/subscriptions/")) {
    $scopeParam.SubscriptionId = $RootScope -replace '^/subscriptions/', ''
    Invoke-AzCli account set --subscription $scopeParam.SubscriptionId -SuppressOutput
}
else {
    Write-Error "RootScope is ""$RootScope""; it must be a subscription ""/subscriptions/123456789-1234-1234-1234-12345678abcd"" or a management group ""/providers/Microsoft.Management/managementGroups/DefaultManagementGroup"""
    throw "RootScope not defined"
}

$globalNotScopeList, $managedIdentityLocation = Get-GlobalSettings -AssignmentSelector $AssignmentSelector -GlobalSettingsFile $GlobalSettingsFile
$scopeTreeInfo = Get-AzScopeTree -tenantId $TenantId -scopeParam $scopeParam

#endregion

#region Getting existing Policy/Initiative definitions and Policy Assignments in the chosen scope of Azure
$collections = Get-AllAzPolicyInitiativeDefinitions -RootScope $RootScope
$allPolicyDefinitions = $collections.builtInPolicyDefinitions
$existingCustomPolicyDefinitions = $collections.existingCustomPolicyDefinitions
$allInitiativeDefinitions = $collections.builtInInitiativeDefinitions
$existingCustomInitiativeDefinitions = $collections.existingCustomInitiativeDefinitions

$assignmentsInAzure, $null = Get-AzAssignmentsAtScopeRecursive -scopeTreeInfo $scopeTreeInfo -notScopeIn $globalNotScopeList -includeResourceGroups $IncludeResourceGroupsForAssignments.IsPresent

#endregion

#region Process Policy definitions

Write-Information "==================================================================================================="
Write-Information "Processing Policy definitions JSON files in folder '$PolicyDefinitionsRootFolder'"
Write-Information "==================================================================================================="
$policyFiles = @()
$policyFiles += Get-ChildItem -Path $PolicyDefinitionsRootFolder -Recurse -File -Filter "*.json"
$policyFiles += Get-ChildItem -Path $PolicyDefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
Write-Information "Number of files = $($policyFiles.Length)"

if ($policyFiles.Length -lt 1) {
    Write-Warning "There aren't any JSON files in the folder provided!"
}

# Getting Policy definitions from the JSON files
$policyObjectsInJson = @{}
$replacedPolicyDefinitions = @{}
$newPolicyDefinitions = @{}
$updatedPolicyDefinitions = @{}
$maybeDeletedPolicyDefinitions = $existingCustomPolicyDefinitions.Clone()
$unchangedPolicyDefinitions = @{}
# $first = $true
$hasErrors = $false

foreach ($policyFile in $policyFiles) {

    # Check if the policy definition JSON file is a valid JSON
    $Json = Get-Content -Path $policyFile.FullName -Raw -ErrorAction Stop

    try {
        $Json | Test-Json -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Policy JSON file '$($policyFile.FullName)' is not valid = $Json"
        $hasErrors = $true
        continue
    }

    $policyObject = $Json | ConvertFrom-Json
    $name = $policyObject.name
    $displayName = $policyObject.properties.displayName
    if ($null -eq $name) {
        $name = $displayName
        if ($null -eq $displayName) {
            Write-Error "Policy JSON file '$($policyFile.FullName)' is missing a Policy name or displayName "
            $hasErrors = $true
            continue
        }
    }
    elseif ($null -eq $displayName) {
        $displayName = $name

    }
    if ($policyObjectsInJson.ContainsKey($name)) {
        Write-Error "There is more than one Policy definition JSON that contains definition of '$($name)': '$($policyObjectsInJson[$name].FullName)' and '$($policyFile.FullName)'"
        $hasErrors = $true
        continue
    }
    else {
        $policyObjectsInJson.Add($name, $policyFile)
    }

    # If policy mode was not defined, it should be defaulted to "All"
    if (-not $policyObject.properties.mode) {
        $Mode = "All"
    }
    else {
        $Mode = $policyObject.properties.mode
    }

    # Constructing policy definitions parameters for splatting
    $policyDefinitionConfig = @{
        Name        = $name
        DisplayName = $displayName
        Policy      = $policyObject.properties.policyRule
        Parameter   = $policyObject.properties.parameters
        Metadata    = $policyObject.properties.metadata
        Mode        = $Mode
    }

    # Adding SubscriptionId or ManagementGroupName value (depending on the parameter set in use)
    $policyDefinitionConfig += $scopeParam

    # Add policy description if it's present in the definition file
    if ($policyObject.properties.description) {
        $policyDefinitionConfig.Description = $policyObject.properties.description
    }

    Write-Verbose "    Processing: '$($name)' from $($policyFile.Name)"
    $allPolicyDefinitions.Add($name, $policyDefinitionConfig)
    if ($existingCustomPolicyDefinitions.ContainsKey($name)) {
        # Update scenarios

        # Remove defined Policy definition entry from deleted hashtable (the hastable originally contains all custom Policy definition in the scope)
        $matchingCustomDefinition = $existingCustomPolicyDefinitions[$name]
        $maybeDeletedPolicyDefinitions.Remove($name)
        $policyDefinitionConfig.Add("id", $matchingCustomDefinition.id)


        # Check if policy definition in Azure is the same as in the JSON file
        $displayNameMatches = $matchingCustomDefinition.displayName -eq $displayName
        $descriptionMatches = $matchingCustomDefinition.description -eq $policyDefinitionConfig.Description
        $modeMatches = $matchingCustomDefinition.mode -eq $policyDefinitionConfig.Mode
        $metadataMatches = Confirm-MetadataMatches -existingMetadataObj $matchingCustomDefinition.metadata -definedMetadataObj $policyObject.properties.metadata
        $parameterMatchResults = Confirm-ParametersMatch -existingParametersObj $matchingCustomDefinition.parameters -definedParametersObj $policyObject.properties.parameters
        $policyRuleMatches = Confirm-ObjectValueEqualityDeep -existingObj $matchingCustomDefinition.policyRule -definedObj $policyObject.properties.policyRule

        # Update policy definition in Azure if necessary
        if ($displayNameMatches -and $policyRuleMatches -and $parameterMatchResults.match -and $metadataMatches -and $modeMatches -and $descriptionMatches) {
            # Write-Information "Unchanged '$($name)' - '$($displayName)'"
            $unchangedPolicyDefinitions.Add($name, $displayName)
        }
        else {
            if ($parameterMatchResults.incompatible) {
                # check if parameters are compatible with an update. Otherwise the Policy will need to be deleted (and any Initiatives and Assignments referencing the Policy)
                Write-Information "Replace '$($name)' - '$($displayName)'"
                $replacedPolicyDefinitions.Add($name, $policyDefinitionConfig)
            }
            else {
                Write-Information "Update '$($name)' - '$($displayName)'"
                $updatedPolicyDefinitions.Add($name, $policyDefinitionConfig)
            }
        }
    }
    else {
        $newPolicyDefinitions.Add($name, $policyDefinitionConfig)
        Write-Information "New '$($name)' - '$($displayName)'"
    }
}

$deletedPolicyDefinitions = @{}
foreach ($deletedName in $maybeDeletedPolicyDefinitions.Keys) {
    $deleted = $maybeDeletedPolicyDefinitions[$deletedName]
    if ($SuppressDeletes.IsPresent) {
        Write-Information "Suppressing Delete '$($deletedName)' - '$($deleted.displayName)'"
    }
    else {
        Write-Information "Delete '$($deletedName)' - '$($deleted.displayName)'"
        $splat = @{
            Name        = $deletedName
            DisplayName = $deleted.displayName
            id          = $deleted.id
        }
        $splat += $scopeParam
        $deletedPolicyDefinitions.Add($deletedName, $splat)
    }
}
Write-Information "Number of unchanged Policies = $($unchangedPolicyDefinitions.Count)"
Write-Information ""
Write-Information ""

if ($hasErrors) {
    throw "Policy definitions content errors"
}

#endregion

#region Process Initiative definitions

Write-Information "==================================================================================================="
Write-Information "Processing Initiative definitions JSON files in folder '$InitiativeDefinitionsRootFolder'"
Write-Information "==================================================================================================="
$initiativeFiles = @()
$initiativeFiles += Get-ChildItem -Path $InitiativeDefinitionsRootFolder -Recurse -File -Filter "*.json"
$initiativeFiles += Get-ChildItem -Path $InitiativeDefinitionsRootFolder -Recurse -File -Filter "*.jsonc"
Write-Information "Number of files = $($initiativeFiles.Length)"

if ($initiativeFiles.Length -lt 1) {
    Write-Warning "    There aren't any JSON files in the folder provided!"
}

# Getting Initiative definitions from the JSON files
$initiativeObjectsInJson = @{}
$deletedInitiativeDefinitions = @{}
$replacedInitiativeDefinitions = @{}
$newInitiativeDefinitions = @{}
$updatedInitiativeDefinitions = @{}
$unchangedInitiativeDefinitions = @{}
$maybeDeletedInitiativeDefinitions = $existingCustomInitiativeDefinitions.Clone()
# $first = $true

foreach ($initiativeFile in $initiativeFiles) {

    # Check if the Initiative definition JSON file is a valid JSON
    $Json = Get-Content -Path $initiativeFile.FullName -Raw -ErrorAction Stop

    try {
        $Json | Test-Json -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Initiative JSON file '$($initiativeFile.Name)' is not valid = $Json"
        $hasErrors = $true
        continue
    }

    $initiativeObject = $Json | ConvertFrom-Json -Depth 100
    $name = $initiativeObject.name
    $displayName = $initiativeObject.properties.displayName
    if (($null -eq $name) -or ($null -eq $displayName)) {
        Write-Information "Initiative JSON file '$($initiativeFile.FullName)' is missing Initiative name or displayName "
        $hasErrors = $true
        continue
    }
    if ($initiativeObjectsInJson.ContainsKey($name)) {
        Write-Information "There is more than one Initiative definition JSON that contains definition of '$($name)': '$($initiativeObjectsInJson[$name].FullName)' and '$($initiativeFile.FullName)'"
        $hasErrors = $true
    }
    else {
        $initiativeObjectsInJson.Add($name, $initiativeFile)
    }

    # Constructing Initiative definitions parameters for splatting
    $initiativeDefinitionConfig = @{
        Name        = $name
        DisplayName = $displayName
        Parameter   = $initiativeObject.properties.parameters
    }

    # Adding SubscriptionId or ManagementGroupName value (depending on the parameter set in use)
    $initiativeDefinitionConfig += $scopeParam

    # Add Initiative description if it's present in the definition file
    if ($initiativeObject.properties.description) {
        $initiativeDefinitionConfig.Description = $initiativeObject.properties.description
    }
    else {
        $initiativeDefinitionConfig.Description = ""
    }

    #Add Initiative metadata if it's present in the definition file
    if ($initiativeObject.properties.metadata) {
        $initiativeDefinitionConfig.Metadata = $initiativeObject.properties.metadata
    }
    else {
        $initiativeDefinitionConfig.Metadata = @{}
    }

    if ($initiativeObject.properties.policyDefinitionGroups) {
        $initiativeDefinitionConfig.GroupDefinition = $initiativeObject.properties.policyDefinitionGroups
    }
    else {
        $initiativeDefinitionConfig.GroupDefinition = @()
    }

    Write-Verbose "    Processing: '$($initiativeDefinitionConfig.Name)' from $($initiativeFile.Name)"
    $allInitiativeDefinitions.Add($initiativeDefinitionConfig.Name, $initiativeDefinitionConfig)
    $result = Build-PolicyDefinitionsForInitiative -allPolicyDefinitions $allPolicyDefinitions -replacedPolicyDefinitions $replacedPolicyDefinitions `
        -policyDefinitionsInJson $initiativeObject.properties.PolicyDefinitions -definitionScope $RootScope
    if ($result.usingUndefinedReference) {
        Write-Information "Undefined Policy referenced in '$($initiativeDefinitionConfig.Name)' from $($initiativeFile.Name)"
        $hasErrors = $true
    }
    else {
        $initiativeDefinitionConfig.PolicyDefinition = $result.policyDefinitions
        if ($existingCustomInitiativeDefinitions.ContainsKey($initiativeDefinitionConfig.Name)) {
            # Update scenarios

            # Remove defined Initative definition entry from deleted hashtable (the hastable originall contains all custom Initiative definition in the scope)
            $matchingCustomDefinition = $existingCustomInitiativeDefinitions[$initiativeDefinitionConfig.Name]
            $maybeDeletedInitiativeDefinitions.Remove($initiativeDefinitionConfig.Name)
            $initiativeDefinitionConfig.Add("id", $matchingCustomDefinition.id)

            if ($result.usingReplacedReference) {
                Write-Information "Replace '$($name)' - '$($displayName)'"
                $replacedInitiativeDefinitions.Add($name, $initiativeDefinitionConfig)
            }
            else {
                # Check if policy definition in Azure is the same as in the JSON file
                $displayNameMatches = $matchingCustomDefinition.displayName -eq $initiativeDefinitionConfig.DisplayName
                $descriptionMatches = $matchingCustomDefinition.description -eq $initiativeDefinitionConfig.Description
                $metadataMatches = Confirm-MetadataMatches `
                    -existingMetadataObj $matchingCustomDefinition.metadata `
                    -definedMetadataObj $initiativeObject.properties.metadata
                $parameterMatchResults = Confirm-ParametersMatch `
                    -existingParametersObj $matchingCustomDefinition.parameters `
                    -definedParametersObj  $initiativeObject.properties.parameters
                $groupDefinitionMatches = Confirm-ObjectValueEqualityDeep `
                    -existingObj $matchingCustomDefinition.policyDefinitionGroups `
                    -definedObj $initiativeDefinitionConfig.GroupDefinition
                $policyDefinitionsMatch = Confirm-ObjectValueEqualityDeep `
                    -existingObj $matchingCustomDefinition.policyDefinitions `
                    -definedObj $initiativeDefinitionConfig.PolicyDefinition

                # Update policy definition in Azure if necessary
                if ($displayNameMatches -and $groupDefinitionMatches -and $parameterMatchResults.match -and $metadataMatches -and $policyDefinitionsMatch -and $descriptionMatches) {
                    # Write-Information "Unchanged '$($name)' - '$($displayName)'"
                    $unchangedInitiativeDefinitions.Add($name, $displayName)
                }
                else {
                    if ($parameterMatchResults.incompatible) {
                        # check if parameters are compatible with an update. Otherwise the Policy will need to be deleted (and any Initiatives and Assignments referencing the Policy)
                        Write-Information "Replace '$($name)' - '$($displayName)'"
                        $replacedInitiativeDefinitions.Add($name, $initiativeDefinitionConfig)
                    }
                    else {
                        Write-Information "Update '$($name)' - '$($displayName)'"
                        $updatedInitiativeDefinitions.Add($name, $initiativeDefinitionConfig)
                    }
                
                }
            }
        }
        else {
            Write-Information "New '$($name)' - '$($displayName)'"
            $newInitiativeDefinitions.Add($name, $initiativeDefinitionConfig)
        }
    }
}
$deletedInitiativeDefinitions = @{}
foreach ($deletedName in $maybeDeletedInitiativeDefinitions.Keys) {
    $deleted = $maybeDeletedInitiativeDefinitions[$deletedName]
    if ($SuppressDeletes.IsPresent) {
        Write-Information "Suppressing Delete '$($deletedName)' - '$($deleted.displayName)'"
    }
    else {

        Write-Information "Delete '$($deletedName)' - '$($deleted.displayName)'"
        $splat = @{
            Name        = $deletedName
            DisplayName = $deleted.displayName
            id          = $deleted.id
        }
        $splat += $scopeParam
        $deletedInitiativeDefinitions.Add($deletedName, $splat)
    }
}

Write-Information "Number of unchanged Initiatives =  $($unchangedInitiativeDefinitions.Count)"
Write-Information  ""
Write-Information  ""

if ($hasErrors) {
    throw "Initiative definitions content errors"
}

#endregion

#region Process Assignment JSON files

#region Reading Assignment definitions from JSON files

Write-Information "==================================================================================================="
Write-Information "Processing Assignments JSON files in folder '$AssignmentsRootFolder'"
Write-Information "==================================================================================================="
$assignmentFiles = @()
$assignmentFiles += Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.json"
$assignmentFiles += Get-ChildItem -Path $AssignmentsRootFolder -Recurse -File -Filter "*.jsonc"
Write-Information "Number of files = $($assignmentFiles.Length)"

if ($assignmentFiles.Length -lt 1) {
    Write-Error "    There aren't any JSON files in the folder provided!"
    throw "At least one Assignment JSON file must be specified"
}

# Getting Assignment definitions from the JSON files
$obsoleteAssignments = $assignmentsInAzure.Clone()
$replacedAssignments = @{}
$newAssignments = @{}
$updatedAssignments = @{}
$deletedAssignments = @{}
$unchangedAssignments = @{}
$removedIdentities = @{}
$removedRoleAssignments = @{}
$addedRoleAssignments = @{}

#endregion

foreach ($assignmentFile in $assignmentFiles) {

    #region Process assignment file

    # Check if the policy definition JSON file is a valid JSON
    $Json = Get-Content -Path $assignmentFile.FullName -Raw -ErrorAction Stop

    try {
        $Json | Test-Json -ErrorAction Stop | Out-Null
        Write-Information "Process '$($assignmentFile.FullName)'"
    }
    catch {
        Write-Error "JSON file '$($assignmentFile.FullName)' is not valid."
        $hasErrors = $true
        continue
    }

    $assignmentObject = $Json | ConvertFrom-Json -AsHashtable

    # Collect all assignment definitions (values)
    $initialAssignmentDef = @{
        nodeName                       = "/"
        assignment                     = @{
            name        = ""
            displayName = ""
            description = ""
        }
        parameters                     = @{}
        additionalRoleAssignments      = @()
        hasErrors                      = $false
        hasOnlyNotSelectedEnvironments = $false
        ignoreBranch                   = $false
    }
    if ($globalNotScopeList) {
        $initialAssignmentDef.notScope = $globalNotScopeList
    }
    if ($managedIdentityLocation) {
        $initialAssignmentDef.managedIdentityLocation = $managedIdentityLocation
    }
    $assignmentDefList = Get-AssignmentDefs -scopeTreeInfo $scopeTreeInfo -definitionNode $assignmentObject -assignmentDef $initialAssignmentDef -assignmentSelector $AssignmentSelector

    #endregion

    $numberOfUnchangedAssignmentsInFile = 0
    $numberOfNotScopeChanges = 0
    foreach ($def in $assignmentDefList) {
        if ($def.hasErrors) {
            $hasErrors = $true
            throw "Assignment definitions content errors"
        }
        $noChangedAssignments = $true
        $numberOfUnchangedAssignmentsForAssignmentDef = 0

        # What is being assigned
        $definitionEntry = $def.definitionEntry
        $policyDefinitionId = $null

        # Find what to assign and check if it exists
        $name = $null
        $friendlyName = $definitionEntry.friendlyNameToDocumentIfGuid
        $policySpecText = ""
        $result = $null
        $parametersInDefinition = $null
        $policySpec = @{}
        # Potential update scenario
        if ($definitionEntry.initiativeName) {
            $name = $definitionEntry.initiativeName
            if ($friendlyName) {
                $policySpecText = "Initiative '$name' - '$friendlyName'"
            }
            else {
                $policySpecText = "Initiative '$name'"
            }
            $result = Confirm-InitiativeDefinitionUsedExists -allInitiativeDefinitions $allInitiativeDefinitions -replacedInitiativeDefinitions $replacedInitiativeDefinitions -initiativeNameRequired $name
            if ($result.usingUndefinedReference) {
                $hasErrors = $true
                continue
            }
            else {
                $initiativeDefinition = $allInitiativeDefinitions[$name]
                if ($initiativeObjectsInJson.ContainsKey($name)) {
                    # is custom
                    $policyDefinitionId = $RootScope + "/providers/Microsoft.Authorization/policySetDefinitions/" + $name
                    $parametersInDefinition = $initiativeDefinition.Parameter
                }
                else {
                    # is built in
                    $policyDefinitionId = "/providers/Microsoft.Authorization/policySetDefinitions/" + $name
                    $parametersInDefinition = $initiativeDefinition.parameters
                }
                $policySpec = @{ initiativeId = $policyDefinitionId } 
            }
        }
        elseif ($definitionEntry.policyName) {
            $name = $definitionEntry.policyName
            if ($friendlyName) {
                $policySpecText = "Policy '$name' - '$friendlyName'"
            }
            else {
                $policySpecText = "Policy '$($name)'"
            }       
            $result = Confirm-PolicyDefinitionUsedExists -allPolicyDefinitions $allPolicyDefinitions -replacedPolicyDefinitions $replacedPolicyDefinitions -policyNameRequired $name
            if ($result.usingUndefinedReference) {
                $hasErrors = $true
                continue
            }
            else {
                $policyDefinition = $allPolicyDefinitions[$name]
                if ($policyObjectsInJson.ContainsKey($name)) {
                    # is custom
                    $policyDefinitionId = $RootScope + "/providers/Microsoft.Authorization/policyDefinitions/" + $name
                    $parametersInDefinition = $policyDefinition.Parameter
                }
                else {
                    # is built in
                    $policyDefinitionId = "/providers/Microsoft.Authorization/policyDefinitions/" + $name
                    $parametersInDefinition = $policyDefinition.parameters
                }
                $policySpec = @{ policyId = $policyDefinitionId }
            }
        }
        else {
            Write-Error "Neither policyName nor initiativeName specified for Assignment `'$($def.assignment.DisplayName)`' ($($def.assignment.Name))  - must specify exactly one"
            $hasErrors = $true
            continue
        }

        # Check if branch is active
        if ($def.ignoreBranch) {
            #     Write-Information "        %%% IGNORED node=$($def.nodeName), reason=ignoreBranch flag set"
            # }
            # elseif ($def.hasOnlyNotSelectedEnvironments) {
            #     Write-Information "        %%% IGNORED node=$($def.nodeName), reason=PaC-Env $AssignmentSelector without scope definition"
        }
        else {
            # Set parameters
            $parametersSetInAssignment = $def.parameters
            $parameterObject = @{}
            if ($parametersInDefinition -and $parametersSetInAssignment) {
                foreach ($definedParameter in $parametersInDefinition.psobject.Properties) {
                    $parameterName = $definedParameter.Name
                    if ($parametersSetInAssignment.ContainsKey($parameterName)) {
                        Write-Debug "              Setting param $parametername = $($parametersSetInAssignment[$parametername])"
                        $parameterObject[$parameterName] = $parametersSetInAssignment[$parameterName]
                    }
                }
            }
            Write-Debug "              parameters[$($parameterObject.Count)] = $($parameterObject | ConvertTo-Json -Depth 100)"

            # Process list of scopes in this branch
            foreach ($scopeInfo in $def.scopeCollection) {
                # Create the assignment splat (modified)
                $id = $scopeInfo.scope + "/providers/Microsoft.Authorization/policyAssignments/" + $def.assignment.Name
                $createAssignment = @{
                    Id                    = $id
                    Name                  = $def.assignment.Name
                    DisplayName           = $def.assignment.DisplayName
                    Description           = $def.assignment.Description
                    Metadata              = @{}
                    DefinitionEntry       = $definitionEntry
                    Scope                 = $scopeInfo.scope
                    PolicyParameterObject = $parameterObject
                    identityRequired      = $false
                }
                $createAssignment += $policySpec
                if ($null -ne $def.metadata) {
                    $createAssignment.Metadata = $def.metadata
                }
                if ($null -ne $def.managedIdentityLocation) {
                    $createAssignment.managedIdentityLocation = $def.managedIdentityLocation
                }

                # Retrieve roleDefinitionIds
                $roleDefinitions = @()
                if ($definitionEntry.roleDefinitionIds) {
                    foreach ($roleDefinitionId in $definitionEntry.roleDefinitionIds) {
                        $roleDefinitions += @{
                            scope            = $scopeInfo.scope
                            roleDefinitionId = $roleDefinitionId
                        }
                    }
                }
                if ($def.additionalRoleAssignments) {
                    $roleDefinitions += $def.additionalRoleAssignments
                }
                if ($roleDefinitions.Length -gt 0) {
                    $createAssignment.identityRequired = $true
                    $createAssignment.Metadata.Add("roles", $roleDefinitions)
                    if ($null -eq $createAssignment.managedIdentityLocation) {
                        Write-Error "Assignment requires an identity and the definition does not define a managedIdentityLocation"
                        Throw "Assignment requires an identity and the definition does not define a managedIdentityLocation"
                    }
                }

                if ($scopeInfo.notScope.Length -gt 0) {
                    Write-Debug "                notScope added = $($scopeInfo.notScope | ConvertTo-Json -Depth 100)"
                    $createAssignment.NotScope = @() + $scopeInfo.notScope
                }

                if ($assignmentsInAzure.ContainsKey($id)) {
                    # Assignment already exists
                    $obsoleteAssignments.Remove($id) # do not delete
                    $assignmentInfoInAzure = $assignmentsInAzure[$id]
                    $assignmentInAzure = $assignmentInfoInAzure.assignment
                    $value = @{
                        assignmentId    = $id
                        identity        = $assignmentInAzure.identity
                        location        = $assignmentInAzure.location
                        roleAssignments = $assignmentInfoInAzure.roleAssignments
                    }
                    $createAssignment += @{
                        existingAssignment = $value
                    }
                
                    $policyDefinitionMatches = $policyDefinitionId -eq $assignmentInAzure.policyDefinitionId
                    $replace = (-not $policyDefinitionMatches) -or $result.usingReplacedReference
                    $identityLocationChanged, $addingIdentity = Build-AzPolicyAssignmentIdentityAndRoleChanges `
                        -replacingAssignment $replace `
                        -managedIdentityLocation $createAssignment.managedIdentityLocation `
                        -assignmentConfig $createAssignment `
                        -removedIdentities $removedIdentities `
                        -removedRoleAssignments $removedRoleAssignments `
                        -addedRoleAssignments $addedRoleAssignments
                
                    if ($replace -or $identityLocationChanged) {
                        $replacedAssignments.Add($Id, $createAssignment)
                        Write-AssignmentDetails `
                            -printHeader $noChangedAssignments `
                            -def $def `
                            -policySpecText $policySpecText `
                            -scopeInfo $scopeInfo `
                            -roleDefinitions $roleDefinitions `
                            -prefix "### REPLACE"
                        $noChangedAssignments = $false
                    }
                    else {
                        $displayMatches = ($createAssignment.DisplayName -eq $assignmentInAzure.displayName) -and ($createAssignment.Description -eq $assignmentInAzure.description)
                        $notScopeMatches = Confirm-ObjectValueEqualityDeep `
                            -existingObj $assignmentInAzure.notScopes `
                            -definedObj $scopeInfo.notScope
                        $parametersMatch = Confirm-AssignmentParametersMatch `
                            -existingParametersObj $assignmentInAzure.parameters `
                            -definedParametersObj $parameterObject
                        $metadataMatches = Confirm-MetadataMatches `
                            -existingMetadataObj $assignmentInAzure.metadata `
                            -definedMetadataObj $createAssignment.Metadata
                        $update = -not ($displayMatches -and $notScopeMatches -and $parametersMatch -and $metadataMatches)
                        $createAssignment.addingIdentity = $addingIdentity

                        if ($addingIdentity) {
                            $updatedAssignments.Add($Id, $createAssignment)
                            if ($update) {
                                Write-AssignmentDetails `
                                    -printHeader $noChangedAssignments `
                                    -def $def `
                                    -policySpecText $policySpecText `
                                    -scopeInfo $scopeInfo `
                                    -roleDefinitions $roleDefinitions `
                                    -prefix "~~~ UPDATE"
                                $noChangedAssignments = $false
                            }
                            else {
                                # Should not be possible
                                Write-AssignmentDetails `
                                    -printHeader $noChangedAssignments `
                                    -def $def `
                                    -policySpecText $policySpecText `
                                    -scopeInfo $scopeInfo `
                                    -roleDefinitions $roleDefinitions `
                                    -prefix "~~~ ADD IDENTITY"
                                $noChangedAssignments = $false
                            }
                        }
                        elseif ($update) {
                            $updatedAssignments.Add($Id, $createAssignment)
                            if ($displayMatches -and $parametersMatch -and $metadataMatches) {
                                # Write-Information "        *** NOTSCOPE UPDATE at $($scopeInfo.scope)"
                                $numberOfNotScopeChanges += 1
                            }
                            else {
                                Write-AssignmentDetails `
                                    -printHeader $noChangedAssignments `
                                    -def $def `
                                    -policySpecText $policySpecText `
                                    -scopeInfo $scopeInfo `
                                    -roleDefinitions $roleDefinitions `
                                    -prefix "~~~ UPDATE"
                                $noChangedAssignments = $false
                            }
                        }
                        else {
                            $unchangedAssignments.Add($id, $createAssignment.Name)
                            $numberOfUnchangedAssignmentsForAssignmentDef++
                            $numberOfUnchangedAssignmentsInFile++
                        }
                    }
                }
                else {
                    $newAssignments.Add($createAssignment.Id, $createAssignment)
                    Write-AssignmentDetails `
                        -printHeader $noChangedAssignments `
                        -def $def `
                        -policySpecText $policySpecText `
                        -scopeInfo $scopeInfo `
                        -roleDefinitions $roleDefinitions `
                        -prefix "+++ NEW"
                    $noChangedAssignments = $false
                }
            }
        }
    }
    if ($numberOfNotScopeChanges -gt 0) {
        Write-Information "    *** $($numberOfNotScopeChanges) NotScope Changes only Assignments"
    }
    if ($numberOfUnchangedAssignmentsInFile -gt 0) {
        Write-Information "    === $($numberOfUnchangedAssignmentsInFile) Unchanged Assignments"
    }
}

if ($obsoleteAssignments.Count -gt 0) {
    if ($SuppressDeletes.IsPresent) {
        Write-Information "Suppressing Delete Assignments ($($obsoleteAssignments.Count))"
        foreach ($id in $obsoleteAssignments.Keys) {
            Write-Information "    '$id'"
        }
    }
    else {
        Write-Information "Delete Assignments ($($obsoleteAssignments.Count))"
        foreach ($id in $obsoleteAssignments.Keys) {
            $assignmentInfoInAzure = $assignmentsInAzure[$id]
            $assignmentInAzure = $assignmentInfoInAzure.assignment
            $roleAssignmentsInAzure = $assignmentInfoInAzure.roleAssignments
            Write-Information "    '$id'"
            $deletedAssignment = @{
                assignmentId = $id
                DisplayName  = $assignmentInAzure.displayName
            }
            $deletedAssignments.Add($id, $deletedAssignment)
            if ($null -ne $roleAssignmentsInAzure -and $roleAssignmentsInAzure.Count -gt 0) {
                $removedRoleAssignments.Add($id, @{
                        DisplayName     = $assignmentInAzure.DisplayName
                        identity        = $assignmentInAzure.identity
                        roleAssignments = $roleAssignmentsInAzure
                    }
                )
            }
        }
    }
}
Write-Information ""
Write-Information ""

#endregion

#region Publish plan to be consumed by next stage
$numberOfChanges = `
    $deletedPolicyDefinitions.Count + `
    $replacedPolicyDefinitions.Count + `
    $updatedPolicyDefinitions.Count + `
    $newPolicyDefinitions.Count + `
    $deletedInitiativeDefinitions.Count + `
    $replacedInitiativeDefinitions.Count + `
    $updatedInitiativeDefinitions.Count + `
    $newInitiativeDefinitions.Count + `
    $deletedAssignments.Count + `
    $replacedAssignments.Count + `
    $updatedAssignments.Count + `
    $newAssignments.Count + `
    $removedIdentities.Count + `
    $removedRoleAssignments.Count + `
    $addedRoleAssignments.Count
$noChanges = $numberOfChanges -eq 0

$plan = @{
    rootScope                     = $RootScope
    scopeParam                    = $scopeParam
    tenantID                      = $TenantId
    noChanges                     = $noChanges
    createdOn                     = (Get-Date -AsUTC -Format "u")

    deletedPolicyDefinitions      = $deletedPolicyDefinitions
    replacedPolicyDefinitions     = $replacedPolicyDefinitions
    updatedPolicyDefinitions      = $updatedPolicyDefinitions
    newPolicyDefinitions          = $newPolicyDefinitions

    deletedInitiativeDefinitions  = $deletedInitiativeDefinitions
    replacedInitiativeDefinitions = $replacedInitiativeDefinitions
    updatedInitiativeDefinitions  = $updatedInitiativeDefinitions
    newInitiativeDefinitions      = $newInitiativeDefinitions

    deletedAssignments            = $deletedAssignments
    replacedAssignments           = $replacedAssignments
    updatedAssignments            = $updatedAssignments
    newAssignments                = $newAssignments

    removedIdentities             = $removedIdentities
    removedRoleAssignments        = $removedRoleAssignments
    addedRoleAssignments          = $addedRoleAssignments
}

Write-Information "==================================================================================================="
Write-Information "Writing plan file $PlanFile"
if (-not (Test-Path $PlanFile)) {
    $null = New-Item $PlanFile -Force
}
$null = $plan | ConvertTo-Json -Depth 100 | Out-File -FilePath $PlanFile -Force
Write-Information "==================================================================================================="
Write-Information ""
Write-Information ""

Write-Information "==================================================================================================="
Write-Information "Summary"
Write-Information "==================================================================================================="
Write-Information "rootScope   : $($RootScope)"
Write-Information "tenantID    : $($TenantID)"
Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Policy definitions - unchanged : $($unchangedPolicyDefinitions.Count)"
Write-Information "Policy definitions - new       : $($newPolicyDefinitions.Count)"
Write-Information "Policy definitions - updated   : $($updatedPolicyDefinitions.Count)"
Write-Information "Policy definitions - replaced  : $($replacedPolicyDefinitions.Count)"
Write-Information "Policy definitions - deleted   : $($deletedPolicyDefinitions.Count)"
Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Initiative definitions - unchanged : $($unchangedInitiativeDefinitions.Count)"
Write-Information "Initiative definitions - new       : $($newInitiativeDefinitions.Count)"
Write-Information "Initiative definitions - updated   : $($updatedInitiativeDefinitions.Count)"
Write-Information "Initiative definitions - replaced  : $($replacedInitiativeDefinitions.Count)"
Write-Information "Initiative definitions - deleted   : $($deletedInitiativeDefinitions.Count)"
Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Assignments - unchanged : $($unchangedAssignments.Count)"
Write-Information "Assignments - new       : $($newAssignments.Count)"
Write-Information "Assignments - updated   : $($updatedAssignments.Count)"
Write-Information "Assignments - replaced  : $($replacedAssignments.Count)"
Write-Information "Assignments - deleted   : $($deletedAssignments.Count)"
Write-Information "---------------------------------------------------------------------------------------------------"
Write-Information "Assignments - remove Identity           : $($removedIdentities.Count)"
Write-Information "Assignments - remove Role Assignment(s) : $($removedRoleAssignments.Count)"
Write-Information "Assignments - add Role Assignment(s)    : $($addedRoleAssignments.Count)"
Write-Information ""
if ($noChanges) {
    Write-Information "***************************** NO CHANGES NEEDED ***************************************************"
}
else {
    Write-Information "============================= $numberOfChanges CHANGES NEEDED ==================================================="
}

#endregion
