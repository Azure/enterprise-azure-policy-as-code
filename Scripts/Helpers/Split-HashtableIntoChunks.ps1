function Split-HashtableIntoChunks {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable] $Table,
        
        [Parameter(Mandatory = $false)]
        $NumberOfChunks = 5,

        [Parameter(Mandatory = $false)]
        $MinChunkingSize = 5
    )
    
    # split definition array into chunks
    $count = $Table.Count
    if ($count -le $MinChunkingSize) {
        $chunks = @( $Table )
        return , $chunks
    }
    else {
        $chunkingSize = [math]::Ceiling($count / $NumberOfChunks)
        if ($chunkingSize -lt $MinChunkingSize) {
            $NumberOfChunks = [math]::Ceiling($count / $MinChunkingSize)
            $chunkingSize = [math]::Ceiling($count / $NumberOfChunks)
        }
        if ($NumberOfChunks -eq 1) {
            $chunks = @( $Table )
            return , $chunks
        }
        else {
            [array] $chunks = [array]::CreateInstance([array], $NumberOfChunks)
            $chunk = @{}
            $itemCount = 0
            $i = 0
            $Table.GetEnumerator() | ForEach-Object {
                $chunk[$_.key] = $_.value
                $itemCount++
                if ($itemCount -eq $chunkingSize) {
                    $chunks[$i] = $chunk
                    $i++
                    $chunk = @{}
                    $itemCount = 0
                }
            }
            if ($itemCount -gt 0) {
                $chunks[$i] = $chunk
            }
            return $chunks
        }
    }
}
