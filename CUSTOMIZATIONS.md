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

When windows are in `special:magic`, a count badge appears below the group letter. The fly-out lists those windows (`ClassName: Title`). Clicking toggles the special workspace.
**Files:**
- `modules/bar/components/WorkspaceName.qml` — bar component
- `modules/bar/popouts/WorkspaceInfo.qml` — fly-out content
- `services/WorkspaceNameConfig.qml` — configurable singleton (groups, labels, special workspace name)
**Optional config:** `~/.config/caelestia/workspacename.json` overrides defaults at runtime without touching QML:
```json
{
  "grouping": {
    "enabled": true,
    "groups":     [{"from": 1, "to": 3, "label": "W"}, {"from": 4, "to": 6, "label": "M"}, {"from": 7, "to": 9, "label": "P"}],
    "groupNames": [{"from": 1, "to": 3, "name": "Work (1–3)"},  {"from": 4, "to": 6, "name": "Music (4–6)"},  {"from": 7, "to": 9, "name": "Personal (7–9)"}]
  },
  "showIcon": true,
  "showSpecialCount": true,
  "specialWorkspace": "magic"
}

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

## Locking workflow
Session locking is handled by **Caelestia's built-in `WlSessionLock`** (in `modules/lock/Lock.qml`), not by a separate hyprlock process. All lock/unlock operations go through Quickshell IPC.
**`lock_cmd = qs ipc -p ~/.config/quickshell/caelestia/shell.qml call lock lock`**
Triggered by hypridle when the session should be locked. Calls Caelestia's IPC `lock` target directly. The `ext_session_lock_v1` protocol handles the case where the session is already locked — a second call is a no-op. No `pidof` guard needed and no zombie processes possible since there is no separate locker binary.
**`before_sleep_cmd`** uses the same IPC call — if the session was already locked by the idle timer this is a no-op, if not it locks before the system suspends.
**`after_sleep_cmd = ~/.config/hypr/scripts/resume-lock.sh`**
Also called by hypridle's `on-resume` for the 900 s display-off listener. Both paths can crash Caelestia: `wlopm --on` triggers a brief HDMI re-enumeration (even with direct HDMI, the monitors redo the handshake on power-up) which hits a Quickshell bug — `WlrLayershell::~WlrLayershell()` crashes in `ProxyWindowContentItem` when outputs are momentarily removed. Caelestia restarts via `Restart=on-failure`; `resume-lock.sh` polls `qs ipc call lock isLocked` in a loop (up to 15 s) until the IPC responds, then re-locks. A plain `systemctl is-active` check is insufficient — Quickshell uses a supervisor + rendering subprocess architecture; the supervisor never dies on a crash, so `is-active` passes immediately while the renderer is still mid-restart, causing the re-lock call to fail silently.
**Lock keybind** (`Super+Ctrl+L`) uses only `global caelestia:lock` — a duplicate `exec loginctl lock-session` bind on the same key sends two Lock signals per keypress, causing double invocations.
**`misc:allow_session_lock_restore = true`** — safety net for the brief window between Caelestia crashing and restarting: Hyprland shows a "locker died" info screen rather than an unlocked desktop. Caelestia re-creates lock surfaces when it restarts and `resume-lock.sh` re-locks via IPC.

Set in the `misc = { … }` block of `~/.config/hypr/hyprland.lua`. Confirm with `hyprctl getoption misc:allow_session_lock_restore` → `bool: true / set: true`.

> **History:** until 2026-08-07 this was documented here but never actually configured — the option was absent from the old `hyprland.conf` too, so it was never applied rather than dropped by the Lua migration. It reported `set: false` for as long as that note existed, leaving the crash window unprotected. Re-check the live value after Hyprland upgrades rather than trusting this paragraph.
**IPC syntax:**
```bash
# Lock
qs ipc -p ~/.config/quickshell/caelestia/shell.qml call lock lock
# Unlock (for scripting/TTY recovery)
qs ipc -p ~/.config/quickshell/caelestia/shell.qml call lock unlock
# Check state
qs ipc -p ~/.config/quickshell/caelestia/shell.qml call lock isLocked  # → true/false
```
---
## Restarting after changes

Caelestia runs as a systemd user service (`caelestia.service`) with `Restart=on-failure` so it
auto-recovers from crashes (e.g. the hyprlock/Wayland output-flap issue).

```bash
# Restart after config/code changes
systemctl --user restart caelestia.service

# Check status / recent logs
systemctl --user status caelestia.service
journalctl --user -u caelestia.service -f

