import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.quickToggles
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    required property QuickToggleModel toggleModel
    property bool showStatus: false
    property string labelOverride: ""

    visible: toggleModel.available
    toggled: toggleModel.toggled
    implicitHeight: 60
    padding: 10
    buttonRadius: Appearance.rounding.normal
    colBackground: Appearance.colors.colLayer1
    onClicked: toggleModel.mainAction()
    altAction: toggleModel.altAction

    StyledToolTip {
        text: root.toggleModel.tooltipText
        extraVisibleCondition: root.toggleModel.tooltipText !== ""
    }

    contentItem: RowLayout {
        spacing: 8

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.toggleModel.icon
            iconSize: 22
            fill: root.toggled ? 1 : 0
            color: root.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.labelOverride !== "" ? root.labelOverride : root.toggleModel.name
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.showStatus && root.toggleModel.hasStatusText && root.toggleModel.statusText !== ""
                text: root.toggleModel.statusText
                elide: Text.ElideRight
                opacity: 0.75
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
            }
        }
    }
}
