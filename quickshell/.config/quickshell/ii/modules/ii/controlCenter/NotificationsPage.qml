import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.notifications
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 10

    NotificationList {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}
