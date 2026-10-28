pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Battery levels for wireless input peripherals read via OpenLogi (HID++).
// Currently only the Logitech mouse on the Bolt receiver is exposed; the
// Keychron keyboard is on a 2.4GHz dongle that reports no battery to Linux.
Singleton {
    id: root

    // Parsed devices: { index, name, kind, percentage, charging, status }
    property list<var> devices: []
    readonly property var mouse: devices.find(d => d.kind === "mouse") ?? null
    readonly property var keyboard: devices.find(d => d.kind === "keyboard") ?? null

    readonly property int warnLevel: 20 // notify at or below this %
    readonly property int pollInterval: 600000 // 10 minutes
    property var lastUpdated: null // Date of the last successful read

    // Per-device latch so we warn once per low-battery episode, not every poll.
    property var _warned: ({})

    function refresh(): void {
        proc.running = true;
    }

    function isLow(d): bool {
        return d && d.percentage >= 0 && d.percentage <= warnLevel && !d.charging;
    }

    function _parse(text: string): void {
        // One device per line, e.g.
        // "  └─ slot 2 ● MX Master 4 (mouse, wpid=b042, battery=65% full (discharging))"
        const devRe = /^[\s├└│─]*(?:slot\s+(\d+)\s+)?\S\s+(.+?)\s+\((\w+),/;
        const battRe = /battery=(\d+)%[^(,)]*(?:\((\w+)\))?/;

        const result = [];
        for (const line of text.split("\n")) {
            const d = line.match(devRe);
            const b = line.match(battRe);
            if (!d || !b)
                continue;
            const s = (b[2] ?? "").toUpperCase();
            result.push({
                index: d[1] ?? "",
                name: d[2],
                kind: d[3].toLowerCase(),
                percentage: parseInt(b[1]),
                charging: s === "CHARGING" || s === "RECHARGING",
                status: s
            });
        }

        root.devices = result;
        root.lastUpdated = new Date();
        root._checkWarnings(result);
    }

    function _checkWarnings(devs): void {
        const warned = root._warned;
        for (const d of devs) {
            if (root.isLow(d)) {
                if (!warned[d.name]) {
                    warned[d.name] = true;
                    Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "critical", qsTr("%1 battery low").arg(d.name), qsTr("Battery at %1% — time to recharge.").arg(d.percentage)]);
                }
            } else {
                // Recovered or charging: re-arm so the next dip warns again.
                warned[d.name] = false;
            }
        }
        root._warned = warned;
    }

    Process {
        id: proc

        running: false
        command: ["openlogi", "list"]

        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.pollInterval
        onTriggered: root.refresh()
    }
}
