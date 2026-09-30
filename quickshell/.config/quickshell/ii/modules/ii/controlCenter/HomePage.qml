import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.quickToggles
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root
    spacing: 10

    property string username: Quickshell.env("USER") ?? "user"
    property string hostname: ""
    Process {
        running: true
        command: ["hostname"]
        stdout: StdioCollector {
            onStreamFinished: root.hostname = this.text.trim()
        }
    }

    CcCard {
        StyledText {
            text: root.username.charAt(0).toUpperCase() + root.username.slice(1)
            font.pixelSize: Appearance.font.pixelSize.hugeass
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            text: `${root.username}@${root.hostname}`
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1Inactive
        }
        StyledText {
            text: Translation.tr("Uptime: %1").arg(DateTime.uptime)
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1Inactive
        }
        StyledText {
            text: "illogical-impulse"
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1Inactive
            opacity: 0.7
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 85
            Layout.alignment: Qt.AlignTop
            spacing: 10

            CcCard {
                RowLayout {
                    spacing: 12

                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colLayer2

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "music_note"
                            iconSize: 24
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: MprisController.activePlayer ? (MprisController.activeTrack?.title ?? "") : Translation.tr("Nothing playing")
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: MprisController.activePlayer ? (MprisController.activeTrack?.artist ?? "") : Translation.tr("Idle")
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1Inactive
                        }
                    }
                }
            }

            CcCard {
                RowLayout {
                    spacing: 12

                    StyledText {
                        text: DateTime.time
                        font.pixelSize: 30
                        font.family: Appearance.font.family.title
                        color: Appearance.m3colors.m3primary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: DateTime.longDate
                        elide: Text.ElideRight
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1Inactive
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 115
            Layout.alignment: Qt.AlignTop
            columns: 2
            rowSpacing: 10
            columnSpacing: 10

            CcToggleTile {
                Layout.fillWidth: true
                showStatus: true
                toggleModel: NetworkToggle {}
            }
            CcToggleTile {
                Layout.fillWidth: true
                toggleModel: BluetoothToggle {}
            }
            CcToggleTile {
                Layout.fillWidth: true
                labelOverride: Translation.tr("Caffeine")
                toggleModel: IdleInhibitorToggle {}
            }
            CcToggleTile {
                Layout.fillWidth: true
                toggleModel: NightLightToggle {}
            }
            CcToggleTile {
                Layout.fillWidth: true
                toggleModel: NotificationToggle {}
            }
            CcToggleTile {
                Layout.fillWidth: true
                labelOverride: Translation.tr(toggleModel.statusText)
                toggleModel: PowerProfilesToggle {}
            }
        }
    }

    Item { Layout.fillHeight: true }
}
