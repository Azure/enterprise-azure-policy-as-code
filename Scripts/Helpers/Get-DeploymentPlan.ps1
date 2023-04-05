function Get-DeploymentPlan {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Plan input filename.")]
        [string]$planFile,

        [switch] $asHashtable
    )

    $plan = $null
    if (Test-Path -Path $planFile ) {
        # Check if the plan definition JSON file is a valid JSON
        $Json = Get-Content -Path $planFile -Raw -ErrorAction Stop

        if (!(Test-Json $Json)) {
            Write-Error "The JSON file '$planFile' is not valid." -ErrorAction Stop
        }
        $plan = $Json | ConvertFrom-Json -AsHashtable:$asHashtable
    }

    return $plan
}