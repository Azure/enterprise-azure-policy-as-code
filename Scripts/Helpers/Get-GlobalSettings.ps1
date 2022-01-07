function Get-GlobalSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false,
            HelpMessage = "Path of the root folder containing the policy definitions.")]
        [string]$GlobalSettingsFile = "./Definitions/global-settings.jsonc",

        [Parameter(Mandatory = $false,
            HelpMessage = "Selector is used to select different scopes based on environment, most often for Policy DEV, TEST or PROD (not to be confused with regular Sandbox, Dev. QA and Prod).")]
        [string]$AssignmentSelector = "PROD"

            
    )
        
    Write-Information "==================================================================================================="
    Write-Information "Looking for Global settings JSON file ""$GlobalSettingsFile""."
    Write-Information "==================================================================================================="

    $Json = Get-Content -Path $GlobalSettingsFile -Raw -ErrorAction Stop
    try {
        $Json | Test-Json -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "JSON file ""$($GlobalSettingsFile)"" is not valid = $Json" -ErrorAction Stop
        throw """$($GlobalSettingsFile)"" is not valid"
    }

    $globalSettings = $Json | ConvertFrom-Json

    $managedIdentityLocation = $null
    if ($globalSettings.managedIdentityLocation) {
        foreach ($possibleManagedIdentityLocation in $globalSettings.managedIdentityLocation.psobject.Properties) {
            $selector = $possibleManagedIdentityLocation.Name
            if ($selector -eq "*" -or $selector -eq $AssignmentSelector) {
                $managedIdentityLocation = $possibleManagedIdentityLocation.Value
                break
            }
        }
    }
    if ($null -ne $managedIdentityLocation) {
        Write-Information "managedIdentityLocation defined for $AssignmentSelector = $($managedIdentityLocation)"
    }
    else {
        Write-Error "NO global managedIdentityLocatione defined for $AssignmentSelector"
    }

    $globalNotScopeList = $null
    if ($globalSettings.notScope) {
        foreach ($possibleNotScopeList in $globalSettings.notScope.psobject.Properties) {
            $selector = $possibleNotScopeList.Name
            if ($selector -eq "*" -or $selector -eq $AssignmentSelector) {
                if ($null -eq $globalNotScopeList) {
                    $globalNotScopeList = @() + $possibleNotScopeList.Value
                }
                else {
                    $globalNotScopeList += $possibleNotScopeList.Value
                }
            }
        }
    }
    if ($null -ne $globalNotScopeList) {
        Write-Information "Global notScope defined for $AssignmentSelector = $($globalNotScopeList | ConvertTo-Json -Depth 100)"
    }
    else {
        Write-Warning "NO global notScope defined for $AssignmentSelector"
    }
    Write-Information ""
    Write-Information ""

    return $globalNotScopeList, $managedIdentityLocation 
}