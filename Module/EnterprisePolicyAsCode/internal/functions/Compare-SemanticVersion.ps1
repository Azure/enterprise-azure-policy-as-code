function Compare-SemanticVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Version1,

        [Parameter(Mandatory = $true)]
        [string] $Version2
    )

    # Split the versions into their components
    $v1Parts = $Version1 -split '\.'
    $v2Parts = $Version2 -split '\.'

    # Ensure both versions have the same number of components
    $maxLength = [math]::Max($v1Parts.Length, $v2Parts.Length)
    #$v1Parts = $v1Parts + (0..($maxLength - $v1Parts.Length) | ForEach-Object { '*' })
    #$v2Parts = $v2Parts + (0..($maxLength - $v2Parts.Length) | ForEach-Object { '*' })

    for ($i = 0; $i -lt $maxLength; $i++) {
        $part1 = $v1Parts[$i]
        $part2 = $v2Parts[$i]

        if ($part1 -eq '*' -or $part2 -eq '*') {
            continue
        }

        if ($part1 -match "-preview" -or $part2 -match "-preview") {
            if ($part1 -match "-preview" -and $part2 -match "-preview") {
                $part1 = $part1 -replace "-preview", ""
                $part2 = $part2 -replace "-preview", ""

                if ($part1 -eq '*' -or $part2 -eq '*') {
                    continue
                }

                if ([int]$part1 -lt [int]$part2) {
                    return -1
                }
                elseif ([int]$part1 -gt [int]$part2) {
                    return 1
                }
            }
            else {
                return -1
            }
        
        }

        if ([int]$part1 -lt [int]$part2) {
            return -1
        }
        elseif ([int]$part1 -gt [int]$part2) {
            return 1
        }
    }

    return 0
}

# Example usage:
# Compare-SemanticVersion "1.2.3" "1.2.4" # Returns -1
# Compare-SemanticVersion "1.2.3" "1.2.*" # Returns 0
# Compare-SemanticVersion "1.2.3" "1.2.3" # Returns 0
# Compare-SemanticVersion "1.2.3" "1.2.2" # Returns 1