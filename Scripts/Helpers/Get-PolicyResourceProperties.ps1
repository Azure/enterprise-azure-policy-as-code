function Get-PolicyResourceProperties {
    [CmdletBinding()]
    param (
        $policyResource
    )

    if ($policyResource.properties) {
        return $policyResource.properties
    }
    else {
        return $policyResource
    }
}