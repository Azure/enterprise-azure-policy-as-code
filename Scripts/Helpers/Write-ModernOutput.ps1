# Global variable to cache the loaded theme
$script:LoadedTheme = $null

# Global variable to detect CI/CD environment
$script:IsCICD = $null

function Test-CICDEnvironment {
    <#
    .SYNOPSIS
    Detects if running in a CI/CD pipeline environment.
    .DESCRIPTION
    Checks environment variables to determine if running in GitHub Actions, Azure DevOps, GitLab CI, or other CI/CD systems.
    #>
    if ($null -ne $script:IsCICD) {
        return $script:IsCICD
    }
    
    $script:IsCICD = (
        $env:GITHUB_ACTIONS -eq 'true' -or
        $env:TF_BUILD -eq 'true' -or           # Azure DevOps
        $env:GITLAB_CI -eq 'true' -or          # GitLab CI
        $env:CI -eq 'true' -or                 # Generic CI indicator
        $env:BUILD_ID -or                      # Jenkins
        $env:CIRCLECI -eq 'true'               # CircleCI
    )
    
    return $script:IsCICD
}

function ConvertTo-AnsiColorCode {
    <#
    .SYNOPSIS
    Converts PowerShell color name to ANSI escape sequence.
    .DESCRIPTION
    Converts standard PowerShell color names (e.g., 'Red', 'Green', 'Yellow') to ANSI escape codes for use in CI/CD environments.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ColorName,
        
        [Parameter(Mandatory = $false)]
        [switch]$IsBackground
    )
    
    # ANSI color codes
    $foregroundCodes = @{
        'Black'       = 30
        'DarkRed'     = 31
        'DarkGreen'   = 32
        'DarkYellow'  = 33
        'DarkBlue'    = 34
        'DarkMagenta' = 35
        'DarkCyan'    = 36
        'Gray'        = 37
        'DarkGray'    = 90
        'Red'         = 91
        'Green'       = 92
        'Yellow'      = 93
        'Blue'        = 94
        'Magenta'     = 95
        'Cyan'        = 96
        'White'       = 97
    }
    
    # Background codes are foreground + 10
    $backgroundCodes = @{
        'Black'       = 40
        'DarkRed'     = 41
        'DarkGreen'   = 42
        'DarkYellow'  = 43
        'DarkBlue'    = 44
        'DarkMagenta' = 45
        'DarkCyan'    = 46
        'Gray'        = 47
        'DarkGray'    = 100
        'Red'         = 101
        'Green'       = 102
        'Yellow'      = 103
        'Blue'        = 104
        'Magenta'     = 105
        'Cyan'        = 106
        'White'       = 107
    }
    
    $codes = if ($IsBackground) { $backgroundCodes } else { $foregroundCodes }
    $code = $codes[$ColorName]
    
    if ($code) {
        return $code
    }
    else {
        # Default to white for foreground, black for background
        return if ($IsBackground) { 40 } else { 97 }
    }
}

function Write-ColoredOutput {
    <#
    .SYNOPSIS
    Writes colored output that works in both interactive terminals and CI/CD pipelines.
    .DESCRIPTION
    Detects the environment and uses either Write-Host with -ForegroundColor (interactive)
    or ANSI escape sequences (CI/CD) to ensure colors render properly.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = 'White',
        
        [Parameter(Mandatory = $false)]
        [string]$BackgroundColor = '',
        
        [Parameter(Mandatory = $false)]
        [switch]$NoNewline
    )
    
    if (Test-CICDEnvironment) {
        # Use ANSI escape sequences for CI/CD
        $ansiReset = "`e[0m"
        $fgCode = ConvertTo-AnsiColorCode -ColorName $ForegroundColor
        $output = "`e[${fgCode}m$Message$ansiReset"
        
        if ($BackgroundColor -and $BackgroundColor -ne '') {
            $bgCode = ConvertTo-AnsiColorCode -ColorName $BackgroundColor -IsBackground
            $output = "`e[${fgCode};${bgCode}m$Message$ansiReset"
        }
        
        if ($NoNewline) {
            Write-Host $output -NoNewline
        }
        else {
            Write-Host $output
        }
    }
    else {
        # Use standard Write-Host with -ForegroundColor for interactive terminals
        $params = @{
            Object          = $Message
            ForegroundColor = $ForegroundColor
            NoNewline       = $NoNewline.IsPresent
        }
        
        if ($BackgroundColor -and $BackgroundColor -ne '') {
            $params['BackgroundColor'] = $BackgroundColor
        }
        
        Write-Host @params
    }
}

