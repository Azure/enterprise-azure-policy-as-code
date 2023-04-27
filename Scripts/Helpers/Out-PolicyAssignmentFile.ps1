function Out-PolicyAssignmentFile {
    [CmdletBinding()]
    param (
        $perDefinition,
        $propertyNames,
        $policyAssignmentsFolder,
        $invalidChars
    )

    $definition = $perDefinition.definitionEntry
    $definitionKind = $definition.kind
    $definitionName = $definition.name
    $definitionId = $definition.id
    $definitionDisplayName = $definition.displayName

    $kindString = $definitionKind -replace "Definitions", ""
    $fullPath = Get-DefinitionsFullPath `
        -folder $policyAssignmentsFolder `
        -fileSuffix "-$kindString" `
        -name $definition.name `
        -displayName $definitionDisplayName `
        -invalidChars $invalidChars `
        -maxLengthSubFolder 30 `
        -maxLengthFileName 100 `
        -fileExtension $fileExtension

    # Create definitionEntry
    $definitionEntry = [ordered]@{}
    if ($definition.isBuiltin) {
        if ($definitionKind -eq "policySetDefinitions") {
            $definitionEntry = [ordered]@{
                policySetId = $definitionId
                displayName = $definitionDisplayName
            }
        }
        else {
            $definitionEntry = [ordered]@{
                policyId    = $definitionId
                displayName = $definitionDisplayName
            }
        }
    }
    else {
        # Custom
        if ($definitionKind -eq "policySetDefinitions") {
            $definitionEntry = [ordered]@{
                policySetName = $definitionName
                displayName   = $definitionDisplayName
            }
        }
        else {
            $definitionEntry = [ordered]@{
                policyName  = $definitionName
                displayName = $definitionDisplayName
            }
        }
    }

    $assignmentDefinition = @{
        nodeName        = "/root"
        definitionEntry = $definitionEntry
    }
    Set-AssignmentNode `
        -treeNode $perDefinition `
        -assignmentNode $assignmentDefinition `
        -propertyNames $propertyNames

    # Write structure to file
    Remove-NullFields $assignmentDefinition
    $json = ConvertTo-Json $assignmentDefinition -Depth 100
    $null = New-Item $fullPath -Force -ItemType File -Value $json
}