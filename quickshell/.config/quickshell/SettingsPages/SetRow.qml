import QtQuick
import "../"

// One setting: label (and optional hint) on the left, the control(s) on the right.
Rectangle {
    id: row
    property string label: ""
    property string hint: ""
    default property alias controls: ctl.data
    property real controlWidth: 0     // 0 = size to the controls
    property bool wrapHint: false     // let a long hint use more lines instead of eliding

    width: parent ? parent.width : 0
    height: Math.max(hint !== "" ? 52 : 44, labels.implicitHeight + 24)
    radius: Theme.radius
    color: hover.hovered ? Theme.alpha(Theme.accent, 0.05) : "transparent"
    border.width: 1
    border.color: Theme.border
    opacity: enabled ? 1 : 0.4

    HoverHandler { id: hover }

    Column {
        id: labels
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: ctl.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: row.label.toUpperCase()
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.letterSpacing: 1.5
            elide: Text.ElideRight
        }
        Text {
            visible: row.hint !== ""
            width: parent.width
            text: row.hint
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
            wrapMode: row.wrapHint ? Text.WordWrap : Text.NoWrap
            elide: row.wrapHint ? Text.ElideNone : Text.ElideRight
        }
    }

    Row {
        id: ctl
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: row.controlWidth > 0 ? row.controlWidth : childrenRect.width
        spacing: 8
    }
}
