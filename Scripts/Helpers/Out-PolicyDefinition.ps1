#Requires -PSEdition Core

function Out-PolicyDefinition {
    [CmdletBinding()]
    param (
        $definition,
        $folder,
        [hashtable] $policyNames,
        $invalidChars,
        $typeString,
        $id
    )

    # Fields to calculate file name
    $name = $definition.name
    $displayName = $properties.displayName
    $category = $properties.metadata.category

    # Build folder and path
    $subFolder = "Unknown Category"
    if ($null -ne $category -and $category -ne "") {
        $subFolder = $category
    }
    $fullPath = Get-DefinitionsFullPath -folder $folder -rawSubFolder $subFolder -name $name -displayName $displayName -invalidChars $invalidChars -maxLengthSubFolder 30 -maxLengthFileName 100

    # Detect duplicates
    $properties = $definition.properties
    if ($null -eq $displayName -or $displayName -eq "") {
        $displayName = $name
    }

    if ($policyNames.ContainsKey($name)) {
        $exactDuplicate = Confirm-ObjectValueEqualityDeep -existingObj $policyNames.$name $properties
        if ($exactDuplicate) {
            Write-Warning "'$displayName' - '$id' is an exact duplicate" -WarningAction Continue
        }
        else {
            Write-Warning "'$displayName' - '$id' is a duplicate with different properties" -WarningAction Continue
        }
        $guid = (New-Guid).Guid
        $fullPath = "$folder/Duplicates/$guid.jsonc"
        $definition | Add-Member -MemberType NoteProperty -Name 'id' -Value $id
    }
    else {
        # Unique name
        Write-Debug "'$displayName' - '$id'"
        $null = $policyNames.Add($name, $properties)
    }

    # Write the content
    $json = ConvertTo-Json $definition -Depth 100
    $null = New-Item $fullPath -Force -ItemType File -Value $json
}
