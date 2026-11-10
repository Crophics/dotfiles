import QtQuick
import "../"

Rectangle {
    id: b
    property string label: ""
    property bool primary: false
    signal clicked()

    width: text.implicitWidth + 24
    height: 26
    radius: Theme.radius
    color: area.containsMouse ? Theme.alpha(Theme.accent, primary ? 0.25 : 0.10)
                              : (primary ? Theme.alpha(Theme.accent, 0.15) : "transparent")
    border.width: 1
    border.color: primary || area.containsMouse ? Theme.accent : Theme.border
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Text {
        id: text
        anchors.centerIn: parent
        text: b.label.toUpperCase()
        color: b.primary || area.containsMouse ? Theme.accent : Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 1.5
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
