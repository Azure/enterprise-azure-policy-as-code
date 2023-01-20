#Requires -PSEdition Core

function Remove-EmptyFields {
    [CmdletBinding()]
    param (
        [hashtable] $definition
    )

    $definitionClone = $definition.Clone()
    foreach ($key in $definitionClone) {
        if ($null -eq $definition.$key) {
            $null = $definition.Remove($key)
        }
    }
}
