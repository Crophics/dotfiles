import QtQuick
import "../"

Rectangle {
    id: t
    property bool checked: false
    signal toggled(bool value)

    width: 40
    height: 22
    radius: 11
    color: checked ? Theme.alpha(Theme.accent, 0.25) : Theme.trackBg
    border.width: 1
    border.color: checked ? Theme.accent : Theme.border
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: t.checked ? parent.width - width - 4 : 4
        color: t.checked ? Theme.accent : Theme.textDim
        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: t.toggled(!t.checked)
    }
}
