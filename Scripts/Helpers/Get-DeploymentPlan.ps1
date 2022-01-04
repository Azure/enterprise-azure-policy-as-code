#Requires -PSEdition Core

function Get-DeploymentPlan {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = "Plan input filename.")]
        [string]$PlanFile
    )

    # Check if the plan definition JSON file is a valid JSON
    $Json = Get-Content -Path $PlanFile -Raw -ErrorAction Stop

    try {
        $Json | Test-Json -ErrorAction Stop | Out-Null
        Write-Verbose "        The JSON file is valid."
    }
    catch {
        Write-Error "The JSON file ""$PlanFile"" is not valid."
    }
    $plan = $Json | ConvertFrom-Json

    return $plan
}