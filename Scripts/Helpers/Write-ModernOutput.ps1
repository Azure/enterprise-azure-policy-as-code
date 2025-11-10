# Global variable to cache the loaded theme
$script:LoadedTheme = $null

function Reset-OutputTheme {
    <#
    .SYNOPSIS
    Resets the cached theme to force reload from theme file.
    .DESCRIPTION
    Useful for testing theme changes without restarting PowerShell session.
    #>
    $script:LoadedTheme = $null
}

function Get-OutputTheme {
    param()
    
    # Return cached theme if already loaded
    if ($script:LoadedTheme) {
        return $script:LoadedTheme
    }
    
    # Look for .epac/theme.json file
    $themeFilePath = ".epac\theme.json"
    $fallbackPaths = @(
        "$PSScriptRoot\..\..\epac\theme.json",
        "$PSScriptRoot\..\..\.epac\theme.json"
    )
    
    $themeConfig = $null
    
    # Try to find and load theme file
    if (Test-Path $themeFilePath) {
        try {
            $themeConfig = Get-Content $themeFilePath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Warning "Failed to load theme from $themeFilePath`: $($_.Exception.Message)"
        }
    }
    else {
        # Try fallback paths
        foreach ($path in $fallbackPaths) {
            if (Test-Path $path) {
                try {
                    $themeConfig = Get-Content $path -Raw | ConvertFrom-Json
                    break
                }
                catch {
                    Write-Warning "Failed to load theme from $path`: $($_.Exception.Message)"
                }
            }
        }
    }
    
    # If no theme file found or failed to load, use default hardcoded theme
    if (!$themeConfig) {
        $themeConfig = @{
            themeName = "default"
            themes    = @{
                default = @{
                    name       = "Default Modern Theme"
                    characters = @{
                        header  = @{
                            topLeft     = "┏"
                            topRight    = "┓"
                            bottomLeft  = "┗"
                            bottomRight = "┛"
                            horizontal  = "━"
                            vertical    = "┃"
                        }
                        section = @{
                            arrow     = "▶"
                            underline = "━"
                        }
                        status  = @{
                            success    = "✓"
                            warning    = "⚠"
                            error      = "✗"
                            info       = "•"
                            skip       = "⊘"
                            update     = "⭮"
                            processing = "🔄"
                        }
                    }
                    colors     = @{
                        header  = @{
                            primary   = "Cyan"
                            secondary = "DarkCyan"
                        }
                        section = "Blue"
                        status  = @{
                            success    = "Green"
                            warning    = "Yellow"
                            error      = "Red"
                            info       = "White"
                            skip       = "DarkGray"
                            update     = "Cyan"
                            processing = "Yellow"
                        }
                    }
                }
            }
        }
    }
    
    # Get the selected theme
    $selectedThemeName = $themeConfig.themeName
    if (!$selectedThemeName) {
        $selectedThemeName = "default"
    }
    
    # Check if theme exists
    if (!$themeConfig.themes.$selectedThemeName) {
        Write-Warning "Theme '$selectedThemeName' not found, falling back to default"
        $selectedThemeName = "default"
        if (!$themeConfig.themes.default) {
            Write-Warning "Default theme not found, using hardcoded fallback"
            $selectedThemeName = "default"
        }
    }
    
    # Cache and return the theme
    $script:LoadedTheme = $themeConfig.themes.$selectedThemeName
    return $script:LoadedTheme
}

