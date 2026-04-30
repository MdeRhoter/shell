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

**Component not showing after restart:**
The Caelestia Control Center may have a cached state. To fix:

1. Verify the entry exists in config:
   ```bash
   jq '.bar.entries[] | select(.id == "workspaceName")' ~/.config/caelestia/shell.json
   ```
   It should show: `{"enabled": true, "id": "workspaceName"}`

2. If missing, re-add it (adjust position as needed):
   ```bash
   jq '.bar.entries |= (.[0:2] + [{"id": "workspaceName", "enabled": true}] + .[2:])' ~/.config/caelestia/shell.json > /tmp/shell.json && mv /tmp/shell.json ~/.config/caelestia/shell.json
   ```

3. Force restart Caelestia:
   ```bash
   qs -c caelestia kill && sleep 0.5 && caelestia shell -d &
   ```

4. If still not showing, check logs:
   ```bash
   caelestia shell -l 2>&1 | grep -i "workspace\|error"
   ```

**Component not showing (initial):**
- Make sure `"enabled": true` is set in shell.json
- Check that shell.json is valid JSON (`jq . ~/.config/caelestia/shell.json`)
- Look for errors in `caelestia shell -l` logs
- Verify component is installed: `ls -la /etc/xdg/quickshell/caelestia/modules/bar/components/WorkspaceName.qml`

**Wrong workspace name:**
- The component reads from `Hypr.focusedWorkspace.name`
- Verify your Hyprland workspace configuration
- Named workspaces require explicit naming in hyprland.conf

**Styling issues:**
- The component follows Caelestia's Material 3 theme
- Check Tokens and Colours are available
- Rebuild if you modified the QML: `cmake --build build && sudo cmake --install build`

**Persistence after Control Center changes:**
If the component disappears after using Control Center settings:
- This was fixed by adding workspaceName to the C++ defaults in `barconfig.hpp`
- If you're using an older build, rebuild with: `cd ~/.config/quickshell/caelestia && cmake --build build && sudo cmake --install build`
- The component should now persist through Control Center changes
