# EPAC Hydration Kit V2 - Function Loader

# Load Core Functions
. $PSScriptRoot/Core/New-EpacConfiguration.ps1
. $PSScriptRoot/Core/Deploy-EpacResources.ps1
. $PSScriptRoot/Core/Initialize-EpacRepository.ps1

# Load Helper Functions
. $PSScriptRoot/Helpers/Test-EpacPrerequisites.ps1

# Load Optional Functions
. $PSScriptRoot/Optional/Import-EpacPolicies.ps1
. $PSScriptRoot/Optional/New-EpacPipeline.ps1

# Load Main Orchestrator
. $PSScriptRoot/Install-EpacHydration.ps1

# Load Modern Output Functions
. $PSScriptRoot/../Helpers/Write-ModernOutput.ps1

Write-Verbose "EPAC Hydration Kit V2 functions loaded successfully"