function Write-ModernHeader {
    param(
        [string]$Title,
        [string]$Subtitle = ""
    )
    
    $theme = Get-OutputTheme
    $headerChars = $theme.characters.header
    $headerColors = $theme.colors.header
    
    # Calculate the longest text length between title and subtitle
    $maxLength = $Title.Length
    if ($Subtitle -and $Subtitle.Length -gt $maxLength) {
        $maxLength = $Subtitle.Length
    }
    
    $border = $headerChars.horizontal * ($maxLength + 4)
    
    Write-Host ""
    if ($headerChars.topLeft -and $headerChars.topRight) {
        Write-Host "$($headerChars.topLeft)$border$($headerChars.topRight)" -ForegroundColor $headerColors.primary
        Write-Host "$($headerChars.vertical)  $($Title.PadRight($maxLength))  $($headerChars.vertical)" -ForegroundColor $headerColors.primary
        if ($Subtitle) {
            Write-Host "$($headerChars.vertical)  $($Subtitle.PadRight($maxLength))  $($headerChars.vertical)" -ForegroundColor $headerColors.secondary
        }
        Write-Host "$($headerChars.bottomLeft)$border$($headerChars.bottomRight)" -ForegroundColor $headerColors.primary
    }
    else {
        # Screen reader mode - no box drawing
        Write-Host $Title -ForegroundColor $headerColors.primary
        if ($Subtitle) {
            Write-Host $Subtitle -ForegroundColor $headerColors.secondary
        }
    }
    Write-Host ""
}

function Write-ModernSection {
    param(
        [string]$Title,
        [int]$Indent = 0
    )
    
    $theme = Get-OutputTheme
    $sectionChars = $theme.characters.section
    $sectionColor = $theme.colors.section
    
    $prefix = " " * $Indent
    
    Write-Host ""
    Write-Host "$prefix$($sectionChars.arrow) $Title" -ForegroundColor $sectionColor
    if ($sectionChars.underline) {
        $underline = $sectionChars.underline * ($Title.Length + 2)
        Write-Host "$prefix$underline" -ForegroundColor $sectionColor
    }
}

function Write-ModernStatus {
    param(
        [string]$Message,
        [string]$Status = "info",
        [int]$Indent = 0
    )
    
    $theme = Get-OutputTheme
    $statusChars = $theme.characters.status
    $statusColors = $theme.colors.status
    $backgroundColors = $theme.backgroundColors.status
    
    $prefix = " " * $Indent
    $statusLower = $Status.ToLower()
    
    # Get character and color for status
    $statusChar = if ($statusChars.$statusLower) { $statusChars.$statusLower } else { $statusChars.info }
    $statusColor = if ($statusColors.$statusLower) { $statusColors.$statusLower } else { $statusColors.info }
    
    # Check for background color support
    if ($backgroundColors -and $backgroundColors.$statusLower -and $backgroundColors.$statusLower -ne "") {
        $backgroundColor = $backgroundColors.$statusLower
        Write-Host "$prefix$statusChar $Message" -ForegroundColor $statusColor -BackgroundColor $backgroundColor
    }
    else {
        Write-Host "$prefix$statusChar $Message" -ForegroundColor $statusColor
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
    
    Write-ModernSection -Title "$Type Summary" -Indent 0
    
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
        Write-ModernStatus -Message "No changes required" -Status "info" -Indent $Indent
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
            Write-ModernStatus -Message "$($Changes.add) additions" -Status "success" -Indent ($Indent + 2)
        }
        if ($Changes.ContainsKey('remove') -and $Changes.remove -gt 0) {
            Write-ModernStatus -Message "$($Changes.remove) removals" -Status "error" -Indent ($Indent + 2)
        }
    }
}

function Write-ModernProgress {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Activity,
        [int]$Indent = 0
    )
    
    $theme = Get-OutputTheme
    $statusChars = $theme.characters.status
    $statusColors = $theme.colors.status
    
    $prefix = " " * $Indent
    $progressChar = if ($statusChars.processing) { $statusChars.processing } else { "🔄" }
    $progressColor = if ($statusColors.processing) { $statusColors.processing } else { "Yellow" }
    
    $percentage = if ($Total -gt 0) { [math]::Round(($Current / $Total) * 100) } else { 0 }
    $progressText = "$Activity ($Current/$Total - $percentage%)"
    
    Write-Host "$prefix$progressChar $progressText" -ForegroundColor $progressColor
}