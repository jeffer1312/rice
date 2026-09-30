import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.calendar
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 10

    CcCard {
        RowLayout {
            spacing: 12

            StyledText {
                text: DateTime.time
                font.pixelSize: 30
                font.family: Appearance.font.family.title
                color: Appearance.m3colors.m3primary
            }
            StyledText {
                Layout.fillWidth: true
                text: DateTime.longDate
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1Inactive
            }
        }
    }

    CcCard {
        CalendarWidget {
            Layout.alignment: Qt.AlignHCenter
        }
    }

    Item { Layout.fillHeight: true }
}
