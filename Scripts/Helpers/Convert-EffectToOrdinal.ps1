function Convert-EffectToOrdinal {
    param (
        [string] $Effect
    )

    $Effect2sortOrdinal = @{
        Modify            = 0
        Append            = 0
        DeployIfNotExists = 0
        Deny              = 1
        Audit             = 2
        Manual            = 2
        AuditIfNotExists  = 3
        Disabled          = 4
    }


    $Ordinal = -1 # should not be possible
    if ($Effect2sortOrdinal.ContainsKey($Effect)) {
        $Ordinal = $Effect2sortOrdinal.$Effect
    }
    return $Ordinal
}
