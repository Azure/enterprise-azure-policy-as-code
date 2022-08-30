#Requires -PSEdition Core

function Get-GlobalSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)] [string] $definitionsRootFolder,
        [Parameter(Mandatory = $false)] [string] $outputFolder,
        [Parameter(Mandatory = $false)] [string] $inputFolder
    )

    # Callcuate folders
    $folders = Get-PacFolders `
        -definitionsRootFolder $definitionsRootFolder `
        -outputFolder $outputFolder `
        -inputFolder $inputFolder

    $definitionsRootFolder = $folders.definitionsRootFolder
    $outputFolder = $folders.outputFolder
    $inputFolder = $folders.inputFolder
    $globalSettingsFile = $folders.globalSettingsFile

    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Read global settings from '$globalSettingsFile'."
    Write-Information "==================================================================================================="

    $Json = Get-Content -Path $globalSettingsFile -Raw -ErrorAction Stop
    if (!(Test-Json $Json)) {
        Write-Error "JSON file ""$($globalSettingsFile)"" is not valid = $Json" -ErrorAction Stop
    }
    [hashtable] $settings = $Json | ConvertFrom-Json -AsHashtable
    [array] $pacEnvironments = $settings.pacEnvironments
    [hashtable] $pacEnvironmentDefinitions = @{}
    [string[]] $pacEnvironmentSelectors = @()
    foreach ($pacEnvironment in $pacEnvironments) {

        $pacSelector = $pacEnvironment.pacSelector
        if (!$pacEnvironment.pacSelector) {
            Write-Error "Policy as Code environment $pacSelector does not contain a tenantId" -ErrorAction Stop
        }
        $pacEnvironmentSelectors += $pacSelector

        $cloud = $pacEnvironment.cloud
        if ($null -eq $cloud) {
            Write-Information "Warning: no cloud defined in global-settings.jsonc, default to 'AzureCloud'"
            $cloud = "AzureCloud"
        }

        $tenantId = $pacEnvironment.tenantId
        if ($null -eq $tenantId) {
            Write-Error "Policy as Code environment $pacSelector does not contain a tenantId" -ErrorAction Stop
        }

        $rootScopeId = "Unknown"
        $rootScope = $pacEnvironment.rootScope
        if ($null -eq $rootScope) {
            Write-Error "Policy as Code environment $pacSelector does not contain a root scope" -ErrorAction Stop
        }
        else {
            $rootScope = $pacEnvironment.rootScope
            if ($rootScope.SubscriptionId) {
                $rootScopeId = "/subscriptions/$($rootScope.SubscriptionId)"
            }
            elseif ($rootScope.ManagementGroupName) {
                $rootScopeId = "/providers/Microsoft.Management/managementGroups/$($rootScope.ManagementGroupName)"
            }
            else {
                Write-Error "Policy as Code environment $pacSelector does not contain a valid root scope" -ErrorAction Stop
            }
        }

        $defaultSubscriptionId = $pacEnvironment.defaultSubscriptionId
        if ($null -eq $defaultSubscriptionId) {
            Write-Error "Policy as Code environment $pacSelector does not contain a defaultSubscriptionId" -ErrorAction Stop
        }

        [void] $pacEnvironmentDefinitions.Add($pacSelector, @{
                cloud                 = $cloud
                tenantId              = $tenantId
                rootScopeId           = $rootScopeId
                rootScope             = $rootScope
                defaultSubscriptionId = $defaultSubscriptionId
            }
        )
    }
    $prompt = $pacEnvironmentSelectors | Join-String -Separator ', '

    $managedIdentityLocations = $settings.managedIdentityLocations
    if ($null -eq $managedIdentityLocations) {
        $managedIdentityLocation = $settings.managedIdentityLocation
        if ($null -ne $managedIdentityLocation) {
            Write-Information "Warning: no managedIdentityLocations (plural; recent change) defined in global-settings.jsonc. Using legacy managedIdentityLocation (singular) = $managedIdentityLocation"
            $managedIdentityLocations = @{
                "*" = $managedIdentityLocation
            }
        }
        else {
            Write-Error "No managedIdentityLocations (plural; recent change) defined in global-settings.jsonc." -ErrorAction Stop
        }
    }

    $globalNotScopes = $settings.globalNotScopes
    if ($null -eq $globalNotScopes) {
        Write-Information "Warning: no global Not Scope defined in global-settings.jsonc, default an empty list"
        $globalNotScopes = @{
            "*" = @()
        }
    }

    Write-Information "PAC Environments: $($prompt)"
    Write-Information "Definitions root folder: $definitionsRootFolder"
    Write-Information "Input folder: $inputFolder"
    Write-Information "Output folder: $outputFolder"
    Write-Information ""

    $documentationDefinitionsFolder = "$definitionsRootFolder/Documentation"
    if (!(Test-Path $documentationDefinitionsFolder -PathType Container)) {
        $documentationDefinitionsFolder = "$definitionsRootFolder/DocumentationSpecs" # Legacy location
    }

    [hashtable] $globalSettings = @{
        definitionsRootFolder          = $definitionsRootFolder
        globalSettingsFile             = $globalSettingsFile
        outputFolder                   = $outputFolder
        inputFolder                    = $inputFolder
        policyDefinitionsFolder        = "$definitionsRootFolder/Policies"
        initiativeDefinitionsFolder    = "$definitionsRootFolder/Initiatives"
        assignmentsFolder              = "$definitionsRootFolder/Assignments"
        exemptionsFolder               = "$definitionsRootFolder/Exemptions"
        documentationDefinitionsFolder = "$documentationDefinitionsFolder"
        pacEnvironmentSelectors        = $pacEnvironmentSelectors
        pacEnvironmentPrompt           = $prompt
        pacEnvironments                = $pacEnvironmentDefinitions
        globalNotScopes                = $globalNotScopes
        managedIdentityLocations       = $managedIdentityLocations
    }
    return $globalSettings
}
