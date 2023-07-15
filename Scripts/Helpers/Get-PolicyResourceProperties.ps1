function Get-PolicyResourceProperties {
    [CmdletBinding()]
    param (
        $PolicyResource
    )

    if ($PolicyResource.properties) {
        return $PolicyResource.properties
    }
    else {
        return $PolicyResource
    }
}
