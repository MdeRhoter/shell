# Caelestia Shell - Update Guide

> See **[CUSTOMIZATIONS.md](CUSTOMIZATIONS.md)** for the full reference including component docs,
> how the config system works, update workflow, and how to add new components.

## Syncing a machine

To pull the latest from the fork and apply it, just run:

```bash
cd ~/.config/quickshell/caelestia
./update
```

`./update` rebases onto `origin/<branch>`, rebuilds + reinstalls the native plugin
**only when** `plugin/`, `extras/`, or `CMakeLists.txt`
changed, and restarts the shell. It is idempotent — when nothing changed it does
nothing (no `sudo` prompt, no restart). The manual steps it automates are below.

> **Workflow across machines:** always run `./update` *before* you start editing on a
> machine, and `git push` when you finish. This avoids the divergence that requires a
> manual rebase to untangle.

## Getting told when an update is due

You do not have to remember to run `./update` — `caelestia-update-check.timer` does the
remembering. `./update` installs and enables it (and the check script into
`~/.local/bin/`) as part of its vendored-system-files step, so both machines get it.

It fires 5 min after login and once a day thereafter, and sends a desktop notification
when any of the three ways this setup goes stale has happened:

| It notices | It tells you to run |
|---|---|
| the installed plugin was not built from your HEAD (typically a `pacman -Syu` clobber) | `./update` |
| the other machine pushed to `origin/<branch>` | `./update` |
| upstream Caelestia cut a new release tag | `./update --port` |
| local and `origin` have both moved | reconcile by hand |

**It only ever reports — it never applies anything.** That is deliberate and not a
limitation to "fix" later: `./update` needs `sudo` for `cmake --install` (a timer has no
tty, and a NOPASSWD rule for it would be passwordless root, since `build/` is
user-writable) and it restarts the shell out from under you; `./update --port` stops for
manual conflict resolution by design. So the apply half stays a decision you make.

It will not nag. A notification fires when the *set* of pending items changes, and an
unchanged set is re-raised only weekly — so a port you are not ready for does not produce
the same popup every morning until you mute it. Override with
`CAELESTIA_UPDATE_RENAG_DAYS`.

```bash
caelestia-update-check -v        # run it now, print everything, ignore the nag stamp
systemctl --user list-timers caelestia-update-check.timer
journalctl --user -t caelestia-update    # history, including the runs that found nothing
```

## M3Shapes is no longer ours to build (changed in v2.4.0)

Upstream v2.4.0 (#1909, "build: split out m3shapes") moved M3Shapes into its own
project, [soramanew/m3shapes](https://github.com/soramanew/m3shapes), packaged on Arch as
**`qt6-m3shapes-git`** and a hard dependency of `caelestia-shell` >= 2.4.0.

Our QML still does `import M3Shapes` in about a dozen files — including the forked
`modules/bar/components/workspaces/Workspace.qml` — so **it is still required at runtime**.
What changed is only who installs it. `CMakeLists.txt` has no `m3shapes` branch any more,
and CMake accepts unknown entries in `ENABLE_MODULES` **in silence**, so passing
`m3shapes` there is a flag that looks load-bearing and does nothing. Do not re-add it.

If M3Shapes is missing the shell dies with `Type ... unavailable` across every file that
imports it. `./update` warns and points at the fix; a rebuild cannot supply it:

```bash
yay -S qt6-m3shapes-git
```

> **On a machine still running `caelestia-shell` 2.3.0-1:** the M3Shapes files under
> `/usr/lib/qt6/qml/M3Shapes/` are owned by *that package* (`pacman -Qo` confirms it) and
> are all that is keeping the shell alive — they are from 2.3.0 and nothing refreshes them.
> Upgrading the package to 2.4.0-1 removes them and pulls in `qt6-m3shapes-git` as a
> dependency, which is the intended end state.

## Quick reference

### Check for upstream updates
```bash
cd ~/.config/quickshell/caelestia
git fetch upstream
git log HEAD..upstream/main --oneline
```

### Merge upstream into custom branch
```bash
git merge upstream/main
# Resolve any conflicts in Bar.qml, Content.qml, barconfig.hpp, then:
git add . && git commit
```

> ⚠️ **After any version bump (vX.Y.Z changes), rebuild the plugin too** — not just
> when `plugin/src/` shows merge conflicts. New QML routinely references new C++ types
> (e.g. v2.1.0 added the `SessionManager` singleton). Skipping the rebuild gives runtime
> errors like `SomeType is not defined`. Check the bump with `cat version.txt`.

> ⚠️ **Upstream sometimes deletes components our custom files still use.** A fatal
> `Type X is not a type` / `Type X unavailable` after a merge usually means upstream
> removed `components/.../X.qml` that one of our custom files imports. Restore the file
> from history: `git show <last-commit-that-had-it>^:path/to/X.qml`. (This happened with
> `components/controls/SwitchRow.qml`, deleted upstream but used by our `KeepAwake.qml`.)

### Restart shell after QML changes
```bash
systemctl --user restart caelestia.service
# Then check it loaded clean:
journalctl --user -u caelestia.service -n 30 --no-pager | grep -iE "ERROR|Configuration Loaded"
```

### Rebuild plugin (after any version bump, or if plugin/src/ changed)

**Prefer `./update`** (or `./update --force-build`) — it passes the flags below correctly
and restores `shell.qml` afterwards. Only drop to raw cmake if you are debugging the build
itself, and then use the full flag set:

```bash
# PREFIX=/ so files land in /usr/lib/qt6/qml (where Qt looks), not the cmake
#   default /usr/local/usr/lib/... where they are silently ignored.
# ENABLE_MODULES must be spelled out: omitting it on a FRESH build dir silently
#   drops modules (an afternoon lost to that once). An existing build/ keeps the
#   value in CMakeCache.txt, which is why omitting it sometimes "works".
#   Do NOT add "m3shapes" here -- see the M3Shapes note below.
# INSTALL_QSCONFDIR points the config install back at this repo.
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
      -DINSTALL_QSCONFDIR="$PWD" -DENABLE_MODULES="extras;plugin;shell"
cmake --build build
sudo cmake --install build
# The install re-emits shell.qml onto the source as a ROOT-OWNED, watchFiles:false
# copy, clobbering the dev version. ./update undoes this automatically; by hand:
[ "$(stat -c %U shell.qml)" = root ] && rm shell.qml && git checkout -- shell.qml
systemctl --user restart caelestia.service
```

> Note: the system plugin is owned by the `caelestia-shell` pacman package. The install
> above overwrites those files, so a future `pacman -Syu` that upgrades `caelestia-shell`
> will revert the plugin. **`./update` now detects this automatically** by comparing the
> revision baked into `/usr/lib/caelestia/version` against `HEAD`, and rebuilds — the old
> git-diff-only check could not see a package-side clobber and would skip the rebuild.
> `./update --status` shows the comparison without changing anything.

### Push to fork
```bash
git push origin custom-workspace-name
```
