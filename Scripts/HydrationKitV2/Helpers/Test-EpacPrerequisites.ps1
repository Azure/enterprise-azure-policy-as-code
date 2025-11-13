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
        WriteAccess = $false
        Errors = @()
        Warnings = @()
    }

    # Check Azure connection
    try {
        $context = Get-AzContext
        if ($context) {
            $results.AzureConnection = $true
            Write-Verbose "✓ Connected to Azure (Tenant: $($context.Tenant.Id))"
        }
        else {
            $results.Errors += "Not connected to Azure. Run: Connect-AzAccount"
        }
    }
    catch {
        $results.Errors += "Azure connection check failed: $_"
    }

    # Check write access to current directory
    try {
        $testFile = Join-Path (Get-Location) ".epac-test-$(Get-Random)"
        "test" | Out-File $testFile -ErrorAction Stop
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        $results.WriteAccess = $true
        Write-Verbose "✓ Write access confirmed"
    }
    catch {
        $results.Errors += "No write access to current directory: $_"
    }

    # Quick mode skips non-essential checks
    if (!$Quick) {
        # Check for EPAC module (warning only)
        $epacModule = Get-Module -ListAvailable -Name EnterprisePolicyAsCode
        if (!$epacModule) {
            $results.Warnings += "EnterprisePolicyAsCode module not found. Some features may be limited."
        }
        else {
            Write-Verbose "✓ EPAC module available: v$($epacModule.Version)"
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
