import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    implicitWidth: rowLayout.implicitWidth + 8
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    onPressed: {
        GlobalStates.controlCenterTab = 4;
        GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen;
    }

    component SysMonEntry: RowLayout {
        property string entryIcon
        property string entryText
        property bool warning: false
        // Largura fixa pro texto: os valores mudam a cada tick e sem isso
        // a barra inteira fica se reajustando (flicker).
        property real textWidth: 34
        spacing: 2

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: parent.entryIcon
            iconSize: Appearance.font.pixelSize.large
            color: parent.warning ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
        }
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: parent.textWidth
            text: parent.entryText
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: parent.warning ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 10

        SysMonEntry {
            entryIcon: "local_fire_department"
            entryText: SystemTemp.temperature > 0 ? Math.round(SystemTemp.temperature) + "°" : "--"
            warning: SystemTemp.temperature >= 85
            textWidth: 26
        }
        SysMonEntry {
            entryIcon: "memory"
            entryText: Math.round(ResourceUsage.cpuUsage * 100) + "%"
            warning: ResourceUsage.cpuUsage > (Config.options.bar.resources.cpuWarningThreshold / 100)
            textWidth: 32
        }
        SysMonEntry {
            entryIcon: "memory_alt"
            entryText: ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)
            warning: ResourceUsage.memoryUsedPercentage > (Config.options.bar.resources.memoryWarningThreshold / 100)
            textWidth: 52
        }
        SysMonEntry {
            visible: ResourceUsage.gpuAvailable
            entryIcon: "developer_board"
            entryText: Math.round(ResourceUsage.gpuUsage * 100) + "%"
            warning: ResourceUsage.gpuUsage > (Config.options.bar.resources.gpuWarningThreshold / 100)
            textWidth: 32
        }
    }

    ResourcesPopup {
        hoverTarget: root
    }
}