# Stop permanently (won't auto-restart)
systemctl --user stop caelestia.service
```

Or use the Hyprland keybinding (`Super+Ctrl+Shift+Q` by default) — it restarts the process,
and systemd will bring it back up after the `RestartSec=2` delay.

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

### Components upstream may delete out from under us

Our custom files import shared components (e.g. `SwitchRow` from `qs.components.controls`).
Upstream occasionally removes a component it considers unused — but **a deletion is not a
merge conflict**, so it merges cleanly and only fails at load time with a fatal
`Type X is not a type` / `Type X unavailable` chain.

If that happens, restore the deleted file from history:
```bash
# Find the last commit that had it, then dump its contents back:
git log --all --oneline -- components/controls/SwitchRow.qml
git show <commit>^:components/controls/SwitchRow.qml > components/controls/SwitchRow.qml
```
Verify the restored file's token names still match the current API (`Tokens.padding.*`,
`Tokens.rounding.*`, etc.) before committing.

Known cases:
| Component | Deleted by | Used by our |
|---|---|---|
| `components/controls/SwitchRow.qml` | upstream PR #1625 ("remove unused components") | `modules/bar/popouts/KeepAwake.qml` |

### After a conflict-free merge

A plugin rebuild is needed if **either**:
- upstream (or you) changed `plugin/src/` C++ code, **or**
- the version bumped (`version.txt` / `git describe` shows a new `vX.Y.Z`) — new QML often
  references new C++ singletons. v2.1.0, for example, added `SessionManager`, which the
  installed 2.0.3 plugin lacked, producing `SessionManager is not defined` at runtime.

If neither applies, just restart Quickshell:
```bash
systemctl --user restart caelestia.service
```

### When a plugin rebuild is needed

```bash
cd ~/.config/quickshell/caelestia
# Configure with PREFIX=/ so output lands in /usr/lib/qt6/qml (where Qt searches).
# The cmake default prefix is /usr/local, which would install to /usr/local/usr/lib/...
# and be silently ignored — the plugin would appear "not rebuilt".
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build
systemctl --user restart caelestia.service
```

Confirm the new types registered, e.g.:
```bash
grep -c SessionManager /usr/lib/qt6/qml/Caelestia/Services/caelestia-services.qmltypes
```

> The system plugin files are owned by the `caelestia-shell` pacman package. The
> `sudo cmake --install` overwrites them in place. A later `pacman -Syu` that upgrades
> `caelestia-shell` will revert the plugin to the packaged version — if the shell breaks
> after a system update, re-run the rebuild above.

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

## GPU, sleep and power (HX99G-specific)
### Hardware
Two AMD GPUs in a hybrid graphics configuration:
- `0000:e8:00.0` — Ryzen iGPU (Raphael, drives Hyprland)
- `0000:03:00.0` — RX 6600 XT / DIMGREY_CAVEFISH (discrete, drives the three monitors)
Driver stack: `amdgpu` kernel module, Mesa 26.x, `vulkan-radeon` (RADV). No proprietary AMD drivers.
### S3 sleep and the GPU mode1 reset
The amdgpu driver performs a **mode1 reset** of the RX 6600 XT during the S3 suspend path. On wake, GPU-accelerated apps that hold an active GPU context (Brave, etc.) will normally crash if the GPU is reset multiple times in quick succession.
The root cause of repeated resets was **`suspend-then-hibernate`**: systemd 260 maps `systemctl suspend` to `suspend-then-hibernate` by default on systems with a configured swap/resume partition. Each S3 cycle triggered a GPU reset; if the reset caused the system to wake immediately (before hibernation), systemd would retry, causing a reset loop.
**Fixes applied:**
- `/etc/systemd/logind.conf.d/sleep-operation.conf` — `SleepOperation=suspend` forces plain S3, no retry loop
- `suspend-then-hibernate.target`, `hibernate.target`, `hybrid-sleep.target` masked via `systemctl mask`
- With a single clean S3 cycle, GPU-accelerated apps survive the wake (Brave tested successfully)
### Caelestia lock screen on S3 wake
Caelestia's `WlSessionLock` (backed by Quickshell / Qt Wayland) is significantly more resilient to the DP monitor re-enumeration that occurs on S3 wake than standalone hyprlock was:
- **hyprlock** held raw Wayland output object pointers; when outputs were removed/re-added it hit a null-pointer assertion and crashed
- **Caelestia** re-creates lock surfaces for each new output ID automatically; the `WlSessionLock` object itself survives sleep intact
A brief (~3s) "locker died" info screen from Hyprland appears while Caelestia creates surfaces for the new output IDs. This is a cosmetic issue caused by Hyprland showing its fallback screen during the ~3s window between the output being re-created and Caelestia providing a lock surface for it. The session content is never exposed during this window.
### hypridle configuration
See `~/.config/hypr/hypridle.conf`. Key timers:
- **150s** — dim brightness
- **600s** — lock screen (via `loginctl lock-session` → lock_cmd → Caelestia IPC)
- **900s** — DPMS off (`Super+F12` toggles manually)
- **1800s** — `systemctl suspend` (plain S3)
### Idle power consumption (baseline, no special amdgpu params)
- iGPU / CPU package: ~12 W
- RX 6600 XT idle (three monitors active): ~22 W
- Estimated total system: ~44–48 W
Note: `amdgpu.runpm=0 amdgpu.gfxoff=0` kernel params halve dGPU idle power (~11 W) but are not needed for stability since the suspend-then-hibernate loop was the real cause of GPU resets.
---

## Pushing to origin

```bash
git push origin custom-workspace-name
```
