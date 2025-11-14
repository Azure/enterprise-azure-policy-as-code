<#
.SYNOPSIS
    Deploys Azure Management Group structure for EPAC.

.DESCRIPTION
    Optionally creates the epac-dev environment by copying the management group
    hierarchy for testing purposes. In most cases, the intermediate root already
    exists and only the dev environment needs to be created.
#>
function Deploy-EpacResources {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory = $false)]
        [switch] $SkipDevEnvironment
    )

    $PSDefaultParameterValues = @{
        "Write-Information:InformationVariable" = "+global:epacInfoStream"
    }

    try {
        Write-Verbose "Starting Azure resource deployment..."
        $results = @{
            EpacDevCreated = $false
            Errors         = @()
        }

        # Verify the Tenant Intermediate Root exists
        Write-ModernStatus -Message "Verifying Management Group: $($Configuration.TenantIntermediateRoot)" -Status "processing" -Indent 2
        
        $tenantMg = Get-AzManagementGroup -GroupId $Configuration.TenantIntermediateRoot -ErrorAction SilentlyContinue
        if (!$tenantMg) {
            $results.Errors += "Management Group '$($Configuration.TenantIntermediateRoot)' not found. Please create it first or use an existing Management Group ID."
            Write-ModernStatus -Message "Management Group not found: $($Configuration.TenantIntermediateRoot)" -Status "error" -Indent 4
            
            return @{
                Success = $false
                Message = $results.Errors[-1]
                Results = $results
            }
        }
        
        Write-ModernStatus -Message "Management Group verified: $($Configuration.TenantIntermediateRoot)" -Status "success" -Indent 4

        # Create epac-dev environment if requested
        if (-not $SkipDevEnvironment) {
            Write-ModernStatus -Message "Creating EPAC-Dev environment: $($Configuration.EpacDevRoot)" -Status "processing" -Indent 2
        
            try {
                # Use the existing Copy-HydrationManagementGroupHierarchy if available
                $copyCmd = Get-Command Copy-HydrationManagementGroupHierarchy -ErrorAction SilentlyContinue
            
                if ($copyCmd) {
                    # Use existing EPAC command
                    Write-Verbose "  Using Copy-HydrationManagementGroupHierarchy..."
                    $copyResult = Copy-HydrationManagementGroupHierarchy `
                        -SourceGroupName $Configuration.TenantIntermediateRoot `
                        -DestinationParentGroupName $Configuration.EpacDevParent `
                        -Prefix $Configuration.EpacDevPrefix `
                        -ErrorAction Stop
                
                    $results.EpacDevCreated = $true
                    Write-Verbose "  ✓ Created EPAC-Dev hierarchy"
                }
                else {
                    # Fallback: Simple copy without full hierarchy
                    Write-Verbose "  Creating simple EPAC-Dev root (full hierarchy copy not available)..."
                
                    $epacDevMg = Get-AzManagementGroup -GroupId $Configuration.EpacDevRoot -ErrorAction SilentlyContinue
                    if (!$epacDevMg) {
                        $null = New-AzManagementGroup `
                            -GroupId $Configuration.EpacDevRoot `
                            -ParentId "/providers/Microsoft.Management/managementGroups/$($Configuration.EpacDevParent)" `
                            -ErrorAction Stop
                    
                        # Wait for propagation
                        Start-Sleep -Seconds 3
                        $results.EpacDevCreated = $true
                        Write-Verbose "  ✓ Created EPAC-Dev root Management Group"
                        Write-Warning "  Note: Full hierarchy copy requires EPAC module. Only root MG created."
                    }
                    else {
                        Write-Verbose "  EPAC-Dev root already exists"
                        $results.EpacDevCreated = $true
                    }
                }
            }
            catch {
                $results.Errors += "Failed to create EPAC-Dev environment: $_"
                Write-Warning $results.Errors[-1]
            }
        }
        else {
            Write-ModernStatus -Message "Skipping EPAC-Dev environment creation (not requested)" -Status "skip" -Indent 2
        }

        # Return results
        if ($results.Errors.Count -eq 0) {
            Write-Verbose "Resource deployment completed successfully"
            return @{
                Success = $true
                Results = $results
            }
        }
        else {
            return @{
                Success = $false
                Message = "Deployment completed with errors: $($results.Errors -join '; ')"
                Results = $results
            }
        }
    }
    catch {
        Write-Error "Resource deployment failed: $_"
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}
