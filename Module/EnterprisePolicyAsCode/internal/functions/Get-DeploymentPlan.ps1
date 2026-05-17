function Get-DeploymentPlan {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Plan input filename.")]
        [string] $PlanFile,

        [switch] $AsHashTable
    )

    $plan = $null
    if (Test-Path -Path $PlanFile ) {
        # Check if the plan definition JSON file is a valid JSON
        $Json = Get-Content -Path $PlanFile -Raw -ErrorAction Stop
        
        try {
            $plan = $Json | ConvertFrom-Json -AsHashTable:$AsHashTable
        }
        catch {
            Write-Error "Assignment JSON file '$($PlanFile)' is not valid." -ErrorAction Stop
        }
    }

    return $plan
}
