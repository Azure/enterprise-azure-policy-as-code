<#
.SYNOPSIS
    This function creates a new EPAC Global Settings File.

.DESCRIPTION
    The New-HydrationGlobalSettingsFile function creates a new Hydration Global Settings File based on the provided parameters. 
    It takes several parameters including PacOwnerId, EpacRoot, ManagedIdentityLocation, MainPacSelector, EpacPacSelector, Cloud, TenantId, MainDeploymentRoot, EpacDevelopmentRoot, Strategy, RepoRoot, LogFilePath, UseUtc, and KeepDfcSecurityAssignments.

.PARAMETER PacOwnerId
    The owner ID for the PAC. This parameter is mandatory.
.PARAMETER ManagedIdentityLocation
    The location for the managed identity. Run Get-AzLocation to see a list of options. This parameter is mandatory.
.PARAMETER MainPacSelector
    The main PAC selector. This parameter is mandatory.

.PARAMETER EpacPacSelector
    The EPAC PAC selector. This parameter is mandatory.

.PARAMETER Cloud
    The cloud environment. This parameter is mandatory.

.PARAMETER TenantId
    The tenant ID. This parameter is mandatory.

.PARAMETER MainDeploymentRoot
    The main deployment root scope. This parameter is mandatory.

.PARAMETER EpacDevelopmentRoot
    The EPAC development root scope. This parameter is mandatory.

.PARAMETER Strategy
    The strategy for the desired state. This parameter is mandatory.

.PARAMETER RepoRoot
    The root path of the repository. This parameter is mandatory.

.PARAMETER LogFilePath
    The path to the log file. This parameter is optional.

.PARAMETER UseUtc
    Switch to use UTC time. This parameter is optional.

.PARAMETER KeepDfcSecurityAssignments
    Switch to keep DFC security assignments. This parameter is optional.

.EXAMPLE
    New-HydrationGlobalSettingsFile -PacOwnerId "owner123" -EpacRoot "./EpacRoot" -ManagedIdentityLocation "East US" -MainPacSelector "mainSelector" -EpacPacSelector "epacSelector" -Cloud "AzureCloud" -TenantId "tenant123" -MainDeploymentRoot "rootScope" -EpacDevelopmentRoot "devRootScope" -Strategy "strategy" -RepoRoot "./Repo"

    This example creates a new Hydration Global Settings File using the provided parameters and paths.

.NOTES
    The function first checks if the Definitions directory exists in the repository. If it does not, it creates the directory. 
    It then builds the Global Settings object by iterating over the environments in the answers and writes the Global Settings to a JSONC file.

.LINK
    https://aka.ms/epac
    https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
