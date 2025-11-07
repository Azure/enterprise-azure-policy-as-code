# EPAC Output Theme System

EPAC now supports customizable output themes to improve accessibility and allow users to personalize their experience.

## Quick Start

### Using Default Theme (No Action Required)
If you don't create a theme file, EPAC will use the current colorful modern theme with Unicode characters.

### Creating a Custom Theme
1. Copy `Scripts/Helpers/theme-example.json` to `.epac/theme.json`
2. Edit the `themeName` field to select your preferred theme
3. Customize colors and characters as needed

## Available Themes

### `default`
- Colorful Unicode characters (✓, ⚠, ✗, etc.)
- Box drawing for headers
- Standard color scheme

### `high-contrast` 
- Text-based status indicators ([OK], [WARN], [ERROR])
- Simple ASCII borders
- White text on colored backgrounds for maximum contrast
- Avoids red-green color combinations (accessible for color blind users)
- Uses distinct background colors: Green for success, Yellow for warnings, Red for errors
- Better for low vision users and color blindness

### `screen-reader`
- No decorative characters
- Plain text status labels (SUCCESS:, WARNING:, ERROR:)
- No box drawing
- Optimized for screen readers

## Configuration

### Theme Selection
Edit `.epac/theme.json` and change the `themeName` value:

```json
{
  "themeName": "high-contrast",
  "themes": {
    ...
  }
}
```

### Custom Themes
You can create your own themes by adding them to the `themes` object:

```json
{
  "themeName": "my-theme",
  "themes": {
    "my-theme": {
      "name": "My Custom Theme",
      "characters": {
        "status": {
          "success": "✅",
          "warning": "⚠️",
          "error": "❌"
        }
      },
      "colors": {
        "status": {
          "success": "DarkGreen",
          "warning": "DarkYellow",
          "error": "DarkRed"
        }
      }
    }
  }
}
```

## Accessibility Features

- **Color Blind Friendly**: 
  - High contrast theme avoids red-green color combinations
  - Uses text-based indicators instead of just colors
  - Background colors provide additional differentiation beyond text color
- **Low Vision Support**: 
  - High contrast themes with background colors for maximum visibility
  - Simplified characters that are easier to distinguish
  - White text on dark backgrounds for optimal contrast ratios
- **Red-Green Color Blindness**: 
  - High contrast theme uses blue/yellow/white backgrounds instead of red/green
  - Text labels provide semantic meaning independent of color
  - Multiple visual cues (text, background, character) for each status type
- **Screen Reader Support**: Clean text output without decorative elements
- **Customizable**: Modify any aspect to meet your specific accessibility needs

## Examples

### Default Theme Output
```
┏━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  Building Policy Plan  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━┛

▶ Processing Policies
━━━━━━━━━━━━━━━━━━━━━
✓ 5 policies processed successfully
⚠ 2 warnings found
```

### High Contrast Theme Output
```
+------------------------+
|  Building Policy Plan  |
+------------------------+

>> Processing Policies
======================
[OK] 5 policies processed successfully    (white text on green background)
[WARN] 2 warnings found                  (black text on yellow background)
[ERROR] 1 error occurred                 (white text on red background)
```

### Screen Reader Theme Output
```
Building Policy Plan

SECTION: Processing Policies
SUCCESS: 5 policies processed successfully
WARNING: 2 warnings found
```

## Migration

Existing scripts will continue to work without modification. The theme system is opt-in and backwards compatible.