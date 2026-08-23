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

**`session.commands.logout` must exit the compositor, not terminate the logind session.**
Keep it as `["hyprctl", "dispatch", "hl.dsp.exit()"]` in `~/.config/caelestia/shell.json`.

> ⚠️ **Do not "simplify" this to Caelestia's built-in `logout` token** (or `loginctl
> terminate-session`, or `SessionManager.logout()`). Those call
> `org.freedesktop.login1.Session.Terminate`, which SIGTERMs every process in
> `session-N.scope` — and under SDDM the **session leader in that scope is `sddm-helper`
> itself** (`loginctl show-session` → `Leader=975`, pid 975 = `sddm-helper`). Killing it
> makes SDDM log
>
> ```
> Auth: sddm-helper (--start /usr/bin/start-hyprland --user martijn) crashed (exit code 1)
> Authentication error: SDDM::Auth::ERROR_INTERNAL "Process crashed"
> ```
>
> classify the logout as a crash, and never run its show-the-greeter path. Its original Xorg
> stays up on vt2 with `-noreset -background none`, so you get **a bare cursor on a black
> screen and no login prompt**. Recovery: switch to a TTY (`Ctrl+Alt+F3`) and
> `sudo systemctl restart sddm`. Confirmed the hard way on 2026-08-07.
>
> Exiting the compositor instead unwinds the way SDDM expects: Hyprland exits →
> `start-hyprland` exits → `wayland-session` exits → `sddm-helper` exits 0 → greeter returns.
>
> Note the dispatcher syntax matters too: bare `hyprctl dispatch exit` is rejected since
> Hyprland 0.56 and fails *silently* when run detached. See `~/.config/hypr/POST_UPGRADE.md`.
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

## Sleep and power (Surface Laptop-specific)

> The section above is **HX99G only**. This machine is a Microsoft Surface Laptop: Intel Kaby Lake (i915, device ID 5916), a single eDP panel, `intel_backlight` with `max_brightness = 7500`. Config comments that migrated from the HX99G do not describe this hardware — the dim rule here carried the comment "avoid 0 on OLED monitor" for a panel that is not OLED.

### The black-screen-after-idle bug (fixed 2026-08-23)
Symptom: the screen goes dark after idle or suspend and "refuses to come back"; the only apparent recovery is the power button, which produces a clean shutdown.
The machine **never failed to wake**. Every incident shows the kernel reaching `PM: suspend exit`, wifi reassociating and the IPTS touchscreen re-enumerating, followed 12–35 s later by:
```
systemd-logind: Power key pressed short.
systemd-logind: Powering off...
```
`HandlePowerKey=poweroff` was doing exactly its job — which is why the clean shutdown masked the real fault. Three stacked causes:
1. **`brightnessctl -s set 10` was missing its `%`.** brightnessctl treats a bare number as a RAW value; raw 10 of max 7500 is **0.13%**, indistinguishable from a dead panel. (`hyprland.lua` gets this right with `set 40%`.)
2. **`after_sleep_cmd` restored DPMS but not brightness**, and hypridle's `on-resume` handlers do not fire on every resume path. Confirmed miss on a hibernate rollback: `dpms("on")` ran, `brightnessctl -r` never did.
3. **`brightnessctl -s` poisons its own save file.** `-s` overwrites the saved value with whatever is current, so one missed restore leaves the panel dim and the *next* `-s` saves that dim value. Every later `-r` then faithfully restores an invisible screen, surviving further suspends until logout. This is the state that "refuses to come back".

**Fixes applied:**
- `~/.config/hypr/hypridle.conf` — `set 10` → `set 10%`; the `rgb:kbd_backlight` listener removed (no such device here; it logged `Device 'rgb:kbd_backlight' not found.` every cycle)
- `~/.config/hypr/scripts/restore-brightness.sh` — restores the saved value, then floors it at 10% of `max_brightness` so a poisoned save file can never yield an invisible screen. Wired into `after_sleep_cmd` **and** the dim listener's `on-resume`
- `/etc/systemd/logind.conf.d/sleep-operation.conf` — `SleepOperation=suspend`, same as the HX99G. systemd 261 otherwise prefers suspend-then-hibernate, and hibernation is unreliable here (`PM: hibernation: Wakeup event detected during hibernation, rolling back`) — that rollback is one of the paths that skipped the restore
- Unlike the HX99G, the hibernate targets are **deliberately left unmasked**, so `modules/BatteryMonitor.qml`'s critical-battery `SessionManager.hibernate()` still works

**Recovery if it ever recurs:** tap brightness-up, not the power button. `XF86MonBrightnessUp` is bound with `locked = true`, so it reaches the compositor on the lock screen and writes an absolute value that re-latches the panel.

### Two idle stacks were racing
hypridle and Caelestia's own `modules/IdleMonitors.qml` were each running a complete idle stack. They fired ~150 ms apart on every cycle:
```
11:47:59.236  suspend requested from client PID 44340 ('systemctl')      <- hypridle
11:47:59.409  suspend-then-hibernate requested from PID 1198 ('qs')      <- caelestia
12:08:19.421  Call to Suspend failed: Action suspend-then-hibernate already in progress
```
hypridle is now the single owner: `"general": { "idle": { "timeouts": [] } }` in `~/.config/caelestia/shell.json` disables Caelestia's. `lockBeforeSleep` stays `true` — it is idempotent and harmless alongside hypridle's `before_sleep_cmd`. If you ever flip ownership, empty the listeners in `hypridle.conf` instead of re-adding both.

### hypridle timers (this machine)
Not the HX99G's 150/600/900/1800. See `~/.config/hypr/hypridle.conf`:
- **150s** — dim to 10%
- **300s** — lock screen (via `loginctl lock-session` → `lock_cmd` → Caelestia IPC)
- **330s** — DPMS off
- **600s** — `systemctl suspend` (plain S3, pinned by the logind drop-in)

---

## Pushing to origin

```bash
git push origin custom-workspace-name
```
