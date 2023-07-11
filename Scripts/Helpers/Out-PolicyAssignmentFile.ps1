function Out-PolicyAssignmentFile {
    [CmdletBinding()]
    param (
        $PerDefinition,
        $PropertyNames,
        $PolicyAssignmentsFolder,
        $InvalidChars
    )

    $Definition = $PerDefinition.definitionEntry
    $DefinitionKind = $Definition.kind
    $DefinitionName = $Definition.name
    $DefinitionId = $Definition.id
    $DefinitionDisplayName = $Definition.displayName

    $kindString = $DefinitionKind -replace "Definitions", ""
    $fullPath = Get-DefinitionsFullPath `
        -Folder $PolicyAssignmentsFolder `
        -FileSuffix "-$kindString" `
        -Name $Definition.name `
        -DisplayName $DefinitionDisplayName `
        -InvalidChars $InvalidChars `
        -MaxLengthSubFolder 30 `
        -MaxLengthFileName 100 `
        -FileExtension $FileExtension

    # Create definitionEntry
    $DefinitionEntry = [ordered]@{}
    if ($Definition.isBuiltin) {
        if ($DefinitionKind -eq "policySetDefinitions") {
            $DefinitionEntry = [ordered]@{
                policySetId = $DefinitionId
                displayName = $DefinitionDisplayName
            }
        }
        else {
            $DefinitionEntry = [ordered]@{
                policyId    = $DefinitionId
                displayName = $DefinitionDisplayName
            }
        }
    }
    else {
        # Custom
        if ($DefinitionKind -eq "policySetDefinitions") {
            $DefinitionEntry = [ordered]@{
                policySetName = $DefinitionName
                displayName   = $DefinitionDisplayName
            }
        }
        else {
            $DefinitionEntry = [ordered]@{
                policyName  = $DefinitionName
                displayName = $DefinitionDisplayName
            }
        }
    }

    $AssignmentDefinition = @{
        nodeName        = "/root"
        definitionEntry = $DefinitionEntry
    }
    Set-AssignmentNode `
        -TreeNode $PerDefinition `
        -AssignmentNode $AssignmentDefinition `
        -PropertyNames $PropertyNames

    # Write structure to file
    Remove-NullFields $AssignmentDefinition
    $json = ConvertTo-Json $AssignmentDefinition -Depth 100
    $null = New-Item $fullPath -Force -ItemType File -Value $json
}
