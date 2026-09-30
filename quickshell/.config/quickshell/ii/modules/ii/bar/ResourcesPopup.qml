import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    readonly property real netMax: Math.max(1024, ...SysStats.netDownHistory, ...SysStats.netUpHistory)

    function formatPercent(value) {
        return (value < 10 ? value.toFixed(1) : value.toFixed(0)) + "%";
    }

    // Card with the usage history drawn behind the numbers, like a mini task manager.
    component StatCard: Rectangle {
        id: card
        default property alias content: cardColumn.data
        property string icon
        property string title
        property string value
        property string subtitle: ""
        property bool warning: false
        property color accent: Appearance.colors.colPrimary
        property list<real> history: []
        property list<real> history2: []
        property int historyPoints: history.length

        Layout.preferredWidth: 176
        Layout.fillHeight: true
        implicitHeight: cardColumn.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: cardColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 12
            }
            spacing: 4

            RowLayout {
                spacing: 5
                MaterialSymbol {
                    text: card.icon
                    iconSize: Appearance.font.pixelSize.large
                    color: card.warning ? Appearance.colors.colError : card.accent
                }
                StyledText {
                    text: card.title
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
            StyledText {
                text: card.value
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                color: card.warning ? Appearance.colors.colError : Appearance.colors.colOnLayer1
            }
            StyledText {
                visible: card.subtitle !== ""
                text: card.subtitle
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1Inactive
            }
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 26
                clip: true

                Graph {
                    anchors.fill: parent
                    visible: card.history.length > 1
                    values: card.history
                    points: card.historyPoints
                    color: card.warning ? Appearance.colors.colError : card.accent
                    fillOpacity: 0.25
                    alignment: Graph.Alignment.Right
                }
                Graph {
                    anchors.fill: parent
                    visible: card.history2.length > 1
                    values: card.history2
                    points: card.historyPoints
                    color: Appearance.m3colors.m3tertiary
                    fillOpacity: 0.15
                    alignment: Graph.Alignment.Right
                }
            }
        }
    }

    component ProcRow: RowLayout {
        id: procRow
        required property var modelData
        property real share: 0
        property string valueText: ""
        Layout.fillWidth: true
        spacing: 6

        Rectangle {
            implicitWidth: 3
            implicitHeight: 14
            radius: 2
            color: Appearance.colors.colPrimary
            opacity: 0.25 + Math.min(1, procRow.share) * 0.75
        }
        StyledText {
            Layout.fillWidth: true
            text: procRow.modelData.name
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1Inactive
        }
        StyledText {
            text: procRow.valueText
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
        }
    }

    component ProcList: ColumnLayout {
        id: procList
        property string icon
        property string title
        property var model: []
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 4

        RowLayout {
            spacing: 5
            MaterialSymbol {
                text: procList.icon
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurfaceVariant
            }
            StyledText {
                text: procList.title
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
        StyledText {
            visible: procList.model.length === 0
            text: "--"
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1Inactive
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        // LazyLoader builds this on hover and destroys it on leave, so completed/destruction
        // bracket exactly the time the popup is visible.
        Component.onCompleted: SysStats.procsWatchers += 1
        Component.onDestruction: SysStats.procsWatchers -= 1

        RowLayout {
            spacing: 10

            StatCard {
                icon: "memory"
                title: "CPU"
                value: Math.round(ResourceUsage.cpuUsage * 100) + "%"
                subtitle: Math.round(SystemTemp.temperature) + "°C · " + SysStats.cpuThreads + " threads"
                warning: ResourceUsage.cpuUsage * 100 >= Config.options.bar.resources.cpuWarningThreshold
                history: ResourceUsage.cpuUsageHistory
                historyPoints: ResourceUsage.historyLength

                Row {
                    Layout.topMargin: 4
                    spacing: 3
                    Repeater {
                        model: ResourceUsage.cpuCoreUsage
                        delegate: Rectangle {
                            required property real modelData
                            property bool hot: modelData * 100 >= Config.options.bar.resources.cpuWarningThreshold
                            width: 9
                            height: 22
                            radius: 2
                            color: Appearance.colors.colSurfaceContainerHighest
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(2, parent.height * parent.modelData)
                                radius: 2
                                color: parent.hot ? Appearance.colors.colError : Appearance.colors.colPrimary
                            }
                        }
                    }
                }
            }

            StatCard {
                icon: "memory_alt"
                title: "RAM"
                value: ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)
                subtitle: Translation.tr("of %1 · %2%")
                    .arg(ResourceUsage.maxAvailableMemoryString)
                    .arg(Math.round(ResourceUsage.memoryUsedPercentage * 100))
                warning: ResourceUsage.memoryUsedPercentage * 100 >= Config.options.bar.resources.memoryWarningThreshold
                history: ResourceUsage.memoryUsageHistory
                historyPoints: ResourceUsage.historyLength

                StyledText {
                    visible: ResourceUsage.swapTotal > 0
                    Layout.topMargin: 4
                    text: "Swap " + ResourceUsage.kbToGbString(ResourceUsage.swapUsed) + " / " + ResourceUsage.maxAvailableSwapString
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1Inactive
                }
            }

            StatCard {
                visible: ResourceUsage.gpuAvailable
                icon: "developer_board"
                title: "GPU"
                value: Math.round(ResourceUsage.gpuUsage * 100) + "%"
                subtitle: Math.round(ResourceUsage.gpuFreqMhz) + " MHz · " + ResourceUsage.gpuPowerW.toFixed(1) + " W"
                warning: ResourceUsage.gpuUsage * 100 >= Config.options.bar.resources.gpuWarningThreshold
                history: ResourceUsage.gpuUsageHistory
                historyPoints: ResourceUsage.historyLength
            }

            StatCard {
                icon: Network.materialSymbol
                title: Translation.tr("Network")
                value: "↓ " + SysStats.formatSpeed(SysStats.netDown)
                subtitle: "↑ " + SysStats.formatSpeed(SysStats.netUp)
                history: SysStats.netDownHistory.map(v => v / root.netMax)
                history2: SysStats.netUpHistory.map(v => v / root.netMax)
                historyPoints: SysStats.historyLength

                StyledText {
                    Layout.topMargin: 4
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Network.ethernet ? Translation.tr("Wired")
                        : (Network.networkName || Translation.tr("Disconnected"))
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1Inactive
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 24

            ProcList {
                icon: "speed"
                title: Translation.tr("Top CPU")
                model: SysStats.topCpu
                Repeater {
                    model: SysStats.topCpu
                    delegate: ProcRow {
                        // top reports per-core %, the card above is machine-wide
                        share: modelData.cpu / SysStats.cpuThreads / 100
                        valueText: root.formatPercent(share * 100)
                    }
                }
            }

            ProcList {
                icon: "memory_alt"
                title: Translation.tr("Top RAM")
                model: SysStats.topMem
                Repeater {
                    model: SysStats.topMem
                    delegate: ProcRow {
                        share: modelData.mem / 100
                        valueText: ResourceUsage.kbToGbString(modelData.mem / 100 * ResourceUsage.memoryTotal)
                    }
                }
            }
        }
    }
}
