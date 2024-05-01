<#
    .SYNOPSIS
    This function joins the values of a hashtable into a single path string, and provides an option to create the resulting path as a folder.

    .DESCRIPTION
    The function takes an ordered hashtable and concatenates its values into a single path string. If the CreateAsFolder switch is used, it will also create a directory at the resulting path.

    .PARAMETER Hashtable
    An ordered hashtable whose values will be joined into a path string. This parameter is mandatory. The Keys are irrelevant, only the values are used. Order submitted will be preserved.

    .PARAMETER CreateAsFolder
    A switch parameter. If specified, a directory will be created at the resulting path.

    .EXAMPLE
    $hash = [ordered]@{First = "Folder1"; Second = "Folder2", Foo = "Folder3"}
    Join-HydrationHashtableToPath -Hashtable $hash -CreateAsFolder

    This will join the values of the hashtable into a path string "Folder1\Folder2" and create a directory at this path.

    .NOTES
    The function uses the Join-Path cmdlet to concatenate the hashtable values into a path string. If the CreateAsFolder switch is used, the New-Item cmdlet is used to create a directory.
    
    .LINK
        https://aka.ms/epac
        https://github.com/Azure/enterprise-azure-policy-as-code/tree/main/Docs/start-hydration-kit.md
    #>
function Join-HydrationHashtableToPath {

    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.OrderedHashtable]
        $Hashtable,
        [switch]
        $CreateAsFolder
    )
    Write-Debug "Hashtable Count: $($hashtable.count)"

    foreach ($h in $hashtable.values) {
        Write-Debug "Processing $($h)"
        if (!($hashPath)) {
            $hashPath = $h
            Write-Debug "HashPath: $hashPath"
        }
        else {
            $hashPath = Join-Path $hashPath $h
            Write-Debug "HashPath: $hashPath"
        }        
    }
    if ($CreateAsFolder) {
        $null = New-Item -ItemType Directory -Path $hashPath -Force
    }
    return $hashpath
}