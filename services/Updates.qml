pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property list<var> updates: []
    readonly property int count: updates.length
    property bool loading: false
    // Non-empty when the last check failed (e.g. a repo signature/key problem)
    property string error: ""

    function refresh(): void {
        loading = true;
        checkProc.running = true;
    }

    Process {
        id: checkProc

        running: false
        command: ["checkupdates"]

        stdout: StdioCollector {
            id: out
        }

        stderr: StdioCollector {
            id: err
        }

        // checkupdates exit codes: 0 = updates available, 2 = no updates, anything else = error
        onExited: (exitCode, exitStatus) => {
            root.loading = false;

            if (exitCode === 0 || exitCode === 2) {
                root.error = "";
                const lines = out.text.trim().split("\n").filter(l => l.length > 0);
                root.updates = lines.map(line => {
                    const parts = line.split(" ");
                    return {
                        name: parts[0] ?? "",
                        oldVer: parts[1] ?? "",
                        newVer: parts[3] ?? ""  // format: "name oldVer -> newVer"
                    };
                });
            } else {
                const msg = (err.text || out.text).replace(/\x1b\[[0-9;]*m/g, "").replace(/^==> (ERROR: )?/gm, "").trim();
                root.error = msg.length > 0 ? msg : `checkupdates failed (exit code ${exitCode})`;
                root.updates = [];
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 3600000  // 1 hour
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
