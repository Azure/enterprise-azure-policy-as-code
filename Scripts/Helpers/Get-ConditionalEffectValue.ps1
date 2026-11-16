function Get-ConditionalEffectValue {
    <#
    .SYNOPSIS
    Resolves an effect passed as [if(contains(parameters('<list>'),'<item>'),<result>,<result>)], where <result> is parameters('<name>') or '<literal>'.
    Returns $null for any other value, or when a parameter it needs has no value.
    #>
    param (
        [string] $EffectExpression,
        $PolicySetParameters,
        $AssignmentParameters
    )

    $result = "(?:parameters\('([^']+)'\)|'([^']*)')"
    if ($EffectExpression -notmatch "^\[if\(contains\(parameters\('([^']+)'\),\s*'([^']*)'\),\s*$result,\s*$result\)\]$") {
        return $null
    }
    $parts = $Matches

    # Assignment parameters replace Policy Set defaults
    $parameterValues = @{}
    foreach ($name in $PolicySetParameters.Keys) {
        $parameterValues[$name] = $PolicySetParameters.$name.defaultValue
    }
    foreach ($name in $AssignmentParameters.Keys) {
        $parameterValues[$name] = $AssignmentParameters.$name.value
    }

    $list = $parameterValues[$parts[1]]
    if ($null -eq $list) {
        return $null
    }
    # contains() compares strings case-sensitive
    $parameterGroup, $literalGroup = if (@($list) -ccontains $parts[2]) { 3, 4 } else { 5, 6 }
    $effect = if ($parts[$parameterGroup]) { $parameterValues[$parts[$parameterGroup]] } else { $parts[$literalGroup] }
    if ($effect -is [string] -and $effect -ne '') {
        return $effect
    }
    return $null
}
