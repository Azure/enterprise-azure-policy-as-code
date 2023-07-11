function Out-PolicyDefinition {
    [CmdletBinding()]
    param (
        $Definition,
        $Folder,
        [hashtable] $PolicyPropertiesByName,
        $InvalidChars,
        $Id,
        $FileExtension
    )

    # Fields to calculate file name
    $Name = $Definition.name
    $properties = $Definition.properties
    $DisplayName = $properties.displayName
    if ($null -eq $DisplayName -or $DisplayName -eq "") {
        $DisplayName = $Name
    }
    $Metadata = $properties.metadata
    $subFolder = "Unknown Category"
    if ($null -ne $Metadata) {
        $category = $Metadata.category
        if ($null -ne $category -and $category -ne "") {
            $subFolder = $category
        }
    }

    # Build folder and path
    $fullPath = Get-DefinitionsFullPath `
        -Folder $Folder `
        -RawSubFolder $subFolder `
        -Name $Name `
        -DisplayName $DisplayName `
        -InvalidChars $InvalidChars `
        -MaxLengthSubFolder 30 `
        -MaxLengthFileName 100 `
        -FileExtension $FileExtension

    # Detect duplicates

    if ($PolicyPropertiesByName.ContainsKey($Name)) {
        $duplicateProperties = $PolicyPropertiesByName.$Name
        # quietly ignore
        #
        # $exactDuplicate = Confirm-ObjectValueEqualityDeep $duplicateProperties $properties
        # if ($exactDuplicate) {
        #     # Write-Warning "'$DisplayName' - '$Id' is an exact duplicate" -WarningAction Continue
        #     # Quietly ignore
        #     $null = $properties
        # }
        # else {
        #     $guid = (New-Guid)
        #     $fullPath = "$Folder/Duplicates/$($guid.Guid).$FileExtension"
        #     Write-Warning "'$DisplayName' - '$Id' is a duplicate with different properties; writing to file $fullPath" -WarningAction Continue
        #     $Definition | Add-Member -MemberType NoteProperty -Name 'id' -Value $Id
        # }
    }
    else {
        # Unique name
        Write-Debug "'$DisplayName' - '$Id'"
        $null = $PolicyPropertiesByName.Add($Name, $properties)
    }

    # Write the content
    Remove-NullFields $Definition
    $json = ConvertTo-Json $Definition -Depth 100
    $null = New-Item $fullPath -Force -ItemType File -Value $json
}
