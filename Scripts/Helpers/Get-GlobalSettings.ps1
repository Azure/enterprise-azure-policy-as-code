function Get-GlobalSettings {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)] [string] $DefinitionsRootFolder,
        [Parameter(Mandatory = $false)] [string] $OutputFolder,
        [Parameter(Mandatory = $false)] [string] $InputFolder
    )

    # Calculate folders
    $folders = Get-PacFolders `
        -DefinitionsRootFolder $DefinitionsRootFolder `
        -OutputFolder $OutputFolder `
        -InputFolder $InputFolder

    $DefinitionsRootFolder = $folders.definitionsRootFolder
    $OutputFolder = $folders.outputFolder
    $InputFolder = $folders.inputFolder
    $globalSettingsFile = $folders.globalSettingsFile

    Write-Information ""
    Write-Information "==================================================================================================="
    Write-Information "Read global settings from '$globalSettingsFile'."
    Write-Information "==================================================================================================="
    Write-Information "PowerShell Versions: $($PSVersionTable.PSVersion)"

    $Json = Get-Content -Path $globalSettingsFile -Raw -ErrorAction Stop
    $settings = @{}
    try {
        $settings = $Json | ConvertFrom-Json -AsHashTable
    }
    catch {
        Write-Error "Assignment JSON file '$($globalSettingsFile)' is not valid." -ErrorAction Stop
    }

    $telemetryOptOut = $settings.telemetryOptOut
    $telemetryEnabled = $true
    if ($null -ne $telemetryOptOut) {
        $telemetryEnabled = -not $telemetryOptOut
    }

    [hashtable] $pacEnvironmentDefinitions = @{}
    $pacEnvironmentSelectors = [System.Collections.ArrayList]::new()
    $hasErrors = $false
    $pacOwnerId = $settings.pacOwnerId
    if ($null -eq $pacOwnerId) {
        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: does not contain the required pacOwnerId field. Add a pacOwnerId field with a GUID or other unique id!"
        $hasErrors = $true
    }

    if ($null -ne $settings.globalNotScopes) {
        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: contains a deprecated globalNotScopes field. Move the values into each pacEnvironment!"
        $hasErrors = $true
    }
    if ($null -ne $settings.managedIdentityLocations -or $null -ne $settings.managedIdentityLocation) {
        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: contains a deprecated managedIdentityLocations field. Move the values into each pacEnvironment!"
        $hasErrors = $true
    }

    $pacEnvironments = $settings.pacEnvironments
    if ($null -eq $pacEnvironments) {
        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: does not contain a pacEnvironments array. Add a pacEnvironments array with at least one environment!"
        $hasErrors = $true
    }
    elseif ($pacEnvironments -isnot [array]) {
        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironments must be an array of objects."
        $hasErrors = $true
    }
    elseif ($pacEnvironments.Count -eq 0) {
        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironments array must contain at least one environment."
        $hasErrors = $true
    }
    else {
        foreach ($pacEnvironment in $pacEnvironments) {

            $pacSelector = $pacEnvironment.pacSelector
            if ($null -eq $pacSelector) {
                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: a pacEnvironments array element does not contain the required pacSelector element."
                $hasErrors = $true
            }
            $null = $pacEnvironmentSelectors.Add($pacSelector)

            $cloud = $pacEnvironment.cloud
            if ($null -eq $cloud) {
                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector does not define the required cloud element."
                $hasErrors = $true
            }

            $tenantId = $pacEnvironment.tenantId
            if ($null -eq $tenantId) {
                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector does not contain required tenantId field."
                $hasErrors = $true
            }

            # Managed identity location
            $managedIdentityLocation = $pacEnvironment.managedIdentityLocation
            if ($null -eq $managedIdentityLocation) {
                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector does not contain required managedIdentityLocation field."
                $hasErrors = $true
            }

            $managingTenantId = $pacEnvironment.managingTenant.managingTenantId
            $managingTenantRootScope = $pacEnvironment.managingTenant.managingTenantRootScope
            if ($null -ne $managingTenantId) {
                if ($null -eq $pacEnvironment.managingTenant.managingTenantRootScope) {
                    Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector element managingTenantRootScope must have a valid value when managingTenantID has a value."
                    $hasErrors = $true
                }
                $objectGuid = [System.Guid]::empty
                # Returns True if successfully parsed, otherwise returns False.
                $isGUID = [System.Guid]::TryParse($managingTenantId, [System.Management.Automation.PSReference]$objectGuid)
                if ($isGUID -ne $true) {
                    Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field managingTenant ($managingTenantId) must be a GUID."
                    $hasErrors = $true
                }
            }
            elseif ($null -ne $managingTenantRootScope) {
                if ($null -eq $managingTenantId) {
                    Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector element managingTenantID must be a valid GUID when managingTenantRootScope has a value."
                    $hasErrors = $true
                }
            }

            $defaultSubscriptionId = $pacEnvironment.defaultSubscriptionId
            if ($null -ne $defaultSubscriptionId) {
                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector contains a deprecated defaultSubscriptionId. Remove it!"
                $hasErrors = $true
            }
            if ($null -ne $pacEnvironment.rootScope) {
                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector contains a deprecated rootScope. Replace rootScope with deploymentRootScope containing a fully qualified scope id!"
                $hasErrors = $true
            }
            if ($null -ne $pacEnvironment.inheritedDefinitionsScopes) {
                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector contains a deprecated inheritedDefinitionsScopes. To cover the use case see https://aka.ms/epac/settings-desired-state.md#use-case-4-multiple-teams-in-a-hierarchical-organization!"
                $hasErrors = $true
            }

            $deploymentRootScope = $pacEnvironment.deploymentRootScope
            if ($null -eq $pacEnvironment.deploymentRootScope) {
                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector does not contain deploymentRootScope field."
                $hasErrors = $true
            }
            $policyDefinitionsScopes = @( $deploymentRootScope, "")

            $deployedBy = "epac/$pacOwnerId/$pacSelector"
            if ($null -ne $pacEnvironment.deployedBy) {
                $deployedBy = $pacEnvironment.deployedBy
            }

            # globalNotScopes
            $globalNotScopesList = [System.Collections.ArrayList]::new()
            $globalNotScopesResourceGroupsList = [System.Collections.ArrayList]::new()
            $globalNotScopesSubscriptionsList = [System.Collections.ArrayList]::new()
            $globalNotScopesManagementGroupsList = [System.Collections.ArrayList]::new()
            $excludedScopesList = [System.Collections.ArrayList]::new()
            $globalExcludedScopesResourceGroupsList = [System.Collections.ArrayList]::new()
            $globalExcludedScopesSubscriptionsList = [System.Collections.ArrayList]::new()
            $globalExcludedScopesManagementGroupsList = [System.Collections.ArrayList]::new()

            $pacEnvironmentGlobalNotScopes = $pacEnvironment.globalNotScopes
            if ($null -ne $pacEnvironmentGlobalNotScopes) {
                if ($pacEnvironmentGlobalNotScopes -isnot [array]) {
                    Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field globalNotScopes must be an array of strings."
                    $hasErrors = $true
                }
                else {
                    foreach ($globalNotScope in $pacEnvironmentGlobalNotScopes) {
                        if ($globalNotScope -isnot [string]) {
                            Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field globalNotScopes must be an array of strings."
                            $hasErrors = $true
                        }
                        elseif ($globalNotScope.Contains("/resourceGroupPatterns/", [System.StringComparison]::OrdinalIgnoreCase)) {
                            Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field globalNotScopes entry ($globalNotScope) must not contain deprecated /resourceGroupPatterns/.`n`rReplace it with excludedScopes pattern `"/subscriptions/*/resourceGroups/<pattern>`""
                            $hasErrors = $true
                        }
                        else {
                            $null = $excludedScopesList.Add($globalNotScope)
                            if ($globalNotScope.StartsWith("/subscriptions/")) {
                                if ($globalNotScope.Contains("/resourceGroups/", [System.StringComparison]::OrdinalIgnoreCase)) {
                                    $null = $globalExcludedScopesResourceGroupsList.Add($globalNotScope)
                                    $null = $globalNotScopesResourceGroupsList.Add($globalNotScope)
                                }
                                else {
                                    $null = $globalExcludedScopesSubscriptionsList.Add($globalNotScope) 
                                    $null = $globalNotScopesSubscriptionsList.Add($globalNotScope)
                                }
                            }
                            elseif ($globalNotScope.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
                                $null = $globalExcludedScopesManagementGroupsList.Add($globalNotScope)
                                $null = $globalNotScopesManagementGroupsList.Add($globalNotScope)
                            }
                            else {
                                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field globalNotScopes entry ($globalNotScope) must be a valid scope."
                                $hasErrors = $true
                            }
                        }
                    }
                }
            }

            $desiredState = @{
                strategy                             = "undefined"
                keepDfcSecurityAssignments           = $false
                excludedScopes                       = $excludedScopesList
                globalExcludedScopesResourceGroups   = $globalExcludedScopesResourceGroupsList
                globalExcludedScopesSubscriptions    = $globalExcludedScopesSubscriptionsList
                globalExcludedScopesManagementGroups = $globalExcludedScopesManagementGroupsList
                excludedPolicyDefinitions            = @()
                excludedPolicySetDefinitions         = @()
                excludedPolicyAssignments            = @()
            }
            
            $desired = $pacEnvironment.desiredState
            if ($null -eq $desired) {
                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector does not contain required desiredState field."
                $hasErrors = $true
            }
            else {
                $strategy = $desired.strategy
                if ($null -eq $strategy) {
                    Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector does not contain required desiredState.strategy field."
                    $hasErrors = $true
                }
                else {
                    $valid = @("full", "ownedOnly")
                    if ($strategy -notin $valid) {
                        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.strategy ($strategy) must be one of $(ConvertTo-Json $valid -Compress)."
                        $hasErrors = $true
                    }
                    $desiredState.strategy = $strategy
                }
                $includeResourceGroups = $desired.includeResourceGroups
                if ($null -ne $includeResourceGroups) {
                    Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.includeResourceGroups is deprecated.`n`rIf set to false, replace it with excludedScopes pattern `"/subscriptions/*/resourceGroups/*`""
                    $hasErrors = $true
                }
                $keepDfcSecurityAssignments = $desired.keepDfcSecurityAssignments
                if ($null -eq $keepDfcSecurityAssignments) {
                    Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector does not contain required desiredState.keepDfcSecurityAssignments field."
                }
                else {
                    if ($keepDfcSecurityAssignments -is [bool]) {
                        $desiredState.keepDfcSecurityAssignments = $keepDfcSecurityAssignments
                    }
                    else {
                        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.keepDfcSecurityAssignments ($keepDfcSecurityAssignments) must be a boolean value."
                        $hasErrors = $true
                    }
                }
                $excludedScopes = $desired.excludedScopes
                if ($null -ne $excluded) {
                    if ($excludedScopes -isnot [array]) {
                        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.excludedScopes must be an array of strings."
                        $hasErrors = $true
                    }
                    foreach ($excludedScope in $excludedScopes) {
                        if ($null -ne $excludedScope -and $excludedScope -is [string] -and $excludedScope -ne "") {
                            if ($excludedScope.Contains("/resourceGroupPatterns/", [System.StringComparison]::OrdinalIgnoreCase)) {
                                Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.excludedScopes ($excludedScope) must not contain deprecated /resourceGroupPatterns/.`n`rReplace it with excludedScopes pattern `"/subscriptions/*/resourceGroups/<pattern>`""
                                $hasErrors = $true
                            }
                            else {
                                $null = $excludedScopesList.Add($excludedScope)
                                if ($excludedScope.StartsWith("/subscriptions/")) {
                                    if ($excludedScope.Contains("/resourceGroups/", [System.StringComparison]::OrdinalIgnoreCase)) {
                                        $null = $globalExcludedScopesResourceGroupsList.Add($excludedScope)
                                    }
                                    else {
                                        $null = $globalNotScopesSubscriptionsList.Add($excludedScope)
                                    }
                                }
                                elseif ($excludedScope.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
                                    $null = $globalExcludedScopesManagementGroupsList.Add($excludedScope)
                                }
                                else {
                                    Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.excludedScopes ($excludedScope) must be a valid scope."
                                    $hasErrors = $true
                                }
                            }
                        }
                    }
                }
                $excluded = $desired.excludedPolicyDefinitions
                if ($null -ne $excluded) {
                    if ($excluded -isnot [array]) {
                        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.excludedPolicyDefinitions must be an array of strings."
                        $hasErrors = $true
                    }
                    $desiredState.excludedPolicyDefinitions = $excluded
                }
                $excluded = $desired.excludedPolicySetDefinitions
                if ($null -ne $excluded) {
                    if ($excluded -isnot [array]) {
                        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.excludedPolicySetDefinitions must be an array of strings."
                        $hasErrors = $true
                    }
                    $desiredState.excludedPolicySetDefinitions = $excluded
                }
                $excluded = $desired.excludedPolicyAssignments
                if ($null -ne $excluded) {
                    if ($excluded -isnot [array]) {
                        Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.excludedPolicyAssignments must be an array of strings."
                        $hasErrors = $true
                    }
                    $desiredState.excludedPolicyAssignments = $excluded
                }
                $deleteExpired = $desired.deleteExpiredExemptions
                if ($null -ne $deleteExpired) {
                    Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.deleteExpiredExemptions is deprecated. Remove it!"
                }
                $deleteOrphaned = $desired.deleteOrphanedExemptions
                if ($null -ne $deleteOrphaned) {
                    Write-Host -ForegroundColor Red "Error in global-settings.jsonc: pacEnvironment $pacSelector field desiredState.deleteOrphanedExemptions is deprecated. Remove it!"
                }
            }

            $pacEnvironmentDefinition = @{
                pacSelector                     = $pacSelector
                pacOwnerId                      = $pacOwnerId
                deployedBy                      = $deployedBy
                cloud                           = $cloud
                tenantId                        = $tenantId
                managingTenantId                = $managingTenantId
                managingTenantRootScope         = $managingTenantRootScope
                deploymentRootScope             = $deploymentRootScope
                policyDefinitionsScopes         = $policyDefinitionsScopes
                desiredState                    = $desiredState
                managedIdentityLocation         = $managedIdentityLocation
                globalNotScopes                 = $globalNotScopesList.ToArray()
                globalNotScopesResourceGroups   = $globalNotScopesResourceGroupsList.ToArray()
                globalNotScopesSubscriptions    = $globalNotScopesSubscriptionsList.ToArray()
                globalNotScopesManagementGroups = $globalNotScopesManagementGroupsList.ToArray()
            }

            $null = $pacEnvironmentDefinitions.Add($pacSelector, $pacEnvironmentDefinition)
        }
    }
    
    if ($hasErrors) {
        Write-Error "Global settings contains errors." -ErrorAction Stop
    }

    Write-Information "PAC Environments: $($prompt)"
    Write-Information "PAC Owner Id: $pacOwnerId"
    Write-Information "Definitions root folder: $DefinitionsRootFolder"
    Write-Information "Input folder: $InputFolder"
    Write-Information "Output folder: $OutputFolder"
    Write-Information ""
    

    $policyDocumentationsFolder = "$DefinitionsRootFolder/policyDocumentations"
    $policyDefinitionsFolder = "$DefinitionsRootFolder/policyDefinitions"
    $policySetDefinitionsFolder = "$DefinitionsRootFolder/policySetDefinitions"
    $policyAssignmentsFolder = "$DefinitionsRootFolder/policyAssignments"
    $policyExemptionsFolder = "$DefinitionsRootFolder/policyExemptions"

    [hashtable] $globalSettings = @{
        telemetryEnabled           = $telemetryEnabled
        definitionsRootFolder      = $DefinitionsRootFolder
        globalSettingsFile         = $globalSettingsFile
        outputFolder               = $OutputFolder
        inputFolder                = $InputFolder
        policyDocumentationsFolder = $policyDocumentationsFolder
        policyDefinitionsFolder    = $policyDefinitionsFolder
        policySetDefinitionsFolder = $policySetDefinitionsFolder
        policyAssignmentsFolder    = $policyAssignmentsFolder
        policyExemptionsFolder     = $policyExemptionsFolder
        pacEnvironmentSelectors    = $pacEnvironmentSelectors
        pacEnvironmentPrompt       = $prompt
        pacEnvironments            = $pacEnvironmentDefinitions
    }
    return $globalSettings
}
