function Select-PacEnvironment {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false, Position = 0)] [string] $PacEnvironmentSelector,
        [Parameter(Mandatory = $false)] [string] $DefinitionsRootFolder,
        [Parameter(Mandatory = $false)] [string] $OutputFolder,
        [Parameter(Mandatory = $false)] [string] $InputFolder,
        [Parameter(Mandatory = $false)] [bool] $Interactive = $false,
        [switch] $PickFirstPacEnvironment
    )

    $globalSettings = Get-GlobalSettings -DefinitionsRootFolder $DefinitionsRootFolder -OutputFolder $OutputFolder -InputFolder $InputFolder

    $pacEnvironment = $null
    $pacEnvironments = $globalSettings.pacEnvironments

    if ($PickFirstPacEnvironment) {
        $PacEnvironmentSelector = $globalSettings.pacEnvironmentSelectors[0]
    }
    
    if ($PacEnvironmentSelector -eq "") {
        # Interactive
        $InformationPreference = "Continue"
        $Interactive = $true
        if ($pacEnvironments.Count -eq 1) {
            $PacEnvironmentSelector = $globalSettings.pacEnvironmentSelectors[0]
            $pacEnvironment = $pacEnvironments[$PacEnvironmentSelector]
        }
        else {
            $prompt = $globalSettings.pacEnvironmentPrompt
            while ($null -eq $pacEnvironment) {
                $PacEnvironmentSelector = Read-Host "Select Policy as Code environment [$prompt]"
                if ($pacEnvironments.ContainsKey($PacEnvironmentSelector)) {
                    # valid input
                    $pacEnvironment = $pacEnvironments[$PacEnvironmentSelector]
                }
                else {
                    Write-Information "Invalid selection entered."
                }
            }
        }
    }
    else {
        if ($pacEnvironments.ContainsKey($PacEnvironmentSelector)) {
            # valid input
            $pacEnvironment = $pacEnvironments[$PacEnvironmentSelector]
        }
        else {
            Write-Error "Policy as Code environment selector $PacEnvironmentSelector is not valid" -ErrorAction Stop
        }
    }
    Write-Information "Environment Selected: $PacEnvironmentSelector"
    Write-Information "    cloud      = $($pacEnvironment.cloud)"
    Write-Information "    tenant     = $($pacEnvironment.tenantId)"
    Write-Information "    root scope = $($pacEnvironment.deploymentRootScope)"
    Write-Information ""


    $OutputFolder = $globalSettings.outputFolder
    $InputFolder = $globalSettings.inputFolder
    $apiVersions = @{}

    $apiVersions = switch ($pacEnvironment.cloud) {
        AzureChinaCloud {
            @{
                policyDefinitions    = "2021-06-01"
                policySetDefinitions = "2021-06-01"
                policyAssignments    = "2022-06-01"
                policyExemptions     = "2022-07-01-preview"
                roleAssignments      = "2022-04-01"
            }
        }
        AzureUSGovernment {
            @{
                policyDefinitions    = "2021-06-01"
                policySetDefinitions = "2021-06-01"
                policyAssignments    = "2022-06-01"
                policyExemptions     = "2022-07-01-preview"
                roleAssignments      = "2022-04-01"
            }
        }
        default {
            @{
                policyDefinitions    = "2023-04-01"
                policySetDefinitions = "2023-04-01"
                policyAssignments    = "2023-04-01"
                policyExemptions     = "2022-07-01-preview"
                roleAssignments      = "2022-04-01"
            }
        }
    }
    $planFiles = @{
        interactive          = $Interactive
        policyPlanOutputFile = "$($OutputFolder)/plans-$PacEnvironmentSelector/policy-plan.json"
        rolesPlanOutputFile  = "$($OutputFolder)/plans-$PacEnvironmentSelector/roles-plan.json"
        policyPlanInputFile  = "$($InputFolder)/plans-$PacEnvironmentSelector/policy-plan.json"
        rolesPlanInputFile   = "$($InputFolder)/plans-$PacEnvironmentSelector/roles-plan.json"
    }
    $pacEnvironmentDefinition = $pacEnvironment + $planFiles + $globalSettings + @{
        apiVersions = $apiVersions
    }

    return $pacEnvironmentDefinition
}
