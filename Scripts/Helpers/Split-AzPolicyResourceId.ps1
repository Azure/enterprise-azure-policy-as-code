function Split-AzPolicyResourceId {
    [CmdletBinding()]
    param (
        [string] $Id
    )

    $splits = $Id -split "/"
    $name = $splits[-1]
    $segments = $splits.Length
    $end = $splits.Count - 5
    $scopeType = switch ($segments) {
        5 { "builtin" }
        7 { "subscriptions" }
        9 { $splits[3] }
        Default { "unknown" }
    }
    $definitionKey = $Id
    if ($scopeType -ne "builtin") {
        $definitionKey = $splits[-2..-1] -join "/"
    }
    $result = @{
        id            = $Id
        name          = $name
        segments      = $segments
        splits        = $splits
        scope         = $splits[0..$end] -join "/"
        scopeType     = $scopeType
        kind          = $splits[-2]
        definitionKey = $definitionKey
    }

    return $result
}
