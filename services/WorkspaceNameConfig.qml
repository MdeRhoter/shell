pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    // ── Grouping ──────────────────────────────────────────────────────────────
    // When enabled, workspace IDs are mapped to a short label via `groups`.
    // When disabled, the raw workspace number is shown.
    readonly property bool groupingEnabled: _cfg.grouping?.enabled ?? true

    // Array of { from, to, label } — label shown in the bar widget.
    readonly property var groups: _cfg.grouping?.groups ?? [
        { "from": 1, "to": 2, "label": "W" },
        { "from": 3, "to": 4, "label": "M" },
        { "from": 5, "to": 6, "label": "P" }
    ]

    // Array of { from, to, name } — full name shown in the hover popout.
    readonly property var groupNames: _cfg.grouping?.groupNames ?? [
        { "from": 1, "to": 2, "name": "Work (1\u20132)" },
        { "from": 3, "to": 4, "name": "Music (3\u20134)" },
        { "from": 5, "to": 6, "name": "Personal (5\u20136)" }
    ]

    // Label shown when no group matches the active workspace.
    readonly property string fallback: _cfg.grouping?.fallback ?? "?"

    // ── Widget appearance ─────────────────────────────────────────────────────
    // Show the workspace material icon above the label.
    readonly property bool showIcon: _cfg.showIcon ?? true

    // Show the count of windows in special workspaces below the label.
    readonly property bool showSpecialCount: _cfg.showSpecialCount ?? true

    // ── Behaviour ─────────────────────────────────────────────────────────────
    // Name of the special workspace toggled when the widget is clicked.
    readonly property string specialWorkspace: _cfg.specialWorkspace ?? "magic"

    // ── Helpers ───────────────────────────────────────────────────────────────
    // Returns the short bar label for a given workspace ID.
    function labelForWorkspace(wsId: int): string {
        if (!groupingEnabled)
            return wsId.toString();
        for (const g of groups) {
            if (wsId >= g.from && wsId <= g.to)
                return g.label;
        }
        return fallback;
    }

    // Returns the full display name for a given workspace ID (used in the popout).
    function nameForWorkspace(wsId: int): string {
        if (!groupingEnabled)
            return wsId.toString();
        for (const g of groupNames) {
            if (wsId >= g.from && wsId <= g.to)
                return g.name;
        }
        return qsTr("Workspace %1").arg(wsId);
    }

    // ── Internal ──────────────────────────────────────────────────────────────
    property var _cfg: ({})

    FileView {
        path: `${Paths.config}/workspacename.json`
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                root._cfg = JSON.parse(text());
            } catch (_) {
                root._cfg = {};
            }
        }
    }
}
