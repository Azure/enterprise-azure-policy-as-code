function Get-DeploymentPlan {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Plan input filename.")]
        [string]$PlanFile,

        [switch] $AsHashtable
    )

    $plan = $null
    if (Test-Path -Path $PlanFile ) {
        # Check if the plan definition JSON file is a valid JSON
        $Json = Get-Content -Path $PlanFile -Raw -ErrorAction Stop

        if (!(Test-Json $Json)) {
            Write-Error "The JSON file '$PlanFile' is not valid." -ErrorAction Stop
        }
        $plan = $Json | ConvertFrom-Json -AsHashtable:$AsHashtable
    }

    return $plan
}
