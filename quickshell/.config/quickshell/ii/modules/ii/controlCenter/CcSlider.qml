import qs.modules.common
import qs.modules.common.widgets
import QtQuick

StyledSlider {
    id: root
    property string materialSymbol
    configuration: StyledSlider.Configuration.M
    stopIndicatorValues: []

    MaterialSymbol {
        property bool nearFull: root.value >= 0.9
        anchors {
            verticalCenter: root.verticalCenter
            right: nearFull ? root.handle.right : root.right
            rightMargin: nearFull ? 14 : 8
        }
        iconSize: 20
        color: nearFull ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSecondaryContainer
        text: root.materialSymbol

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}
