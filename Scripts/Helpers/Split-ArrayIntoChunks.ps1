function Split-ArrayIntoChunks {
    param (
        [Parameter(Mandatory = $true)]
        [array] $Array,
        
        [Parameter(Mandatory = $false)]
        $NumberOfChunks = 5,

        [Parameter(Mandatory = $false)]
        $MinChunkingSize = 5
    )
    
    # split array into chunks
    $count = $Array.Count
    if ($count -le $MinChunkingSize) {
        [array] $chunks = [array]::CreateInstance([array], 1)
        $chunks[0] = $Array
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
            $chunks[0] = $Array
            return , $chunks
        }
        else {
            for ($i = 0; $i -lt $NumberOfChunks; $i++) {
                $start = $i * $chunkingSize
                $end = $start + $chunkingSize - 1
                if ($end -ge $count) {
                    $end = $count - 1
                }
                $chunks[$i] = $Array[$start..$end]
            }
            return $chunks
        }
    }
}
