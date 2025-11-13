<#
.SYNOPSIS
    Creates CI/CD pipeline files for EPAC deployment.

.DESCRIPTION
    Generates pipeline configuration files for GitHub Actions or Azure DevOps.
    Can create basic pipelines or use StarterKit templates for more comprehensive workflows.
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
        [ValidateSet('Simple', 'StarterKit')]
        [string] $PipelineType = 'Simple',

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

        if ($PipelineType -eq 'StarterKit') {
            # Clone EPAC repository to get StarterKit
            Write-ModernStatus "Cloning EPAC repository for StarterKit templates..." -Status 'Info'
            
            $tempEpacPath = Join-Path $env:TEMP "epac-temp-$(Get-Random)"
            
            try {
                $gitCmd = Get-Command git -ErrorAction SilentlyContinue
                if (-not $gitCmd) {
                    Write-ModernStatus "Git not found. Falling back to simple pipeline." -Status 'Warning'
                    $PipelineType = 'Simple'
                }
                else {
                    # Clone the repo
                    $cloneResult = & git clone --depth 1 --single-branch https://github.com/Azure/enterprise-azure-policy-as-code.git $tempEpacPath 2>&1
                    
                    if ($LASTEXITCODE -ne 0) {
                        Write-ModernStatus "Failed to clone EPAC repository. Falling back to simple pipeline." -Status 'Warning'
                        $PipelineType = 'Simple'
                    }
                    else {
                        Write-ModernStatus "Repository cloned successfully to: $tempEpacPath" -Status 'Success'
                        
                        # Use the New-PipelinesFromStarterKit function
                        $starterKitPath = Join-Path $tempEpacPath "StarterKit"
                        
                        if (Test-Path $starterKitPath) {
                            Write-ModernStatus "Found StarterKit at: $starterKitPath" -Status 'Info'
                            Write-ModernStatus "Copying pipeline templates from StarterKit..." -Status 'Info'
                            
                            $platformParam = if ($Platform -eq 'GitHub') { 'GitHubActions' } else { 'AzureDevOps' }
                            $scriptType = if ($UseModule) { 'Module' } else { 'Scripts' }
                            
                            # Import the function
                            $scriptPath = Join-Path $tempEpacPath "Scripts\Operations\New-PipelinesFromStarterKit.ps1"
                            
                            if (Test-Path $scriptPath) {
                                #. $scriptPath
                                
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
                                }
                            }
                            else {
                                Write-ModernStatus "Script not found: $scriptPath" -Status 'Warning'
                                Write-ModernStatus "Falling back to simple pipeline" -Status 'Info'
                                $PipelineType = 'Simple'
                            }
                        }
                        else {
                            Write-ModernStatus "StarterKit folder not found at: $starterKitPath" -Status 'Warning'
                            Write-ModernStatus "Falling back to simple pipeline" -Status 'Info'
                            $PipelineType = 'Simple'
                        }
                    }
                }
            }
            catch {
                Write-ModernStatus "Error using StarterKit: $_" -Status 'Warning'
                Write-ModernStatus "Falling back to simple pipeline" -Status 'Info'
                $PipelineType = 'Simple'
            }
            finally {
                # Clean up temp directory if it exists
                if (Test-Path $tempEpacPath) {
                    Remove-Item -Path $tempEpacPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }

        # Simple pipeline creation
        if ($PipelineType -eq 'Simple') {
            Write-ModernStatus "Creating simple pipeline template..." -Status 'Info'
            
            if ($Platform -eq 'GitHub') {
                $pipelineDir = ".github/workflows"
                $pipelineFile = "epac-deploy.yml"
                
                New-Item -ItemType Directory -Path $pipelineDir -Force | Out-Null
            
                $pipelineContent = @"
name: EPAC Deploy

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: `${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: `${{ secrets.AZURE_TENANT_ID }}
          subscription-id: `${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Install EPAC Module
        shell: pwsh
        run: Install-Module EnterprisePolicyAsCode -Force
      
      - name: Build Deployment Plans
        shell: pwsh
        run: |
          Build-DeploymentPlans ``
            -PacEnvironmentSelector $($Configuration.PacSelector) ``
            -DefinitionsRootFolder ./Definitions ``
            -OutputFolder ./Output

  deploy-policies:
    needs: plan
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: `${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: `${{ secrets.AZURE_TENANT_ID }}
          subscription-id: `${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Install EPAC Module
        shell: pwsh
        run: Install-Module EnterprisePolicyAsCode -Force
      
      - name: Deploy Policy Plan
        shell: pwsh
        run: |
          Deploy-PolicyPlan ``
            -PacEnvironmentSelector $($Configuration.PacSelector) ``
            -DefinitionsRootFolder ./Definitions
  
  deploy-roles:
    needs: deploy-policies
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: `${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: `${{ secrets.AZURE_TENANT_ID }}
          subscription-id: `${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Install EPAC Module
        shell: pwsh
        run: Install-Module EnterprisePolicyAsCode -Force
      
      - name: Deploy Roles Plan
        shell: pwsh
        run: |
          Deploy-RolesPlan ``
            -PacEnvironmentSelector $($Configuration.PacSelector) ``
            -DefinitionsRootFolder ./Definitions
"@
            
                $pipelinePath = Join-Path $pipelineDir $pipelineFile
                $pipelineContent | Set-Content -Path $pipelinePath -Force
                Write-ModernStatus "Created: $pipelinePath" -Status 'Success'
            }
            else {
                # Azure DevOps
                $pipelineFile = "azure-pipelines.yml"
            
                $pipelineContent = @"
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: Plan
    jobs:
      - job: BuildPlans
        steps:
          - task: AzurePowerShell@5
            displayName: 'Build Deployment Plans'
            inputs:
              azureSubscription: 'Azure-Connection'
              ScriptType: 'InlineScript'
              Inline: |
                Install-Module EnterprisePolicyAsCode -Force
                Build-DeploymentPlans ``
                  -PacEnvironmentSelector $($Configuration.PacSelector) ``
                  -DefinitionsRootFolder ./Definitions ``
                  -OutputFolder ./Output
              azurePowerShellVersion: 'LatestVersion'

  - stage: Deploy
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - job: DeployPolicies
        steps:
          - task: AzurePowerShell@5
            displayName: 'Deploy Policy Plan'
            inputs:
              azureSubscription: 'Azure-Connection'
              ScriptType: 'InlineScript'
              Inline: |
                Install-Module EnterprisePolicyAsCode -Force
                Deploy-PolicyPlan ``
                  -PacEnvironmentSelector $($Configuration.PacSelector) ``
                  -DefinitionsRootFolder ./Definitions
              azurePowerShellVersion: 'LatestVersion'
      
      - job: DeployRoles
        dependsOn: DeployPolicies
        steps:
          - task: AzurePowerShell@5
            displayName: 'Deploy Roles Plan'
            inputs:
              azureSubscription: 'Azure-Connection'
              ScriptType: 'InlineScript'
              Inline: |
                Install-Module EnterprisePolicyAsCode -Force
                Deploy-RolesPlan ``
                  -PacEnvironmentSelector $($Configuration.PacSelector) ``
                  -DefinitionsRootFolder ./Definitions
              azurePowerShellVersion: 'LatestVersion'
"@
                
                $pipelineContent | Set-Content -Path $pipelineFile -Force
                Write-ModernStatus "Created: $pipelineFile" -Status 'Success'
            }

            return @{
                Success = $true
                Type    = 'Simple'
                Message = "Basic pipeline template created. Customize for your environment."
            }
        }
    }
    catch {
        Write-ModernStatus "Pipeline creation failed: $_" -Status 'Error'
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}
