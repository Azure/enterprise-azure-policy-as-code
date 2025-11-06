function Write-ModernHeader {
    param(
        [string]$Title,
        [string]$Subtitle = "",
        [ConsoleColor]$HeaderColor = [ConsoleColor]::Cyan,
        [ConsoleColor]$SubtitleColor = [ConsoleColor]::DarkCyan
    )
    
    # Calculate the longest text length between title and subtitle
    $maxLength = $Title.Length
    if ($Subtitle -and $Subtitle.Length -gt $maxLength) {
        $maxLength = $Subtitle.Length
    }
    
    $border = "━" * ($maxLength + 4)
    
    Write-Host ""
    Write-Host "┏$border┓" -ForegroundColor $HeaderColor
    Write-Host "┃  $($Title.PadRight($maxLength))  ┃" -ForegroundColor $HeaderColor
    if ($Subtitle) {
        Write-Host "┃  $($Subtitle.PadRight($maxLength))  ┃" -ForegroundColor $SubtitleColor
    }
    Write-Host "┗$border┛" -ForegroundColor $HeaderColor
    Write-Host ""
}

function Write-ModernSection {
    param(
        [string]$Title,
        [ConsoleColor]$Color = [ConsoleColor]::Blue
    )
    
    Write-Host ""
    Write-Host "▶ $Title" -ForegroundColor $Color
    $underline = "━" * ($Title.Length + 2)
    Write-Host $underline -ForegroundColor $Color
}

function Write-ModernStatus {
    param(
        [string]$Message,
        [string]$Status = "Info",
        [int]$Indent = 0
    )
    
    $prefix = " " * $Indent
    switch ($Status.ToLower()) {
        "update" { Write-Host "$prefix⭮ $Message" -ForegroundColor Cyan }
        "success" { Write-Host "$prefix✓ $Message" -ForegroundColor Green }
        "warning" { Write-Host "$prefix⚠ $Message" -ForegroundColor Yellow }
        "error" { Write-Host "$prefix✗ $Message" -ForegroundColor Red }
        "info" { Write-Host "$prefix• $Message" -ForegroundColor White }
        "skip" { Write-Host "$prefix⊘ $Message" -ForegroundColor DarkGray }
        default { Write-Host "$prefix$Message" -ForegroundColor White }
    }
}

function Write-ModernCountSummary {
    param(
        [string]$Type,
        [int]$Unchanged,
        [int]$TotalChanges,
        [hashtable]$Changes = @{},
        [int]$Orphaned = -1,
        [int]$Expired = -1,
        [int]$Indent = 2
    )
    
    Write-ModernSection -Title "$Type Summary" -Color Magenta
    
    if ($Unchanged -gt 0) {
        Write-ModernStatus -Message "$Unchanged resources unchanged" -Status "info" -Indent $Indent
    }
    
    if ($Orphaned -ge 0) {
        if ($Orphaned -gt 0) {
            Write-ModernStatus -Message "$Orphaned orphaned resources" -Status "warning" -Indent $Indent
        }
    }
    
    if ($Expired -ge 0) {
        if ($Expired -gt 0) {
            Write-ModernStatus -Message "$Expired expired resources" -Status "warning" -Indent $Indent
        }
    }
    
    if ($TotalChanges -eq 0) {
        Write-ModernStatus -Message "No changes required" -Status "success" -Indent $Indent
    }
    else {
        Write-ModernStatus -Message "$TotalChanges total changes:" -Status "info" -Indent $Indent
        
        if ($Changes.ContainsKey('new') -and $Changes.new -gt 0) {
            Write-ModernStatus -Message "$($Changes.new) new" -Status "success" -Indent ($Indent + 2)
        }
        if ($Changes.ContainsKey('update') -and $Changes.update -gt 0) {
            Write-ModernStatus -Message "$($Changes.update) updates" -Status "update" -Indent ($Indent + 2)
        }
        if ($Changes.ContainsKey('replace') -and $Changes.replace -gt 0) {
            Write-ModernStatus -Message "$($Changes.replace) replacements" -Status "warning" -Indent ($Indent + 2)
        }
        if ($Changes.ContainsKey('delete') -and $Changes.delete -gt 0) {
            Write-ModernStatus -Message "$($Changes.delete) deletions" -Status "error" -Indent ($Indent + 2)
        }
        if ($Changes.ContainsKey('add') -and $Changes.add -gt 0) {
            Write-ModernStatus -Message "$($Changes.add) additions" -Status "info" -Indent ($Indent + 2)
        }
        if ($Changes.ContainsKey('remove') -and $Changes.remove -gt 0) {
            Write-ModernStatus -Message "$($Changes.remove) removals" -Status "error" -Indent ($Indent + 2)
        }
    }
}

function Write-ModernProgress {
    param(
        [string]$Activity,
        [string]$Status = "Processing",
        [ConsoleColor]$Color = [ConsoleColor]::Yellow
    )
    
    Write-Host ""
    Write-Host "🔄 $Activity..." -ForegroundColor $Color
}