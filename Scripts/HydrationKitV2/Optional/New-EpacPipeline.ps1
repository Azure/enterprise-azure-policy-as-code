<#
.SYNOPSIS
    Creates CI/CD pipeline files for EPAC deployment using StarterKit templates.

.DESCRIPTION
    Generates pipeline configuration files for GitHub Actions or Azure DevOps.
    Uses StarterKit templates for comprehensive, production-ready workflows.
#>
function New-EpacPipeline {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('GitHub', 'AzureDevOps')]
    [string] $Platform,

    [Parameter(Mandatory = $true)]
    [PSCustomObject] $Configuration,

    [Parameter(Mandatory = $false)]
    [ValidateSet('GitHub', 'Release')]
    [string] $BranchingFlow = 'GitHub',

    [Parameter(Mandatory = $false)]
    [switch] $UseModule
  )

  $PSDefaultParameterValues = @{
    "Write-Information:InformationVariable" = "+global:epacInfoStream"
  }

  try {
    Write-ModernSection "Creating $Platform Pipeline Files"

    # Clone EPAC repository to get StarterKit
    Write-ModernStatus "Cloning EPAC repository for StarterKit templates..." -Status 'Info'
            
    $tempEpacPath = Join-Path $env:TEMP "epac-temp-$(Get-Random)"
            
    try {
      $gitCmd = Get-Command git -ErrorAction SilentlyContinue
      if (-not $gitCmd) {
        throw "Git is required to clone the EPAC repository for StarterKit templates. Please install Git and try again."
      }

      # Clone the repo
      $cloneResult = & git clone --depth 1 --single-branch https://github.com/Azure/enterprise-azure-policy-as-code.git $tempEpacPath 2>&1
                
      if ($LASTEXITCODE -ne 0) {
        throw "Failed to clone EPAC repository: $cloneResult"
      }

      Write-ModernStatus "Repository cloned successfully to: $tempEpacPath" -Status 'Success'
                    
      # Use the New-PipelinesFromStarterKit function
      $starterKitPath = Join-Path $tempEpacPath "StarterKit"
                    
      if (-not (Test-Path $starterKitPath)) {
        throw "StarterKit folder not found at: $starterKitPath"
      }

      Write-ModernStatus "Found StarterKit at: $starterKitPath" -Status 'Info'
      Write-ModernStatus "Copying pipeline templates from StarterKit..." -Status 'Info'
                        
      $platformParam = if ($Platform -eq 'GitHub') { 'GitHubActions' } else { 'AzureDevOps' }
      $scriptType = if ($UseModule) { 'Module' } else { 'Scripts' }
                        
      # Import the function
      $scriptPath = Join-Path $tempEpacPath "Scripts\Operations\New-PipelinesFromStarterKit.ps1"
                        
      if (-not (Test-Path $scriptPath)) {
        throw "Script not found: $scriptPath"
      }

      # Convert to absolute path to ensure it works across contexts
      $absoluteStarterKitPath = (Resolve-Path $starterKitPath).Path
                            
      # Call it with the correct parameters
      New-PipelinesFromStarterKit `
        -StarterKitFolder $absoluteStarterKitPath `
        -PipelineType $platformParam `
        -BranchingFlow $BranchingFlow `
        -ScriptType $scriptType `
        -ErrorAction Stop
                            
      Write-ModernStatus "Pipeline files created from StarterKit" -Status 'Success'
                            
      # Clean up temp directory
      Remove-Item -Path $tempEpacPath -Recurse -Force -ErrorAction SilentlyContinue
                            
      return @{
        Success = $true
        Type    = 'StarterKit'
        Message = "StarterKit pipeline templates have been successfully deployed."
      }
    }
    catch {
      Write-ModernStatus "Error creating pipeline: $_" -Status 'Error'
      throw
    }
    finally {
      # Clean up temp directory if it exists
      if (Test-Path $tempEpacPath) {
        Remove-Item -Path $tempEpacPath -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }
  catch {
    Write-ModernStatus "Pipeline creation failed: $_" -Status 'Error'
    return @{
      Success = $false
      Type    = 'StarterKit'
      Message = $_.Exception.Message
    }
  }
}
