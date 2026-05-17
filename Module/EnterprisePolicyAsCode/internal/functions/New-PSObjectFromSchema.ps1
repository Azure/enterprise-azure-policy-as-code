<#
.SYNOPSIS
Generates a PowerShell custom object from a JSON schema. This should generally be used with Azure related Schemas as this is all that has been tested.

.DESCRIPTION
The `New-PSObjectFromSchema` function creates a PowerShell custom object based on the structure defined in a provided JSON schema. The function recursively processes the schema to handle nested objects and arrays.

.PARAMETER Schema
The JSON schema used to generate the PowerShell custom object. This parameter is mandatory.

.EXAMPLE
$jsonSchemaUri = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-documentation-schema.json"
$schema = Invoke-RestMethod -Uri $JsonSchemaUri | ConvertTo-json -Depth 100 | ConvertFrom-Json -Depth 100 -AsHashtable
$psObject = New-PSObjectFromSchema -Schema $schema
#>

function New-PSObjectFromSchema {
    param (
        [Parameter(Mandatory = $true)]
        $Schema
    )

    $psObject = [PSCustomObject]@{}

    foreach ($property in $Schema.properties.GetEnumerator()) {
        $propertyName = $property.Name
        $propertySchema = $property.Value

        switch ($propertySchema.type) {
            "object" {
                $psObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value (New-PSObjectFromSchema -Schema $propertySchema)
            }
            "array" {
                if ($propertySchema.items.type -eq "object") {
                    $psObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value @((New-PSObjectFromSchema -Schema $propertySchema.items))
                }
                else {
                    $psObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value @()
                }
            }
            default {
                $psObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $null
            }
        }
    }

    return $psObject
}