#Requires -PSEdition Core

function Write-AssignmentDetails {
    [CmdletBinding()]
    param (
        $printHeader,
        $assignmentName,
        $assignmentDisplayName,
        $assignmentDescription,
        $policySpecText,
        $scopeInfo,
        $roleDefinitions,
        $prefix
    )
    
    if ($printHeader) {
        Write-Information "    Assignment `'$($assignmentDisplayName)`' ($($assignmentName))"
        Write-Information "                Description: $($assignmentDescription)"
        Write-Information "                $($policySpecText)"
    }
    Write-Information "        $($prefix) at $($scopeInfo.scope)"
    # if ($roleDefinitions.Length -gt 0) {
    #     foreach ($roleDefinition in $roleDefinitions) {
    #         Write-Information "                RoleId=$($roleDefinition.roleDefinitionId), Scope=$($roleDefinition.scope)"
    #     }
    # }
}
