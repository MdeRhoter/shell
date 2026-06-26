# Caelestia Shell - Update Guide

> See **[CUSTOMIZATIONS.md](CUSTOMIZATIONS.md)** for the full reference including component docs,
> how the config system works, update workflow, and how to add new components.

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
