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
        [array] $chunks = [array]::CreateInstance([array], 1)
        $chunks[0] = $Table
        return , $chunks
    }
    else {
        $chunkingSize = [math]::Ceiling($count / $NumberOfChunks)
        if ($chunkingSize -lt $MinChunkingSize) {
            $NumberOfChunks = [math]::Ceiling($count / $MinChunkingSize)
            $chunkingSize = [math]::Ceiling($count / $NumberOfChunks)
        }
        [array] $chunks = [array]::CreateInstance([array], $NumberOfChunks)
        if ($NumberOfChunks -eq 1) {
            Write-Error "Coding error: NumberOfChunks is 1" -ErrorAction Continue
            $chunks[0] = $Table
            return , $chunks
        }
        else {
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
