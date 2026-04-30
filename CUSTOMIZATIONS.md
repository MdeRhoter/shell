# Caelestia Shell — Custom Fork Reference

## Overview

This is a personal fork of [caelestia-dots/shell](https://github.com/caelestia-dots/shell) with custom bar components.

| Item | Value |
|---|---|
| Fork | https://github.com/MdeRhoter/shell |
| Upstream | https://github.com/caelestia-dots/shell |
| Local path | `~/.config/quickshell/caelestia` |
| Working branch | `custom-workspace-name` |

The shell is started via a Hyprland keybinding that explicitly uses the local fork:
```
qs -p ~/.config/quickshell/caelestia/shell.qml
```

---

## How the configuration system works

Bar entries are driven by **`~/.config/caelestia/shell.json`** (`bar.entries`), not by the C++ defaults in `plugin/src/Caelestia/Config/barconfig.hpp`. When `shell.json` has an `entries` array, it fully replaces the C++ defaults. This means:

- Adding a new bar entry only requires editing `shell.json` — no plugin rebuild needed.
- `barconfig.hpp` is kept in sync as documentation and for fresh installs (before the user saves from Control Center), but has no effect on a machine where `shell.json` already defines entries.
- New QML files (services, components, popouts) are picked up automatically by Quickshell's file watcher (`settings.watchFiles: true`). A plugin rebuild is **only** needed when changing C++ config types (i.e. `barconfig.hpp`).

---

## Custom bar components

Both components follow the same integration pattern as upstream bar components:
1. A `services/` singleton provides data.
2. A `modules/bar/components/` file renders the bar pill.
3. A `modules/bar/popouts/` file renders the fly-out shown on hover.
4. `modules/bar/Bar.qml` routes hover events (`checkPopout`) and declares a `DelegateChoice`.
5. `modules/bar/popouts/Content.qml` registers the named `Popout`.
6. `shell.json` and `barconfig.hpp` both list the entry ID.

### WorkspaceName

Shows the active workspace **group** (W / M / P) based on waybar-style grouping:

| Letter | Workspaces |
|---|---|
| W | 1–3 (Work) |
| M | 4–6 (Music) |
| P | 7–9 (Personal) |

When windows are in `special:magic`, a count badge appears below the group letter. The fly-out lists those windows (`ClassName: Title`). Clicking toggles the `special:magic` workspace.

**Files:**
- `modules/bar/components/WorkspaceName.qml` — bar component
- `modules/bar/popouts/WorkspaceInfo.qml` — fly-out content

**Data source:** `Quickshell.Hyprland` (Hypr service, no custom singleton needed)

---

### PendingUpdates

Shows a `system_update` icon (highlighted when updates are available) with the pending package count below. The fly-out lists each package as `name  oldVer → newVer`. Clicking launches `garuda-update` in the configured terminal.

**Files:**
- `services/Updates.qml` — singleton; runs `checkupdates` on startup and every hour
- `modules/bar/components/PendingUpdates.qml` — bar component
- `modules/bar/popouts/UpdatesInfo.qml` — fly-out content

**Dependencies:** `checkupdates` from `pacman-contrib` (already installed on Garuda)

**Click action:**
```qml
Quickshell.execDetached([...GlobalConfig.general.apps.terminal, "-e", "garuda-update"])
```
Uses the terminal configured in `shell.json` → `general.apps.terminal` (currently `footclient`).

---

## Bar entry order (shell.json)

```
logo → workspaces → workspaceName → pendingUpdates → spacer →
activeWindow → spacer → tray → clock → statusIcons → power
```

---

## Restarting after changes

For any QML change, restart Quickshell:
```bash
pkill -f "qs.*caelestia" && qs -p ~/.config/quickshell/caelestia/shell.qml &
```
Or use the Hyprland keybinding (`Super+Ctrl+Shift+Q` by default).

Quickshell's `watchFiles: true` means many edits hot-reload automatically without a full restart.

---

## Updating from upstream

```bash
cd ~/.config/quickshell/caelestia

# Fetch upstream changes
git fetch upstream

# Preview what changed
git log HEAD..upstream/main --oneline

# Merge into custom branch
git merge upstream/main
```

### Likely conflict files

These files were modified locally and are the most likely sources of merge conflicts:

| File | What we changed |
|---|---|
| `modules/bar/Bar.qml` | Added `DelegateChoice` entries and `checkPopout` cases |
| `modules/bar/popouts/Content.qml` | Added `Popout` registrations |
| `plugin/src/Caelestia/Config/barconfig.hpp` | Added entries to C++ defaults |

### After a conflict-free merge

No rebuild is needed unless upstream changed C++ files. Restart Quickshell:
```bash
pkill -f "qs.*caelestia" && qs -p ~/.config/quickshell/caelestia/shell.qml &
```

### When a plugin rebuild is needed

Only required if upstream (or you) changed `plugin/src/` C++ code:
```bash
cd ~/.config/quickshell/caelestia
cmake --build build
sudo cmake --install build
```

---

## Adding a new bar component

1. Create `services/MyService.qml` (if data polling is needed):
   - `pragma Singleton` + `import Quickshell.Io`
   - Use `Process` + `StdioCollector` for shell commands
   - Use a `Timer` for periodic refresh

2. Create `modules/bar/components/MyComponent.qml`:
   - Extend `StyledRect`, set `implicitWidth: Tokens.sizes.bar.innerWidth`
   - Use `Colours.palette.m3*` for colours
   - `MouseArea` for click; hover is handled by `Bar.qml`'s `checkPopout`

3. Create `modules/bar/popouts/MyPopout.qml`:
   - Use `ColumnLayout` with `StyledText` rows
   - Access your service singleton directly (it's a global via `import qs.services`)

4. Register in `modules/bar/popouts/Content.qml`:
   ```qml
   Popout {
       name: "myComponent"
       sourceComponent: MyPopout {}
   }
   ```

5. Add `DelegateChoice` and `checkPopout` case in `modules/bar/Bar.qml` (follow the `workspaceName` pattern).

6. Add to `shell.json` entries and `barconfig.hpp` defaults.

---

## Pushing to origin

```bash
git push origin custom-workspace-name
```
