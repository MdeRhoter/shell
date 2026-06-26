pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Battery levels for wireless input peripherals read via Solaar (HID++).
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

    // Per-device latch so we warn once per low-battery episode, not every poll.
    property var _warned: ({})

    function refresh(): void {
        proc.running = true;
    }

    function isLow(d): bool {
        return d && d.percentage >= 0 && d.percentage <= warnLevel && !d.charging;
    }

    function _parse(text: string): void {
        const lines = text.split("\n");
        const devHeader = /^ {2}(\d+): (.+?)\s*$/; // "  2: MX Master 3S"
        const kindRe = /^\s+Kind\s*:\s*(\w+)/;
        const battRe = /Battery:\s*(\d+)%(?:,\s*(?:BatteryStatus\.)?(\w+))?/;

        const result = [];
        let cur = null;
        for (const line of lines) {
            const h = line.match(devHeader);
            if (h) {
                if (cur)
                    result.push(cur);
                cur = {
                    index: h[1],
                    name: h[2],
                    kind: "unknown",
                    percentage: -1,
                    charging: false,
                    status: ""
                };
                continue;
            }
            if (!cur)
                continue;

            const k = line.match(kindRe);
            if (k) {
                cur.kind = k[1].toLowerCase();
                continue;
            }

            const b = line.match(battRe);
            if (b) {
                cur.percentage = parseInt(b[1]);
                const s = (b[2] ?? "").toUpperCase();
                cur.status = s;
                cur.charging = s === "CHARGING" || s === "RECHARGING";
            }
        }
        if (cur)
            result.push(cur);

        const valid = result.filter(d => d.percentage >= 0);
        root.devices = valid;
        root._checkWarnings(valid);
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
        command: ["solaar", "show"]

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
