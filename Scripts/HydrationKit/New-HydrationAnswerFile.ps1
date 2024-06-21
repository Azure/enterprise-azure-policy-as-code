<#
.SYNOPSIS
    This function creates a new Hydration Answer File.

.DESCRIPTION
    The New-HydrationAnswerFile function creates a new Hydration Answer File with values determined by an interactive session.

.PARAMETER Output
    The path where the Hydration Answer File will be created. Defaults to "./Output".

.EXAMPLE
    New-HydrationAnswerFile -Output "./CustomOutput"

    This example creates a new Hydration Answer File in the "./CustomOutput" directory.

.NOTES
    The Hydration Answer File is used to store answers for the hydration process.
    
.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>

[CmdletBinding()]
param (
    [string]
    $Output = "./Output"
)
$returnData = [ordered]@{
    useCurrent               = ""
    useEpacBaseline          = ""
    usePciBaseline           = ""
    outputPath               = ""
    epacPrefix               = ""
    epacSuffix               = ""
    platform                 = ""
    pipelineType             = ""
    pipelinePath             = ""
    branchingFlow            = ""
    scriptType               = ""
    epacParentGroupName      = ""
    epacSourceGroupName      = ""
    pacOwnerId               = ""
    initialTenantId          = ""
    managedIdentityLocations = ""
    useCaf                   = $false # Not supported yet [ordered]@{}
    environments             = [ordered]@{}
}
$environmentEntry = [ordered]@{
    pacSelector                = ""
    intermediateRootGroupName  = ""
    initialPolicyScope         = ""
    tenantId                   = ""
    cloud                      = ""
    strategy                   = "ownedOnly"
    keepDfcSecurityAssignments = $false
}
$InformationPreference = "Continue"
$acceptablePlatforms = @( "ado", "github", "other")
################################################## TEST ENVIRONMENT ##################################################
Write-Debug "PSScriptRoot: $PSScriptRoot"
Write-Information "Confirming file location within repo filestructure has not changed..."
$repoRoot = Split-Path $Output
Write-Debug "Repo Root: $repoRoot"
Set-Location -Path $repoRoot
$returnData.outputPath = Join-Path $Output "HydrationKitAnswerFile"
Write-Information "Testing Connection to Azure is active..."
$azContext = get-azcontext
$conTest = get-azsubscription -SubscriptionId $($azContext.Subscription.Id) -WarningAction SilentlyContinue
if ($null -eq $conTest) {
    Write-Error "You are not connected to Azure. `n`
      Please connect to Azure using 'Connect-AzAccount' within the context of the tenant that you wish to deploy your EPAC Dev environment to prior to running this script."
    return
}
$tenantEntry = Copy-HydrationOrderedHashtable $environmentEntry
Write-Information "    Connection validated..."
$returnData.initialTenantId = $tenantEntry.tenantId = $azContext.Tenant.Id
$tenantEntry.cloud = $azContext.Environment.Name
Write-Debug "TenantId: $($tenantEntry.tenantId)"
Write-Debug "Cloud: $($tenantEntry.cloud)"
Write-Host "`n"
Write-Host "################################################################################"
Write-Host "# Beginning Hydration Interview"
Write-Host "################################################################################"
Write-Host "We show your target tenant to be $($returnData.initialTenantId), which is in the $($tenantEntry.cloud) environment." 
Write-Host "     This information was taken from Get-AzContext.`n`n"
$response = Read-Host "If this is incorrect, please type 'N' to leave the script. `nOtherwise press enter to continue."
if ($response -eq "N") {
    Write-Warnig "You have chosen to exit the script. If your connection information was incorrect, use Connect-AzAccount with the TenantId and SubscriptionId options to specify the connection you desire."
    return
}
Write-Host "`nYou have chosen to continue."
Write-Information "`nGathering supporting information for script processing...`n`n"
    
## PacSelector
do {
    Write-Host "`n################################################################################"
    if ($repeat) { Write-Host "The value `'$($tenantEntry.pacSelector)`' is an invalid selection for PacSelector. Please use only alpha-neumeric characters, dashes, and underscores." }
    Write-Host "We must choose a unique string to identify the deployment environment to be governed by EPAC where your deployed resources reside.`n"
    Write-Host "Please choose a name for the PacSelector. Only alpha-neumeric characters, dashes, and underscores are permitted."
    Write-Host "This is the name that will be used to identify the unique PacSelector in Global Settings under which settings for this deployment will be grouped for use in policy orchestration by EPAC.`n"
    Write-Host "Recommendation: 'tenant01'"
    $repeat = $true
    $tenantEntry.pacSelector = Read-Host "Please provide a PacSelector."
}until($null -ne $tenantEntry.pacSelector -and $tenantEntry.pacSelector -match '^[a-zA-Z0-9_-]+$')
Clear-Variable repeat
Write-Information "`nResult Verified for variable $($tenantEntry.pacSelector), which will be used to identify the deployment to this Tenant.`n"

