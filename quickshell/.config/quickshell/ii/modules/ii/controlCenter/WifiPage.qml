import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.wifiNetworks
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    spacing: 10

    Component.onCompleted: {
        if (Network.wifiStatus !== "disabled") Network.rescanWifi();
    }

    CcCard {
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: Network.materialSymbol
                iconSize: 24
                color: Appearance.colors.colOnLayer1
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: Network.networkName !== "" ? Network.networkName : Translation.tr("Not connected")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Network.wifiStatus === "disabled" ? Translation.tr("Wi-Fi off") : Translation.tr("Wi-Fi on")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1Inactive
                }
            }
            RippleButton {
                id: rescanBtn
                implicitWidth: 40
                implicitHeight: 36
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                enabled: Network.wifiStatus !== "disabled" && !Network.wifiScanning
                onClicked: Network.rescanWifi()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "refresh"
                    iconSize: 20
                    color: Appearance.colors.colOnLayer1
                }
            }
            RippleButton {
                implicitWidth: 40
                implicitHeight: 36
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                toggled: Network.wifiStatus !== "disabled"
                onClicked: Network.toggleWifi()
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
        StyledIndeterminateProgressBar {
            visible: Network.wifiScanning
            Layout.fillWidth: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        StyledText {
            anchors.centerIn: parent
            visible: wifiList.count === 0
            text: Network.wifiStatus === "disabled" ? Translation.tr("Wi-Fi off") : Translation.tr("No networks found")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1Inactive
        }

        ListView {
            id: wifiList
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            spacing: 0

            model: ScriptModel {
                values: Network.friendlyWifiNetworks
            }
            delegate: WifiNetworkItem {
                required property var modelData
                wifiNetwork: modelData
                width: wifiList.width
            }
        }
    }
}
