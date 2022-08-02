#Requires -PSEdition Core

function Select-PacEnvironment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false, Position = 0)] [string] $pacEnvironmentSelector,
        [Parameter(Mandatory = $false)] [string] $definitionsRootFolder,
        [Parameter(Mandatory = $false)] [string] $outputFolder,
        [Parameter(Mandatory = $false)] [string] $inputFolder,
        [Parameter(Mandatory = $false)] [bool] $interactive = $false
    )

    $globalSettings = Get-GlobalSettings -definitionsRootFolder $definitionsRootFolder -outputFolder $outputFolder -inputFolder $inputFolder

    $pacEnvironment = $null
    $pacEnvironments = $globalSettings.pacEnvironments
    if ($pacEnvironmentSelector -eq "") {
        # Interactive
        $InformationPreference = "Continue"
        $interactive = $true
        if ($pacEnvironments.Count -eq 1) {
            $pacEnvironmentSelector = $pacEnvironments.Keys # returns first value if array is exactly one element long
            $pacEnvironment = $pacEnvironments.Values # returns first value if array is exactly one element long
            Write-Information "Auto-selected the only Policy as Code environment: $pacEnvironmentSelector"
        }
        else {
            $prompt = $globalSettings.pacEnvironmentPrompt
            while ($null -eq $pacEnvironment) {
                $pacEnvironmentSelector = Read-Host "Select Policy as Code environment [$prompt]"
                if ($pacEnvironments.ContainsKey($pacEnvironmentSelector)) {
                    # valid input
                    $pacEnvironment = $pacEnvironments[$pacEnvironmentSelector]
                    Write-Information ""
                }
                else {
                    Write-Information "Invalid selection entered."
                }
            }
        }
    }
    else {
        if ($pacEnvironments.ContainsKey($pacEnvironmentSelector)) {
            # valid input
            $pacEnvironment = $pacEnvironments[$pacEnvironmentSelector]
        }
        else {
            Write-Error "Policy as Code environment selector $pacEnvironmentSelector is not valid" -ErrorAction Stop
        }
    }
    Write-Information "Environment Selected: $pacEnvironmentSelector"
    Write-Information "    cloud        = $($pacEnvironment.cloud)"
    Write-Information "    tenant       = $($pacEnvironment.tenantId)"
    Write-Information "    rootScope    = $($pacEnvironment.rootScope | ConvertTo-Json -Compress)"
    Write-Information "    subscription = $($pacEnvironment.defaultSubscriptionId)"

    # Managed identity location
    $managedIdentityLocation = $null
    if ($globalSettings.managedIdentityLocations) {
        $managedIdentityLocations = $globalSettings.managedIdentityLocations
        if ($managedIdentityLocations.ContainsKey($pacEnvironmentSelector)) {
            $managedIdentityLocation = $managedIdentityLocations[$pacEnvironmentSelector]
        }
        elseif ($managedIdentityLocations.ContainsKey("*")) {
            $managedIdentityLocation = $managedIdentityLocations["*"]

        }
    }
    if ($null -ne $managedIdentityLocation) {
        Write-Information "    managedIdentityLocation = $managedIdentityLocation"
    }
    else {
        Write-Information "    managedIdentityLocation = Undefined"
    }
    Write-Information ""
    Write-Information ""


    # Global notScope
    [array] $globalNotScopeList = @()
    if ($globalSettings.globalNotScopes) {
        $globalNotScopes = $globalSettings.globalNotScopes
        $globalNotScopeList = @()
        if ($globalNotScopes.ContainsKey($pacEnvironmentSelector)) {
            $globalNotScopeList += $globalNotScopes[$pacEnvironmentSelector]
        }
        if ($globalNotScopes.ContainsKey("*")) {
            $globalNotScopeList += $globalNotScopes["*"]
        }
    }
    $pacEnvironmentDefinition = @{
        pacEnvironmentSelector         = $pacEnvironmentSelector
        interactive                    = $interactive
        cloud                          = $pacEnvironment.cloud
        tenantId                       = $pacEnvironment.tenantId
        defaultSubscriptionId          = $pacEnvironment.defaultSubscriptionId
        rootScope                      = $pacEnvironment.rootScope
        rootScopeId                    = $pacEnvironment.rootScopeId
        globalNotScopeList             = $globalNotScopeList
        managedIdentityLocation        = $managedIdentityLocation
        definitionsRootFolder          = $globalSettings.definitionsRootFolder
        policyDefinitionsFolder        = $globalSettings.policyDefinitionsFolder
        initiativeDefinitionsFolder    = $globalSettings.initiativeDefinitionsFolder
        assignmentsFolder              = $globalSettings.assignmentsFolder
        exemptionsFolder               = $globalSettings.exemptionsFolder
        documentationDefinitionsFolder = $globalSettings.documentationDefinitionsFolder
        outputFolder                   = $globalSettings.outputFolder
        inputFolder                    = $globalSettings.inputFolder
        policyPlanOutputFile           = "$($globalSettings.outputFolder)/policy-plan-$pacEnvironmentSelector/policy-plan.json"
        rolesPlanOutputFile            = "$($globalSettings.outputFolder)/roles-plan-$pacEnvironmentSelector/roles-plan.json"
        policyPlanInputFile            = "$($globalSettings.inputFolder)/policy-plan-$pacEnvironmentSelector/policy-plan.json"
        rolesPlanInputFile             = "$($globalSettings.inputFolder)/roles-plan-$pacEnvironmentSelector/roles-plan.json"

    }
    return $pacEnvironmentDefinition
}
