<#
.SYNOPSIS
    Initializes the EPAC repository structure and core files.

.DESCRIPTION
    Creates the Definitions folder structure and generates the global-settings.jsonc file
    with the configured EPAC environments.
#>
function Initialize-EpacRepository {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $Configuration
    )

    $PSDefaultParameterValues = @{
        "Write-Information:InformationVariable" = "+global:epacInfoStream"
    }

    try {
        Write-Verbose "Initializing repository structure..."
        $results = @{
            DefinitionsFolderCreated = $false
            GlobalSettingsCreated    = $false
            Errors                   = @()
        }

        # Create Definitions folder structure
        Write-ModernStatus -Message "Creating Definitions folder structure" -Status "processing" -Indent 2
        
        $defFolders = @(
            $Configuration.DefinitionsRootFolder,
            (Join-Path $Configuration.DefinitionsRootFolder "policyDefinitions"),
            (Join-Path $Configuration.DefinitionsRootFolder "policySetDefinitions"),
            (Join-Path $Configuration.DefinitionsRootFolder "policyAssignments"),
            (Join-Path $Configuration.DefinitionsRootFolder "policyExemptions"),
            (Join-Path $Configuration.DefinitionsRootFolder "policyDocumentations")
        )

        foreach ($folder in $defFolders) {
            if (!(Test-Path $folder)) {
                New-Item -ItemType Directory -Path $folder -Force | Out-Null
                Write-Verbose "  ✓ Created: $folder"
            }
            else {
                Write-Verbose "  Exists: $folder"
            }
        }
        $results.DefinitionsFolderCreated = $true

        # Create global-settings.jsonc
        Write-ModernStatus -Message "Creating global-settings.jsonc" -Status "processing" -Indent 2
        
        $globalSettingsPath = Join-Path $Configuration.DefinitionsRootFolder "global-settings.jsonc"
        
        $globalSettings = @{
            pacOwnerId      = $Configuration.PacOwnerId
            pacEnvironments = @(
                @{
                    pacSelector              = $Configuration.PacSelector
                    cloud                    = $Configuration.CloudName
                    tenantId                 = $Configuration.TenantId
                    deploymentRootScope      = "/providers/Microsoft.Management/managementGroups/$($Configuration.TenantIntermediateRoot)"
                    desiredState             = @{
                        strategy                   = $Configuration.DesiredState
                        keepDfcSecurityAssignments = $false
                    }
                    managedIdentityLocations = @{
                        globalLocations = @($Configuration.ManagedIdentityLocation)
                    }
                },
                @{
                    pacSelector              = $Configuration.EpacDevSelector
                    cloud                    = $Configuration.CloudName
                    tenantId                 = $Configuration.TenantId
                    deploymentRootScope      = "/providers/Microsoft.Management/managementGroups/$($Configuration.EpacDevRoot)"
                    desiredState             = @{
                        strategy                   = $Configuration.DesiredState
                        keepDfcSecurityAssignments = $false
                    }
                    managedIdentityLocations = @{
                        globalLocations = @($Configuration.ManagedIdentityLocation)
                    }
                }
            )
        }

        # Convert to JSONC (JSON with comments)
        $jsonContent = @"
{
  // EPAC Environment Configuration
  // Generated: $($Configuration.Timestamp)
  // Documentation: https://aka.ms/epac/settings

  // Unique identifier for this EPAC instance
  "pacOwnerId": "$($Configuration.PacOwnerId)",

  // EPAC Environments (pacEnvironments)
  "pacEnvironments": [
    {
      // Main production environment
      "pacSelector": "$($Configuration.PacSelector)",
      "cloud": "$($Configuration.CloudName)",
      "tenantId": "$($Configuration.TenantId)",
      "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/$($Configuration.TenantIntermediateRoot)",
      "desiredState": {
        "strategy": "$($Configuration.DesiredState)",
        "keepDfcSecurityAssignments": false
      },
      "managedIdentityLocation": "$($Configuration.ManagedIdentityLocation)"
    },
    {
      // Development/testing environment
      "pacSelector": "$($Configuration.EpacDevSelector)",
      "cloud": "$($Configuration.CloudName)",
      "tenantId": "$($Configuration.TenantId)",
      "deploymentRootScope": "/providers/Microsoft.Management/managementGroups/$($Configuration.EpacDevRoot)",
      "desiredState": {
        "strategy": "$($Configuration.DesiredState)",
        "keepDfcSecurityAssignments": false
      },
      "managedIdentityLocation": "$($Configuration.ManagedIdentityLocation)"
    }
  ]
}
"@

        $jsonContent | Set-Content -Path $globalSettingsPath -Force
        $results.GlobalSettingsCreated = $true
        Write-Verbose "  ✓ Created: $globalSettingsPath"

        # Create a README in Definitions folder
        $readmePath = Join-Path $Configuration.DefinitionsRootFolder "README.md"
        $readmeContent = @"
# EPAC Policy Definitions

This folder contains your Enterprise Policy as Code (EPAC) policy definitions.

## Structure

- **policyDefinitions/** - Custom policy definitions
- **policySetDefinitions/** - Custom policy set definitions (initiatives)
- **policyAssignments/** - Policy and policy set assignments
- **policyExemptions/** - Policy exemptions
- **policyDocumentations/** - Documentation generation configuration

## Configuration

The `global-settings.jsonc` file defines your EPAC environments:
- **$($Configuration.PacSelector)** - Main environment (root: $($Configuration.TenantIntermediateRoot))
- **$($Configuration.EpacDevSelector)** - Development environment (root: $($Configuration.EpacDevRoot))

## Next Steps

1. Review and customize policy assignments in `policyAssignments/`
2. Test deployment: `Build-DeploymentPlans -PacEnvironmentSelector $($Configuration.EpacDevSelector)`
3. Deploy to dev: `Deploy-PolicyPlan -PacEnvironmentSelector $($Configuration.EpacDevSelector)`

## Documentation

- EPAC Documentation: https://aka.ms/epac
- Policy Assignments: https://aka.ms/epac/assignments
- Global Settings: https://aka.ms/epac/settings
"@

        $readmeContent | Set-Content -Path $readmePath -Force
        Write-Verbose "  ✓ Created: $readmePath"

        # Return results
        if ($results.Errors.Count -eq 0) {
            Write-Verbose "Repository initialization completed successfully"
            return @{
                Success = $true
                Results = $results
            }
        }
        else {
            return @{
                Success = $false
                Message = "Initialization completed with errors: $($results.Errors -join '; ')"
                Results = $results
            }
        }
    }
    catch {
        Write-Error "Repository initialization failed: $_"
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}
