function Convert-EffectToOrdinal {
    param (
        [string] $effect
    )

    $effect2sortOrdinal = @{
        Modify            = 0
        Append            = 0
        DeployIfNotExists = 0
        Deny              = 1
        Audit             = 2
        Manual            = 2
        AuditIfNotExists  = 3
        Disabled          = 4
    }


    $ordinal = -1 # should not be possible
    if ($effect2sortOrdinal.ContainsKey($effect)) {
        $ordinal = $effect2sortOrdinal.$effect
    }
    return $ordinal
}
