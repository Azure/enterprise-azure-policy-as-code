# Output Themes and Accessibility

## Overview

EPAC supports customizable output themes to improve accessibility and provide better user experience for people with visual impairments, color blindness, or those using screen readers. The theme system allows you to modify the appearance of command-line output including colors, characters, and formatting.

By default, EPAC uses a modern theme with colorful Unicode characters. You can override this by creating a `.epac/theme.json` configuration file in your repository root.

## Theme Configuration File

### Location and Setup

Create a theme configuration file at `.epac/theme.json` in your repository root directory:

```
your-epac-repo/
├── Definitions/
├── Scripts/
├── .epac/
│   └── theme.json    # ← Theme configuration file
└── ...
```

### Basic Configuration

The theme file structure follows this format:

```json
{
    "themeName": "default",
    "themes": {
        "theme-name": {
            "name": "Display Name",
            "description": "Theme description",
            "characters": { /* character definitions */ },
            "colors": { /* color definitions */ },
            "backgroundColors": { /* optional background colors */ }
        }
    }
}
```

### Example Configuration

Copy the following example to `.epac/theme.json` and customize as needed:

```json
{
    "themeName": "default",
    "themes": {
        "default": {
            "name": "Default Modern Theme",
            "description": "Standard colorful theme with Unicode characters",
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
        }
    }
}
```

## Built-in Accessibility Themes

EPAC includes three pre-configured themes optimized for different accessibility needs:

### Default Theme

The standard modern theme with colorful Unicode characters:

- **Use case**: Standard users with full color vision
- **Features**: Unicode symbols, box drawing, full color palette
- **Output example**:
  ```
  ┏━━━━━━━━━━━━━━━━━━━━━━━━┓
  ┃  Building Policy Plan  ┃
  ┗━━━━━━━━━━━━━━━━━━━━━━━━┛
  
  ▶ Processing Policies
  ━━━━━━━━━━━━━━━━━━━━━
  ✓ 5 policies processed successfully
  ⚠ 2 warnings found
  ```

### High Contrast Theme

Optimized for users with low vision or color blindness:

- **Use case**: Low vision, red-green color blindness
- **Features**: Text-based status indicators, background colors, high contrast
- **Benefits**: White text on colored backgrounds, avoids red-green combinations
- **Configuration**:
  ```json
  {
      "themeName": "high-contrast",
      "themes": { /* ... */ }
  }
  ```
- **Output example**:
  ```
  +------------------------+
  |  Building Policy Plan  |
  +------------------------+
  
  >> Processing Policies
  ======================
  [OK] 5 policies processed successfully    (white on green)
  [WARN] 2 warnings found                  (black on yellow)
  [ERROR] 1 error occurred                 (white on red)
  ```

### Screen Reader Theme

Optimized for screen reader users:

- **Use case**: Screen readers, text-to-speech software
- **Features**: Pure text output, no decorative characters, semantic labels
- **Benefits**: Clean text without Unicode, clear status descriptions
- **Configuration**:
  ```json
  {
      "themeName": "screen-reader",
      "themes": { /* ... */ }
  }
  ```
- **Output example**:
  ```
  Building Policy Plan
  
  SECTION: Processing Policies
  SUCCESS: 5 policies processed successfully
  WARNING: 2 warnings found
  ERROR: 1 error occurred
  ```

## Theme Customization

### Switching Themes

To use a different theme, modify the `themeName` in your `.epac/theme.json`:

```json
{
    "themeName": "high-contrast",
    "themes": {
        "default": { /* ... */ },
        "high-contrast": { /* ... */ },
        "screen-reader": { /* ... */ }
    }
}
```

### Creating Custom Themes

Add your own themes to the configuration:

```json
{
    "themeName": "my-custom-theme",
    "themes": {
        "my-custom-theme": {
            "name": "My Custom Theme",
            "description": "Personalized theme with preferred colors",
            "characters": {
                "status": {
                    "success": "✅",
                    "warning": "⚠️",
                    "error": "❌",
                    "info": "ℹ️"
                }
            },
            "colors": {
                "status": {
                    "success": "DarkGreen",
                    "warning": "DarkYellow",
                    "error": "DarkRed",
                    "info": "Gray"
                }
            }
        }
    }
}
```

### Modifying Existing Themes

Customize any aspect of the built-in themes:

```json
{
    "themeName": "default",
    "themes": {
        "default": {
            "colors": {
                "status": {
                    "success": "DarkGreen",    // Changed from "Green"
                    "warning": "DarkYellow",   // Changed from "Yellow"
                    "error": "DarkRed"         // Changed from "Red"
                }
            }
        }
    }
}
```

## Configuration Reference

### Theme Structure

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `themeName` | string | Yes | Name of the active theme |
| `themes` | object | Yes | Collection of theme definitions |

### Character Definitions

Configure display characters for different elements:

```json
"characters": {
    "header": {
        "topLeft": "┏",      // Top-left corner of header box
        "topRight": "┓",     // Top-right corner of header box
        "bottomLeft": "┗",   // Bottom-left corner of header box
        "bottomRight": "┛",  // Bottom-right corner of header box
        "horizontal": "━",   // Horizontal border line
        "vertical": "┃"      // Vertical border line
    },
    "section": {
        "arrow": "▶",        // Section header prefix
        "underline": "━"     // Section underline character
    },
    "status": {
        "success": "✓",      // Success indicator
        "warning": "⚠",      // Warning indicator
        "error": "✗",        // Error indicator
        "info": "•",         // Information indicator
        "skip": "⊘",         // Skip indicator
        "update": "⭮",       // Update indicator
        "processing": "🔄"   // Processing indicator
    }
}
```

### Color Definitions

Configure colors using PowerShell color names:

```json
"colors": {
    "header": {
        "primary": "Cyan",      // Main header color
        "secondary": "DarkCyan" // Subtitle color
    },
    "section": "Blue",          // Section header color
    "status": {
        "success": "Green",     // Success text color
        "warning": "Yellow",    // Warning text color
        "error": "Red",         // Error text color
        "info": "White",        // Information text color
        "skip": "DarkGray",     // Skip text color
        "update": "Cyan",       // Update text color
        "processing": "Yellow"  // Processing text color
    }
}
```

### Background Colors (Optional)

For high contrast themes, add background colors:

```json
"backgroundColors": {
    "status": {
        "success": "DarkGreen",   // Success background
        "warning": "DarkYellow",  // Warning background
        "error": "DarkRed",       // Error background
        "update": "DarkBlue"      // Update background
        // Leave empty string "" for no background
    }
}
```

### Supported Colors

PowerShell console colors supported:

- **Basic**: Black, White, Gray, DarkGray
- **Colors**: Red, DarkRed, Green, DarkGreen, Blue, DarkBlue
- **Extended**: Yellow, DarkYellow, Cyan, DarkCyan, Magenta, DarkMagenta