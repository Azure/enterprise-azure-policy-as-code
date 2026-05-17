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
        $chunks = @( $Array )
        return , $chunks
    }
    else {
        $chunkingSize = [math]::Ceiling($count / $NumberOfChunks)
        if ($chunkingSize -lt $MinChunkingSize) {
            $NumberOfChunks = [math]::Ceiling($count / $MinChunkingSize)
            $chunkingSize = [math]::Ceiling($count / $NumberOfChunks)
        }
        if ($NumberOfChunks -eq 1) {
            $chunks = @( $Array )
            return , $chunks
        }
        else {
            [array] $chunks = [array]::CreateInstance([array], $NumberOfChunks)
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
