<#
.SYNOPSIS
    Builds the core configuration object for EPAC environment setup.

.DESCRIPTION
    Creates a configuration object with smart defaults and validates required settings.
    Prompts for missing required values when running interactively.
#>
function New-EpacConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TenantIntermediateRoot,

        [Parameter(Mandatory = $false)]
        [string] $PacSelector = "tenant01",

        [Parameter(Mandatory = $false)]
        [string] $ManagedIdentityLocation,

        [Parameter(Mandatory = $false)]
        [string] $DefinitionsRootFolder = "./Definitions",

        [Parameter(Mandatory = $false)]
        [string] $OutputFolder = "./Output",

        [Parameter(Mandatory = $false)]
        [switch] $NonInteractive
    )

    try {
        # Get Azure context
        $context = Get-AzContext
        if (!$context) {
            throw "Not connected to Azure. Please run Connect-AzAccount first."
        }

        $tenantId = $context.Tenant.Id
        $cloudName = $context.Environment.Name

        Write-Verbose "Connected to Tenant: $tenantId ($cloudName)"

        # Generate PacOwnerId (unique identifier for this EPAC instance)
        $pacOwnerId = (New-Guid).Guid
        Write-Verbose "Generated PacOwnerId: $pacOwnerId"

        # Validate or prompt for Managed Identity Location
        if (!$ManagedIdentityLocation) {
            if ($NonInteractive) {
                # Use a sensible default based on common regions
                $ManagedIdentityLocation = "eastus"
                Write-Verbose "Using default Managed Identity location: $ManagedIdentityLocation"
            }
            else {
                # Get available locations and prompt
                Write-ModernStatus -Message "Fetching available Azure regions..." -Status "processing" -Indent 2
                $locations = Get-AzLocation | Select-Object -ExpandProperty Location | Sort-Object
                
                Write-Host ""
                Write-ModernStatus -Message "Common regions:" -Status "info" -Indent 2
                $commonRegions = @('eastus', 'westus', 'eastus2', 'westeurope', 'northeurope', 'uksouth')
                $availableCommon = $commonRegions | Where-Object { $locations -contains $_ }
                $availableCommon | ForEach-Object { Write-ModernStatus -Message $_ -Status "info" -Indent 4 }
                Write-Host ""
                do {
                    $ManagedIdentityLocation = Read-Host "Enter Managed Identity location (e.g., eastus)"
                    if ($locations -notcontains $ManagedIdentityLocation) {
                        Write-Warning "Location '$ManagedIdentityLocation' not found. Please choose from available regions."
                        $ManagedIdentityLocation = $null
                    }
                } while (!$ManagedIdentityLocation)
            }
        }

        # Validate Tenant Intermediate Root exists or can be created
        Write-Verbose "Checking if Management Group '$TenantIntermediateRoot' exists..."
        $mgExists = $false
        try {
            $mg = Get-AzManagementGroup -GroupId $TenantIntermediateRoot -ErrorAction SilentlyContinue
            if ($mg) {
                $mgExists = $true
                Write-Verbose "Management Group '$TenantIntermediateRoot' exists."
            }
        }
        catch {
            Write-Verbose "Management Group '$TenantIntermediateRoot' does not exist yet."
        }

        # Generate EPAC-Dev naming
        $epacDevPrefix = "epac-dev-"
        $epacDevRoot = "$epacDevPrefix$TenantIntermediateRoot"
        $epacDevParent = $tenantId  # Default to Tenant Root

        Write-Verbose "EPAC-Dev root will be: $epacDevRoot (under $epacDevParent)"

        # Resolve paths
        $DefinitionsRootFolder = Resolve-Path $DefinitionsRootFolder -ErrorAction SilentlyContinue
        if (!$DefinitionsRootFolder) {
            $DefinitionsRootFolder = Join-Path (Get-Location) "Definitions"
        }

        $OutputFolder = Resolve-Path $OutputFolder -ErrorAction SilentlyContinue
        if (!$OutputFolder) {
            $OutputFolder = Join-Path (Get-Location) "Output"
        }

        # Create output directories if needed
        $logDir = Join-Path $OutputFolder "Logs"
        if (!(Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        # Build configuration object
        $config = [PSCustomObject]@{
            Success                      = $true
            TenantId                     = $tenantId
            CloudName                    = $cloudName
            TenantIntermediateRoot       = $TenantIntermediateRoot
            TenantIntermediateRootExists = $mgExists
            PacSelector                  = $PacSelector
            PacOwnerId                   = $pacOwnerId
            ManagedIdentityLocation      = $ManagedIdentityLocation
            EpacDevSelector              = "epac-dev"
            EpacDevPrefix                = $epacDevPrefix
            EpacDevRoot                  = $epacDevRoot
            EpacDevParent                = $epacDevParent
            DefinitionsRootFolder        = $DefinitionsRootFolder
            OutputFolder                 = $OutputFolder
            LogFile                      = Join-Path $logDir "epac-hydration-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            DesiredState                 = "ownedOnly"  # Safe default
            Timestamp                    = Get-Date
        }

        Write-Verbose "Configuration built successfully"
        return $config
    }
    catch {
        Write-Error "Failed to build configuration: $_"
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}