# Define intermediateRootGroupName
$tenantRootObject = Get-AzManagementGroupRestMethod -GroupId $tenantEntry.tenantId -recurse  -expand 
$tenantChildrenString = $tenantRootObject.Children.Name -join ", "
do {
    Write-Host "`n################################################################################"
    if ($repeat) { Write-Host "`nPlease choose a valid Management Group ID. $($tenantEntry.intermediateRootGroupName) could not be located within the current Tenant.`n" }
    Write-Host "We must identify the Intermediate Root Management Group."
    Write-Host "    - This is the Management Group under which all of your Azure Resource deployments are being created."
    Write-Host "    - This is generally a level below the Tenant Root."
    Write-Host "    - This should value not be confused with the display name, which can differ."
    Write-Host "    - This value should not be misconstrued for the full Resource ID of the Management Group."
    Write-Host "    - This is the root of the hierarchy that will be duplicated for EPAC DevOps deployment testing."
    Write-Host "    - This is generally one of the Management Groups that exist as children of the Tenant Root."
    Write-Host "`nTenant Root Children: $tenantChildrenString`n"
        
    $tenantEntry.intermediateRootGroupName = Read-Host "What is the ID of your Intermediate Management Group Root?"
    $repeat = $true
    $test = Get-AzManagementGroupRestMethod -GroupId $tenantEntry.intermediateRootGroupName
}until($null -ne $test)
Clear-Variable repeat
Write-Information "`nResult Verified for variable intermediateRootGroupName: $($tenantEntry.intermediateRootGroupName)`n"
# TODO Make a better return for a no children response to the tenant root management group

## Tenant Node Definition for Assignment files
do {
    Write-Host "`n################################################################################"
    if ($repeat) { Write-Host "Please choose an existing Management Group ID. $($tenantEntry.initialPolicyScope) could not be located within the current Tenant.`n" }
    Write-Host "We must choose a Management Group that will recieve initial assignments intended for Management Groups in the $($tenantEntry.pacSelector) PacSelector."
    Write-Host "    - This can be any Management Group inside of $($tenantEntry.intermediateRootGroupName), but initial deployments are intended to audit the environment"
    Write-Host "    and are generally applied at the top level of the PacSelector.`n"
    Write-Host "Recommendation: $($tenantEntry.intermediateRootGroupName)"
    $tenantEntry.initialPolicyScope = Read-Host "What is the ID of the Management Group for this PacSelector?"
    $repeat = $true
    $test = Get-AzManagementGroupRestMethod -GroupID $tenantEntry.intermediateRootGroupName -ErrorAction SilentlyContinue
}until($null -ne $test)
Clear-Variable repeat
Clear-Variable test
Write-Information "`nResult Verified for variable $($tenantEntry.intermediateRootGroupName), which will be the Assignment Scope for new policy assignments.`n"

########## END TENAN ENTRY ##########
$returnData.environments.add($tenantEntry.pacSelector, $tenantEntry)
$returnData.epacSourceGroupName = $tenantEntry.intermediateRootGroupName
Write-Information "Test Here to confirm above was set as expected"
######################################################################

    
## Define epacParentGroupName
do {
    Write-Host "`n################################################################################"
    if ($repeat) { Write-Host "Please choose a valid Management Group ID. $($returnData.epacParentGroupName) could not be located within the current Tenant.`n" }
    Write-Host "We must choose a Management Group to house the EPAC Dev environment."
    Write-Host "    - This can be any Management Group, including the Tenant Root."
    Write-Host "    - This will be the new parent of the root of the Management Group hierarchy that EPAC will use to test prior to deployment to $($tenantEntry.intermediateRootGroupName)."
    Write-Host "    - This ID should not be confused with the display name, which can differ, nor the full ResourceId."
    Write-Host "    - Common choices are the Tenant Root (recommended) or the Intermediate Root Management Group.`n"
    Write-Host "Recommendation: $($returnData.initialTenantId)"
    $returnData.epacParentGroupName = Read-Host "What is the ID of the Management Group that you would like to use?"
    $repeat = $true
    $test = Get-AzManagementGroupRestMethod -GroupId $returnData.epacParentGroupName -ErrorAction SilentlyContinue
}until($null -ne $test)
Clear-Variable repeat
Clear-Variable test
Write-Information "`nResult Verified for variable epacParentGroupName $($returnData.epacParentGroupName)`n"
  
