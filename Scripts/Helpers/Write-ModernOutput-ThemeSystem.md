# EPAC Modern Output Theme System Design

## Overview
A comprehensive theme system to make EPAC output accessible for users with low vision, color blindness, or other visual accessibility needs.

## Proposed Implementation

### 1. Theme Configuration File Structure

```jsonc
// Scripts/Helpers/output-themes.jsonc
{
  "themes": {
    "default": {
      "name": "Default Modern Theme",
      "description": "Standard colorful theme with Unicode characters",
      "accessibility": {
        "colorBlindFriendly": false,
        "highContrast": false,
        "screenReaderOptimized": false
      },
      "characters": {
        "header": {
          "topLeft": "┏",
          "topRight": "┓", 
          "bottomLeft": "┗",
          "bottomRight": "┛",
          "horizontal": "━",
          "vertical": "┃"
        },
        "section": {
          "arrow": "▶",
          "underline": "━"
        },
        "status": {
          "success": "✓",
          "warning": "⚠",
          "error": "✗", 
          "info": "•",
          "skip": "⊘",
          "update": "⭮",
          "processing": "🔄"
        }
      },
      "colors": {
        "header": {
          "primary": "Cyan",
          "secondary": "DarkCyan"
        },
        "section": "Blue",
        "status": {
          "success": "Green",
          "warning": "Yellow", 
          "error": "Red",
          "info": "White",
          "skip": "DarkGray",
          "update": "Cyan",
          "processing": "Yellow"
        }
      }
    },
    "high-contrast": {
      "name": "High Contrast Theme",
      "description": "High contrast theme for low vision users",
      "accessibility": {
        "colorBlindFriendly": true,
        "highContrast": true,
        "screenReaderOptimized": false
      },
      "characters": {
        "header": {
          "topLeft": "+",
          "topRight": "+",
          "bottomLeft": "+", 
          "bottomRight": "+",
          "horizontal": "-",
          "vertical": "|"
        },
        "section": {
          "arrow": ">>",
          "underline": "="
        },
        "status": {
          "success": "[OK]",
          "warning": "[WARN]",
          "error": "[ERROR]",
          "info": "[INFO]",
          "skip": "[SKIP]",
          "update": "[UPDATE]", 
          "processing": "[PROC]"
        }
      },
      "colors": {
        "header": {
          "primary": "White",
          "secondary": "Gray"
        },
        "section": "White",
        "status": {
          "success": "White",
          "warning": "Black",
          "error": "White", 
          "info": "Gray",
          "skip": "DarkGray",
          "update": "White",
          "processing": "Gray"
        }
      },
      "background": {
        "success": "DarkGreen",
        "warning": "DarkYellow",
        "error": "DarkRed"
      }
    },
    "monochrome": {
      "name": "Monochrome Theme", 
      "description": "Black and white theme for color blind users",
      "accessibility": {
        "colorBlindFriendly": true,
        "highContrast": false,
        "screenReaderOptimized": false
      },
      "characters": {
        "header": {
          "topLeft": "+",
          "topRight": "+",
          "bottomLeft": "+",
          "bottomRight": "+", 
          "horizontal": "-",
          "vertical": "|"
        },
        "section": {
          "arrow": ">>",
          "underline": "-"
        },
        "status": {
          "success": "[SUCCESS]",
          "warning": "[WARNING]", 
          "error": "[ERROR]",
          "info": "[INFO]",
          "skip": "[SKIPPED]",
          "update": "[UPDATED]",
          "processing": "[PROCESSING]"
        }
      },
      "colors": {
        "header": {
          "primary": "White",
          "secondary": "Gray"
        },
        "section": "White", 
        "status": {
          "success": "White",
          "warning": "White",
          "error": "White",
          "info": "Gray", 
          "skip": "DarkGray",
          "update": "White",
          "processing": "Gray"
        }
      }
    },
    "screen-reader": {
      "name": "Screen Reader Optimized",
      "description": "Text-only theme optimized for screen readers",
      "accessibility": {
        "colorBlindFriendly": true,
        "highContrast": true,
        "screenReaderOptimized": true
      },
      "characters": {
        "header": {
          "topLeft": "",
          "topRight": "",
          "bottomLeft": "",
          "bottomRight": "",
          "horizontal": "",
          "vertical": ""
        },
        "section": {
          "arrow": "SECTION:",
          "underline": ""
        },
        "status": {
          "success": "SUCCESS:",
          "warning": "WARNING:",
          "error": "ERROR:", 
          "info": "INFO:",
          "skip": "SKIPPED:",
          "update": "UPDATED:",
          "processing": "PROCESSING:"
        }
      },
      "colors": {
        "header": {
          "primary": "White",
          "secondary": "White"
        },
        "section": "White",
        "status": {
          "success": "White",
          "warning": "White", 
          "error": "White",
          "info": "White",
          "skip": "White", 
          "update": "White",
          "processing": "White"
        }
      }
    }
  },
  "settings": {
    "defaultTheme": "default",
    "enableThemeDetection": true,
    "fallbackToBasic": true
  }
}
```

