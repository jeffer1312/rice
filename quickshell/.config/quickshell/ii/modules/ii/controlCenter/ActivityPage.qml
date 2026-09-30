import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 10

    readonly property real netMax: Math.max(1024, ...SysStats.netDownHistory, ...SysStats.netUpHistory)

    // Polling top processes costs a blocking ~0.7s sample, so only do it while this page is on screen.
    property bool watchingProcs: false
    function syncProcsWatch() {
        if (root.visible === root.watchingProcs) return;
        root.watchingProcs = root.visible;
        SysStats.procsWatchers += root.visible ? 1 : -1;
    }
    onVisibleChanged: syncProcsWatch()
    Component.onCompleted: syncProcsWatch()
    Component.onDestruction: if (watchingProcs) SysStats.procsWatchers -= 1

    // `top` reports CPU per core, so a process on 2 busy threads reads 200% — meaningless next to the
    // machine-wide 68% on the card above. Divide by the thread count so both speak the same scale.
    function cpuPercentOfMachine(perCore) {
        return perCore / SysStats.cpuThreads;
    }
    function formatPercent(value) {
        return (value < 10 ? value.toFixed(1) : value.toFixed(0)) + "%";
    }

    component ProcRow: RowLayout {
        id: procRow
        property string procName
        property string procValue
        property string tooltipText: ""
        property real fraction: 0
        property bool hovered: rowHover.hovered
        Layout.fillWidth: true
        spacing: 8

        HoverHandler { id: rowHover }
        StyledToolTip {
            text: procRow.tooltipText
            extraVisibleCondition: procRow.tooltipText !== ""
        }

        Rectangle {
            implicitWidth: 3
            implicitHeight: 14
            radius: 2
            color: Appearance.colors.colPrimary
            opacity: 0.25 + Math.min(1, procRow.fraction) * 0.75
        }
        StyledText {
            Layout.fillWidth: true
            text: procRow.procName
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1Inactive
        }
        StyledText {
            text: procRow.procValue
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
        }
    }

    component InfoRow: RowLayout {
        id: infoRow
        property string rowIcon
        property string label
        property string valueText: ""
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: infoRow.rowIcon
            iconSize: 17
            color: Appearance.colors.colOnLayer1Inactive
        }
        StyledText {
            Layout.fillWidth: true
            text: infoRow.label
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1Inactive
        }
        StyledText {
            visible: infoRow.valueText !== ""
            text: infoRow.valueText
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
        }
    }

    component FooterStat: RowLayout {
        id: footerStat
        property string statIcon
        property string statText
        property color statColor: Appearance.colors.colOnLayer1
        spacing: 4

        MaterialSymbol {
            text: footerStat.statIcon
            iconSize: 17
            color: footerStat.statColor
        }
        StyledText {
            text: footerStat.statText
            font.pixelSize: Appearance.font.pixelSize.small
            color: footerStat.statColor
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        CcCard {
            Layout.preferredWidth: 1
            title: "CPU"

            Item {
                Layout.fillWidth: true
                implicitHeight: 64

                Graph {
                    anchors.fill: parent
                    values: SystemTemp.history
                    points: SystemTemp.historyLength
                    color: Appearance.m3colors.m3tertiary
                    fillOpacity: 0.1
                    alignment: Graph.Alignment.Right
                }
                Graph {
                    anchors.fill: parent
                    values: ResourceUsage.cpuUsageHistory
                    points: ResourceUsage.historyLength
                    color: Appearance.colors.colPrimary
                    fillOpacity: 0.3
                    alignment: Graph.Alignment.Right
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                FooterStat {
                    statIcon: "speed"
                    statText: Math.round(ResourceUsage.cpuUsage * 100) + "%"
                    statColor: Appearance.colors.colPrimary
                }
                FooterStat {
                    statIcon: "local_fire_department"
                    statText: Math.round(SystemTemp.temperature) + "°C"
                    statColor: Appearance.m3colors.m3tertiary
                }
            }
        }

        CcCard {
            Layout.preferredWidth: 1
            title: Translation.tr("Memory")

            Item {
                Layout.fillWidth: true
                implicitHeight: 64

                Graph {
                    anchors.fill: parent
                    values: ResourceUsage.memoryUsageHistory
                    points: ResourceUsage.historyLength
                    color: Appearance.colors.colPrimary
                    fillOpacity: 0.25
                    alignment: Graph.Alignment.Right
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter

                FooterStat {
                    statIcon: "memory"
                    statText: `${ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)} · ${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`
                }
            }
        }
    }

    CcCard {
        title: Translation.tr("Connection")

        Item {
            Layout.fillWidth: true
            implicitHeight: 56

            Graph {
                anchors.fill: parent
                values: SysStats.netDownHistory.map(v => v / root.netMax)
                points: SysStats.historyLength
                color: Appearance.colors.colPrimary
                fillOpacity: 0.15
                alignment: Graph.Alignment.Right
            }
            Graph {
                anchors.fill: parent
                values: SysStats.netUpHistory.map(v => v / root.netMax)
                points: SysStats.historyLength
                color: Appearance.m3colors.m3tertiary
                fillOpacity: 0.1
                alignment: Graph.Alignment.Right
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            FooterStat {
                statIcon: "download"
                statText: SysStats.formatSpeed(SysStats.netDown)
                statColor: Appearance.colors.colPrimary
            }
            FooterStat {
                statIcon: "upload"
                statText: SysStats.formatSpeed(SysStats.netUp)
                statColor: Appearance.m3colors.m3tertiary
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 10

        CcCard {
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: Translation.tr("Top CPU")

            Repeater {
                model: SysStats.topCpu
                delegate: ProcRow {
                    required property var modelData
                    readonly property real share: root.cpuPercentOfMachine(modelData.cpu)
                    procName: modelData.name
                    procValue: root.formatPercent(share)
                    fraction: share / 100
                    tooltipText: Translation.tr("%1 of %2 threads · %3 per core")
                        .arg((modelData.cpu / 100).toFixed(1))
                        .arg(SysStats.cpuThreads)
                        .arg(modelData.cpu.toFixed(0) + "%")
                }
            }
            StyledText {
                visible: SysStats.topCpu.length === 0
                text: "--"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1Inactive
            }
        }

        CcCard {
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: Translation.tr("Top RAM")

            Repeater {
                model: SysStats.topMem
                delegate: ProcRow {
                    required property var modelData
                    procName: modelData.name
                    procValue: ResourceUsage.kbToGbString(modelData.mem / 100 * ResourceUsage.memoryTotal)
                    fraction: modelData.mem / 100
                    tooltipText: root.formatPercent(modelData.mem) + Translation.tr(" of total RAM")
                }
            }
            StyledText {
                visible: SysStats.topMem.length === 0
                text: "--"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1Inactive
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 10

        CcCard {
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: Translation.tr("System")

            InfoRow { rowIcon: "developer_board"; label: SysStats.cpuModel || "--" }
            InfoRow { rowIcon: "monitor"; label: SysStats.gpuName || "--" }
            InfoRow { rowIcon: "computer"; label: SystemInfo.distroName }
            InfoRow { rowIcon: "terminal"; label: "Linux " + SysStats.kernel }
            InfoRow { rowIcon: "web_asset"; label: "Hyprland" }
            InfoRow { rowIcon: "schedule"; label: Translation.tr("Uptime: %1").arg(DateTime.uptime) }
        }

        CcCard {
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            title: Translation.tr("Resources")

            InfoRow {
                rowIcon: "monitoring"
                label: Translation.tr("CPU Load")
                valueText: SysStats.loadAvg || "--"
            }
            InfoRow {
                rowIcon: "memory"
                label: "RAM"
                valueText: `${ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)} / ${ResourceUsage.maxAvailableMemoryString}`
            }
            InfoRow {
                rowIcon: "swap_horiz"
                label: "Swap"
                valueText: `${ResourceUsage.kbToGbString(ResourceUsage.swapUsed)} / ${ResourceUsage.maxAvailableSwapString}`
            }
            InfoRow {
                rowIcon: "hard_drive"
                label: "/"
                valueText: `${SysStats.diskUsed} / ${SysStats.diskTotal} GB (${SysStats.diskPercent})`
            }
        }
    }

    Item { Layout.fillHeight: true }
}
