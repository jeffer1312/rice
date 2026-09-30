import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.bluetoothDevices
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

ColumnLayout {
    id: root
    spacing: 10

    CcCard {
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                iconSize: 24
                color: Appearance.colors.colOnLayer1
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: "Bluetooth"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: BluetoothStatus.firstActiveDevice?.name ?? (BluetoothStatus.enabled ? Translation.tr("Not connected") : Translation.tr("Off"))
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1Inactive
                }
            }
            RippleButton {
                implicitWidth: 40
                implicitHeight: 36
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                enabled: BluetoothStatus.enabled
                opacity: enabled ? 1 : 0.5
                toggled: Bluetooth.defaultAdapter?.discovering ?? false
                onClicked: Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter?.discovering
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: parent.toggled ? "bluetooth_searching" : "add"
                    iconSize: 20
                    color: parent.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                }
            }
            RippleButton {
                implicitWidth: 40
                implicitHeight: 36
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                toggled: BluetoothStatus.enabled
                onClicked: Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter?.enabled
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "power_settings_new"
                    iconSize: 20
                    color: parent.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        StyledText {
            anchors.centerIn: parent
            visible: btList.count === 0
            text: BluetoothStatus.enabled ? Translation.tr("No devices found") : Translation.tr("Off")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1Inactive
        }

        ListView {
            id: btList
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            spacing: 0

            model: ScriptModel {
                values: BluetoothStatus.friendlyDeviceList
            }
            delegate: BluetoothDeviceItem {
                required property var modelData
                device: modelData
                width: btList.width
            }
        }
    }
}