function Reset-OutputTheme {
    <#
    .SYNOPSIS
    Resets the cached theme to force reload from theme file.
    .DESCRIPTION
    Useful for testing theme changes without restarting PowerShell session.
    #>
    $script:LoadedTheme = $null
    $script:IsCICD = $null
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
    
    # Capture output for epacInfoStream
    $outputLines = @()
    $outputLines += ""
    
    Write-Host ""
    if ($headerChars.topLeft -and $headerChars.topRight) {
        $line1 = "$($headerChars.topLeft)$border$($headerChars.topRight)"
        $line2 = "$($headerChars.vertical)  $($Title.PadRight($maxLength))  $($headerChars.vertical)"
        $line4 = "$($headerChars.bottomLeft)$border$($headerChars.bottomRight)"
        
        Write-ColoredOutput -Message $line1 -ForegroundColor $headerColors.primary
        Write-ColoredOutput -Message $line2 -ForegroundColor $headerColors.primary
        $outputLines += $line1
        $outputLines += $line2
        
        if ($Subtitle) {
            $line3 = "$($headerChars.vertical)  $($Subtitle.PadRight($maxLength))  $($headerChars.vertical)"
            Write-ColoredOutput -Message $line3 -ForegroundColor $headerColors.secondary
            $outputLines += $line3
        }
        Write-ColoredOutput -Message $line4 -ForegroundColor $headerColors.primary
        $outputLines += $line4
    }
    else {
        # Screen reader mode - no box drawing
        Write-ColoredOutput -Message $Title -ForegroundColor $headerColors.primary
        $outputLines += $Title
        if ($Subtitle) {
            Write-ColoredOutput -Message $Subtitle -ForegroundColor $headerColors.secondary
            $outputLines += $Subtitle
        }
    }
    Write-Host ""
    $outputLines += ""
    
    # Append to global epacInfoStream
    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
        $Global:epacInfoStream += $outputLines
    }
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
    
    $line1 = "$prefix$($sectionChars.arrow) $Title"
    
    Write-Host ""
    Write-ColoredOutput -Message $line1 -ForegroundColor $sectionColor
    
    # Capture output for epacInfoStream
    $outputLines = @("", $line1)
    
    if ($sectionChars.underline) {
        $underline = $sectionChars.underline * ($Title.Length + 2)
        $line2 = "$prefix$underline"
        Write-ColoredOutput -Message $line2 -ForegroundColor $sectionColor
        $outputLines += $line2
    }
    
    # Append to global epacInfoStream
    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
        $Global:epacInfoStream += $outputLines
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
    
    $outputLine = "$prefix$statusChar $Message"
    
    # Check for background color support
    if ($backgroundColors -and $backgroundColors.$statusLower -and $backgroundColors.$statusLower -ne "") {
        $backgroundColor = $backgroundColors.$statusLower
        Write-ColoredOutput -Message $outputLine -ForegroundColor $statusColor -BackgroundColor $backgroundColor
    }
    else {
        Write-ColoredOutput -Message $outputLine -ForegroundColor $statusColor
    }
    
    # Append to global epacInfoStream
    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
        $Global:epacInfoStream += $outputLine
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
    
    # This function calls other Write-Modern* functions which will handle appending to epacInfoStream
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
    $outputLine = "$prefix$progressChar $progressText"
    
    Write-ColoredOutput -Message $outputLine -ForegroundColor $progressColor
    
    # Append to global epacInfoStream
    if (Get-Variable -Name epacInfoStream -Scope Global -ErrorAction SilentlyContinue) {
        $Global:epacInfoStream += $outputLine
    }
}