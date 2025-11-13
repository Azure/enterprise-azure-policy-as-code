<#
.SYNOPSIS
    Imports existing policy assignments into EPAC.

.DESCRIPTION
    Exports existing policies from the specified scope and converts them to EPAC format.
    This function uses the EPAC Export-AzPolicyResources command to extract policies,
    policy sets, assignments, and exemptions from your Azure environment.
#>
function Import-EpacPolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory = $false)]
        [switch] $IncludeAutoAssigned,

        [Parameter(Mandatory = $false)]
        [ValidateSet('none', 'csv', 'json')]
        [string] $ExemptionFiles = 'csv'
    )

    $PSDefaultParameterValues = @{
        "Write-Information:InformationVariable" = "+global:epacInfoStream"
    }

    try {
        Write-ModernSection -Title "Importing Existing Policies" -Indent 2

        # Check if Export-AzPolicyResources is available
        $exportCmd = Get-Command Export-AzPolicyResources -ErrorAction SilentlyContinue
        if (!$exportCmd) {
            Write-ModernStatus -Message "Export-AzPolicyResources command not found" -Status "error" -Indent 4
            Write-ModernStatus -Message "Please ensure the EnterprisePolicyAsCode module is loaded" -Status "info" -Indent 4
            return @{
                Success = $false
                Message = "Export-AzPolicyResources command not found. Please install the EnterprisePolicyAsCode module."
            }
        }

        # Create export directory
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $exportPath = Join-Path $Configuration.OutputFolder "PolicyExport-$timestamp"
        if (!(Test-Path $exportPath)) {
            New-Item -ItemType Directory -Path $exportPath -Force | Out-Null
        }
        
        Write-ModernStatus -Message "Export location: $exportPath" -Status "info" -Indent 4
        Write-ModernStatus -Message "Exporting from scope: /providers/Microsoft.Management/managementGroups/$($Configuration.TenantIntermediateRoot)" -Status "processing" -Indent 4
        
        # Build parameters for Export-AzPolicyResources
        $exportParams = @{
            DefinitionsRootFolder = $Configuration.DefinitionsRootFolder
            OutputFolder          = $exportPath
            InputPacSelector      = $Configuration.PacSelector
            FileExtension         = 'jsonc'
            IncludeChildScopes    = $true
            ExemptionFiles        = $ExemptionFiles
            Mode                  = 'export'
            Interactive           = $false
            ErrorAction           = 'Stop'
        }

        if ($IncludeAutoAssigned) {
            $exportParams['IncludeAutoAssigned'] = $true
            Write-ModernStatus -Message "Including auto-assigned policies (e.g., Defender for Cloud)" -Status "info" -Indent 4
        }

        # Execute the export
        Write-ModernStatus -Message "Executing policy export..." -Status "processing" -Indent 4
        Export-AzPolicyResources @exportParams

        # Analyze and report what was exported
        $exportDefPath = Join-Path $exportPath "Definitions"
        if (Test-Path $exportDefPath) {
            $stats = @{
                policyDefinitions    = 0
                policySetDefinitions = 0
                policyAssignments    = 0
                policyExemptions     = 0
            }

            # Count exported items
            $policyDefDir = Join-Path $exportDefPath "policyDefinitions"
            if (Test-Path $policyDefDir) {
                $stats.policyDefinitions = (Get-ChildItem $policyDefDir -Recurse -File -Filter "*.json*").Count
            }

            $policySetDir = Join-Path $exportDefPath "policySetDefinitions"
            if (Test-Path $policySetDir) {
                $stats.policySetDefinitions = (Get-ChildItem $policySetDir -Recurse -File -Filter "*.json*").Count
            }

            $assignmentDir = Join-Path $exportDefPath "policyAssignments"
            if (Test-Path $assignmentDir) {
                $stats.policyAssignments = (Get-ChildItem $assignmentDir -Recurse -File -Filter "*.json*").Count
            }

            $exemptionDir = Join-Path $exportDefPath "policyExemptions"
            if (Test-Path $exemptionDir) {
                if ($ExemptionFiles -eq 'csv') {
                    $stats.policyExemptions = (Get-ChildItem $exemptionDir -Recurse -File -Filter "*.csv").Count
                }
                else {
                    $stats.policyExemptions = (Get-ChildItem $exemptionDir -Recurse -File -Filter "*.json*").Count
                }
            }

            Write-ModernSection -Title "Export Results" -Indent 4
            Write-ModernStatus -Message "Policy Definitions: $($stats.policyDefinitions)" -Status "success" -Indent 6
            Write-ModernStatus -Message "Policy Set Definitions: $($stats.policySetDefinitions)" -Status "success" -Indent 6
            Write-ModernStatus -Message "Policy Assignments: $($stats.policyAssignments)" -Status "success" -Indent 6
            
            if ($ExemptionFiles -ne 'none') {
                Write-ModernStatus -Message "Policy Exemptions: $($stats.policyExemptions)" -Status "success" -Indent 6
            }

            # Provide guidance on next steps
            Write-ModernSection -Title "Next Steps for Imported Policies" -Indent 4
            Write-ModernStatus -Message "1. Review exported files in: $exportDefPath" -Status "info" -Indent 6
            Write-ModernStatus -Message "2. Custom policy definitions have been exported to $policyDefDir" -Status "info" -Indent 6
            Write-ModernStatus -Message "3. Custom policy set definitions have been exported to $policySetDir" -Status "info" -Indent 6
            Write-ModernStatus -Message "4. Assignments are ready to review in $assignmentDir" -Status "info" -Indent 6
            
            if ($stats.policyDefinitions -eq 0 -and $stats.policySetDefinitions -eq 0) {
                Write-ModernStatus -Message "No custom policies found - only built-in policies are assigned" -Status "info" -Indent 6
            }

            return @{
                Success              = $true
                ExportPath           = $exportPath
                PolicyDefinitions    = $stats.policyDefinitions
                PolicySetDefinitions = $stats.policySetDefinitions
                PolicyAssignments    = $stats.policyAssignments
                PolicyExemptions     = $stats.policyExemptions
            }
        }
        else {
            Write-ModernStatus -Message "No policies found to export from the specified scope" -Status "warning" -Indent 4
            return @{
                Success = $false
                Message = "No policies found to export from the specified scope."
            }
        }
    }
    catch {
        Write-ModernStatus -Message "Policy import failed: $($_.Exception.Message)" -Status "error" -Indent 4
        Write-Error "Policy import failed: $_"
        return @{
            Success = $false
            Message = $_.Exception.Message
            Error   = $_
        }
    }
}
