#Requires -PSEdition Core

function Get-DeploymentPlan {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = "Plan input filename.")]
        [string]$PlanFile
    )

    # Check if the plan definition Json file is a valid Json
    $Json = Get-Content -Path $PlanFile -Raw -ErrorAction Stop

    if ((Test-Json $Json)) {
        Write-Verbose "        The Json file is valid."
    }
    else {
        Write-Error "The Json file ""$PlanFile"" is not valid."
    }
    $plan = $Json | ConvertFrom-Json

    return $plan
}