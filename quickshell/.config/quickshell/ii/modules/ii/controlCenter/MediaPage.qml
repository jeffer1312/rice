import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 10

    readonly property var player: MprisController.activePlayer
    readonly property var track: MprisController.activeTrack

    Timer {
        running: root.player?.playbackState === 1 || (root.player?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    component MediaButton: RippleButton {
        id: mediaButton
        property string buttonIcon
        implicitWidth: 44
        implicitHeight: 40
        buttonRadius: Appearance.rounding.normal
        colBackground: Appearance.colors.colLayer2
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: mediaButton.buttonIcon
            iconSize: 22
            fill: mediaButton.toggled ? 1 : 0
            color: mediaButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
        }
    }

    CcCard {
        RowLayout {
            spacing: 14

            Rectangle {
                implicitWidth: 96
                implicitHeight: 96
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2
                clip: true

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: 40
                    color: Appearance.colors.colOnLayer1Inactive
                    visible: artImage.status !== Image.Ready
                }
                Image {
                    id: artImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: root.track?.artUrl ?? ""
                    visible: status === Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: root.player ? (root.track?.title ?? "") : Translation.tr("Nothing playing")
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.family: Appearance.font.family.title
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.player ? (root.track?.artist ?? "") : Translation.tr("Idle")
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1Inactive
                }

                RowLayout {
                    spacing: 8

                    MediaButton {
                        enabled: root.player != null
                        buttonIcon: "skip_previous"
                        onClicked: MprisController.previous()
                    }
                    MediaButton {
                        enabled: root.player != null
                        buttonIcon: root.player?.isPlaying ? "pause" : "play_arrow"
                        toggled: root.player?.isPlaying ?? false
                        onClicked: MprisController.togglePlaying()
                    }
                    MediaButton {
                        enabled: root.player != null
                        buttonIcon: "skip_next"
                        onClicked: MprisController.next()
                    }
                }
            }
        }

        StyledProgressBar {
            visible: (root.player?.length ?? 0) > 0
            Layout.fillWidth: true
            valueBarWidth: parent.width
            valueBarHeight: 6
            value: root.player ? Math.min(1, root.player.position / root.player.length) : 0
        }
        StyledText {
            visible: (root.player?.length ?? 0) > 0
            text: `${StringUtils.friendlyTimeForSeconds(root.player?.position)} / ${StringUtils.friendlyTimeForSeconds(root.player?.length)}`
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1Inactive
        }
    }

    Item { Layout.fillHeight: true }
}
