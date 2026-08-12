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
(including **M3Shapes**) **only when** `plugin/`, `extras/`, or `CMakeLists.txt`
changed, and restarts the shell. It is idempotent — when nothing changed it does
nothing (no `sudo` prompt, no restart). The manual steps it automates are below.

> **Workflow across machines:** always run `./update` *before* you start editing on a
> machine, and `git push` when you finish. This avoids the divergence that requires a
> manual rebase to untangle.

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
#   drops M3Shapes (an afternoon lost to that once). An existing build/ keeps the
#   value in CMakeCache.txt, which is why omitting it sometimes "works".
# INSTALL_QSCONFDIR points the config install back at this repo.
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
      -DINSTALL_QSCONFDIR="$PWD" -DENABLE_MODULES="extras;plugin;shell;m3shapes"
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
