<#
.SYNOPSIS
Creates a new PowerShell object based on a JSON schema URI.

.DESCRIPTION
The `New-SchemaJsonTemplate` function generates a PowerShell object for use as a template from a specified JSON schema URI. It can also generate a blank template JSONC file if required.

.PARAMETER JsonSchemaUri
The URI of the JSON schema to be used for generating the PowerShell object for use as a template. This parameter is mandatory.

.PARAMETER Output
The path to the output directory where the generated files will be saved. This parameter is optional and defaults to "./Output".

.PARAMETER SuppressReturn
A switch parameter that, if specified, suppresses the return of the generated PowerShell object.

.PARAMETER SuppressFileCreation
A switch parameter that, if specified, suppresses the creation of the blank template JSONC file.

.EXAMPLE
```powershell
New-SchemaJsonTemplate -JsonSchemaUri "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-documentation-schema.json"
#>

function New-SchemaJsonTemplate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $JsonSchemaUri,
        [Parameter(Mandatory = $false)]
        [string]
        $Output = "./Output",
        [switch]
        $SuppressReturn,
        [switch]
        $SuppressFileCreation
    )
    $InformationPreference = "Continue"
    $outputPath = $(Join-Path $Output (Get-Date -Format "yyyy-MM-dd") policyDocumentations)
        
    if (!(Test-Path -Path $outputPath)) {
        $null = New-Item -Path $path -ItemType Directory -Force
    }
    
    # Gather JSON schema from URI
    Write-Information "Gathering latest $(Split-Path $JsonSchemaUri -LeafBase) schema..."
    $jsonSchema = Invoke-RestMethod -Uri $JsonSchemaUri | ConvertTo-json -Depth 100 | ConvertFrom-Json -Depth 100 -AsHashtable
        
    # Generate PSObject based on JSON schema
    $psObject = New-PSObjectFromSchema -Schema $jsonSchema
        
    # Return the generated PSObject
    Write-Information "Testing Schema"
    try {
        $psObject | ConvertTo-Json -Depth 100 | Out-Null
    }
    catch {
        Write-Error "The schema is not valid. Please check the schema and try again."
        return
    }
    if (!($SuppressFileCreation)) {
        # Generate blank template JSONC file
        Write-Information "Generating Blank Template JSONC file at $(Join-Path ($outputPath) blankTemplate.jsonc)..."
        $psObject | ConvertTo-Json -Depth 100 | Out-File -FilePath $(Join-Path ($outputPath) $( -join ((Split-Path $JsonSchemaUri -LeafBase), '-blankTemplate.jsonc'))) -Force
    }
    if ($SuppressReturn) {
        return
    }
    else {
        return $psObject
    }
}
    