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
    $pacOwnerId = $settings.pacOwnerId
    $errorInfo = New-ErrorInfo -FileName $globalSettingsFile
    if ($null -eq $pacOwnerId) {
        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: does not contain the required pacOwnerId field. Add a pacOwnerId field with a GUID or other unique id!"
    }

    if ($null -ne $settings.globalNotScopes) {
        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: contains a deprecated globalNotScopes field. Move the values into each pacEnvironment!"
    }
    if ($null -ne $settings.managedIdentityLocations -or $null -ne $settings.managedIdentityLocation) {
        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: contains a deprecated managedIdentityLocations field. Move the values into each pacEnvironment!"
    }

    $pacEnvironments = $settings.pacEnvironments
    if ($null -eq $pacEnvironments) {
        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: does not contain a pacEnvironments array. Add a pacEnvironments array with at least one environment!"
    }
    elseif ($pacEnvironments -isnot [array]) {
        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironments must be an array of objects."
    }
    elseif ($pacEnvironments.Count -eq 0) {
        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironments array must contain at least one environment."
    }
    else {
        foreach ($pacEnvironment in $pacEnvironments) {

            $pacSelector = $pacEnvironment.pacSelector
            if ($null -eq $pacSelector) {
                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: a pacEnvironments array element does not contain the required pacSelector element."
            }
            $null = $pacEnvironmentSelectors.Add($pacSelector)

            $cloud = $pacEnvironment.cloud
            if ($null -eq $cloud) {
                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector does not define the required cloud element."
            }

            $tenantId = $pacEnvironment.tenantId
            if ($null -eq $tenantId) {
                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector does not contain required tenantId field."
            }

            # Managed identity location
            $managedIdentityLocation = $pacEnvironment.managedIdentityLocation
            if ($null -eq $managedIdentityLocation) {
                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector does not contain required managedIdentityLocation field."
            }

            $managingTenantId = $pacEnvironment.managingTenant.managingTenantId
            $managingTenantRootScope = $pacEnvironment.managingTenant.managingTenantRootScope
            if ($null -ne $managingTenantId) {
                if ($null -eq $pacEnvironment.managingTenant.managingTenantRootScope) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector element managingTenantRootScope must have a valid value when managingTenantID has a value."
                }
                $objectGuid = [System.Guid]::empty
                # Returns True if successfully parsed, otherwise returns False.
                $isGUID = [System.Guid]::TryParse($managingTenantId, [System.Management.Automation.PSReference]$objectGuid)
                if ($isGUID -ne $true) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field managingTenant ($managingTenantId) must be a GUID."
                }
            }
            elseif ($null -ne $managingTenantRootScope) {
                if ($null -eq $managingTenantId) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector element managingTenantID must be a valid GUID when managingTenantRootScope has a value."
                }
            }

            $defaultSubscriptionId = $pacEnvironment.defaultSubscriptionId
            if ($null -ne $defaultSubscriptionId) {
                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector contains a deprecated defaultSubscriptionId. Remove it!"
            }
            if ($null -ne $pacEnvironment.rootScope) {
                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector contains a deprecated rootScope. Replace rootScope with deploymentRootScope containing a fully qualified scope id!"
            }
            if ($null -ne $pacEnvironment.inheritedDefinitionsScopes) {
                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector contains a deprecated inheritedDefinitionsScopes. To cover the use case see https://aka.ms/epac/settings-desired-state.md#use-case-4-multiple-teams-in-a-hierarchical-organization!"
            }

            $deploymentRootScope = $pacEnvironment.deploymentRootScope
            if ($null -eq $pacEnvironment.deploymentRootScope) {
                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector does not contain deploymentRootScope field."
            }
            $policyDefinitionsScopes = @( $deploymentRootScope, "")

            $defaultContext = $pacEnvironment.defaultContext
            if ($null -ne $defaultContext) {
                if ($pacEnvironment.defaultContext -isnot [string]) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector has an invalid defaultContext field."
                }
            }
            else {
                $defaultContext = ""
            }

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
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field globalNotScopes must be an array of strings."
                }
                else {
                    foreach ($globalNotScope in $pacEnvironmentGlobalNotScopes) {
                        if ($globalNotScope -isnot [string]) {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field globalNotScopes must be an array of strings."
                        }
                        elseif ($globalNotScope.Contains("/resourceGroupPatterns/", [System.StringComparison]::OrdinalIgnoreCase)) {
                            Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field globalNotScopes entry ($globalNotScope) must not contain deprecated /resourceGroupPatterns/.`n`r`t`tReplace it with excludedScopes pattern `"/subscriptions/*/resourceGroups/<pattern>`""
                        }
                        else {
                            $null = $globalNotScopesList.Add($globalNotScope)
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
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field globalNotScopes entry ($globalNotScope) must be a valid scope."
                            }
                        }
                    }
                }
            }
            $skipResourceValidationForExemptions = $false
            $skipResourceValidationForExemptionsRaw = $pacEnvironment.skipResourceValidationForExemptions
            if ($skipResourceValidationForExemptionsRaw) {
                $skipResourceValidationForExemptions = $true
            }

            $desiredState = @{
                strategy                             = "undefined"
                keepDfcSecurityAssignments           = $false
                cleanupObsoleteExemptions            = $false
                excludedScopes                       = $excludedScopesList
                globalExcludedScopesResourceGroups   = $globalExcludedScopesResourceGroupsList
                globalExcludedScopesSubscriptions    = $globalExcludedScopesSubscriptionsList
                globalExcludedScopesManagementGroups = $globalExcludedScopesManagementGroupsList
                excludedPolicyDefinitions            = @()
                excludedPolicySetDefinitions         = @()
                excludedPolicyAssignments            = @()
                excludeSubscriptions                 = $false
                doNotDisableDeprecatedPolicies       = $false
            }
            
            $desired = $pacEnvironment.desiredState
            if ($null -eq $desired) {
                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector does not contain required desiredState field."
            }
            else {
                $strategy = $desired.strategy
                if ($null -eq $strategy) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector does not contain required desiredState.strategy field."
                }
                else {
                    $valid = @("full", "ownedOnly")
                    if ($strategy -notin $valid) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.strategy ($strategy) must be one of $(ConvertTo-Json $valid -Compress)."
                    }
                    $desiredState.strategy = $strategy
                }
                $includeResourceGroups = $desired.includeResourceGroups
                if ($null -ne $includeResourceGroups) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.includeResourceGroups is deprecated.`n`r`t`tIf set to false, replace it with excludedScopes pattern `"/subscriptions/*/resourceGroups/*`""
                }
                $keepDfcSecurityAssignments = $desired.keepDfcSecurityAssignments
                if ($null -eq $keepDfcSecurityAssignments) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector does not contain required desiredState.keepDfcSecurityAssignments field."
                }
                else {
                    if ($keepDfcSecurityAssignments -is [bool]) {
                        $desiredState.keepDfcSecurityAssignments = $keepDfcSecurityAssignments
                    }
                    else {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.keepDfcSecurityAssignments ($keepDfcSecurityAssignments) must be a boolean value."
                    }
                }
                $cleanupObsoleteExemptions = $desired.cleanupObsoleteExemptions
                if ($null -ne $cleanupObsoleteExemptions) {
                    if ($cleanupObsoleteExemptions -is [bool]) {
                        $desiredState.cleanupObsoleteExemptions = $cleanupObsoleteExemptions
                    }
                    else {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.cleanupObsoleteExemptions ($cleanupObsoleteExemptions) must be a boolean value."
                    }
                }
                $excludedScopes = $desired.excludedScopes
                if ($null -ne $excludedScopes) {
                    if ($excludedScopes -isnot [array]) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.excludedScopes must be an array of strings."
                    }
                    foreach ($excludedScope in $excludedScopes) {
                        if ($null -ne $excludedScope -and $excludedScope -is [string] -and $excludedScope -ne "") {
                            if ($excludedScope.Contains("/resourceGroupPatterns/", [System.StringComparison]::OrdinalIgnoreCase)) {
                                Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.excludedScopes ($excludedScope) must not contain deprecated /resourceGroupPatterns/.`n`r`t`tReplace it with excludedScopes pattern `"/subscriptions/*/resourceGroups/<pattern>`""
                            }
                            else {
                                $null = $excludedScopesList.Add($excludedScope)
                                if ($excludedScope.StartsWith("/subscriptions/")) {
                                    if ($desired.excludeSubscriptions -eq $false -or $null -eq $desired.excludeSubscriptions) {
                                        if ($excludedScope.Contains("/resourceGroups/", [System.StringComparison]::OrdinalIgnoreCase)) {
                                            $null = $globalExcludedScopesResourceGroupsList.Add($excludedScope)
                                        }
                                        else {
                                            $null = $globalExcludedScopesSubscriptionsList.Add($excludedScope)
                                        }
                                    }
                                }
                                elseif ($excludedScope.StartsWith("/providers/Microsoft.Management/managementGroups/")) {
                                    $null = $globalExcludedScopesManagementGroupsList.Add($excludedScope)
                                }
                                else {
                                    Write-Host "Global settings error: pacEnvironment $pacSelector field desiredState.excludedScopes ($excludedScope) must be a valid scope."
                                }
                            }
                        }
                    }
                }
                $excluded = $desired.excludedPolicyDefinitions
                if ($null -ne $excluded) {
                    if ($excluded -isnot [array]) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.excludedPolicyDefinitions must be an array of strings."
                    }
                    $desiredState.excludedPolicyDefinitions = $excluded
                }
                $excluded = $desired.excludedPolicySetDefinitions
                if ($null -ne $excluded) {
                    if ($excluded -isnot [array]) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.excludedPolicySetDefinitions must be an array of strings."
                    }
                    $desiredState.excludedPolicySetDefinitions = $excluded
                }
                $excluded = $desired.excludedPolicyAssignments
                if ($null -ne $excluded) {
                    if ($excluded -isnot [array]) {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.excludedPolicyAssignments must be an array of strings."
                    }
                    $desiredState.excludedPolicyAssignments = $excluded
                }
                if ($desired.excludeSubscriptions) {
                    $desiredState.excludeSubscriptions = $true
                }
                $deleteExpired = $desired.deleteExpiredExemptions
                if ($null -ne $deleteExpired) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.deleteExpiredExemptions is deprecated. Remove it!"
                }
                $deleteOrphaned = $desired.deleteOrphanedExemptions
                if ($null -ne $deleteOrphaned) {
                    Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.deleteOrphanedExemptions is deprecated. Remove it!"
                }
                $doNotDisableDeprecatedPolicies = $desired.doNotDisableDeprecatedPolicies
                if ($null -ne $doNotDisableDeprecatedPolicies) {
                    if ($doNotDisableDeprecatedPolicies -is [bool]) {
                        $desiredState.doNotDisableDeprecatedPolicies = $doNotDisableDeprecatedPolicies
                    }
                    else {
                        Add-ErrorMessage -ErrorInfo $errorInfo -ErrorString "Global settings error: pacEnvironment $pacSelector field desiredState.doNotDisableDeprecatedPolicies ($doNotDisableDeprecatedPolicies) must be a boolean value."
                    }
                }
                else {
                    $doNotDisableDeprecatedPolicies = $false
                }
            }

            $pacEnvironmentDefinition = @{
                pacSelector                         = $pacSelector
                pacOwnerId                          = $pacOwnerId
                deployedBy                          = $deployedBy
                cloud                               = $cloud
                tenantId                            = $tenantId
                managingTenantId                    = $managingTenantId
                managingTenantRootScope             = $managingTenantRootScope
                deploymentRootScope                 = $deploymentRootScope
                defaultContext                      = $defaultContext
                policyDefinitionsScopes             = $policyDefinitionsScopes
                skipResourceValidationForExemptions = $skipResourceValidationForExemptions
                doNotDisableDeprecatedPolicies      = $doNotDisableDeprecatedPolicies
                desiredState                        = $desiredState
                managedIdentityLocation             = $managedIdentityLocation
                globalNotScopes                     = $globalNotScopesList.ToArray()
                globalNotScopesResourceGroups       = $globalNotScopesResourceGroupsList.ToArray()
                globalNotScopesSubscriptions        = $globalNotScopesSubscriptionsList.ToArray()
                globalNotScopesManagementGroups     = $globalNotScopesManagementGroupsList.ToArray()
            }

            $null = $pacEnvironmentDefinitions.Add($pacSelector, $pacEnvironmentDefinition)
        }
    }

    Write-ErrorsFromErrorInfo -ErrorInfo $errorInfo -ErrorAction Stop

    $prompt = $pacEnvironmentSelectors -join ", "
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
