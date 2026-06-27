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

### Restart shell after QML changes
```bash
pkill -f "qs.*caelestia" && qs -p ~/.config/quickshell/caelestia/shell.qml &
```

### Rebuild plugin (only if C++ plugin/src/ changed)
```bash
cmake --build build && sudo cmake --install build
```

### Push to fork
```bash
git push origin custom-workspace-name
```