## Define epacPrefix
do {
    Write-Host "`n################################################################################"
    if ($repeat) { Write-Host " `'$newIrgName`' is not a valid Management Group name option.`n" }
    Write-Host "We must choose either a unique prefix and/or suffix to configure on Management Groups used for EPAC deployment testing."
    Write-Host "    - This should result in a unique name that does not already exist within your tenant. "
    Write-Host "    - For example, if you choose 'EPAC-' as your prefix, the Root Management Group for  EPAC testing will be named `'EPAC-$($tenantEntry.intermediateRootGroupName)`' and each child management group under $($tenantEntry.intermediateRootGroupName) will also gain this prefix, or if you choose '-EPAC' as your suffix, the Root Management Group for  EPAC testing will be named `'$($tenantEntry.intermediateRootGroupName)-EPAC`' Management Group will be duplicated with the same naming convention.`n"
    Write-Host "We recommend a short prefix or suffix, generally no more than ten characters."
    $returnData.epacPrefix = Read-Host "    Please provide a prefix for the EPAC Management Groups"
    $returnData.epacSuffix = Read-Host "    Please provide a suffix for the EPAC Management Groups"
    $newIrgName = -join ($returnData.epacPrefix, $($tenantEntry.intermediateRootGroupName), $returnData.epacSuffix)
    $newNameTest = Test-HydrationManagementGroupName -ManagementGroupName $newIrgName -ErrorAction SilentlyContinue
    # TODO: Could build resiliency here to allow it to confirm existing MG with same name is child of appropriate parent.
    $repeat = $true
}until(($null -ne $returnData.epacPrefix -or $null -ne $returnData.epacPrefix) -and $newNameTest -eq $true)
Clear-Variable repeat

# Duplicate Tenant Entry with modifications for EPAC
$epacEntry = Copy-HydrationOrderedHashtable $environmentEntry
$epacEntry.pacSelector = "epac-dev"
$epacEntry.intermediateRootGroupName = $newIrgName
$epacEntry.initialPolicyScope = $returnData.epacPrefix + $tenantEntry.initialPolicyScope + $returnData.epacSuffix
$epacEntry.tenantId = $tenantEntry.tenantId
$epacEntry.cloud = $tenantEntry.cloud   
$returnData.environments.add($epacEntry.pacSelector, $epacEntry)
Write-Information "`nDecision Data:"
if ($returnData.epacPrefix) {
    Write-Information "    epacPrefix: $($returnData.epacPrefix)"
}
if ($returnData.epacSuffix) {
    Write-Information "    epacSuffix: $($returnData.epacSuffix)"
}
## Define epacSuffix
Write-Information "    The Group Representing $($tenantEntry.intermediateRootGroupName) within EPAC's Management Group Root Structure used for DevOps testing will be $($epacEntry.intermediateRootGroupName).`n"
    
# TODO: Offer an option to deploy a CAF3 hierarchy under the IntermediateRootGroupName, and potentially skip some of the items below.
# TODO: ACTIVE Confirm there's an MG Builder below, and clean it up with the new code

## We don't need this, our recommendation is the root. No need to enable bad behavior.
# ## Gather Child Management Groups for use as Tenant Nodes
# Write-Information "`n################################################################################"
# Write-Information "Gathering available Management Groups for use as EPAC Nodes used for Assignments..."
# try {
#     $irList = -join (((Get-HydrationChildManagementGroupNameList -ManagementGroupName $tenantEntry.intermediateRootGroupName).Name | Where-Object { $_ -notlike "$($returnData.epacPrefix)*" -and $_ -notlike "*$($returnData.epacSuffix)" }) -join (", "), $tenantEntry.intermediateRootGroupName)
# }
# catch {
#     Write-Error "Unable to retrieve child Management Groups for $($tenantEntry.intermediateRootGroupName). Please ensure that you have access to this Management Group and try again."
#     return
# }

