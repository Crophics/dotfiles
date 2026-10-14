import QtQuick
import "../"

// A compact option inside a SetDetail: label and hint left, controls right.
Item {
    id: s
    property string label: ""
    property string hint: ""
    default property alias controls: ctl.data

    width: parent ? parent.width : 0
    height: Math.max(30, labels.implicitHeight + 6)

    Column {
        id: labels
        anchors.left: parent.left
        anchors.right: ctl.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text {
            width: parent.width
            text: s.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Text {
            visible: s.hint !== ""
            width: parent.width
            text: s.hint
            color: Theme.textFaint
            font.family: Theme.fontFamily
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }
    }
    Row {
        id: ctl
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }
}
