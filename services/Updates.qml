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

    // Process.exited and StdioCollector.streamFinished arrive in no guaranteed
    // order, and the collector's text is only filled in at stream end. Reading
    // out.text in onExited therefore often saw "" -> exit 0 with no lines ->
    // "System is up to date" (2026-11-21, 260+ updates pending). Only act once
    // the exit code AND both streams are in.
    property int _exitCode: -1
    property bool _outDone: false
    property bool _errDone: false

    function refresh(): void {
        if (checkProc.running)
            return;
        loading = true;
        _exitCode = -1;
        _outDone = false;
        _errDone = false;
        checkProc.running = true;
    }

    function _maybeFinish(): void {
        if (_exitCode < 0 || !_outDone || !_errDone)
            return;
        const exitCode = _exitCode;
        _exitCode = -1;
        root.loading = false;

        // checkupdates exit codes: 0 = updates available, 2 = no updates, anything else = error
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

    Process {
        id: checkProc

        running: false
        command: ["checkupdates"]

        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                root._outDone = true;
                root._maybeFinish();
            }
        }

        stderr: StdioCollector {
            id: err
            onStreamFinished: {
                root._errDone = true;
                root._maybeFinish();
            }
        }

        onExited: (exitCode, exitStatus) => {
            root._exitCode = exitCode;
            root._maybeFinish();
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