## Managed ID Location
$locationList = (Get-AzLocation).Location
$locationString = $locationList -join ", "
do {
    Write-Host "`n################################################################################"
    if ($repeat) { Write-Host "That was not a valid location, please choose one option from the list below." }
    Write-Host "DINE and Modify Policies use Managed Identities to remediate compliance failures, and these must exist in a region of Azure."
    Write-Host "    This is also known as a location. Please choose a location from the list, and be aware of what regions are approved for your organization."
    Write-Host "`nRegion Options: $locationString`n"
    $returnData.managedIdentityLocations = Read-Host "Please use a region from the list above."
    $repeat = $true
}until($locationList -contains $returnData.managedIdentityLocations)
Clear-Variable repeat
Write-Information "`nResult Verified for variable $($returnData.managedIdentityLocations), which will be used to contain Managed IDs that will be used by Azure Policy to complete remediations.`n"

## pacOwnerId
$newGuid = (New-Guid).Guid
do {
    Write-Host "`n################################################################################"
    if ($repeat) {
        if (!($pacOwnerId)) { 
            Write-Host "Null values for pacOwnerId are not permitted for this setting." 
        }
        else { 
            Write-Host $( -join ("You can either use ", $newGuid, ' or conform to the regex pattern ^[a-zA-Z0-9_-]+$.', "`n")) 
        }
    }
    Write-Host "We must define the PacOwnerId that will be used to identify the policies managed by EPAC by assigning this information in metadata."
    Write-Host "If you choose to create your own, we recommend that it include a unique GUID."
    $response = Read-Host "Would you like to use the pacOwnerId $newGuid (Y/N)?"
    if ($response -eq "Y") {
        $returnData.pacOwnerId = $newGuid
        $repeat = $false
    }
    elseif ($response -eq "N") {
        #TESTREM: $returnData.pacOwnerId = Read-Host "Please provide a PacOwnerId, we recommend that it include a unique GUID."
        $returnData.pacOwnerId = Read-Host "What would you like to use as the pacOwnerId?"
        if (!($returnData.pacOwnerId -match '^[a-zA-Z0-9_-]+$')) {
            Write-Warning "Invalid characters detected. Please use only alpha-neumeric characters, dashes, and underscores."
            $repeat = $true
        }
        else {
            $repeat = $false
            
        }
    }
    else {
        Write-Information "Invalid response."
        $repeat = $true
    }
}until($null -ne $returnData.pacOwnerId -and $true -ne $repeat )
Clear-Variable repeat
Write-Information "`nResult Verified for variable $($returnData.pacOwnerId), which will be the ID used in metadata for policies orchestrated by EPAC.`n"
## Platform Selection
$platformInc = 0
do {
    Write-Host "`n################################################################################"
    if ($repeat) { Write-Host "Please choose one of the following platforms: $($acceptablePlatforms -join ", ")." }
    Write-Host "We must choose a DevOps Platform to use for deployment of policies using EPAC.`n"
    Write-Host "This will populate pipelines for supported types, but will not modify the configuration of your deployment environment at this time."
    Write-Host "If your deployment tool is not among those listed, you can choose 'other' and create your own, or choose one of the supported platforms to recieve pipelines to start from.1n"
    Write-Host "Valid choices: $($acceptablePlatforms -join ", ").`n"
    $returnData.platform = Read-Host "What DevOps Platform will you be using to run EPAC?"
    $repeat = $true
}until($acceptablePlatforms -contains $returnData.platform -or $platformInc -gt 5)
Clear-Variable repeat
Clear-Variable platformInc
if ($acceptablePlatforms -notcontains $returnData.platform) {
    Write-Warning "Invalid response after numerous attempts."
    Write-Warning "We will take this to mean that you are not using any of the provided options, and have designated 'other', which will result in the pipeline not being created, and you will need to create your own."
    $returnData.platform = "other"
}
if (!($returnData.platform -eq "other") -and !($null -eq $returnData.platform )) {
    $bfInt = 0
    do {
        if ($repeat) { Write-Host "Please choose 1 or 2.`n" }
        Write-Host "`n`nPlease choose a branching flow from the valid choices below:"
        Write-Host "    (1) Release (Non-Prod assignments DO exist in $($tenantEntry.initialPolicyScope))"
        Write-Host "    (2) GitHub (Non-Prod assignments DO NOT exist in $($tenantEntry.initialPolicyScope))`n"
        Write-Warning "Release flow requires manual exclusions be created, and that the scope be set for Non-Prod nodes manually. This will be resolved in the next release.`n"
    
        $branchingFlow = Read-Host "Please choose option 1 or 2"
        switch ($branchingFlow) {
            1 {
                $returnData.branchingFlow = "release"
            }
            2 {
                $returnData.branchingFlow = "github"
            }
            default {
                $repeat = $true
                $bfInt ++
            }
        }
    }until($branchingFlow -eq 1 -or $branchingFlow -eq 2 -or $bfInt -eq 10)
    Remove-Variable repeat -erroraction SilentlyContinue
    Remove-Variable bfInt -erroraction SilentlyContinue

    $stInt = 0
    do {
        if ($repeat) { Write-Host "Please choose 1 or 2.`n" }
        Write-Host "`n`nPlease choose how you would like the Pipeline to interact with EPAC code in order to run processes."
        Write-Host "    (1) Local scripts in the repo will be used to run processes."
        Write-Host "    (2) The EPAC Module will be used to run processes."
        $scriptType = Read-Host "Please choose option 1 or 2"
        switch ($scriptType) {
            1 {
                $returnData.scriptType = "scripts"
            }
            2 {
                $returnData.scriptType = "module"
            }
            default {
                $repeat = $true
                $stInt ++
            }
        }
    }until($scriptType -eq 1 -or $scriptType -eq 2 -or $stInt -eq 10)
    Remove-Variable repeat -erroraction SilentlyContinue
    Remove-Variable stInt -erroraction SilentlyContinue

    # No recovery needed on pipeline path, we expect null
    Write-Host "`n`nIf you have a desired custom path for your pipeline storage, please list it here."
    Write-Host "    This should be a relative path from the directory $repoRoot.`n"
    Write-Host "Recommendation: Leave this blank to use the default path."
    $pipelinePath = Read-Host "Please enter a custom path, if desired"
    if ($pipelinePath) {
        $returnData.pipelinePath = join-path $repoRoot $pipelinePath
        if (!(Test-Path $returnData.pipelinePath)) {
            Write-Host "Creating pipeline folder at $($returnData.pipelinePath)..."
            New-Item -Path $returnData.pipelinePath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

}
# Platform specific options
switch ($returnData.platform) {
    "ado" {
        $returnData.pipelineType = "AzureDevOps"
        Write-Information "`nResult Verified for platform: $($returnData.platform), which will be used to determine the pipeline configuration for EPAC DevOps testing.`n"
    }
    "github" {
        $returnData.pipelineType = "GitHubActions"
        Write-Information "`nResult Verified for platform: $($returnData.platform), which will be used to determine the pipeline configuration for EPAC DevOps testing.`n"
    }
    "other" {
        Write-Information "`nNo pipeline data will be generated.`n"
    }
    default {
        Write-Error "Invalid response. This is a bug. Please report this to the EPAC team."
        return
    }
}

# Define Initial Policy Sets
## Decision: Import CAF Policy Set
# TODO: Requires infrastructure to be in place, too much for this script at this time.
# do {
#     Write-Host "`n################################################################################"
#     if ($repeat) { Write-Host "Please choose 1 or 2." }
#     Write-Host "We must choose whether to import the Cloud Adoption Framework policies for deployment."
#     Write-Host "    CAF policies can be reviewed at https://github.com/Azure/Enterprise-Scale/tree/main/src/resources/Microsoft.Authorization"
#     Write-Host "    CAF policySets build on existing built-in Policies, and incorporate new policyDefinitions included in the repo."
#     Write-Host "Please choose from the options Below:"
#     Write-Host "    1. Yes, import the CAF policy set for deployment."
#     Write-Host "    2. No, DO NOT import the CAF policy set for deployment."
#     $useCaf = 1
#     $useCaf = Read-Host "Would you like to import the CAF policy set for deployment? (1 or 2)"
# }until($useCaf -eq 1 -or $useCaf -eq 2)
# Clear-Variable repeat
# switch ($useCaf) {
#     1 {
#         $returnData.useCaf = $true
#         Write-Host "`nResult is that CAF Policies will be used.`n"
#     }
#     2 {
#         $returnData.useCaf = $false
#         Write-Host "`nResult is that CAF Policies WILL NOT be used.`n"
#     }
#     default {
#         Write-Error "Invalid response. This is a bug. CAF policies will not be used."
#         $returnData.useCaf = $false
#         return
#     }
# }
## Decision: Export current policies/assignments for EPAC management
do {
    Write-Host "`n################################################################################"
    if ($repeat) { Write-Host "Please choose 1 or 2." }
    Write-Host "We must choose whether to include existing policy objects in the EPAC deployment."
    Write-Host "    EPAC can export the assignments in $($tenantEntry.intermediateRootGroupName), and its child objects, for integration and orchestration through the EPAC system.`n"
    Write-Host "Please choose from the options Below:"
    Write-Host "    1. Prepare the contents of this Management Group for EPAC deployment."
    Write-Host "    2. DO NOT prepare the contents of this Management Group for EPAC deployment.`n"
    $useCurrent = Read-Host "Would you like to prepare those policies for EPAC management?"
    $repeat = $true
}until($useCurrent -eq 1 -or $useCurrent -eq 2)
Clear-Variable repeat
switch ($useCurrent) {
    1 {
        $returnData.useCurrent = $true
        Write-Host "`nResult is that the current policy assignments will be exported for EPAC management.`n"
    }
    2 {
        $returnData.useCurrent = $false
        Write-Host "`nResult is that the current policy assignments will NOT be exported for EPAC management.`n"
    }
    default {
        Write-Error "Invalid response. This is a bug. Current policy assignments will NOT be exported for EPAC management."
        $returnData.useCurrent = $false
        return
    }
}
# Decision: Include Microsoft Security Baseline and NIST 800-53 Policy Set to Audit Current Configuration
do {
    Write-Host "`n################################################################################"
    if ($repeat) { Write-Host "Please choose 1 or 2." }
    Write-Host "We must choose whether to include EPAC recommended baseline auditing policies."
    Write-Host "    EPAC includes configurations For Microsoft Security Baseline as well as NIST 800-53 policies.`n"
    Write-Host "Please choose from the options below:"
    Write-Host "    1. Import the MSB and NIST 800-53 policy set for deployment in Audit mode."
    Write-Host "    2. DO NOT import the MSB and NIST 800-53 policy set for deployment in Audit mode.`n"
    $useEpacBaseline = Read-Host "Would you like to import the MSB and NIST 800-53 policy set for deployment in Audit mode?"
    $repeat = $true
}until($useEpacBaseline -eq 1 -or $useEpacBaseline -eq 2)
Clear-Variable repeat
if ($useEpacBaseline = 1) {
    $returnData.useEpacBaseline = $true
}
elseif ($useEpacBaseline = 2) {
    $returnData.useEpacBaseline = $false
}
else {
    write-error "Invalid response. This is a bug. EPAC recommended baseline will not be applied."
    $returnData.useEpacBaseline = $false
    return
}
# Decision: Include PCI-DSS Policy Set to Audit Current Configuration
do {
    Write-Host "`n################################################################################"
    if ($repeat) { Write-Host "Please choose 1 or 2." }
    Write-Host "We must choose whether to include PCI-DSS auditing policies."
    Write-Host "    EPAC includes configurations for the PCI-DSS policy set that is part of Azure.`n"
    Write-Host "Please choose from the options below:"
    Write-Host "    1. Import the PCI-DSS policy set for deployment in Audit mode."
    Write-Host "    2. DO NOT import the PCI-DSS policy set for deployment in Audit mode.`n"
    $usePci = Read-Host "Would you like to import the PCI-DSS policy set for deployment in Audit mode?"
    $repeat = $true
}until($usePci -eq 1 -or $usePci -eq 2)
Clear-Variable repeat
if ($usePci = 1) {
    $returnData.usePciBaseline = $true
}
elseif ($usePci = 2) {
    $returnData.usePciBaseline = $false
}
else {
    write-error "Invalid response. This is a bug. PCI-DSS baseline will not be applied."
    $returnData.usePciBaseline = $false
    return
}
## Build Output directory
Write-Host "`n################################################################################"
if (!(Test-Path $returnData.outputPath)) {
    Write-Host "Creating output folder at $($returnData.outputPath)..."
    New-Item -Path $returnData.outputPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
}
## Build Answer File
$configFilePath = $(Join-Path $returnData.outputPath 'answerFile.json')
Write-Host "An answer file will be created at $configFilePath."
Write-Host "    This can be used to rerun the script without prompts should you run into a rights issue, or something else that might require this to be run again without updating any values."
# Write-Host "    Manual updating of values is not supported."
Write-Host "`nCreating answer file..."
$returnData | ConvertTo-Json -Depth 50 | Out-File -FilePath $configFilePath -Force
return $returnData
