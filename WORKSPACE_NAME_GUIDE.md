# WorkspaceName Component Usage Guide

## Overview

The `WorkspaceName` component displays the currently active workspace name on the Caelestia bar, similar to how waybar showed workspace names.

## Features

- **Numbered workspaces**: Displays just the number (e.g., "1", "2", "3")
- **Named workspaces**: Displays the full name
- **Special workspaces**: Displays the name without the "special:" prefix
- **Animated transitions**: Smooth height animations when workspace changes
- **Consistent styling**: Matches other bar components like Clock

## Configuration

To enable the WorkspaceName component in your bar, edit `~/.config/caelestia/shell.json` and add it to the bar entries:

```json
{
    "bar": {
        "entries": [
            {"id": "logo", "enabled": true},
            {"id": "workspaces", "enabled": true},
            {"id": "workspaceName", "enabled": true},
            {"id": "spacer", "enabled": true},
            {"id": "activeWindow", "enabled": true},
            {"id": "spacer", "enabled": true},
            {"id": "tray", "enabled": true},
            {"id": "clock", "enabled": true},
            {"id": "statusIcons", "enabled": true},
            {"id": "power", "enabled": true}
        ]
    }
}
```

### Example Configurations

#### Minimal setup (just after workspaces)
```json
{
    "bar": {
        "entries": [
            {"id": "workspaces", "enabled": true},
            {"id": "workspaceName", "enabled": true},
            {"id": "spacer", "enabled": true}
        ]
    }
}
```

#### Between workspaces and active window
```json
{
    "bar": {
        "entries": [
            {"id": "workspaces", "enabled": true},
            {"id": "workspaceName", "enabled": true},
            {"id": "activeWindow", "enabled": true}
        ]
    }
}
```

## Styling

The component uses:
- **Color**: `m3secondary` from the Material 3 color palette
- **Icon**: "workspaces" Material icon
- **Font**: System sans font at small size
- **Background**: Rounded rectangle with surface container color

## Customization

To customize the component, edit `modules/bar/components/WorkspaceName.qml`:

### Change the color
```qml
readonly property color colour: Colours.palette.m3primary  // or m3tertiary, etc.
```

### Change the icon
```qml
MaterialIcon {
    text: "desktop_windows"  // or any other Material icon
    // ...
}
```

### Adjust font size
```qml
StyledText {
    font.pointSize: Tokens.font.size.smaller  // or .normal, .large
    // ...
}
```

## Testing

After adding the component to your configuration:

1. Reload Caelestia shell:
   ```bash
   killall quickshell
   caelestia shell -d
   ```

2. Switch between workspaces to see the name update
3. Try special workspaces to verify the "special:" prefix is removed

## Troubleshooting

**Component not showing:**
- Make sure `"enabled": true` is set in shell.json
- Check that shell.json is valid JSON
- Look for errors in `caelestia shell -l` logs

**Wrong workspace name:**
- The component reads from `Hypr.focusedWorkspace.name`
- Verify your Hyprland workspace configuration
- Named workspaces require explicit naming in hyprland.conf

**Styling issues:**
- The component follows Caelestia's Material 3 theme
- Check Tokens and Colours are available
- Rebuild if you modified the QML: `cmake --build build && sudo cmake --install build`