### 2. Updated Write-ModernOutput.ps1 with Theme Support

Key changes needed:

1. **Theme Loading Function**
```powershell
function Get-OutputTheme {
    param([string]$ThemeName = $null)
    
    # Check environment variable first
    if (!$ThemeName) {
        $ThemeName = $env:EPAC_OUTPUT_THEME
    }
    
    # Check global settings
    if (!$ThemeName) {
        $globalSettings = Get-GlobalSettings -DefinitionsRootFolder $DefinitionsRootFolder -ErrorAction SilentlyContinue
        $ThemeName = $globalSettings.outputTheme
    }
    
    # Auto-detect accessibility needs
    if (!$ThemeName -and $env:EPAC_AUTO_DETECT_THEME) {
        $ThemeName = Get-AutoDetectedTheme
    }
    
    # Default fallback
    if (!$ThemeName) {
        $ThemeName = "default"
    }
    
    return Load-ThemeConfiguration -ThemeName $ThemeName
}

function Get-AutoDetectedTheme {
    # Detect Windows high contrast mode
    if ((Get-ItemProperty -Path "HKCU:\Control Panel\Accessibility\HighContrast" -Name "Flags" -ErrorAction SilentlyContinue).Flags -band 1) {
        return "high-contrast"
    }
    
    # Check for screen reader indicators
    if ($env:NVDA -or $env:JAWS -or $env:NARRATOR) {
        return "screen-reader"
    }
    
    return "default"
}
```

2. **Enhanced Status Functions**
```powershell
function Write-ModernStatus {
    param(
        [string]$Message,
        [string]$Status = "Info", 
        [int]$Indent = 0,
        [object]$Theme = $null
    )
    
    if (!$Theme) {
        $Theme = Get-OutputTheme
    }
    
    $prefix = " " * $Indent
    $statusChar = $Theme.characters.status.$Status.ToLower()
    $color = $Theme.colors.status.$Status.ToLower()
    
    # Handle background colors for high contrast
    if ($Theme.background -and $Theme.background.$Status.ToLower()) {
        $bgColor = $Theme.background.$Status.ToLower()
        Write-Host "$prefix$statusChar $Message" -ForegroundColor $color -BackgroundColor $bgColor
    } else {
        Write-Host "$prefix$statusChar $Message" -ForegroundColor $color
    }
}
```

### 3. Configuration Integration

Add theme support to global-settings.jsonc:

```jsonc
{
  "outputTheme": "default", // or "high-contrast", "monochrome", "screen-reader"
  "accessibility": {
    "autoDetectTheme": true,
    "verboseScreenReader": false,
    "enableProgressAnnouncements": true
  }
}
```

### 4. Environment Variable Support

Users could set:
```powershell
$env:EPAC_OUTPUT_THEME = "high-contrast"
$env:EPAC_AUTO_DETECT_THEME = "true"
$env:EPAC_VERBOSE_OUTPUT = "true"  # For screen readers
```

### 5. Benefits for Accessibility

1. **Color Blindness Support**:
   - Monochrome theme eliminates color dependency
   - High contrast uses distinct text patterns
   - Clear textual status indicators

2. **Low Vision Support**:
   - High contrast theme with background colors
   - Larger, clearer status indicators
   - Simplified border characters

3. **Screen Reader Optimization**:
   - Text-only status indicators
   - No decorative Unicode characters
   - Clear semantic labeling
   - Optional verbose announcements

4. **Motor Impairment Consideration**:
   - Consistent indentation patterns
   - Predictable layout structure

### 6. Implementation Phases

**Phase 1**: Basic theme loading and character/color substitution
**Phase 2**: Auto-detection of accessibility settings  
**Phase 3**: Integration with global settings
**Phase 4**: Advanced features (screen reader optimization, verbose mode)

### 7. Backward Compatibility

- Default theme maintains current appearance
- Existing scripts work without modification
- Progressive enhancement approach
- Graceful fallbacks for missing theme files

This system would provide comprehensive accessibility support while maintaining the modern appearance for users who can benefit from it.