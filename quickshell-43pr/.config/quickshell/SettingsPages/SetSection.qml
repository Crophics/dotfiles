import QtQuick
import "../"

// Small caps heading that groups related rows.
Item {
    property string text: ""
    width: parent ? parent.width : 0
    height: 30

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: parent.text.toUpperCase()
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 2.5
    }
}
