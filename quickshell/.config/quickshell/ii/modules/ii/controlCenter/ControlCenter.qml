import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    PanelWindow {
        id: panelWindow
        visible: GlobalStates.controlCenterOpen

        function hide() {
            GlobalStates.controlCenterOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: 640 + Appearance.sizes.hyprlandGapsOut * 2
        implicitHeight: Math.max(320, (contentLoader.item?.implicitHeight ?? 600)) + Appearance.sizes.hyprlandGapsOut * 2
        WlrLayershell.namespace: "quickshell:controlCenter"
        WlrLayershell.keyboardFocus: GlobalStates.controlCenterOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            left: true
        }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }
        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                panelWindow.hide();
            }
        }

        Loader {
            id: contentLoader
            active: GlobalStates.controlCenterOpen
            anchors {
                fill: parent
                margins: Appearance.sizes.hyprlandGapsOut
            }

            focus: GlobalStates.controlCenterOpen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    panelWindow.hide();
                }
            }

            sourceComponent: ControlCenterContent {}
        }
    }

    IpcHandler {
        target: "controlCenter"

        function toggle(): void {
            GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen;
        }

        function close(): void {
            GlobalStates.controlCenterOpen = false;
        }

        function open(): void {
            GlobalStates.controlCenterOpen = true;
        }

        function openTab(tab: int): void {
            GlobalStates.controlCenterTab = tab;
            GlobalStates.controlCenterOpen = true;
        }
    }

    GlobalShortcut {
        name: "controlCenterToggle"
        description: "Toggles control center on press"

        onPressed: {
            GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen;
        }
    }
}
