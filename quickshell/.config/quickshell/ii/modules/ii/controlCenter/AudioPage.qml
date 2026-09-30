import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.volumeMixer
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    spacing: 10

    component MuteButton: RippleButton {
        id: muteButton
        property string onIcon
        property string offIcon
        implicitWidth: 40
        implicitHeight: 36
        buttonRadius: Appearance.rounding.small
        colBackground: Appearance.colors.colLayer2
        colBackgroundToggled: Appearance.m3colors.m3error
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: muteButton.toggled ? muteButton.offIcon : muteButton.onIcon
            iconSize: 20
            color: muteButton.toggled ? Appearance.m3colors.m3onError : Appearance.colors.colOnLayer1
        }
    }

    CcCard {
        title: Translation.tr("Output")

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            CcSlider {
                Layout.fillWidth: true
                materialSymbol: "volume_up"
                value: Audio.sink?.audio.volume ?? 0
                onMoved: Audio.sink.audio.volume = value
            }
            MuteButton {
                onIcon: "volume_up"
                offIcon: "volume_off"
                toggled: Audio.sink?.audio.muted ?? false
                onClicked: Audio.toggleMute()
            }
        }
    }

    CcCard {
        title: Translation.tr("Input")

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            CcSlider {
                Layout.fillWidth: true
                materialSymbol: "mic"
                value: Audio.source?.audio.volume ?? 0
                onMoved: Audio.source.audio.volume = value
            }
            MuteButton {
                onIcon: "mic"
                offIcon: "mic_off"
                toggled: Audio.source?.audio.muted ?? false
                onClicked: Audio.toggleMicMute()
            }
        }
    }

    CcCard {
        title: Translation.tr("Applications")

        StyledText {
            visible: Audio.outputAppNodes.length === 0
            text: Translation.tr("No applications playing audio")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1Inactive
        }
        Repeater {
            model: ScriptModel {
                values: Audio.outputAppNodes
            }
            delegate: VolumeMixerEntry {
                Layout.fillWidth: true
                required property var modelData
                node: modelData
            }
        }
    }

    Item { Layout.fillHeight: true }
}