#>
function New-HydrationGlobalSettingsFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = "The owner ID for the PAC. This parameter is mandatory.")]
        [string]$PacOwnerId,

        [Parameter(Mandatory = $true, HelpMessage = "The location for the managed identity. Run Get-AzLocation to see a list of options. This parameter is mandatory.")]
        [string]$ManagedIdentityLocation,

        [Parameter(Mandatory = $true, HelpMessage = "The main PAC selector. This parameter is mandatory.")]
        [string]$MainPacSelector,

        [Parameter(Mandatory = $true, HelpMessage = "The EPAC PAC selector. This parameter is mandatory.")]
        [string]$EpacPacSelector,

        [Parameter(Mandatory = $true, HelpMessage = "The cloud environment. This parameter is mandatory.")]
        [ValidateSet("AzureCloud", "AzureGovernment","AzureChinaCloud","AzureGermanCloud","AzureStack")]
        [string]$Cloud,

        [Parameter(Mandatory = $true, HelpMessage = "The tenant ID. This parameter is mandatory.")]
        [string]$TenantId,

        [Parameter(Mandatory = $true, HelpMessage = "The main deployment root Management Group ID. This parameter is mandatory.")]
        [string]$MainDeploymentRoot,

        [Parameter(Mandatory = $true, HelpMessage = "The EPAC development root Management Group ID. This parameter is mandatory.")]
        [string]$EpacDevelopmentRoot,

        [Parameter(Mandatory = $true, HelpMessage = "The strategy for the desired state (full/ownedOnly). This parameter is mandatory.")]
        [ValidateSet("full", "ownedOnly")]
        [string]$Strategy,

        [Parameter(Mandatory = $true, HelpMessage = "The root path of the repository. This parameter is mandatory.")]
        [string]$DefinitionsRootFolder,

        [Parameter(Mandatory = $false, HelpMessage = "The path to the log file. This parameter is optional.")]
        [string]$LogFilePath,

        [Parameter(Mandatory = $false, HelpMessage = "Switch to use UTC time. This parameter is optional.")]
        [bool]$UseUtc,

        [Parameter(Mandatory = $false, HelpMessage = "Switch to keep DFC security assignments. This parameter is optional.")]
        [bool]$KeepDfcSecurityAssignments
    )

    $InformationPreference = "Continue"
    $mgBaseString = "/providers/Microsoft.Management/managementGroups/"
    if (!(Test-Path $DefinitionsRootFolder)) {
        $null = New-HydrationDefinitionFolder -DefinitionsRootFolder $DefinitionsRootFolder
        Write-HydrationLogFile -entrytype logEntryDataAsPresented -LogFilePath $LogFilePath -EntryData "Created Definitions folder at $DefinitionsRootFolder" -UseUtc:$UseUtc -ForegroundColor Yellow
    }
    Write-Information "`nCreating Global Settings..."
    # Build GlobalSettings object
    $environmentBlock = @()
    $mainEntry = [ordered]@{
        pacSelector             = $MainPacSelector
        cloud                   = $Cloud
        tenantId                = $TenantId
        deploymentRootScope     = $($mgBaseString + "/" + $MainDeploymentRoot).Replace("//", "/")
        desiredState            = @{
            strategy                     = $Strategy
            keepDfcSecurityAssignments   = $KeepDfcSecurityAssignments
            excludedScopes               = @() # TODO: Improvement, add exceptions question loop for these
            excludedPolicyDefinitions    = @() # TODO: Improvement, add exceptions question loop for these
            excludedPolicySetDefinitions = @() # TODO: Improvement, add exceptions question loop for these
            excludedPolicyAssignments    = @() # TODO: Improvement, add exceptions question loop for these
        }
        globalNotScopes         = @() # TODO: Improvement, add exceptions question loop for these
        managedIdentityLocation = $ManagedIdentityLocation
    }
    $environmentBlock += $mainEntry
    $mainBlockString = $mainEntry | ConvertTo-Json -Depth 10 -Compress
    Write-HydrationLogFile -entrytype logEntryDataAsPresented -LogFilePath $LogFilePath -EntryData "Main Tenant, Main PacSelector: $mainBlockString" -UseUtc:$UseUtc -Silent
    $epdEntry = [ordered]@{
        pacSelector             = $EpacPacSelector
        cloud                   = $Cloud
        tenantId                = $TenantId
        deploymentRootScope     = $($mgBaseString + "/" + $EpacDevelopmentRoot).Replace("//", "/")
        desiredState            = @{
            strategy                     = $Strategy
            keepDfcSecurityAssignments   = $KeepDfcSecurityAssignments
            excludedScopes               = @() # TODO: Improvement, add exceptions question loop for these
            excludedPolicyDefinitions    = @() # TODO: Improvement, add exceptions question loop for these
            excludedPolicySetDefinitions = @() # TODO: Improvement, add exceptions question loop for these
            excludedPolicyAssignments    = @() # TODO: Improvement, add exceptions question loop for these
        }
        globalNotScopes         = @() # TODO: Improvement, add exceptions question loop for these
        managedIdentityLocation = $ManagedIdentityLocation
    }
    $epdBlockString = $mainEntry | ConvertTo-Json -Depth 10 -Compress
    Write-HydrationLogFile -entrytype logEntryDataAsPresented -LogFilePath $LogFilePath -EntryData "Main Tenant, EPAC PacSelector: $epdBlockString" -UseUtc:$UseUtc -Silent
    $environmentBlock += $epdEntry

    # TODO: Improvement, add blocks for additional pacSelectors using a loop and a list of hashtables as input
    $globalSettings = [ordered]@{
        '$schema'       = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/global-settings-schema.json"
        pacOwnerId      = $PacOwnerId
        pacEnvironments = $environmentBlock
    }
    $globalSettingsPath = Join-Path $DefinitionsRootFolder "global-settings.jsonc"
    Write-Information "Writing Global Settings to $globalSettingsPath`n"
    if (!(test-path $(Split-Path $globalSettingsPath))) {
        $null = New-Item -ItemType Directory -Path $DefinitionsRootFolder -Force
    }
    if ($DebugPreference -eq "Continue") {
        $globalSettingsString = $globalSettings | ConvertTo-Json -Depth 10 -Compress
        Write-HydrationLogFile -entrytype logEntryDataAsPresented -LogFilePath $LogFilePath -EntryData "Global Settings content: $globalSettingsString" -UseUtc:$UseUtc -Silent
    }
    Write-HydrationLogFile -entrytype logEntryDataAsPresented -LogFilePath $LogFilePath -EntryData "Global Settings file created: $globalSettingsPath" -UseUtc:$UseUtc -foregroundcolor yellow
    $globalSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $globalSettingsPath -Encoding ascii -Force
    return $globalSettings
}