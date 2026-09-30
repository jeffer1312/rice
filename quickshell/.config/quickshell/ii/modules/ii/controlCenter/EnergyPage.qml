import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

ColumnLayout {
    id: root
    spacing: 10

    function formatSeconds(s) {
        const h = Math.floor(s / 3600);
        const m = Math.round((s % 3600) / 60);
        if (h > 0) return `${h}h ${m}min`;
        return `${m} min`;
    }

    component ProfileButton: RippleButton {
        id: profileButton
        property int profile
        property string profileIcon
        property string label
        Layout.fillWidth: true
        implicitHeight: 44
        toggled: PowerProfiles.profile === profile
        buttonRadius: Appearance.rounding.normal
        colBackground: Appearance.colors.colLayer2
        onClicked: PowerProfiles.profile = profileButton.profile

        contentItem: RowLayout {
            spacing: 6
            Item { Layout.fillWidth: true }
            MaterialSymbol {
                text: profileButton.profileIcon
                iconSize: 18
                fill: profileButton.toggled ? 1 : 0
                color: profileButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
            }
            StyledText {
                text: profileButton.label
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: profileButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
            }
            Item { Layout.fillWidth: true }
        }
    }

    CcCard {
        title: Translation.tr("Battery")
        visible: Battery.available

        RowLayout {
            spacing: 8

            MaterialSymbol {
                text: Battery.isCharging ? "battery_charging_full" : "battery_full"
                iconSize: 26
                fill: 1
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                text: Math.round(Battery.percentage * 100) + "%"
                font.pixelSize: Appearance.font.pixelSize.huge
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Battery.isCharging ? Translation.tr("Charging")
                    : Battery.chargeState === UPowerDeviceState.FullyCharged ? Translation.tr("Fully charged")
                    : Translation.tr("Discharging")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1Inactive
            }
        }
        StyledProgressBar {
            Layout.fillWidth: true
            valueBarWidth: parent.width
            valueBarHeight: 8
            value: Battery.percentage
        }
        RowLayout {
            visible: Battery.isCharging ? Battery.timeToFull > 0 : Battery.timeToEmpty > 0
            spacing: 8

            MaterialSymbol {
                text: "schedule"
                iconSize: 17
                color: Appearance.colors.colOnLayer1Inactive
            }
            StyledText {
                text: Battery.isCharging
                    ? Translation.tr("%1 until full").arg(root.formatSeconds(Battery.timeToFull))
                    : Translation.tr("%1 remaining").arg(root.formatSeconds(Battery.timeToEmpty))
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1Inactive
            }
        }
        RowLayout {
            visible: Battery.energyRate > 0
            spacing: 8

            MaterialSymbol {
                text: "bolt"
                iconSize: 17
                color: Appearance.colors.colOnLayer1Inactive
            }
            StyledText {
                text: Battery.energyRate.toFixed(1) + " W"
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1Inactive
            }
        }
    }

    CcCard {
        title: Translation.tr("Power Profile")

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ProfileButton {
                profile: PowerProfile.PowerSaver
                profileIcon: "energy_savings_leaf"
                label: Translation.tr("Power Saver")
            }
            ProfileButton {
                profile: PowerProfile.Balanced
                profileIcon: "balance"
                label: Translation.tr("Balanced")
            }
            ProfileButton {
                visible: PowerProfiles.hasPerformanceProfile
                profile: PowerProfile.Performance
                profileIcon: "speed"
                label: Translation.tr("Performance")
            }
        }
    }

    CcCard {
        title: Translation.tr("Battery Health")
        visible: Battery.available && Battery.health > 0

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Of standard capacity")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1Inactive
            }
            StyledText {
                text: Math.round(Battery.health) + "%"
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                color: Appearance.colors.colOnLayer1
            }
        }
        StyledProgressBar {
            Layout.fillWidth: true
            valueBarWidth: parent.width
            valueBarHeight: 8
            value: Battery.health / 100
            highlightColor: Appearance.m3colors.m3tertiary
        }
    }

    CcCard {
        id: devicesCard
        title: Translation.tr("Connected Devices")
        property var devices: UPower.devices.values.filter(d =>
            d && !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.percentage > 0)
        visible: devices.length > 0

        Repeater {
            model: devicesCard.devices
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: {
                        switch (modelData.type) {
                            case UPowerDeviceType.Keyboard: return "keyboard";
                            case UPowerDeviceType.Mouse: return "mouse";
                            case UPowerDeviceType.Headphones:
                            case UPowerDeviceType.Headset: return "headphones";
                            case UPowerDeviceType.Phone: return "smartphone";
                            default: return "devices";
                        }
                    }
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: modelData.model || Translation.tr("Device")
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Math.round(modelData.percentage * 100) + "%"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1Inactive
                }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
