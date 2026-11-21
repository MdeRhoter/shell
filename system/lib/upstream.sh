# shellcheck shell=bash
# Shared "what has upstream Caelestia got that we don't" logic, sourced by
# ./update and system/bin/caelestia-update-check (which cd's into the repo).
# One copy on purpose: these used to be three hand-synced snippets.
#
# WHY main AND NOT THE RELEASE TAG (changed 2026-11-21): upstream went from
# v2.5.0 (2026-09-18) to 65 commits on main, 10 of them features (video
# wallpapers, lock Ctrl+U, DND shortcut, ...), without cutting a release. A
# tag-only check said "up to date" the whole time. Our branch had in fact been
# ported onto main by hand on 2026-11-12, so main is what we really track.
#
# Only feat/fix/perf commits count as "something to port" — upstream follows
# conventional commits, and chore(nix) flake bumps, ci, docs, style and
# refactors with no behaviour change land several times a week. Notifying on
# those would teach you to ignore the notification.

UPSTREAM_REF=upstream/main
UPSTREAM_RELEVANT='^(feat|fix|perf)(\([^)]*\))?!?:'

# Commits on upstream/main not in HEAD, as "<short-hash> <subject>", newest
# first. --cherry-pick drops upstream commits we already carry as a
# patch-equivalent cherry-pick (a fix we pulled in early).
upstream_missing() {
    git log --format='%h %s' --cherry-pick --right-only --no-merges \
        "HEAD...$UPSTREAM_REF" 2>/dev/null
}

# Same, filtered to commits worth porting for.
upstream_missing_relevant() {
    upstream_missing | grep -E "^[0-9a-f]+ ${UPSTREAM_RELEVANT#^}" || true
}

# Latest release tag reachable from upstream/main, or empty.
upstream_latest_tag() {
    git describe --tags --abbrev=0 "$UPSTREAM_REF" 2>/dev/null || true
}

# One-line summary for status output, e.g.
#   "3 commit(s) behind upstream/main (1 feat/fix/perf)". Empty when level.
upstream_summary() {
    local all rel
    all="$(upstream_missing | grep -c . || true)"
    [ "$all" -gt 0 ] || return 0
    rel="$(upstream_missing_relevant | grep -c . || true)"
    printf '%s commit(s) behind %s (%s feat/fix/perf)\n' "$all" "$UPSTREAM_REF" "$rel"
}
