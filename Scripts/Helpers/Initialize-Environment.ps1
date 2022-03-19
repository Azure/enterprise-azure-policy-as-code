#Requires -PSEdition Core

function Initialize-Environment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector = "",
        [parameter(Mandatory = $false)] [string] $CompareSet = "",
        [Parameter(Mandatory = $true, HelpMessage = "Global settings filename.")] [string]$GlobalSettingsFile,
        [parameter(Mandatory = $false)] [switch] $retrieveFirstEnvironment,
        [parameter(Mandatory = $false)] [switch] $retrieveRepresentativeInitiatives,
        [parameter(Mandatory = $false)] [switch] $retrieveCompareSet
    )

    Write-Information "==================================================================================================="
    Write-Information "Get global settings from '$GlobalSettingsFile'."
    Write-Information "==================================================================================================="

    $Json = Get-Content -Path $GlobalSettingsFile -Raw -ErrorAction Stop
    if (!(Test-Json $Json)) {
        Write-Error "JSON file ""$($GlobalSettingsFile)"" is not valid = $Json" -ErrorAction Stop
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
    Write-Information "    planFile     = $($pacEnvironment.planFile)"
    Write-Information "    roleFile     = $($pacEnvironment.roleFile)"

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
    if ($retrieveCompareSet.IsPresent) {
        Write-Information "---------------------------------------------------------------------------------------------------"
        if ($globalSettings.initiativeSetsToCompare) {
            [hashtable] $sets = @{}
            [System.Text.StringBuilder] $buildPrompt = [System.Text.StringBuilder]::new()
            $comma = ""
            foreach ($set in $globalSettings.initiativeSetsToCompare) {
                [void] $sets.Add($env.setName, $set)
                [void] $buildPrompt.Append("$comma$($set.setName)")
                $comma = ", "
            }
            $prompt = $buildPrompt.ToString()

            if ($null -ne $CompareSet -and $CompareSet -ne "") {
                if ($sets.ContainsKey($CompareSet)) {
                    # valid input
                    $initiativeSetToCompare = $sets.$CompareSet
                }
                else {
                    Throw "Initiative set selection $initiativeSetSelector is not valid"
                }
            }
            else {
                $InformationPreference = "Continue"
                while ($null -eq $initiativeSet) {
                    $CompareSet = Read-Host "Select initiative set [$prompt]"
                    if ($sets.ContainsKey($CompareSet)) {
                        # valid input
                        $initiativeSetToCompare = $initiativeSetsToCompare[$CompareSet]
                    }
                }
            }
            Write-Information "Compare $CompareSet Initiatives set"
            foreach ($initiativeId in $initiativeSet) {
                Write-Information "    $initiativeId"
            }
        }
    }
    Write-Information "---------------------------------------------------------------------------------------------------"
    Write-Information ""

    $environment = @{
        pacEnvironmentSelector    = $PacEnvironmentSelector
        managedIdentityLocation   = $managedIdentityLocation
        tenantId                  = $pacEnvironment.tenantId
        defaultSubscriptionID     = $pacEnvironment.defaultSubscriptionId
        rootScope                 = $rootScope
        rootScopeId               = $rootScopeId
        planFile                  = $pacEnvironment.planFile
        roleFile                  = $pacEnvironment.roleFile
        globalNotScopeList        = $globalNotScopeList
        representativeAssignments = $representativeAssignments
        initiativeSetToCompare    = $initiativeSetToCompare
    }

    Invoke-AzCli account set --subscription $environment.defaultSubscriptionId -SuppressOutput

    return $environment 
}
