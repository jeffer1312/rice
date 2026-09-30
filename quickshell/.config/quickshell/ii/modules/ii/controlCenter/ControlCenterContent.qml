import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    radius: Appearance.rounding.windowRounding
    color: Appearance.colors.colLayer0
    border.width: 1
    border.color: Appearance.colors.colLayer0Border
    implicitHeight: mainRow.implicitHeight + 28

    property int currentTab: GlobalStates.controlCenterTab
    onCurrentTabChanged: GlobalStates.controlCenterTab = currentTab
    readonly property var tabs: [
        { icon: "home", name: Translation.tr("Home") },
        { icon: "play_circle", name: Translation.tr("Media") },
        { icon: "volume_up", name: Translation.tr("Audio") },
        { icon: "desktop_windows", name: Translation.tr("Display") },
        { icon: "monitoring", name: Translation.tr("Activity") },
        { icon: "battery_charging_full", name: Translation.tr("Energy") },
        { icon: "wifi", name: "Wi-Fi" },
        { icon: "bluetooth", name: "Bluetooth" },
        { icon: "partly_cloudy_day", name: Translation.tr("Weather") },
        { icon: "calendar_month", name: Translation.tr("Calendar") },
        { icon: "notifications", name: Translation.tr("Notifications") },
    ]

    component HeaderButton: RippleButton {
        id: headerButton
        property string buttonIcon
        implicitWidth: 42
        implicitHeight: 36
        buttonRadius: Appearance.rounding.small
        colBackground: Appearance.colors.colLayer1
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: headerButton.buttonIcon
            iconSize: 20
            color: Appearance.colors.colOnLayer1
        }
    }

    RowLayout {
        id: mainRow
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Nav rail
        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 56
            implicitHeight: railColumn.implicitHeight + 16
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1

            ColumnLayout {
                id: railColumn
                anchors {
                    top: parent.top
                    topMargin: 8
                    horizontalCenter: parent.horizontalCenter
                }
                spacing: 4

                Repeater {
                    model: root.tabs
                    delegate: RippleButton {
                        id: tabButton
                        required property var modelData
                        required property int index
                        implicitWidth: 44
                        implicitHeight: 44
                        buttonRadius: Appearance.rounding.normal
                        toggled: root.currentTab === index
                        onClicked: root.currentTab = index
                        StyledToolTip { text: tabButton.modelData.name }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: tabButton.modelData.icon
                            iconSize: 24
                            fill: tabButton.toggled ? 1 : 0
                            color: tabButton.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    text: root.tabs[root.currentTab].name
                    color: Appearance.m3colors.m3primary
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.family: Appearance.font.family.title
                }
                Item { Layout.fillWidth: true }
                HeaderButton {
                    buttonIcon: "settings"
                    onClicked: {
                        GlobalStates.controlCenterOpen = false;
                        Quickshell.execDetached(["qs", "-c", "ii", "-p", Quickshell.shellPath("settings.qml")]);
                    }
                }
                HeaderButton {
                    buttonIcon: "power_settings_new"
                    onClicked: {
                        GlobalStates.controlCenterOpen = false;
                        GlobalStates.sessionOpen = true;
                    }
                }
                HeaderButton {
                    buttonIcon: "close"
                    onClicked: GlobalStates.controlCenterOpen = false
                }
            }

            // Pages are taller than the panel on smaller screens (Display especially), and a
            // bare StackLayout just clips the overflow with no way to reach it.
            StyledFlickable {
                id: pageFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageStack.height

                StackLayout {
                    id: pageStack
                    width: pageFlick.width
                    // StackLayout's own implicitHeight is the max across ALL pages, which would
                    // leave every short page scrolling through the tallest one's empty space.
                    // Measure the page actually on screen instead, and never go below the
                    // viewport so a short page still fills it.
                    readonly property real currentPageHeight: children[currentIndex]?.implicitHeight ?? 0
                    height: Math.max(pageFlick.height, currentPageHeight)
                    currentIndex: root.currentTab

                    HomePage {}
                    MediaPage {}
                    AudioPage {}
                    DisplayPage {}
                    ActivityPage {}
                    EnergyPage {}
                    WifiPage {}
                    BluetoothPage {}
                    WeatherPage {}
                    CalendarPage {}
                    NotificationsPage {}
                }
            }
        }
    }
}
