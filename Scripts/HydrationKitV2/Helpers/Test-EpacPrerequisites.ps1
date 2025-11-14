<#
.SYNOPSIS
    Performs quick prerequisite checks for EPAC installation.

.DESCRIPTION
    Validates essential requirements: Azure connection, permissions, and paths.
#>
function Test-EpacPrerequisites {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch] $Quick
    )

    $PSDefaultParameterValues = @{
        "Write-Information:InformationVariable" = "+global:epacInfoStream"
    }

    $results = @{
        AzureConnection = $false
        WriteAccess     = $false
        Errors          = @()
        Warnings        = @()
    }

    # Check Azure connection
    try {
        $context = Get-AzContext
        if ($context) {
            $results.AzureConnection = $true
            Write-ModernStatus -Message "Azure PowerShell module found" -Status "success" -Indent 2
            Write-Verbose "Connected to Azure (Tenant: $($context.Tenant.Id))"
        }
        else {
            $results.Errors += "Not connected to Azure. Run: Connect-AzAccount"
            Write-ModernStatus -Message "Not connected to Azure" -Status "error" -Indent 2
        }
    }
    catch {
        $results.Errors += "Azure connection check failed: $_"
        Write-ModernStatus -Message "Azure connection check failed" -Status "error" -Indent 2
    }

    # Check write access to current directory
    try {
        $testFile = Join-Path (Get-Location) ".epac-test-$(Get-Random)"
        "test" | Out-File $testFile -ErrorAction Stop
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        $results.WriteAccess = $true
        Write-ModernStatus -Message "Write access confirmed" -Status "success" -Indent 2
    }
    catch {
        $results.Errors += "No write access to current directory: $_"
        Write-ModernStatus -Message "No write access to current directory" -Status "error" -Indent 2
    }

    # Quick mode skips non-essential checks
    if (!$Quick) {
        # Check for EPAC module (warning only)
        $epacModule = Get-Module -ListAvailable -Name EnterprisePolicyAsCode
        if (!$epacModule) {
            $results.Warnings += "EnterprisePolicyAsCode module not found. Some features may be limited."
            Write-ModernStatus -Message "EPAC module not found (optional)" -Status "warning" -Indent 2
        }
        else {
            Write-ModernStatus -Message "EPAC module available: v$($epacModule.Version)" -Status "success" -Indent 2
        }
    }

    # Determine success
    $success = $results.Errors.Count -eq 0

    return @{
        Success = $success
        Message = if ($success) { "Prerequisites check passed" } else { $results.Errors -join "; " }
        Results = $results
    }
}
