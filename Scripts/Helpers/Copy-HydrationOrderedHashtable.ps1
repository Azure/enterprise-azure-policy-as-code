function Copy-HydrationOrderedHashtable {
    <#
    .SYNOPSIS
        Creates a copy of an ordered hashtable.

    .DESCRIPTION
        The Copy-HydrationOrderedHashtable function creates a new copy of an ordered hashtable in memory as this .Net object contains no clone() method. 
        This allows you to modify the new hashtable without affecting the original hashtable.

    .PARAMETER Hashtable
        The ordered hashtable to copy.

    .EXAMPLE
        $original = [ordered]@{ Key1 = "Value1"; Key2 = "Value2" }
        $copy = Copy-HydrationOrderedHashtable -Hashtable $original

        This command creates a copy of the $original hashtable and assigns it to $copy.

    .NOTES
        The new hashtable is a semi-shallow copy of the original ordered hashtable. If the values in the original hashtable are reference types that are not ordered hashtables, then the values in the new hashtable will point to the same objects as the values in the original hashtable.
    .LINK
        https://aka.ms/epac
        https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
    #>
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.OrderedHashtable]$Hashtable
    )

    $newHashtable = [ordered]@{}

    foreach ($key in $Hashtable.Keys) {
        if ($Hashtable[$key] -is [System.Management.Automation.OrderedHashtable]) {
            $newHashtable[$key] = Copy-HydrationOrderedHashtable -Hashtable $Hashtable[$key]
            continue
        }
        else {
            $newHashtable[$key] = $Hashtable[$key]
        }
    }

    return $newHashtable
}