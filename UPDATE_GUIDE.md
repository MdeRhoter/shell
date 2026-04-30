# Caelestia Shell - Custom Fork Update Guide

This is your personal fork of caelestia-shell with custom modifications.

## Setup Summary
- **Your Fork**: https://github.com/MdeRhoter/shell
- **Upstream**: https://github.com/caelestia-dots/shell
- **Custom Branch**: `custom-workspace-name`
- **Local Path**: `~/.config/quickshell/caelestia`

## Making Custom Changes

1. Make your modifications to QML/code files
2. Commit your changes:
   ```bash
   cd ~/.config/quickshell/caelestia
   git add .
   git commit -m "Description of your changes"
   ```
3. Push to your fork (optional, for backup):
   ```bash
   git push origin custom-workspace-name
   ```

## Updating from Upstream

When new Caelestia updates are released:

```bash
cd ~/.config/quickshell/caelestia

# Fetch latest changes from upstream
git fetch upstream

# Merge upstream changes into your custom branch
git merge upstream/main

# If there are conflicts, resolve them, then:
# git add <resolved-files>
# git commit

# Rebuild and reinstall
cmake --build build
sudo cmake --install build

# Restart Caelestia shell
```

## Quick Commands

### Check for updates
```bash
cd ~/.config/quickshell/caelestia
git fetch upstream
git log HEAD..upstream/main --oneline
```

### Rebuild after changes
```bash
cd ~/.config/quickshell/caelestia
cmake --build build
sudo cmake --install build
```

### Switch branches
```bash
# Switch to custom branch
git checkout custom-workspace-name

# Switch to main (upstream default)
git checkout main
```

### Reset to upstream (discard all custom changes)
```bash
git fetch upstream
git reset --hard upstream/main
```

## Notes

- The AUR package `caelestia-shell` can remain installed but won't be used
- Your local version takes precedence over system installation
- Always work on the `custom-workspace-name` branch for modifications
- Keep `main` branch in sync with upstream for easy comparisons
