function Split-AzPolicyResourceId {
    [CmdletBinding()]
    param (
        [string] $Id
    )

    $splits = $Id -split "/"
    $Name = $splits[-1]
    $segments = $splits.Length
    $end = $splits.Count - 5
    $ScopeType = switch ($segments) {
        5 { "builtin" }
        7 { "subscriptions" }
        9 { $splits[3] }
        Default { "unknown" }
    }
    $DefinitionKey = $Id
    if ($ScopeType -ne "builtin") {
        $DefinitionKey = $splits[-2..-1] -join "/"
    }
    $result = @{
        id            = $Id
        name          = $Name
        segments      = $segments
        splits        = $splits
        scope         = $splits[0..$end] -join "/"
        scopeType     = $ScopeType
        kind          = $splits[-2]
        definitionKey = $DefinitionKey
    }

    return $result
}
