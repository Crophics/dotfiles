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
    property alias leading: lead.data // icon or signal bars before the label
    property bool selected: false     // outlined in the accent colour (an open row)
    property bool clickable: false    // whole row acts as a button
    property bool popupOpen: false    // a dropdown inside is open: draw above the rows below
    z: popupOpen ? 100 : 0
    signal clicked()

    width: parent ? parent.width : 0
    height: Math.max(hint !== "" ? 52 : 44, labels.implicitHeight + 24, ctl.implicitHeight + 16)
    radius: Theme.radius
    color: hover.hovered ? Theme.alpha(Theme.accent, 0.05) : "transparent"
    border.width: 1
    border.color: selected ? Theme.accent : Theme.border
    opacity: enabled ? 1 : 0.4

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        enabled: row.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }

    Row {
        id: lead
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }

    Column {
        id: labels
        anchors.left: lead.right
        anchors.leftMargin: lead.children.length > 0 ? 12 : 0
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
        width: row.controlWidth > 0 ? row.controlWidth : implicitWidth
        spacing: 8
    }
}
