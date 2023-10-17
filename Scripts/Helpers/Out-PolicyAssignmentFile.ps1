function Out-PolicyAssignmentFile {
    [CmdletBinding()]
    param (
        $PerDefinition,
        $PropertyNames,
        $PolicyAssignmentsFolder,
        $InvalidChars
    )

    $definition = $PerDefinition.definitionEntry
    $definitionKind = $definition.kind
    $definitionName = $definition.name
    $definitionId = $definition.id
    $definitionDisplayName = $definition.displayName

    $kindString = $definitionKind -replace "Definitions", ""
    $fullPath = Get-DefinitionsFullPath `
        -Folder $PolicyAssignmentsFolder `
        -FileSuffix "-$kindString" `
        -Name $definition.name `
        -DisplayName $definitionDisplayName `
        -InvalidChars $InvalidChars `
        -MaxLengthSubFolder 30 `
        -MaxLengthFileName 100 `
        -FileExtension $fileExtension

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

    $assignmentDefinition = [ordered]@{
        '$schema'       = "https://raw.githubusercontent.com/Azure/enterprise-azure-policy-as-code/main/Schemas/policy-assignment-schema.json"
        nodeName        = "/root"
        definitionEntry = $definitionEntry
    }
    Export-AssignmentNode `
        -TreeNode $PerDefinition `
        -AssignmentNode $assignmentDefinition `
        -PropertyNames $PropertyNames

    # Write structure to file
    $json = ConvertTo-Json $assignmentDefinition -Depth 100
    $null = New-Item $fullPath -Force -ItemType File -Value $json
}
