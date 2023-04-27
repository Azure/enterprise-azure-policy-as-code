function Out-PolicyDefinition {
    [CmdletBinding()]
    param (
        $definition,
        $folder,
        [hashtable] $policyPropertiesByName,
        $invalidChars,
        $id,
        $fileExtension
    )

    # Fields to calculate file name
    $name = $definition.name
    $properties = $definition.properties
    $displayName = $properties.displayName
    if ($null -eq $displayName -or $displayName -eq "") {
        $displayName = $name
    }
    $metadata = $properties.metadata
    $subFolder = "Unknown Category"
    if ($null -ne $metadata) {
        $category = $metadata.category
        if ($null -ne $category -and $category -ne "") {
            $subFolder = $category
        }
    }

    # Build folder and path
    $fullPath = Get-DefinitionsFullPath `
        -folder $folder `
        -rawSubFolder $subFolder `
        -name $name `
        -displayName $displayName `
        -invalidChars $invalidChars `
        -maxLengthSubFolder 30 `
        -maxLengthFileName 100 `
        -fileExtension $fileExtension

    # Detect duplicates

    if ($policyPropertiesByName.ContainsKey($name)) {
        $duplicateProperties = $policyPropertiesByName.$name
        # quietly ignore
        #
        # $exactDuplicate = Confirm-ObjectValueEqualityDeep $duplicateProperties $properties
        # if ($exactDuplicate) {
        #     # Write-Warning "'$displayName' - '$id' is an exact duplicate" -WarningAction Continue
        #     # Quietly ignore
        #     $null = $properties
        # }
        # else {
        #     $guid = (New-Guid)
        #     $fullPath = "$folder/Duplicates/$($guid.Guid).$fileExtension"
        #     Write-Warning "'$displayName' - '$id' is a duplicate with different properties; writing to file $fullPath" -WarningAction Continue
        #     $definition | Add-Member -MemberType NoteProperty -Name 'id' -Value $id
        # }
    }
    else {
        # Unique name
        Write-Debug "'$displayName' - '$id'"
        $null = $policyPropertiesByName.Add($name, $properties)
    }

    # Write the content
    Remove-NullFields $definition
    $json = ConvertTo-Json $definition -Depth 100
    $null = New-Item $fullPath -Force -ItemType File -Value $json
}
