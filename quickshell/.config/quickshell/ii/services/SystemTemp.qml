pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property real temperature: 0 // °C, hottest thermal zone
    readonly property int historyLength: 40
    property list<real> history: [] // normalized 0-1 (temp / 100)

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: tempProc.running = true
    }

    Process {
        id: tempProc
        command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim());
                if (isNaN(v)) return;
                root.temperature = v / 1000;
                let h = [...root.history, Math.min(1, root.temperature / 100)];
                if (h.length > root.historyLength) h = h.slice(-root.historyLength);
                root.history = h;
            }
        }
    }
}
