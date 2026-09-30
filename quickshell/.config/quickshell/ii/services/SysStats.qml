pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Static info (fetched once)
    property string cpuModel: ""
    property string gpuName: ""
    property string kernel: ""
    property int cpuThreads: 1

    // Periodic info
    property string loadAvg: ""
    property string diskUsed: ""
    property string diskTotal: ""
    property string diskPercent: ""

    // Top processes, aggregated by command name. Only polled while something asks for it:
    // `top -bn2` needs two samples to report real instantaneous CPU, so each run blocks ~0.7s.
    // Counter, not a bool: the bar popup and the Control Center page can both be on screen.
    property int procsWatchers: 0
    readonly property bool procsEnabled: procsWatchers > 0
    property var topCpu: []
    property var topMem: []

    // Network rates (bytes/s) + history for graphs
    readonly property int historyLength: 40
    property real netDown: 0
    property real netUp: 0
    property list<real> netDownHistory: []
    property list<real> netUpHistory: []
    property real _lastRx: -1
    property real _lastTx: -1

    function formatSpeed(bps) {
        if (bps >= 1024 * 1024) return (bps / (1024 * 1024)).toFixed(1) + " MB/s";
        return (bps / 1024).toFixed(1) + " kB/s";
    }

    Component.onCompleted: {
        cpuModelProc.running = true;
        gpuProc.running = true;
        kernelProc.running = true;
    }

    Process {
        id: cpuModelProc
        command: ["bash", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: root.cpuModel = this.text.trim()
        }
    }
    Process {
        id: gpuProc
        command: ["bash", "-c", "lspci -mm 2>/dev/null | grep -im1 -E 'vga|3d controller' | awk -F'\"' '{print $6}'"]
        stdout: StdioCollector {
            onStreamFinished: root.gpuName = this.text.trim()
        }
    }
    Process {
        id: kernelProc
        command: ["uname", "-r"]
        stdout: StdioCollector {
            onStreamFinished: root.kernel = this.text.trim()
        }
    }
    Process {
        id: threadsProc
        running: true
        command: ["nproc"]
        stdout: StdioCollector {
            onStreamFinished: root.cpuThreads = Math.max(1, parseInt(this.text.trim()) || 1)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netProc.running = true
    }
    Process {
        id: netProc
        command: ["bash", "-c", "awk -F'[: ]+' 'NR>2 && $2!=\"lo\" {rx+=$3; tx+=$11} END {print rx, tx}' /proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(" ");
                const rx = parseFloat(parts[0]), tx = parseFloat(parts[1]);
                if (isNaN(rx) || isNaN(tx)) return;
                if (root._lastRx >= 0) {
                    root.netDown = Math.max(0, (rx - root._lastRx) / 2);
                    root.netUp = Math.max(0, (tx - root._lastTx) / 2);
                    let down = [...root.netDownHistory, root.netDown];
                    let up = [...root.netUpHistory, root.netUp];
                    if (down.length > root.historyLength) down = down.slice(-root.historyLength);
                    if (up.length > root.historyLength) up = up.slice(-root.historyLength);
                    root.netDownHistory = down;
                    root.netUpHistory = up;
                }
                root._lastRx = rx;
                root._lastTx = tx;
            }
        }
    }

    Timer {
        interval: 3000
        running: root.procsEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!procsProc.running) procsProc.running = true
    }
    Process {
        id: procsProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        // Second `top` iteration only: the first one reports averages since boot.
        command: ["bash", "-c", "top -bn2 -d 0.7 -w 512 | awk 'BEGIN{b=0} /^ *PID/{b++; next} b==2 && NF>=12 {c[$12]+=$9; m[$12]+=$10} END{for (k in c) print k, c[k], m[k]}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                // ponytail: soma %MEM por nome conta páginas compartilhadas (chrome, electron) mais de uma
                // vez, igual ao htop. Se precisar do valor exato, trocar por PSS de /proc/*/smaps_rollup.
                const rows = this.text.trim().split("\n").map(line => {
                    const p = line.trim().split(/\s+/);
                    return { name: p[0], cpu: parseFloat(p[1]), mem: parseFloat(p[2]) };
                }).filter(r => r.name && !isNaN(r.cpu) && !isNaN(r.mem));
                root.topCpu = [...rows].sort((a, b) => b.cpu - a.cpu).slice(0, 5);
                root.topMem = [...rows].sort((a, b) => b.mem - a.mem).slice(0, 5);
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            loadProc.running = true;
            diskProc.running = true;
        }
    }
    Process {
        id: loadProc
        command: ["bash", "-c", "cut -d' ' -f1-3 /proc/loadavg"]
        stdout: StdioCollector {
            onStreamFinished: root.loadAvg = this.text.trim().split(" ").join(" / ")
        }
    }
    Process {
        id: diskProc
        command: ["bash", "-c", "df --output=used,size,pcent -BG / | tail -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/);
                if (parts.length >= 3) {
                    root.diskUsed = parts[0].replace("G", "");
                    root.diskTotal = parts[1].replace("G", "");
                    root.diskPercent = parts[2];
                }
            }
        }
    }
}
