pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property list<var> updates: []
    readonly property int count: updates.length
    property bool loading: false

    function refresh(): void {
        loading = true;
        checkProc.running = true;
    }

    Process {
        id: checkProc

        running: false
        command: ["checkupdates"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                const lines = text.trim().split("\n").filter(l => l.length > 0);
                root.updates = lines.map(line => {
                    const parts = line.split(" ");
                    return {
                        name: parts[0] ?? "",
                        oldVer: parts[1] ?? "",
                        newVer: parts[3] ?? ""  // format: "name oldVer -> newVer"
                    };
                });
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
