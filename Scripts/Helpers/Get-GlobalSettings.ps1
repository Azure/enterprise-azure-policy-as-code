function Get-GlobalSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)] [string] $DefinitionsRootFolder,
        [Parameter(Mandatory = $false)] [string] $OutputFolder,
        [Parameter(Mandatory = $false)] [string] $InputFolder
    )

    # Calculate folders
    $Folders = Get-PacFolders `
        -DefinitionsRootFolder $DefinitionsRootFolder `
        -OutputFolder $OutputFolder `
        -InputFolder $InputFolder

    $DefinitionsRootFolder = $Folders.definitionsRootFolder
    $OutputFolder = $Folders.outputFolder
    $InputFolder = $Folders.inputFolder
    $globalSettingsFile = $Folders.globalSettingsFile

    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Read global settings from '$globalSettingsFile'."
    Write-Information "==================================================================================================="
    Write-Information "PowerShell Versions: $($PSVersionTable.PSVersion)"

    $Json = Get-Content -Path $globalSettingsFile -Raw -ErrorAction Stop
    if (!(Test-Json $Json)) {
        Write-Error "JSON file ""$($globalSettingsFile)"" is not valid = $Json" -ErrorAction Stop
    }
    [hashtable] $settings = $Json | ConvertFrom-Json -AsHashtable
    [array] $PacEnvironments = $settings.pacEnvironments
    [hashtable] $PacEnvironmentDefinitions = @{}
    [string[]] $PacEnvironmentSelectors = @()
    $PacOwnerId = $settings.pacOwnerId
    if ($null -eq $PacOwnerId) {
        Write-Error "global-settings does not contain a pacOwnerId. Add a pacOwnerId field with a GUID or other unique id!" -ErrorAction Stop
    }

    foreach ($PacEnvironment in $PacEnvironments) {

        $PacSelector = $PacEnvironment.pacSelector
        if ($null -eq $PacSelector) {
            Write-Error "Policy as Code pacEnvironments array element does not contain a pacSelector." -ErrorAction Stop
        }
        $PacEnvironmentSelectors += $PacSelector

        $Cloud = $PacEnvironment.cloud
        if ($null -eq $Cloud) {
            Write-Warning "Policy as Code environment $PacSelector does not define the cloud to use, default to 'AzureCloud'"
            $Cloud = "AzureCloud"
        }

        $TenantId = $PacEnvironment.tenantId
        if ($null -eq $TenantId) {
            Write-Error "Policy as Code environment $PacSelector does not contain a tenantId." -ErrorAction Stop
        }

        $defaultSubscriptionId = $PacEnvironment.defaultSubscriptionId
        if ($null -ne $defaultSubscriptionId) {
            Write-Warning "Policy as Code environment $PacSelector contains a legacy defaultSubscriptionId. Remove it!" -ErrorAction Stop
        }
        if ($null -ne $PacEnvironment.rootScope) {
            Write-Error "Policy as Code environment $PacSelector contains a legacy rootScope. Replace rootScope with deploymentRootScope containing a fully qualified scope id!" -ErrorAction Stop
        }

        $PolicyDefinitionsScopes = @()
        $deploymentRootScope = $null
        if ($null -ne $PacEnvironment.deploymentRootScope) {
            $deploymentRootScope = $PacEnvironment.deploymentRootScope
            $PolicyDefinitionsScopes += $deploymentRootScope

            if ($null -ne $PacEnvironment.inheritedDefinitionsScopes) {
                $inheritedDefinitionsScopes = $PacEnvironment.inheritedDefinitionsScopes
                if ($inheritedDefinitionsScopes -isnot [array]) {
                    Write-Error "Policy as Code environment $PacSelector element inheritedDefinitionsScopes must be an array of strings." -ErrorAction Stop
                }
                $PolicyDefinitionsScopes += $inheritedDefinitionsScopes
            }
            $PolicyDefinitionsScopes += ""
        }
        else {
            Write-Error "Policy as Code environment $PacSelector must contain a deploymentRootScope field." -ErrorAction Stop
        }

        # globalNotScopes
        [array] $globalNotScopeList = @()
        if ($null -ne $settings.globalNotScopes) {
            $GlobalNotScopes = $settings.globalNotScopes
            if ($GlobalNotScopes.ContainsKey($PacSelector)) {
                $globalNotScopeList += $GlobalNotScopes[$PacSelector]
            }
            if ($GlobalNotScopes.ContainsKey("*")) {
                $globalNotScopeList += $GlobalNotScopes["*"]
            }
        }

        $desiredState = @{ # defaults
            strategy                     = "full" # Mirrors previous behavior (before desireState feature). -NoDelete would be equivalent to ownedOnly
            includeResourceGroups        = $false # Mirrors previous behavior (before desireState feature). -IncludeResourceGroups would be equivalent to $true
            excludedScopes               = [System.Collections.ArrayList]::new()
            excludedPolicyDefinitions    = @()
            excludedPolicySetDefinitions = @()
            excludedPolicyAssignments    = @()
        }
        if ($null -ne $PacEnvironment.desiredState) {
            $desired = $PacEnvironment.desiredState
            $Strategy = $desired.strategy
            if ($null -ne $Strategy) {
                $valid = @("full", "ownedOnly")
                if ($Strategy -notin $valid) {
                    Write-Error "Policy as Code environment $PacSelector field desiredState.strategy ($Strategy) must be one of $(ConvertTo-Json $valid -Compress)." -ErrorAction Stop
                }
                $desiredState.strategy = $Strategy
            }
            $IncludeResourceGroups = $desired.includeResourceGroups
            if ($null -ne $IncludeResourceGroups) {
                if ($IncludeResourceGroups -is [bool]) {
                    $desiredState.includeResourceGroups = $IncludeResourceGroups
                }
                else {
                    Write-Error "Policy as Code environment $PacSelector field desiredState.includeResourceGroups ($IncludeResourceGroups) must be a boolean value." -ErrorAction Stop
                }
            }
            $excluded = $desired.excludedScopes
            if ($null -ne $excluded) {
                if ($excluded -isnot [array]) {
                    Write-Error "Policy as Code environment $PacSelector field desiredState.excludedScopes ($(ConvertTo-Json $excluded -Compress)) must be an array of strings." -ErrorAction Stop
                }
                foreach ($entry in $excluded) {
                    if ($null -ne $entry -and $entry -is [string] -and $entry -ne "") {
                        $null = $desiredState.excludedScopes.Add($entry)
                    }
                }
            }
            $excluded = $desired.excludedPolicyDefinitions
            if ($null -ne $excluded) {
                if ($excluded -isnot [array]) {
                    Write-Error "Policy as Code environment $PacSelector field desiredState.excludedPolicyDefinitions ($(ConvertTo-Json $excluded -Compress)) must be an array of strings." -ErrorAction Stop
                }
                $desiredState.excludedPolicyDefinitions = $excluded
            }
            $excluded = $desired.excludedPolicySetDefinitions
            if ($null -ne $excluded) {
                if ($excluded -isnot [array]) {
                    Write-Error "Policy as Code environment $PacSelector field desiredState.excludedPolicySetDefinitions ($(ConvertTo-Json $excluded -Compress)) must be an array of strings." -ErrorAction Stop
                }
                $desiredState.excludedPolicySetDefinitions = $excluded
            }
            $excluded = $desired.excludedPolicyAssignments
            if ($null -ne $excluded) {
                if ($excluded -isnot [array]) {
                    Write-Error "Policy as Code environment $PacSelector field desiredState.excludedPolicyAssignments ($(ConvertTo-Json $excluded -Compress)) must be an array of strings." -ErrorAction Stop
                }
                $desiredState.excludedPolicyAssignments = $excluded
            }
        }
        foreach ($entry in $globalNotScopeList) {
            if ($null -ne $entry -and $entry -ne "" -and !$entry.Contains("*")) {
                $null = $desiredState.excludedScopes.Add($entry)
            }
        }

        # Managed identity location
        $managedIdentityLocation = $null
        if ($settings.managedIdentityLocations) {
            $managedIdentityLocations = $settings.managedIdentityLocations
            if ($managedIdentityLocations.ContainsKey($PacSelector)) {
                $managedIdentityLocation = $managedIdentityLocations[$PacSelector]
            }
            elseif ($managedIdentityLocations.ContainsKey("*")) {
                $managedIdentityLocation = $managedIdentityLocations["*"]

            }
        }
        $null = $PacEnvironmentDefinitions.Add($PacSelector, @{
                pacSelector             = $PacSelector
                pacOwnerId              = $PacOwnerId
                cloud                   = $Cloud
                tenantId                = $TenantId
                deploymentRootScope     = $deploymentRootScope
                policyDefinitionsScopes = $PolicyDefinitionsScopes
                desiredState            = $desiredState
                globalNotScopes         = $globalNotScopeList
                managedIdentityLocation = $managedIdentityLocation
            }
        )
    }
    $prompt = $PacEnvironmentSelectors | Join-String -Separator ', '

    Write-Information "PAC Environments: $($prompt)"
    Write-Information "Definitions root folder: $DefinitionsRootFolder"
    Write-Information "Input folder: $InputFolder"
    Write-Information "Output folder: $OutputFolder"
    Write-Information ""

    $PolicyDocumentationsFolder = "$DefinitionsRootFolder/policyDocumentations"
    $PolicyDefinitionsFolder = "$DefinitionsRootFolder/policyDefinitions"
    $PolicySetDefinitionsFolder = "$DefinitionsRootFolder/policySetDefinitions"
    $PolicyAssignmentsFolder = "$DefinitionsRootFolder/policyAssignments"
    $PolicyExemptionsFolder = "$DefinitionsRootFolder/policyExemptions"

    [hashtable] $globalSettings = @{
        definitionsRootFolder      = $DefinitionsRootFolder
        globalSettingsFile         = $globalSettingsFile
        outputFolder               = $OutputFolder
        inputFolder                = $InputFolder
        policyDocumentationsFolder = $PolicyDocumentationsFolder
        policyDefinitionsFolder    = $PolicyDefinitionsFolder
        policySetDefinitionsFolder = $PolicySetDefinitionsFolder
        policyAssignmentsFolder    = $PolicyAssignmentsFolder
        policyExemptionsFolder     = $PolicyExemptionsFolder
        pacEnvironmentSelectors    = $PacEnvironmentSelectors
        pacEnvironmentPrompt       = $prompt
        pacEnvironments            = $PacEnvironmentDefinitions
    }
    return $globalSettings
}
