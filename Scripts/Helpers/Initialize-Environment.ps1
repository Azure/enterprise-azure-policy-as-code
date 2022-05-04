#Requires -PSEdition Core

function Initialize-Environment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector,
        [parameter(Mandatory = $false)] [string] $initiativeSetSelector,
        [parameter(Mandatory = $false)] [switch] $retrieveFirstEnvironment,
        [parameter(Mandatory = $false)] [switch] $retrieveRepresentativeInitiatives,
        [parameter(Mandatory = $false)] [switch] $retrieveInitiativeSet,
        [Parameter(Mandatory = $false)] [string] $definitionsRootFolder,
        [Parameter(Mandatory = $false)] [string] $outputFolder,
        [Parameter(Mandatory = $false)] [string] $inputFolder
    )

    # Callcuate folders
    if ($definitionsRootFolder -eq "") {
        if ($null -eq $env:PAC_DEFINITIONS_FOLDER) {
            $definitionsRootFolder = "$PSScriptRoot/../../Definitions"
        }
        else {
            $definitionsRootFolder = $env:PAC_DEFINITIONS_FOLDER
        }
    }
    $globalSettingsFile = "$definitionsRootFolder/global-settings.jsonc"

    if ($outputFolder -eq "") {
        if ($null -eq $env:PAC_OUTPUT_FOLDER) {
            $outputFolder = "$PSScriptRoot/../../Output"
        }
        else {
            $outputFolder = $env:PAC_OUTPUT_FOLDER
        }
    }

    if ($inputFolder -eq "") {
        if ($null -eq $env:PAC_INPUT_FOLDER) {
            $inputFolder = $outputFolder
        }
        else {
            $inputFolder = $env:PAC_INPUT_FOLDER
        }
    }

    Write-Information "==================================================================================================="
    Write-Information "Get global settings from '$globalSettingsFile'."
    Write-Information "==================================================================================================="

    $Json = Get-Content -Path $globalSettingsFile -Raw -ErrorAction Stop
    if (!(Test-Json $Json)) {
        Write-Error "JSON file ""$($globalSettingsFile)"" is not valid = $Json" -ErrorAction Stop
    }
    $globalSettings = $Json | ConvertFrom-Json

    [hashtable] $pacEnvironmentDefinitions = @{}
    [System.Text.StringBuilder] $buildPrompt = [System.Text.StringBuilder]::new()
    $comma = ""
    $first = $true
    foreach ($env in $globalSettings.pacEnvironments) {
        if ($first -and $retrieveFirstEnvironment.IsPresent) {
            $PacEnvironmentSelector = $env.pacSelector
        }
        [void] $pacEnvironmentDefinitions.Add($env.pacSelector, $env)
        [void] $buildPrompt.Append("$comma$($env.pacSelector)")
        $comma = ", "
        $first = $false
    }
    $prompt = $buildPrompt.ToString()

    $pacEnvironment = $null
    $rootScopeId = ""
    if ($null -ne $PacEnvironmentSelector -and $PacEnvironmentSelector -ne "") {
        if ($pacEnvironmentDefinitions.ContainsKey($PacEnvironmentSelector)) {
            # valid input
            $pacEnvironment = $pacEnvironmentDefinitions[$PacEnvironmentSelector]
        }
        else {
            Write-Error "Policy as Code environment selector $PacEnvironmentSelector is not valid" -ErrorAction Stop
        }
    }
    else {
        # Interactive
        $InformationPreference = "Continue"
        while ($null -eq $pacEnvironment) {
            $PacEnvironmentSelector = Read-Host "Select Policy as Code environment [$prompt]"
            if ($pacEnvironmentDefinitions.ContainsKey($PacEnvironmentSelector)) {
                # valid input
                $pacEnvironment = $pacEnvironmentDefinitions[$PacEnvironmentSelector]
            }
        }
    }

    $rootScope = $null
    if ($pacEnvironment.rootScope) {
        $scope = $pacEnvironment.rootScope
        if ($scope.SubscriptionId) {
            $rootScopeId = "/subscriptions/$($scope.SubscriptionId)"
        }
        elseif ($scope.ManagementGroupName) {
            $rootScopeId = "/providers/Microsoft.Management/managementGroups/$($scope.ManagementGroupName)"
        }
        else {
            Write-Error "Policy as Code environment does not contain a valid root scope" -ErrorAction Stop
        }
        $rootScope = ConvertTo-HashTable $scope
    }
    else {
        Write-Error "Policy as Code environment does not contain a root scope" -ErrorAction Stop
    }
    Write-Information "Environment Selected: $PacEnvironmentSelector"
    Write-Information "    tenantId     = $($pacEnvironment.tenantId)"
    Write-Information "    subscription = $($pacEnvironment.defaultSubscriptionId)"
    Write-Information "    rootScope    = $($rootScope | ConvertTo-Json -Compress)"
    Write-Information "    rootScopeId  = $rootScopeId"

    # Managed identity location
    $managedIdentityLocation = $null
    if ($globalSettings.managedIdentityLocation) {
        $managedIdentityLocations = ConvertTo-HashTable $globalSettings.managedIdentityLocation
        if ($managedIdentityLocations.ContainsKey($PacEnvironmentSelector)) {
            $managedIdentityLocation = $managedIdentityLocations[$PacEnvironmentSelector]
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

    # Global notScope
    $globalNotScopeList = $null
    if ($globalSettings.globalNotScopes) {
        $globalNotScopes = ConvertTo-HashTable $globalSettings.globalNotScopes
        if ($globalNotScopes.ContainsKey($PacEnvironmentSelector) -and $globalNotScopes.ContainsKey("*")) {
            $globalNotScopeList = $globalNotScopes[$PacEnvironmentSelector] + $globalNotScopes["*"]
        }
        elseif ($globalNotScopes.ContainsKey($PacEnvironmentSelector)) {
            $globalNotScopeList = $globalNotScopes[$PacEnvironmentSelector]
        }
        elseif ($globalNotScopes.ContainsKey("*")) {
            $globalNotScopeList = $globalNotScopes["*"]
        }
    }
    if ($null -ne $globalNotScopeList) {
        Write-Information "    globalNotScopeList = "
        foreach ($entry in $globalNotScopeList) {
            Write-Information "        $entry"
        }
    }
    else {
        Write-Information "    globalNotScopeList = UNDEFINED"
    }

    # Representative Assignments
    $representativeAssignments = $null
    if ($retrieveRepresentativeInitiatives.IsPresent) {
        Write-Information "---------------------------------------------------------------------------------------------------"
        if ($globalSettings.representativeAssignments) {
            $representativeAssignments = $globalSettings.representativeAssignments
            Write-Information "Representative Assignments =" 
            Write-Information "$($representativeAssignments | ConvertTo-Json -Depth 100)"
        }
    }

    # Initiative Sets To Compare
    $initiativeSetToCompare = $null
    if ($retrieveInitiativeSet.IsPresent) {
        Write-Information "---------------------------------------------------------------------------------------------------"
        if ($globalSettings.initiativeSetsToCompare) {
            [hashtable] $sets = @{}
            [System.Text.StringBuilder] $buildPrompt = [System.Text.StringBuilder]::new()
            $comma = ""
            foreach ($set in $globalSettings.initiativeSetsToCompare) {
                [void] $sets.Add($set.setName, $set)
                [void] $buildPrompt.Append("$comma$($set.setName)")
                $comma = ", "
            }
            $prompt = $buildPrompt.ToString()

            if ($null -ne $initiativeSetSelector -and $initiativeSetSelector -ne "") {
                if ($sets.ContainsKey($initiativeSetSelector)) {
                    # valid input
                    $initiativeSetToCompare = $sets.$initiativeSetSelector
                }
                else {
                    Throw "Initiative set selection $initiativeSetSelector is not valid"
                }
            }
            elseif ($sets.Count -eq 1) {
                foreach ($key in $sets.Keys) {
                    # Excatly one
                    $initiativeSetSelector = $key
                }
                $initiativeSetToCompare = $sets.$initiativeSetSelector
            }
            else {
                $InformationPreference = "Continue"
                while ($null -eq $initiativeSetToCompare) {
                    $initiativeSetSelector = Read-Host "Select initiative set [$prompt]"
                    if ($sets.ContainsKey($initiativeSetSelector)) {
                        # valid input
                        $initiativeSetToCompare = $initiativeSetsToCompare[$initiativeSetSelector]
                    }
                }
            }
            Write-Information "Compare $initiativeSetSelector Initiatives set"
            foreach ($initiativeId in $initiativeSetToCompare) {
                Write-Information "    $initiativeId"
            }
        }
    }
    Write-Information "---------------------------------------------------------------------------------------------------"
    Write-Information ""

    $environment = @{
        pacEnvironmentSelector      = $PacEnvironmentSelector
        managedIdentityLocation     = $managedIdentityLocation
        tenantId                    = $pacEnvironment.tenantId
        defaultSubscriptionID       = $pacEnvironment.defaultSubscriptionId
        rootScope                   = $rootScope
        rootScopeId                 = $rootScopeId
        globalNotScopeList          = $globalNotScopeList
        representativeAssignments   = $representativeAssignments
        initiativeSetSelector       = $initiativeSetSelector
        initiativeSetToCompare      = $initiativeSetToCompare
        definitionsRootFolder       = $definitionsRootFolder
        policyDefinitionsFolder     = "$definitionsRootFolder/Policies"
        initiativeDefinitionsFolder = "$definitionsRootFolder/Initiatives"
        assignmentsFolder           = "$definitionsRootFolder/Assignments"
        outputFolder                = $outputFolder
        inputFolder                 = $inputFolder
        policyPlanOutputFile        = "$outputFolder/policy-plan-$PacEnvironmentSelector/policy-plan.json"
        rolesPlanOutputFile         = "$outputFolder/roles-plan-$PacEnvironmentSelector/roles-plan.json"
        policyPlanInputFile         = "$inputFolder/policy-plan-$PacEnvironmentSelector/policy-plan.json"
        rolesPlanInputFile          = "$inputFolder/roles-plan-$PacEnvironmentSelector/roles-plan.json"

    }
    return $environment 
}
